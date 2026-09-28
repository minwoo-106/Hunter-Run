import Foundation
import CoreLocation
import CoreMotion

final class SensorProbe: NSObject, CLLocationManagerDelegate {
    let location = CLLocationManager()
    let motion = CMMotionActivityManager()
    let pedometer = CMPedometer()
    let deviceMotion = CMMotionManager()
    private var environment: ActivityEnvironment = .outdoor
    private var indoor = IndoorMovementTracker()
    private var totalSteps = 0
    private var pendingSteps = 0
    private var stepCallbackAt = Date()
    private var generation = UUID()
    var indoorAvailable: Bool { CMPedometer.isStepCountingAvailable() || deviceMotion.isDeviceMotionAvailable }
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
    private var pendingDistanceDuration: TimeInterval = 0
    private var pendingStepsDistance: Double = 0
    private var pendingStepsDuration: TimeInterval = 0
    private var stepsDistance: Double = 0
    private var stepsAt = Date.distantPast
    private var stepsSpeed: Double = 0
    private var velocity = GPSVelocityWindow()
    private var outdoorDistance = OutdoorDistanceAccumulator()
    private(set) var acceptedGPSMeters: Double = 0
    private(set) var comparableGPSMeters: Double = 0
    private(set) var comparableVelocityMeters: Double = 0
    private(set) var comparableSeconds: Double = 0
    private(set) var gpsFixCount = 0
    private var gpsAccuracyTotal: Double = 0
    var averageGPSAccuracy: Double? { gpsFixCount > 0 ? gpsAccuracyTotal / Double(gpsFixCount) : nil }
    private var active = false
    private var sessionStartedAt = Date.distantPast
    var outdoorSignalHint: String {
        if permission != .authorizedAlways && permission != .authorizedWhenInUse { return "위치 권한을 확인해주세요." }
        if !precision { return "iPhone 설정에서 정확한 위치를 켜주세요." }
        guard let fix = latestFix else { return "GPS 위치를 찾는 중이에요. 하늘이 보이는 곳에서 잠시 기다려주세요." }
        if Date().timeIntervalSince(fix.timestamp) > 5 { return "최근 GPS 신호가 없어요. 잠시 위치를 다시 확인할게요." }
        if fix.horizontalAccuracy.isFinite && fix.horizontalAccuracy > 35 && fix.horizontalAccuracy < 10_000 {
            return "현재 위치 오차가 약 \(Int(fix.horizontalAccuracy))m예요. 신호가 좋아지면 토벌을 진행해요."
        }
        return "GPS 위치를 확인하고 있어요."
    }
    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .fitness
        location.pausesLocationUpdatesAutomatically = false
    }
    func requestPermission() { location.requestWhenInUseAuthorization() }
    func start(environment: ActivityEnvironment = .outdoor) {
        stop()
        self.environment = environment
        let token = UUID(); generation = token
        indoor.reset(); totalSteps = 0; pendingSteps = 0; stepCallbackAt = Date()
        active = true; sessionStartedAt = Date(); latestFix = nil; velocity.reset(); outdoorDistance.reset(); pendingDistance = 0
        acceptedGPSMeters = 0; comparableGPSMeters = 0; comparableVelocityMeters = 0; comparableSeconds = 0
        gpsFixCount = 0; gpsAccuracyTotal = 0
        pendingDistanceDuration = 0; stepsDistance = 0; pendingStepsDistance = 0; pendingStepsDuration = 0; stepsAt = .distantPast; motionAt = .distantPast
        motionValue = .unknown; speed = 0; signal = .unavailable
        if !environment.isIndoor {
            location.allowsBackgroundLocationUpdates = true
            location.showsBackgroundLocationIndicator = true
            location.startUpdatingLocation()
        } else if deviceMotion.isDeviceMotionAvailable {
            deviceMotion.deviceMotionUpdateInterval = 1.0 / 25
            deviceMotion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, self.active, self.generation == token, let data else { return }
                let a = data.userAcceleration
                self.indoor.observeAcceleration(sqrt(a.x * a.x + a.y * a.y + a.z * a.z), at: Date().timeIntervalSince1970)
            }
        }
        if CMMotionActivityManager.isActivityAvailable() {
            motion.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, self.active, self.generation == token, let activity else { return }
                // startDate is when this activity began, not when Core Motion
                // delivered the classification. Long runs otherwise look stale.
                self.motionAt = Date()
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
                    guard let self, self.active, self.generation == token else { return }
                    self.motionPermission = CMPedometer.authorizationStatus()
                    guard let data else { return }
                    let count = data.numberOfSteps.intValue
                    let added = max(0, count - self.totalSteps)
                    self.pendingSteps += added; self.totalSteps = count
                    let now = Date()
                    let callbackElapsed = max(0, now.timeIntervalSince(self.stepCallbackAt))
                    if now.timeIntervalSince(data.endDate) <= 3 {
                        self.indoor.observeSteps(count: added, elapsed: callbackElapsed, at: now.timeIntervalSince1970)
                    }
                    self.stepCallbackAt = now
                    let total = data.distance?.doubleValue ?? self.stepsDistance
                    let addedDistance = max(0, total - self.stepsDistance)
                    self.pendingStepsDistance += addedDistance
                    if addedDistance > 0 { self.pendingStepsDuration += callbackElapsed }
                    self.stepsDistance = total; self.stepsAt = data.endDate
                    if let pace = data.currentPace?.doubleValue, pace > 0 { self.stepsSpeed = 1 / pace }
                }
            }
        }
    }
    func stop() {
        active = false; location.stopUpdatingLocation(); motion.stopActivityUpdates(); pedometer.stopUpdates()
        generation = UUID(); deviceMotion.stopDeviceMotionUpdates(); indoor.reset(); pendingSteps = 0
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
            guard fix.timestamp >= sessionStartedAt, fix.horizontalAccuracy >= 0, now.timeIntervalSince(fix.timestamp) < 60,
                  now.timeIntervalSince(fix.timestamp) >= -1 else { continue }
            if let old = latestFix, fix.timestamp <= old.timestamp { continue }
            let previousFix = latestFix
            let meters = previousFix.map { fix.distance(from: $0) }
            let accepted = outdoorDistance.observe(
                timestamp: fix.timestamp.timeIntervalSince1970,
                horizontalAccuracy: fix.horizontalAccuracy,
                distanceFromPrevious: meters
            )
            pendingDistance += accepted
            pendingDistanceDuration += outdoorDistance.lastAcceptedDuration
            acceptedGPSMeters += accepted
            gpsFixCount += 1; gpsAccuracyTotal += fix.horizontalAccuracy
            // Aggregate-only comparison for diagnosing path jitter; no coordinates
            // or individual location samples are written to diagnostics.
            if let previousFix, outdoorDistance.lastAcceptedDuration > 0,
               (0...8).contains(previousFix.speed), (0...8).contains(fix.speed),
               (0...1).contains(previousFix.speedAccuracy), (0...1).contains(fix.speedAccuracy) {
                let elapsed = outdoorDistance.lastAcceptedDuration
                comparableGPSMeters += accepted
                comparableVelocityMeters += (previousFix.speed + fix.speed) * elapsed / 2
                comparableSeconds += elapsed
            }
            latestFix = fix
            velocity.observe(time: fix.timestamp.timeIntervalSince1970, speed: fix.speed, accuracy: fix.speedAccuracy)
        }
        onUpdate?()
    }
    func frame(at date: Date) -> SensorFrame {
        if environment.isIndoor {
            let denied = CMPedometer.authorizationStatus() == .denied || CMPedometer.authorizationStatus() == .restricted
            let vehicle = date.timeIntervalSince(motionAt) <= 15 && motionValue == .vehicle
            let moving = active && !denied && !vehicle && indoor.isMoving(at: date.timeIntervalSince1970)
            movement = vehicle ? .vehicle : moving ? .walking : .stationary
            signal = moving ? .good : .unavailable; speed = 0
            let steps = pendingSteps; pendingSteps = 0
            return SensorFrame(timestamp: date.timeIntervalSince1970, speed: 0, distance: 0, movement: movement, signal: signal, steps: steps)
        }
        let fixAge = latestFix.map { date.timeIntervalSince($0.timestamp) }
        let freshFix = fixAge.map { (0...5).contains($0) } ?? false
        let freshMotion = date.timeIntervalSince(motionAt) <= 15
        let freshSteps = date.timeIntervalSince(stepsAt) <= 8
        let quality = latestFix?.horizontalAccuracy ?? -1
        let gpsSpeed = velocity.speed(at: date.timeIntervalSince1970)
        signal = OutdoorSignalQuality.classify(fixAge: fixAge, horizontalAccuracy: quality, precise: precision)
        let rawSpeed = freshFix ? (latestFix?.speed ?? -1) : -1
        let runSpeed = freshFix && signal == .good && OutdoorSignalQuality.credibleRunningSpeed(rawSpeed, accuracy: latestFix?.speedAccuracy ?? -1)
        // A moderately accurate running velocity is useful for event scoring
        // even when it is too uncertain for the strict pace-only window.
        speed = freshFix ? (gpsSpeed ?? (runSpeed ? rawSpeed : freshSteps ? stepsSpeed : 0)) : freshSteps ? stepsSpeed : 0
        movement = OutdoorMovementClassifier.classify(motion: freshMotion ? motionValue : nil,
            rawSpeed: rawSpeed, speed: speed, credibleRunning: runSpeed,
            hasRecentFix: freshFix, hasRecentSteps: freshSteps)
        if movement == .stationary || movement == .vehicle { velocity.reset() }
        let useSteps = signal == .unavailable && freshSteps
        let meters = useSteps ? pendingStepsDistance : signal == .unavailable ? 0 : pendingDistance
        let distanceDuration = useSteps ? pendingStepsDuration : signal == .unavailable ? 0 : pendingDistanceDuration
        pendingDistance = 0; pendingDistanceDuration = 0; pendingStepsDistance = 0; pendingStepsDuration = 0
        return SensorFrame(timestamp: date.timeIntervalSince1970, speed: speed, distance: meters, movement: movement,
                           signal: signal, distanceDuration: distanceDuration > 0 ? distanceDuration : nil)
    }
}
