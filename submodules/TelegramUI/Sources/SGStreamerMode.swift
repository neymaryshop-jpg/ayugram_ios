import Foundation
import UIKit
import SGSimpleSettings

// MARK: Swiftgram — streamer mode: скрытие содержимого при захвате экрана
// (AyuGram: ayu/features/streamer_mode/streamer_mode.cpp SetWindowCaptureExcluded;
// iOS не имеет аналога NSWindowSharingNone — при активной записи экрана содержимое
// приложения закрывается заглушкой, как при исключении окна из захвата на десктопе)

public final class SGStreamerMode {
    public static let shared = SGStreamerMode()

    private var overlayView: UIView?
    private var isSubscribed = false

    private var shouldShowOverlay: Bool {
        return SGSimpleSettings.shared.streamerMode && UIScreen.main.isCaptured
    }

    private init() {
    }

    public func start() {
        guard !self.isSubscribed else {
            return
        }
        self.isSubscribed = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.captureStateChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.captureStateChanged), name: UserDefaults.didChangeNotification, object: nil)
        self.apply()
    }

    @objc private func captureStateChanged() {
        self.apply()
    }

    private func apply() {
        UIApplication.shared.isIdleTimerDisabled = SGSimpleSettings.shared.streamerMode
        if self.shouldShowOverlay {
            self.ensureOverlay()
            self.overlayView?.isHidden = false
        } else if let overlayView = self.overlayView {
            overlayView.isHidden = true
        }
    }

    private func ensureOverlay() {
        if self.overlayView == nil, let window = self.mainWindow() {
            let overlay = UIView(frame: window.bounds)
            overlay.backgroundColor = UIColor.black
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let label = UILabel()
            label.text = "Streamer Mode"
            label.textColor = UIColor.white
            label.font = UIFont.systemFont(ofSize: 22.0, weight: .semibold)
            label.textAlignment = .center
            label.frame = window.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.addSubview(label)
            window.addSubview(overlay)
            window.bringSubviewToFront(overlay)
            self.overlayView = overlay
        }
    }

    private func mainWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
    }
}