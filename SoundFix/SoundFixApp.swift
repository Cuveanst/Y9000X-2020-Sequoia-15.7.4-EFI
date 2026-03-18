import ServiceManagement
import SwiftUI

@main
struct SoundFixApp: App {
    @StateObject private var audioManager: AudioManager
    @StateObject private var timerManager: TimerManager
    @StateObject private var offlineRepairManager: OfflineRepairManager
    @StateObject private var loginLaunchManager: LoginLaunchManager

    init() {
        let audioManager = AudioManager()
        let timerManager = TimerManager()
        let offlineRepairManager = OfflineRepairManager()
        let loginLaunchManager = LoginLaunchManager()

        _audioManager = StateObject(wrappedValue: audioManager)
        _timerManager = StateObject(wrappedValue: timerManager)
        _offlineRepairManager = StateObject(wrappedValue: offlineRepairManager)
        _loginLaunchManager = StateObject(wrappedValue: loginLaunchManager)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard loginLaunchManager.shouldRunStartupRepairNow() else { return }

            offlineRepairManager.refreshStatus()
            if offlineRepairManager.isInstalled {
                offlineRepairManager.restart()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                audioManager.performMuteUnmuteCycle()
                loginLaunchManager.markStartupRepairPerformedForCurrentBoot()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(audioManager)
                .environmentObject(timerManager)
                .environmentObject(offlineRepairManager)
                .environmentObject(loginLaunchManager)
        } label: {
            Image(systemName: menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(audioManager)
                .environmentObject(timerManager)
                .environmentObject(offlineRepairManager)
                .environmentObject(loginLaunchManager)
        }
    }

    private var menuBarSymbolName: String {
        if audioManager.isMuted || audioManager.volume <= 0.001 {
            return "speaker.slash.fill"
        }

        if audioManager.volume < 0.33 {
            return "speaker.wave.1.fill"
        }

        if audioManager.volume < 0.66 {
            return "speaker.wave.2.fill"
        }

        return "speaker.wave.3.fill"
    }
}

// MARK: - Menu Bar Content View

struct MenuBarContentView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var offlineRepairManager: OfflineRepairManager
    @EnvironmentObject var loginLaunchManager: LoginLaunchManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SoundFix")
                    .font(.system(size: 15, weight: .semibold))

                StatusCard(
                    title: statusTitle,
                    subtitle: statusSubtitle,
                    accentColor: statusColor
                )

                HeroActionButton(
                    title: audioManager.isProcessing ? "Repair In Progress" : "Fix Audio Now",
                    subtitle: repairButtonSubtitle,
                    systemImage: audioManager.isProcessing ? "waveform" : "wrench.and.screwdriver.fill",
                    tint: audioManager.isProcessing ? .orange : .blue,
                    isDisabled: audioManager.isProcessing
                ) {
                    audioManager.performMuteUnmuteCycle()
                }

