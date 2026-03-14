import Foundation
import Combine

class TimerManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var intervalMinutes: Double {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes")
            if isRunning, let am = currentAudioManager {
                stop()
                start(audioManager: am)
            }
        }
    }

    private var timer: Timer?
    private var countdownTimer: Timer?
    private var nextFireDate: Date?
    private weak var currentAudioManager: AudioManager?

    var formattedTimeRemaining: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "intervalMinutes")
        self.intervalMinutes = saved > 0 ? saved : 10
    }

    func start(audioManager: AudioManager) {
        stopTimers()
        currentAudioManager = audioManager
        isRunning = true

        let interval = intervalMinutes * 60
        nextFireDate = Date().addingTimeInterval(interval)
        timeRemaining = interval

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            audioManager.performMuteUnmuteCycle()
            self?.nextFireDate = Date().addingTimeInterval(interval)
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let fire = self.nextFireDate else { return }
            let remaining = fire.timeIntervalSinceNow
            self.timeRemaining = max(remaining, 0)
        }
    }

    func stop() {
        stopTimers()
        isRunning = false
        timeRemaining = 0
        nextFireDate = nil
    }

    func toggle(audioManager: AudioManager) {
        isRunning ? stop() : start(audioManager: audioManager)
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
