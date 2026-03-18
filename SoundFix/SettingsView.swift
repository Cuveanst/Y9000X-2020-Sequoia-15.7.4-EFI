import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var offlineRepairManager: OfflineRepairManager
    @EnvironmentObject var loginLaunchManager: LoginLaunchManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text("SoundFix")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Y9000X Hackintosh Audio Repair")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 10)

                Divider()

                GroupBox("Startup") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch SoundFix after login", isOn: launchAtLoginBinding)
                        Toggle("Run Deep Fix restart and audio repair once per boot", isOn: startupRepairBinding)

                        Text(loginLaunchManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                }

                GroupBox("Repair Details") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Target Output", value: currentDeviceName)
                            .lineLimit(1)

                        LabeledContent("Repair Method", value: "Toggle mute, then restore the previous mute state")

                        if let lastRepairText {
                            LabeledContent("Last Repair", value: lastRepairText)
                        }

                        Text("Use this when audio disappears after wake, device switching, or random Y9000X codec glitches.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                }

                GroupBox("Hardware Keepalive") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Keep a near-silent audio stream running in the background", isOn: silentKeepAliveBinding)

                        Text(audioManager.keepAliveStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("This keeps feeding a near-inaudible low-level signal to the output path, which can help stop the Y9000X codec from idling out after video playback ends.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                }

                GroupBox("Offline ALCPlugFix") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Installed", value: offlineRepairManager.isInstalled ? "Yes" : "No")
                        LabeledContent("Agent Running", value: offlineRepairManager.isAgentRunning ? "Yes" : "No")

                        Text(offlineRepairManager.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("This installs the bundled Y9000X ALCPlugFix and alc-verb resources locally, so it still works without internet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button {
                                offlineRepairManager.restart()
                            } label: {
                                Label("Restart Deep Fix", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .tint(.green)
                            .disabled(offlineRepairManager.isRunning || !offlineRepairManager.isInstalled)

                            Button {
                                offlineRepairManager.install()
                            } label: {
                                Label(offlineRepairManager.isInstalled ? "Reinstall Offline Fix" : "Install Offline Fix",
                                      systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .disabled(offlineRepairManager.isRunning)

                            Button {
                                offlineRepairManager.uninstall()
                            } label: {
                                Label("Remove Offline Fix", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .tint(.red)
                            .disabled(offlineRepairManager.isRunning || !offlineRepairManager.isInstalled)
                        }
                    }
                    .padding(8)
                }

                // Interval setting
                GroupBox("Auto Fix Interval") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Interval:")
                            Spacer()
                            Text("\(Int(timerManager.intervalMinutes)) min")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                        }

                        Slider(value: $timerManager.intervalMinutes, in: 1...60, step: 1)

                        HStack {
                            Text("1 min").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("60 min").font(.caption).foregroundColor(.secondary)
                        }

                        Stepper(
                            "Fine adjust: \(Int(timerManager.intervalMinutes)) min",
                            value: $timerManager.intervalMinutes,
                            in: 1...60, step: 1
                        )
                    }
                    .padding(8)
                }

                // Status
                GroupBox("Status") {
                    VStack(spacing: 8) {
                        HStack {
                            Circle()
                                .fill(timerManager.isRunning ? Color.green : Color.gray)
                                .frame(width: 10, height: 10)
                            Text(timerManager.isRunning ? "Auto Fix is running" : "Auto Fix is stopped")
                            Spacer()
                        }

                        if timerManager.isRunning {
                            HStack {
                                Image(systemName: "clock")
                                Text("Next fix in: \(timerManager.formattedTimeRemaining)")
                                    .monospacedDigit()
                                Spacer()
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        audioManager.performMuteUnmuteCycle()
                    } label: {
                        Label("Fix Now", systemImage: "speaker.wave.2")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        timerManager.toggle(audioManager: audioManager)
                    } label: {
                        Label(
                            timerManager.isRunning ? "Stop" : "Start",
                            systemImage: timerManager.isRunning ? "stop.circle" : "play.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .tint(timerManager.isRunning ? .red : .green)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 430, height: 620)
        .onAppear {
            offlineRepairManager.refreshStatus()
            loginLaunchManager.refreshStatus()
        }
    }

    private var currentDeviceName: String {
        audioManager.outputDevices.first(where: { $0.id == audioManager.currentDeviceID })?.name ?? "No active output"
    }

    private var lastRepairText: String? {
        guard let lastRepairDate = audioManager.lastRepairDate else { return nil }
        return lastRepairDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginLaunchManager.launchAtLoginEnabled },
            set: { loginLaunchManager.setLaunchAtLoginEnabled($0) }
        )
    }

    private var startupRepairBinding: Binding<Bool> {
        Binding(
            get: { loginLaunchManager.runStartupRepair },
            set: { loginLaunchManager.setRunStartupRepair($0) }
        )
    }

    private var silentKeepAliveBinding: Binding<Bool> {
        Binding(
            get: { audioManager.isSilentKeepAliveEnabled },
            set: { audioManager.setSilentKeepAliveEnabled($0) }
        )
    }
}