                Button {
                    timerManager.toggle(audioManager: audioManager)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: timerManager.isRunning ? "checkmark.circle.fill" : "clock.badge.xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(timerManager.isRunning ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(timerManager.isRunning ? "Auto Repair Enabled" : "Auto Repair Disabled")
                                .font(.system(size: 13, weight: .semibold))
                            Text(timerManager.isRunning
                                ? "Next refresh in \(timerManager.formattedTimeRemaining)"
                                : "Run the mute cycle automatically on a schedule")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Spacer()

                        Text(timerManager.isRunning ? "Stop" : "Start")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(timerManager.isRunning ? .red : .green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            SectionDivider()

            // MARK: Sound + Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("Sound")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.leading, 2)

                CapsuleVolumeSlider(
                    volume: $audioManager.volume,
                    isMuted: audioManager.isMuted,
                    onVolumeChange: { audioManager.setVolume($0, interactive: true) },
                    onInteractionChanged: { isDragging in
                        if isDragging {
                            audioManager.beginVolumeInteraction()
                        } else {
                            audioManager.endVolumeInteraction()
                        }
                    },
                    onToggleMute: { audioManager.setMute(!audioManager.isMuted) }
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)

            SectionDivider()

            // MARK: Output
            VStack(alignment: .leading, spacing: 0) {
                Text("Output")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.leading, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ForEach(audioManager.outputDevices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: device.id == audioManager.currentDeviceID,
                        icon: deviceIcon(for: device)
                    ) {
                        audioManager.setDefaultOutputDevice(device.id)
                    }
                }
            }
            .padding(.bottom, 6)

            SectionDivider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Deep Fix")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.leading, 16)
                    .padding(.top, 10)

                Text(offlineRepairManager.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    SmallActionButton(
                        title: "Restart",
                        tint: .green,
                        isDisabled: offlineRepairManager.isRunning || !offlineRepairManager.isInstalled
                    ) {
                        offlineRepairManager.restart()
                    }

                    SmallActionButton(
                        title: offlineRepairManager.isInstalled ? "Reinstall" : "Install",
                        tint: .blue,
                        isDisabled: offlineRepairManager.isRunning
                    ) {
                        offlineRepairManager.install()
                    }

                    SmallActionButton(
                        title: "Remove",
                        tint: .red,
                        isDisabled: offlineRepairManager.isRunning || !offlineRepairManager.isInstalled
                    ) {
                        offlineRepairManager.uninstall()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            SectionDivider()

            // MARK: Footer
            VStack(alignment: .leading, spacing: 0) {
                MenuRow(
                    title: offlineRepairManager.isRunning ? "Finish Deep Fix Before Opening Settings" : "Sound Settings...",
                    icon: "slider.horizontal.3",
                    isDisabled: offlineRepairManager.isRunning
                ) {
                    openSettings()
                }
                MenuRow(title: "Quit SoundFix", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 310)
        .onAppear {
            offlineRepairManager.refreshStatus()
        }
    }

    private var currentDeviceName: String {
        audioManager.outputDevices.first(where: { $0.id == audioManager.currentDeviceID })?.name ?? "current output"
    }

    private var statusTitle: String {
        switch audioManager.repairState {
        case .running:
            return "Repairing audio..."
        case .failed:
            return "Repair Needs Attention"
        case .idle:
            return "Y9000X Audio Repair"
        }
    }

    private var statusSubtitle: String {
        switch audioManager.repairState {
        case .running:
            return "Running the mute cycle on \(currentDeviceName)"
        case .failed(let message):
            return message
        case .idle:
            return timerManager.isRunning
                ? "Auto repair every \(Int(timerManager.intervalMinutes)) min on \(currentDeviceName)"
                : "Ready to refresh audio on \(currentDeviceName)"
        }
    }

    private var statusColor: Color {
        switch audioManager.repairState {
        case .running:
            return .orange
        case .failed:
            return .red
        case .idle:
            return .blue
        }
    }

    private var repairButtonSubtitle: String {
        switch audioManager.repairState {
        case .running:
            return "Trying the system mute toggle with AppleScript"
        case .failed:
            return "Mute toggle timed out. Try Deep Fix if this output keeps hanging."
        case .idle:
            return "Uses the system mute toggle, then restores your previous state"
        }
    }

    private func deviceIcon(for device: AudioDevice) -> String {
        let name = device.name.lowercased()
        if name.contains("headphone") || name.contains("airpod") {
            return "headphones"
        } else if name.contains("bluetooth") || name.contains("boom") {
            return "speaker.wave.2.fill"
        } else if name.contains("hdmi") || name.contains("displayport") || name.contains("display") || name.contains("monitor") {
            return "display"
        } else if name.contains("internal") || name.contains("built-in") || name.contains("speaker") || name.contains("macbook") {
            return "laptopcomputer"
        } else {
            return "hifispeaker"
        }
    }
}

// MARK: - Capsule Volume Slider (matches macOS system style)

struct CapsuleVolumeSlider: NSViewRepresentable {
    @Binding var volume: Float
    var isMuted: Bool
    var onVolumeChange: (Float) -> Void
    var onInteractionChanged: (Bool) -> Void
    var onToggleMute: () -> Void

    func makeNSView(context: Context) -> CapsuleSliderView {
        let view = CapsuleSliderView()
        view.applyExternalVolume(CGFloat(volume))
        view.isMuted = isMuted
        view.onVolumeChange = { val in onVolumeChange(Float(val)) }
        view.onInteractionChanged = onInteractionChanged
        view.onToggleMute = onToggleMute
        applyAccessibility(to: view)
        return view
    }

    func updateNSView(_ nsView: CapsuleSliderView, context: Context) {
        nsView.applyExternalVolume(CGFloat(volume))
        nsView.isMuted = isMuted
        nsView.onVolumeChange = { val in onVolumeChange(Float(val)) }
        nsView.onInteractionChanged = onInteractionChanged
        nsView.onToggleMute = onToggleMute
        applyAccessibility(to: nsView)
        nsView.needsDisplay = true
    }

    private func applyAccessibility(to view: CapsuleSliderView) {
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.slider)
        view.setAccessibilityLabel("Output volume")
        view.setAccessibilityValue(isMuted ? "Muted" : "\(Int(volume * 100)) percent")
    }
}

class CapsuleSliderView: NSView {
    var volume: CGFloat = 0.5
    var isMuted = false
    var onVolumeChange: ((CGFloat) -> Void)?
    var onInteractionChanged: ((Bool) -> Void)?
    var onToggleMute: (() -> Void)?

    private var isDragging = false
    private var isScrollInteracting = false
    private var scrollEndWorkItem: DispatchWorkItem?
    private let sliderHeight: CGFloat = 28
    private let iconAreaWidth: CGFloat = 34

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: sliderHeight)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let rect = bounds
        let cornerRadius = sliderHeight / 2
        let knobDiameter: CGFloat = sliderHeight
        let trackRect = sliderTrackRect(in: rect, knobDiameter: knobDiameter)

        // Track background
        let trackPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(trackPath)
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        } else {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        }
        ctx.fillPath()

