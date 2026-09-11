import AVFoundation
import Foundation

/// Owns only the lobby loop. Running instructions use AudioDirector separately.
final class LobbyMusicPlayer: NSObject {
    private var player: AVAudioPlayer?
    private var routeBlocked = false
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(secondaryAudio(_:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func allowPlayback() { routeBlocked = false }
    func play(volume: Float) {
        let session = AVAudioSession.sharedInstance()
        guard !routeBlocked, !session.isOtherAudioPlaying, !session.secondaryAudioShouldBeSilencedHint else { stop(); return }
        if let player { player.volume = volume; return }
        guard let url = Bundle.main.url(forResource: "association-theme", withExtension: "wav", subdirectory: "Music") ?? Bundle.main.url(forResource: "association-theme", withExtension: "wav") else { return }
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let loop = try AVAudioPlayer(contentsOf: url)
            loop.numberOfLoops = -1; loop.volume = 0; player = loop
            guard loop.play() else { stop(); return }
            loop.setVolume(volume, fadeDuration: 0.6)
        } catch { stop() }
    }
    func stop() {
        // Do not deactivate the shared audio session when an instruction owns it.
        guard let player else { return }
        player.stop(); self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    @objc private func interrupted(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }
        routeBlocked = true; stop()
    }
    @objc private func routeChanged(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        routeBlocked = true; stop()
    }
    @objc private func secondaryAudio(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt) == AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue else { return }
        stop()
    }
}
