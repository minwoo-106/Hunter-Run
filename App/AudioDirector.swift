import AVFoundation
import Foundation

final class AudioDirector: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var ownsSession = false
    private var completion: (() -> Void)?
    private var playingID: UUID?
    private let request = AudioRequest()
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
        let token = request.begin(), level = volume, shouldDuck = ducking
        if AudioEnvironment.silentUITest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                guard request.valid(token) else { return }; request.cancel(); completion?()
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.request.expire(token) else { return }
            AudioWorker.shared.enqueue { self.stopCurrent() }
            self.onFailure?("소리 출력 장치가 응답하지 않습니다. 이어폰 연결을 확인하고 앱을 다시 열어주세요.")
        }
        AudioWorker.shared.enqueue { [self] in
            guard request.valid(token) else { return }
            stopCurrent()
            guard let url = Bundle.main.url(forResource: key, withExtension: "wav", subdirectory: "Audio") ?? Bundle.main.url(forResource: key, withExtension: "wav") else {
                request.cancel(); onFailure?("안내 음성 파일을 찾을 수 없습니다: " + key); return
            }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: shouldDuck ? [.mixWithOthers, .duckOthers] : [.mixWithOthers])
                try session.setActive(true); ownsSession = true
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self; player?.volume = level; playingID = token
                self.completion = completion
                guard request.valid(token) else { stopCurrent(); return }
                guard player?.play() == true else { throw AudioFailure.playback }
                if !request.ready(token) { stopCurrent() }
            } catch { stopCurrent(); if request.valid(token) { request.cancel(); onFailure?("음성 재생을 시작하지 못했습니다.") } }
        }
    }
    enum AudioFailure: Error { case playback }
    func stop() { request.cancel(); AudioWorker.shared.enqueue { [self] in stopCurrent() } }
    private func stopCurrent() {
        completion = nil; playingID = nil
        player?.stop(); player = nil
        guard ownsSession else { return }; ownsSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        AudioWorker.shared.enqueue { [self] in
            guard player === finished, let token = playingID, request.valid(token) else { return }
            let callback = completion; request.cancel(); stopCurrent()
            if flag { callback?() } else { onFailure?("안내 음성이 중단되었습니다.") }
        }
    }
    func audioPlayerDecodeErrorDidOccur(_ failed: AVAudioPlayer, error: Error?) {
        AudioWorker.shared.enqueue { [self] in
            guard player === failed else { return }
            request.cancel(); stopCurrent(); onFailure?("안내 음성을 읽을 수 없습니다.")
        }
    }
    @objc private func interrupted(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }
        stop(); onInterruption?()
    }
    @objc private func routeChanged(_ notification: Notification) {
        guard (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        stop(); onInterruption?()
    }
}
