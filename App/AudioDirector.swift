import AVFoundation
import Foundation

final class AudioDirector: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?
    var onInterruption: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var ducking = true
    var volume: Float = 0.85
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func play(_ key: String, completion: (() -> Void)? = nil) {
        stop()
        guard let url = Bundle.main.url(forResource: key, withExtension: "wav", subdirectory: "Audio") ??
                Bundle.main.url(forResource: key, withExtension: "wav") else {
            onFailure?("안내 음성 파일을 찾을 수 없습니다: " + key); return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: ducking ? [.mixWithOthers, .duckOthers] : [.mixWithOthers])
            try session.setActive(true)
            self.completion = completion
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self; player?.volume = volume
            guard player?.play() == true else { throw AudioFailure.playback }
        } catch { stop(); onFailure?("음성 재생을 시작하지 못했습니다.") }
    }
    enum AudioFailure: Error { case playback }
    func stop() {
        completion = nil; player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let callback = completion
        stop()
        if flag { callback?() } else { onFailure?("안내 음성이 중단되었습니다.") }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stop(); onFailure?("안내 음성을 읽을 수 없습니다.")
    }
    @objc private func interrupted(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              value == AVAudioSession.InterruptionType.began.rawValue else { return }
        stop(); onInterruption?()
    }
    @objc private func routeChanged(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              value == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        stop(); onInterruption?()
    }
}

