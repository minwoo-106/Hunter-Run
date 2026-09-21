import Foundation
import CoreFoundation

/// Own audio APIs on a non-UI run loop so hardware delays never freeze SwiftUI.
final class AudioWorker {
    static let shared = AudioWorker()
    private let lock = NSLock()
    private var loop: CFRunLoop?
    private var pending: [() -> Void] = []
    private var thread: Thread!
    private init() {
        thread = Thread { [self] in
            let current = CFRunLoopGetCurrent()!
            let keepAlive = Timer(timeInterval: 3600, repeats: true) { _ in }
            RunLoop.current.add(keepAlive, forMode: .default)
            lock.lock(); let tasks = pending; pending = []
            for task in tasks { schedule(on: current, task) }
            loop = current; lock.unlock()
            while true {
                #if canImport(ObjectiveC)
                autoreleasepool { _ = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 3600, true) }
                #else
                _ = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 3600, true)
                #endif
            }
        }
        thread.name = "HunterRun.Audio"; thread.qualityOfService = .userInitiated; thread.start()
    }
    func enqueue(_ task: @escaping () -> Void) {
        lock.lock()
        guard let loop else { pending.append(task); lock.unlock(); return }
        lock.unlock()
        schedule(on: loop, task); CFRunLoopWakeUp(loop)
    }
    private func schedule(on loop: CFRunLoop, _ task: @escaping () -> Void) {
        #if canImport(ObjectiveC)
        CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode!.rawValue, task)
        #else
        CFRunLoopPerformBlock(loop, kCFRunLoopDefaultMode!, task)
        #endif
    }
}

/// Cancellation remains available while an OS call is waiting for hardware.
final class AudioRequest {
    private let lock = NSLock()
    private var id: UUID?
    private var preparing = false
    func begin() -> UUID { lock.lock(); defer { lock.unlock() }; let next = UUID(); id = next; preparing = true; return next }
    func cancel() { lock.lock(); defer { lock.unlock() }; id = nil; preparing = false }
    func valid(_ token: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; return id == token }
    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return id != nil }
    func ready(_ token: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; guard id == token else { return false }; preparing = false; return true }
    func expire(_ token: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; guard id == token, preparing else { return false }; id = nil; preparing = false; return true }
}

enum AudioEnvironment {
    static var silentUITest: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--ui-testing-silent-audio")
        #else
        return false
        #endif
    }
}