        // Knob and fill geometry:
        // Knob range: x=0 (volume 0) to x=rect.width-knobDiameter (volume 1)
        // Fill covers from left edge to knob's right edge
        let knobRange = max(trackRect.width - knobDiameter, 0)
        let knobX = trackRect.minX + (knobRange * volume)
        let fillWidth = (knobX - trackRect.minX) + knobDiameter

        // Filled portion
        let fillRect = CGRect(x: trackRect.minX, y: 0, width: fillWidth, height: sliderHeight)
        ctx.saveGState()
        ctx.addPath(trackPath)
        ctx.clip()

        let fillPath = CGPath(roundedRect: fillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(fillPath)
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        } else {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.18).cgColor)
        }
        ctx.fillPath()
        ctx.restoreGState()

        // White knob/thumb
        let knobY: CGFloat = 0
        let knobRect = CGRect(x: knobX, y: knobY, width: knobDiameter, height: knobDiameter)

        // Knob shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: knobRect)
        ctx.restoreGState()

        // Knob fill (on top without shadow)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: knobRect)

        // Speaker icon (always at fixed left position)
        let iconName: String
        if isMuted || volume <= 0 {
            iconName = "speaker.slash.fill"
        } else if volume < 0.33 {
            iconName = "speaker.wave.1.fill"
        } else if volume < 0.66 {
            iconName = "speaker.wave.2.fill"
        } else {
            iconName = "speaker.wave.3.fill"
        }

        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let configured = img.withSymbolConfiguration(config) ?? img
            let imgSize = configured.size
            let iconX: CGFloat = (iconAreaWidth - imgSize.width) / 2
            let iconY: CGFloat = (sliderHeight - imgSize.height) / 2
            configured.draw(in: NSRect(x: iconX, y: iconY, width: imgSize.width, height: imgSize.height))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if loc.x < iconAreaWidth {
            onToggleMute?()
            return
        }
        isDragging = true
        onInteractionChanged?(true)
        updateVolume(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            updateVolume(from: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            updateVolume(from: event)
        }
        isDragging = false
        onInteractionChanged?(false)
    }

    override func scrollWheel(with event: NSEvent) {
        beginScrollInteractionIfNeeded()

        let rawDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
        let step: CGFloat = event.hasPreciseScrollingDeltas ? 0.004 : 0.035
        let delta = CGFloat(rawDelta) * step
        let newVol = max(0, min(1, volume + delta))

        if abs(newVol - volume) > 0.0001 {
            volume = newVol
            onVolumeChange?(newVol)
            needsDisplay = true
        }

        scheduleScrollInteractionEnd()
    }

    private func updateVolume(from event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let knobDiameter = sliderHeight
        let trackRect = sliderTrackRect(in: bounds, knobDiameter: knobDiameter)
        let sliderRange = trackRect.width - knobDiameter
        guard sliderRange > 0 else { return }

        let pos = loc.x - trackRect.minX - (knobDiameter / 2)
        let newVol = CGFloat(max(0, min(1, pos / sliderRange)))
        volume = newVol
        onVolumeChange?(newVol)
        needsDisplay = true
    }

    private func sliderTrackRect(in bounds: CGRect, knobDiameter: CGFloat) -> CGRect {
        let leadingInset = iconAreaWidth + 4
        let width = max(bounds.width - leadingInset, knobDiameter)
        return CGRect(x: leadingInset, y: 0, width: width, height: sliderHeight)
    }

    func applyExternalVolume(_ newVolume: CGFloat) {
        guard !isDragging, !isScrollInteracting else { return }
        volume = newVolume
    }

    private func beginScrollInteractionIfNeeded() {
        scrollEndWorkItem?.cancel()
        if !isScrollInteracting {
            isScrollInteracting = true
            onInteractionChanged?(true)
        }
    }

    private func scheduleScrollInteractionEnd() {
        scrollEndWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isScrollInteracting = false
            self.onInteractionChanged?(false)
        }

        scrollEndWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Circular icon badge
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.1))
                        .frame(width: 30, height: 30)

                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                Text(device.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let title: String
    let icon: String?
    var isDisabled = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .frame(width: 18)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDisabled ? Color.clear : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                .padding(.horizontal, 6)
        )
        .onHover { hovering in
            isHovered = isDisabled ? false : hovering
        }
    }
}

