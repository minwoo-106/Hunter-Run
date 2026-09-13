import AVFoundation
import Foundation

final class LobbyMusicPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var effect: AVAudioPlayer?
    private var ownsSession = false
    private var routeBlocked = false
    private let request = AudioRequest()
    var onFailure: ((String) -> Void)?
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(secondaryAudio(_:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func allowPlayback() { AudioWorker.shared.enqueue { [self] in routeBlocked = false } }
    func play(volume: Float) {
        guard !AudioEnvironment.silentUITest else { return }
        let token = request.begin()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.request.expire(token) else { return }
            AudioWorker.shared.enqueue { self.stopCurrent() }
            self.onFailure?("BGM 출력 준비가 지연되어 중지했습니다. 소리 장치를 확인하고 앱을 다시 열어주세요.")
        }
        AudioWorker.shared.enqueue { [self] in
            guard request.valid(token) else { return }
            let session = AVAudioSession.sharedInstance()
            guard !routeBlocked, !session.isOtherAudioPlaying, !session.secondaryAudioShouldBeSilencedHint else { request.cancel(); stopCurrent(); return }
            if let player { player.volume = volume; _ = request.ready(token); return }
            guard let url = Bundle.main.url(forResource: "association-theme", withExtension: "wav", subdirectory: "Music") ?? Bundle.main.url(forResource: "association-theme", withExtension: "wav") else { request.cancel(); return }
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true); ownsSession = true
                let loop = try AVAudioPlayer(contentsOf: url)
                loop.numberOfLoops = -1; loop.volume = 0; player = loop
                guard request.valid(token) else { stopCurrent(); return }
                guard loop.play() else { request.cancel(); stopCurrent(); return }
                guard request.ready(token) else { stopCurrent(); return }
                loop.setVolume(volume, fadeDuration: 0.6)
            } catch { request.cancel(); stopCurrent(); onFailure?("협회 BGM을 재생하지 못했습니다.") }
        }
    }
    func stop() { request.cancel(); AudioWorker.shared.enqueue { [self] in stopCurrent() } }
    func playEffect(_ key: String, volume: Float) {
        guard volume > 0, !AudioEnvironment.silentUITest else { return }
        AudioWorker.shared.enqueue { [self] in
            let session = AVAudioSession.sharedInstance()
            guard !routeBlocked, !session.isOtherAudioPlaying,
                  let url = Bundle.main.url(forResource: key, withExtension: "wav", subdirectory: "Effects") ?? Bundle.main.url(forResource: key, withExtension: "wav") else { return }
            do {
                if !ownsSession {
                    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                    try session.setActive(true); ownsSession = true
                }
                effect?.stop()
                let cue = try AVAudioPlayer(contentsOf: url); effect = cue
                cue.volume = volume; cue.delegate = self
                if !cue.play() { effect = nil; if player == nil { stopCurrent() } }
            } catch { effect = nil; if player == nil { stopCurrent() } }
        }
    }
    func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        AudioWorker.shared.enqueue { [self] in
            guard effect === finished else { return }; effect = nil
            if player == nil { stopCurrent() }
        }
    }
    private func stopCurrent() {
        effect?.stop(); effect = nil
        player?.stop(); player = nil
        guard ownsSession else { return }; ownsSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func blockRoute() {
        request.cancel(); AudioWorker.shared.enqueue { [self] in routeBlocked = true; stopCurrent() }
    }
    @objc private func interrupted(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }; blockRoute()
    }
    @objc private func routeChanged(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }; blockRoute()
    }
    @objc private func secondaryAudio(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt) == AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue else { return }; stop()
    }
}
