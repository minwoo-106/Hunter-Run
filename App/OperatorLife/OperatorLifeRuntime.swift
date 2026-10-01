import SwiftUI
import os
import Darwin

@MainActor final class OperatorLifeRuntime: ObservableObject {
    @Published private(set) var phase: LifePhase
    @Published private(set) var cue: String?
    @Published private(set) var animating = false
#if DEBUG && targetEnvironment(simulator)
    @Published private(set) var testingActiveTime: TimeInterval?
    @Published private(set) var testingVisitedPhases: [LifePhase] = []
    private var exposesHistory = false
    var testingAccessibilityValue: String {
        if exposesHistory {
            return phase.rawValue + "|seen=," + testingVisitedPhases.map(\.rawValue).joined(separator: ",") + ","
        }
        return testingActiveTime.map { phase.rawValue + "|" + String($0) } ?? phase.rawValue
    }
#endif
    private var machine: LifeStateMachine
    private var lastTick: TimeInterval?
    private var ticker: Task<Void, Never>?
    private var inspecting = false
    private let configurationLoaded: Bool
    private var renderWindow: Date?
    private var scheduledFrames = 0
    private let log = Logger(subsystem: "com.hunterrun.demo", category: "OperatorLife")

    init() {
        let loaded = Bundle.main.url(forResource: "operator-life-cues", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? LifeSequence.decode($0) }
        configurationLoaded = loaded != nil
        let sequence = loaded ?? .standby
        machine = LifeStateMachine(sequence: sequence, initialPhase: loaded == nil ? .idle : .stretching)
#if DEBUG && targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--life-inspect-clock") { testingActiveTime = 0 }
        if let index = args.firstIndex(of: "--life-inspect-phase"), index + 1 < args.count,
           let initial = LifePhase(rawValue: args[index + 1]) {
            machine = LifeStateMachine(sequence: sequence, initialPhase: initial, initialElapsed: initial == .dozing ? 5 : 1.2)
            inspecting = true
        } else if let index = args.firstIndex(of: "--life-start-phase"), index + 1 < args.count,
                  let initial = LifePhase(rawValue: args[index + 1]) {
            machine = LifeStateMachine(sequence: sequence, initialPhase: initial)
        }
#endif
        phase = machine.phase
#if DEBUG && targetEnvironment(simulator)
        if args.contains("--life-inspect-history") {
            exposesHistory = true
            testingVisitedPhases = [machine.phase]
        }
#endif
    }
    deinit { ticker?.cancel() }
    func configure(available: Bool, motionEnabled: Bool, reducedMotion: Bool) {
        tick()
        let enabled = motionEnabled && configurationLoaded
        machine.configure(available: available && !inspecting, motionEnabled: enabled, reducedMotion: reducedMotion)
        animating = available && enabled && !reducedMotion && !inspecting
        lastTick = ProcessInfo.processInfo.systemUptime
        publish()
        ticker?.cancel(); ticker = nil
        renderWindow = nil; scheduledFrames = 0
        guard available && enabled && !inspecting else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }
    func consumeTap() -> Bool {
        tick()
        let consumed = machine.consumeTap()
        publish()
        return consumed
    }
    func renderFrame() -> LifeRenderFrame {
        var projected = machine
        if let lastTick { projected.advance(min(0.15, max(0, ProcessInfo.processInfo.systemUptime - lastTick))) }
        return projected.frame
    }
    func observeRenderTick(_ date: Date) {
#if DEBUG
        guard animating else { return }
        guard let start = renderWindow else { renderWindow = date; return }
        scheduledFrames += 1
        let elapsed = date.timeIntervalSince(start)
        if elapsed >= 5 {
            // Timeline callback cadence, NOT a GPU presentation/FPS measurement.
            let cadence = Double(scheduledFrames) / elapsed
            let memory = footprintMiB()
            log.info("Render schedule Hz: \(cadence); process footprint MiB: \(memory); thermalState: \(ProcessInfo.processInfo.thermalState.rawValue)")
            renderWindow = date; scheduledFrames = 0
        }
#endif
    }
    private func footprintMiB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastTick { machine.advance(max(0, now - lastTick)) }
        lastTick = now
        publish()
    }
    private func publish() {
        if phase != machine.phase {
            phase = machine.phase
#if DEBUG && targetEnvironment(simulator)
            // Retain only phases actually published by the live runtime. Short
            // poses must remain observable when an XCTest AX snapshot is slow.
            if exposesHistory { testingVisitedPhases.append(phase) }
#endif
            log.info("Phase: \(self.phase.rawValue, privacy: .public); thermalState: \(ProcessInfo.processInfo.thermalState.rawValue)")
        }
        if cue != machine.cue { cue = machine.cue }
#if DEBUG && targetEnvironment(simulator)
        if testingActiveTime != nil, testingActiveTime != machine.activeTime {
            testingActiveTime = machine.activeTime
        }
#endif
    }
}

protocol OperatorLifeRendering: View {
    init(frame: LifeRenderFrame, animating: Bool)
}

// This host owns the sole rendering clock. No second OperatorPortrait is layered
// underneath it, so breathing/blinking and the authored reaction cannot compete.
struct OperatorLifeStage<Renderer: OperatorLifeRendering>: View {
    @ObservedObject var runtime: OperatorLifeRuntime
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !runtime.animating)) { context in
            Renderer(frame: runtime.renderFrame(), animating: runtime.animating)
                .onChange(of: context.date) { _, date in runtime.observeRenderTick(date) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
