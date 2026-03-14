import Foundation
import Combine

@MainActor
final class OfflineRepairManager: ObservableObject {
    @Published private(set) var isInstalled = false
    @Published private(set) var isRunning = false
    @Published private(set) var isAgentRunning = false
    @Published var statusMessage = "Offline ALCPlugFix is not installed."

    private let launchAgentPath = "/Library/LaunchAgents/com.black-dragon74.ALCPlugFix.plist"
    private let launchAgentLabel = "com.black-dragon74.ALCPlugFix"
    private var activeOperationID = UUID()

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let installed = FileManager.default.fileExists(atPath: launchAgentPath)
        isInstalled = installed
        guard installed else {
            isAgentRunning = false
            statusMessage = "Offline ALCPlugFix is not installed."
            return
        }

        statusMessage = "Checking whether the offline repair agent is active..."

        let uid = String(getuid())
        let label = launchAgentLabel
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["print", "gui/\(uid)/\(label)"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let isRunning = process.terminationStatus == 0 && output.contains("state = running")
                let isLoaded = process.terminationStatus == 0 && output.contains("path = ")

                DispatchQueue.main.async {
                    guard self.isInstalled else { return }
                    self.isAgentRunning = isRunning
                    if isRunning {
                        self.statusMessage = "Offline ALCPlugFix is installed and running for this login session."
                    } else if isLoaded {
                        self.statusMessage = "Offline ALCPlugFix is installed, but the agent is not running right now. Try Restart instead of Reinstall."
                    } else {
                        self.statusMessage = "Offline ALCPlugFix is installed, but not loaded into the current login session. Try Restart instead of Reinstall."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.isInstalled else { return }
                    self.isAgentRunning = false
                    self.statusMessage = "Offline ALCPlugFix is installed, but SoundFix could not verify the agent state."
                }
            }
        }
    }

    func install() {
        runBundledScript(named: "y9000x_install", actionName: "install")
    }

    func restart() {
        guard isInstalled else { return }
        runSilentRestart()
    }

    func uninstall() {
        runBundledScript(named: "y9000x_uninstall", actionName: "remove")
    }

    private func runBundledScript(named name: String, actionName: String) {
        guard let scriptURL = Bundle.main.url(forResource: name, withExtension: "sh", subdirectory: "OfflineRepair") else {
            statusMessage = "Bundled offline repair script is missing."
            return
        }

        let escapedPath = scriptURL.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"bash \\\"\(escapedPath)\\\"\" with administrator privileges"
        runPrivilegedAppleScript(appleScript, actionName: actionName, successFallbackMessage: nil)
    }

    private func runPrivilegedAppleScript(_ appleScript: String, actionName: String, successFallbackMessage: String?) {
        guard !isRunning else { return }
        let operationID = beginOperation(named: actionName)

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", appleScript]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                DispatchQueue.main.async {
                    guard self.isRunning, self.activeOperationID == operationID else { return }
                    self.statusMessage = "Administrator prompt opened. Completing the \(actionName) process..."
                }

                process.waitUntilExit()
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else { return }
                    self.isRunning = false
                    if process.terminationStatus == 0 {
                        self.refreshStatus()
                        if let output, !output.isEmpty {
                            self.statusMessage = output
                        } else if let successFallbackMessage {
                            self.statusMessage = successFallbackMessage
                        }
                    } else {
                        self.statusMessage = output?.isEmpty == false
                            ? output!
                            : "Offline \(actionName) failed."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else { return }
                    self.isRunning = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func runSilentRestart(completion: ((Bool) -> Void)? = nil) {
        guard !isRunning else {
            completion?(false)
            return
        }

        let operationID = UUID()
        activeOperationID = operationID
        isRunning = true
        statusMessage = "Restarting Deep Fix in the current login session..."

        let domain = "gui/\(getuid())/\(launchAgentLabel)"

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["kickstart", "-k", domain]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else { return }
                    self.isRunning = false
                    self.refreshStatus()
                    if process.terminationStatus == 0 {
                        self.statusMessage = "Offline ALCPlugFix was restarted without prompting for a password."
                        completion?(true)
                    } else {
                        self.statusMessage = output?.isEmpty == false
                            ? output!
                            : "Deep Fix restart did not complete in the current login session. Reinstall may still be needed."
                        completion?(false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.activeOperationID == operationID else { return }
                    self.isRunning = false
                    self.statusMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    @discardableResult
    private func beginOperation(named actionName: String) -> UUID {
        let operationID = UUID()
        activeOperationID = operationID
        isRunning = true
        statusMessage = "Opening administrator prompt for \(actionName)..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard self.isRunning, self.activeOperationID == operationID else { return }
            self.statusMessage = "Still working on \(actionName). If you already entered your password, macOS is finishing the offline repair steps..."
        }

        return operationID
    }
}
