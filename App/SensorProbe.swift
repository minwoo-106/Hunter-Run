import Foundation
import CoreLocation
import CoreMotion

final class SensorProbe: NSObject, CLLocationManagerDelegate {
    let location = CLLocationManager()
    let motion = CMMotionActivityManager()
    let pedometer = CMPedometer()
    var onUpdate: (() -> Void)?
    private(set) var permission: CLAuthorizationStatus = .notDetermined
    private(set) var motionPermission: CMAuthorizationStatus = .notDetermined
    private(set) var precision = false
    private(set) var speed: Double = 0
    private(set) var signal: Signal = .unavailable
    private(set) var movement: Movement = .unknown
    private(set) var lastError: String?
    private var latestFix: CLLocation?
    private var motionAt = Date.distantPast
    private var motionValue: Movement = .unknown
    private var pendingDistance: Double = 0
    private var pendingStepsDistance: Double = 0
    private var stepsDistance: Double = 0
    private var stepsAt = Date.distantPast
    private var stepsSpeed: Double = 0
    private var speeds: [(Date, Double)] = []
    private var active = false
    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .fitness
        location.pausesLocationUpdatesAutomatically = false
    }
    func requestPermission() { location.requestWhenInUseAuthorization() }
    func start() {
        active = true; latestFix = nil; speeds = []; pendingDistance = 0
        stepsDistance = 0; pendingStepsDistance = 0; stepsAt = .distantPast; motionAt = .distantPast
        motionValue = .unknown; speed = 0; signal = .unavailable
        location.allowsBackgroundLocationUpdates = true
        location.showsBackgroundLocationIndicator = true
        location.startUpdatingLocation()
        if CMMotionActivityManager.isActivityAvailable() {
            motion.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, let activity else { return }
                self.motionAt = activity.startDate
                if activity.confidence == .high && (activity.automotive || activity.cycling) { self.motionValue = .vehicle }
                else if activity.confidence != .low && activity.running { self.motionValue = .running }
                else if activity.confidence != .low && activity.walking { self.motionValue = .walking }
                else if activity.confidence != .low && activity.stationary { self.motionValue = .stationary }
                else { self.motionValue = .unknown }
                self.motionPermission = CMMotionActivityManager.authorizationStatus()
            }
        }
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                DispatchQueue.main.async {
                    guard let self, self.active else { return }
                    self.motionPermission = CMPedometer.authorizationStatus()
                    guard let data else { return }
                    let total = data.distance?.doubleValue ?? self.stepsDistance
                    self.pendingStepsDistance += max(0, total - self.stepsDistance)
                    self.stepsDistance = total; self.stepsAt = data.endDate
                    if let pace = data.currentPace?.doubleValue, pace > 0 { self.stepsSpeed = 1 / pace }
                }
            }
        }
    }
    func stop() {
        active = false; location.stopUpdatingLocation(); motion.stopActivityUpdates(); pedometer.stopUpdates()
        location.allowsBackgroundLocationUpdates = false
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permission = manager.authorizationStatus
        precision = manager.accuracyAuthorization == .fullAccuracy
        onUpdate?()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard active else { return }
        let now = Date()
        for fix in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard fix.horizontalAccuracy >= 0, now.timeIntervalSince(fix.timestamp) < 10,
                  now.timeIntervalSince(fix.timestamp) >= -1 else { continue }
            if let old = latestFix, fix.timestamp <= old.timestamp { continue }
            if let old = latestFix {
                let dt = fix.timestamp.timeIntervalSince(old.timestamp)
                let meters = fix.distance(from: old)
                if dt > 0 && dt <= 5 && fix.horizontalAccuracy <= 60 && old.horizontalAccuracy <= 60 && meters <= 8 * dt {
                    pendingDistance += meters
                }
            }
            latestFix = fix
            if fix.speed >= 0 && fix.speed <= 8 && fix.speedAccuracy >= 0 && fix.speedAccuracy <= 1.5 {
                speeds.append((fix.timestamp, fix.speed))
            }
            speeds.removeAll { fix.timestamp.timeIntervalSince($0.0) > 7 }
        }
        onUpdate?()
    }
    func frame(at date: Date) -> SensorFrame {
        let freshFix = latestFix.map { date.timeIntervalSince($0.timestamp) <= 5 } ?? false
        let freshMotion = date.timeIntervalSince(motionAt) <= 15
        let freshSteps = date.timeIntervalSince(stepsAt) <= 8
        let quality = latestFix?.horizontalAccuracy ?? -1
        signal = freshFix && precision && quality >= 0 && quality <= 35 && !speeds.isEmpty ? .good :
                 freshFix && quality >= 0 && quality <= 60 ? .degraded : .unavailable
        let freshSpeeds = speeds.filter { date.timeIntervalSince($0.0) <= 7 }.map { $0.1 }.sorted()
        speed = freshFix && !freshSpeeds.isEmpty ? freshSpeeds[freshSpeeds.count / 2] : freshSteps ? stepsSpeed : 0
        let rawSpeed = freshFix ? (latestFix?.speed ?? -1) : -1
        if freshMotion && motionValue == .vehicle || rawSpeed > 8 { movement = .vehicle }
        else if freshMotion && motionValue == .stationary && rawSpeed < 0.8 { movement = .stationary }
        else if rawSpeed >= 0 && rawSpeed < 0.35 { movement = .stationary }
        else if speed >= 0.5 && (freshFix || freshSteps) {
            movement = freshMotion && motionValue == .running ? .running : speed >= 1.8 ? .running : .walking
        } else { movement = freshFix || freshMotion ? .stationary : .unknown }
        let meters = signal == .unavailable ? (freshSteps ? pendingStepsDistance : 0) : pendingDistance
        pendingDistance = 0; pendingStepsDistance = 0
        return SensorFrame(timestamp: date.timeIntervalSince1970, speed: speed, distance: meters, movement: movement, signal: signal)
    }
}