// MARK: - Section Divider

struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 14)
    }
}

struct StatusCard: View {
    let title: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

struct HeroActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .opacity(0.85)
                        .lineLimit(2)
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDisabled ? Color.gray.opacity(0.6) : tint)
        )
    }
}

struct SmallActionButton: View {
    let title: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .foregroundColor(isDisabled ? .secondary : .white)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDisabled ? Color.gray.opacity(0.35) : tint)
        )
    }
}

@MainActor
final class LoginLaunchManager: ObservableObject {
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var runStartupRepair = false
    @Published private(set) var statusMessage = "SoundFix can launch automatically after you log in."

    private let defaults = UserDefaults.standard
    private let startupRepairKey = "startupRepairEnabled"
    private let lastStartupRepairBootMarkerKey = "lastStartupRepairBootMarker"

    init() {
        if defaults.object(forKey: startupRepairKey) == nil {
            defaults.set(false, forKey: startupRepairKey)
        }

        refreshStatus()
    }

    func shouldRunStartupRepairNow() -> Bool {
        guard launchAtLoginEnabled, runStartupRepair else { return false }
        return defaults.string(forKey: lastStartupRepairBootMarkerKey) != currentBootMarker
    }

    func markStartupRepairPerformedForCurrentBoot() {
        defaults.set(currentBootMarker, forKey: lastStartupRepairBootMarkerKey)
    }

    func refreshStatus() {
        runStartupRepair = defaults.bool(forKey: startupRepairKey)

        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
            statusMessage = "SoundFix is registered to launch after login."
        case .requiresApproval:
            launchAtLoginEnabled = true
            statusMessage = "SoundFix is queued for launch at login, but macOS may still want approval in Login Items."
        case .notRegistered:
            launchAtLoginEnabled = false
            statusMessage = "SoundFix is not registered to launch after login."
        case .notFound:
            launchAtLoginEnabled = false
            statusMessage = "macOS could not find this app for launch-at-login registration."
        @unknown default:
            launchAtLoginEnabled = false
            statusMessage = "SoundFix launch-at-login status could not be determined."
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        setLaunchAtLoginEnabled(enabled, persist: true)
    }

    func setRunStartupRepair(_ enabled: Bool) {
        defaults.set(enabled, forKey: startupRepairKey)
        runStartupRepair = enabled
    }

    private func setLaunchAtLoginEnabled(_ enabled: Bool, persist: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = error.localizedDescription
            if !persist {
                launchAtLoginEnabled = false
            }
        }

        refreshStatus()
    }

    private var currentBootMarker: String {
        String(Int(Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime))
    }
}
