import Foundation
import CoreAudio
import Combine

/// Represents an audio output device
struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let isOutput: Bool

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }
}

class AudioManager: ObservableObject {
    enum RepairState: Equatable {
        case idle
        case running
        case failed(String)
    }

    @Published var isMuted: Bool = false
    @Published var isProcessing: Bool = false
    @Published var volume: Float = 0.5
    @Published var outputDevices: [AudioDevice] = []
    @Published var currentDeviceID: AudioDeviceID = 0
    @Published var lastRepairDate: Date?
    @Published var repairState: RepairState = .idle

    private var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerDeviceID: AudioDeviceID = 0  // track which device the listener is on
    private var lastAppleScriptVolumeRead = Date.distantPast
    private var lastAppleScriptMuteRead = Date.distantPast
    private let audioQueue = DispatchQueue(label: "com.soundfix.audio", qos: .userInitiated)
    private var isRepairingMuteCycle = false
    private var activeRepairID: UUID?
    private var isUserAdjustingVolume = false
    private var pendingInteractiveVolume: Float?
    private var interactiveVolumeWorkItem: DispatchWorkItem?

    init() {
        audioQueue.async {
            self.refreshOutputDevices()
            self.loadCurrentDevice()
            self.loadVolume()
            self.installDeviceListListener()
            self.installDefaultDeviceListener()
            self.installVolumeListener()
        }
    }

    deinit {
        audioQueue.sync {
            removeDeviceListListener()
            removeDefaultDeviceListener()
            removeVolumeListener()
            stopVolumePolling()
        }
    }

    // MARK: - Volume Control

    /// Get the current volume of the default output device (0.0 - 1.0)
    func loadVolume() {
        guard let device = getDefaultOutputDevice() else {
            loadVolumeViaAppleScriptIfNeeded()
            loadMuteState(forceAppleScript: true)
            return
        }
        var vol = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &vol)

        if status != noErr {
            address.mElement = 1
            status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &vol)
        }

        if status == noErr {
            if !isUserAdjustingVolume {
                DispatchQueue.main.async { self.volume = vol }
            }
        } else if !isUserAdjustingVolume {
            // CoreAudio failed (e.g. BoomAudio virtual device) — use AppleScript
            loadVolumeViaAppleScriptIfNeeded()
        }

        loadMuteState()
    }

    /// Fallback: read volume via AppleScript (works with all devices including Boom3D)
    private func loadVolumeViaAppleScriptIfNeeded(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastAppleScriptVolumeRead) >= 3 else { return }
        lastAppleScriptVolumeRead = Date()

        let script = "output volume of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                let intValue = result.int32Value  // 0-100
                let floatValue = Float(intValue) / 100.0
                DispatchQueue.main.async { self.volume = floatValue }
            }
        }
    }

    /// Load the current mute state
    private func loadMuteState(forceAppleScript: Bool = false) {
        guard !forceAppleScript, let device = getDefaultOutputDevice() else {
            loadMuteStateViaAppleScriptIfNeeded(force: true)
            return
        }
        var muteValue = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muteValue)
        if status == noErr {
            DispatchQueue.main.async { self.isMuted = muteValue != 0 }
        } else {
            loadMuteStateViaAppleScriptIfNeeded()
        }
    }

    private func loadMuteStateViaAppleScriptIfNeeded(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastAppleScriptMuteRead) >= 3 else { return }
        lastAppleScriptMuteRead = Date()

        let script = "output muted of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                let muted = result.booleanValue
                DispatchQueue.main.async { self.isMuted = muted }
            }
        }
    }

    /// Set volume of the default output device (0.0 - 1.0)
    func setVolume(_ newVolume: Float, interactive: Bool = false) {
        DispatchQueue.main.async {
            self.volume = newVolume
        }

        audioQueue.async {
            if interactive {
                self.scheduleInteractiveVolumeWrite(newVolume)
            } else {
                self.setVolumeNow(newVolume)
            }
        }
    }

    func beginVolumeInteraction() {
        audioQueue.async {
            self.isUserAdjustingVolume = true
        }
    }

    func endVolumeInteraction() {
        audioQueue.async {
            self.flushInteractiveVolumeWriteIfNeeded()
            self.isUserAdjustingVolume = false
            self.loadVolume()
        }
    }

    private func setVolumeNow(_ newVolume: Float) {
        guard let device = getDefaultOutputDevice() else {
            setVolumeViaAppleScript(newVolume)
            return
        }
        var vol = newVolume
        let size = UInt32(MemoryLayout<Float32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &vol)

        if status != noErr {
            // Try individual channels
            var anySuccess = false
            for ch: UInt32 in [1, 2] {
                address.mElement = ch
                var channelVol = vol
                if AudioObjectSetPropertyData(device, &address, 0, nil, size, &channelVol) == noErr {
                    anySuccess = true
                }
            }
            if !anySuccess {
                // All CoreAudio channels failed — use AppleScript
                setVolumeViaAppleScript(newVolume)
            }
        }

        DispatchQueue.main.async { self.volume = newVolume }
    }

    private func scheduleInteractiveVolumeWrite(_ newVolume: Float) {
        pendingInteractiveVolume = newVolume
        interactiveVolumeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.flushInteractiveVolumeWriteIfNeeded()
        }

        interactiveVolumeWorkItem = workItem
        audioQueue.asyncAfter(deadline: .now() + 0.03, execute: workItem)
    }

    private func flushInteractiveVolumeWriteIfNeeded() {
        interactiveVolumeWorkItem?.cancel()
        interactiveVolumeWorkItem = nil

        guard let volume = pendingInteractiveVolume else { return }
        pendingInteractiveVolume = nil
        setVolumeNow(volume)
    }

    /// Fallback: set volume via AppleScript
    private func setVolumeViaAppleScript(_ volume: Float) {
        let intVolume = Int(volume * 100)
        let script = "set volume output volume \(intVolume)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if error == nil {
                DispatchQueue.main.async { self.volume = volume }
            }
        }
    }

    // MARK: - Audio Device Enumeration

    func refreshOutputDevices() {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propSize
        )
        guard status == noErr else { return }

        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propSize, &deviceIDs
        )
        guard status == noErr else { return }

        var devices: [AudioDevice] = []
        for deviceID in deviceIDs {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            var streamSize: UInt32 = 0
            let streamStatus = AudioObjectGetPropertyDataSize(
                deviceID, &streamAddress, 0, nil, &streamSize
            )
            guard streamStatus == noErr, streamSize > 0 else { continue }

            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: CFString?
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            let nameStatus = withUnsafeMutablePointer(to: &nameRef) { ptr in
                AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, ptr)
            }
            let name = nameStatus == noErr ? (nameRef as String? ?? "Unknown Device") : "Unknown Device"

            devices.append(AudioDevice(id: deviceID, name: name, isOutput: true))
        }

        DispatchQueue.main.async {
            self.outputDevices = devices
        }
    }

    // MARK: - Device Switching

    func loadCurrentDevice() {
        if let device = getDefaultOutputDevice() {
            DispatchQueue.main.async {
                self.currentDeviceID = device
            }
        }
    }

    func setDefaultOutputDevice(_ deviceID: AudioDeviceID) {
        var deviceID = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, size, &deviceID
        )

        if status == noErr {
            DispatchQueue.main.async {
                self.currentDeviceID = deviceID
            }
            // Volume listener will be reinstalled via the default device listener callback
        }
    }

    // MARK: - Listeners

    /// Listen for changes to the list of audio devices (plugged/unplugged)
    private func installDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshOutputDevices()
        }
        self.deviceListListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioQueue, block
        )
    }

    private func removeDeviceListListener() {
        guard let block = deviceListListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioQueue, block
        )
    }

    /// Listen for default output device changes (e.g. Boom3D hijacking)
    private func installDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        self.defaultDeviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioQueue, block
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, audioQueue, block
        )
    }

    /// Called when the default output device changes
    private func handleDefaultDeviceChanged() {
        guard !isRepairingMuteCycle else { return }
        loadCurrentDevice()
        // Reinstall volume listener on the new device
        removeVolumeListener()
        installVolumeListener()
        loadVolume()
    }

    /// Listen for volume changes on the current default device
    private func installVolumeListener() {
        guard let device = getDefaultOutputDevice() else { return }
        volumeListenerDeviceID = device

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self, !self.isRepairingMuteCycle else { return }
            self.loadVolume()
        }
        self.volumeListenerBlock = block

        // Listen on master, channel 1, and channel 2
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            AudioObjectAddPropertyListenerBlock(device, &address, audioQueue, block)
        }

        // Also listen for mute changes
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, audioQueue, block)

        // Start a polling timer as fallback (some system changes don't trigger listeners)
        startVolumePolling()
    }

    private func removeVolumeListener() {
        stopVolumePolling()

        guard volumeListenerDeviceID != 0,
              let block = volumeListenerBlock else { return }

        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            AudioObjectRemovePropertyListenerBlock(
                volumeListenerDeviceID, &address, audioQueue, block
            )
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            volumeListenerDeviceID, &muteAddress, audioQueue, block
        )

        volumeListenerDeviceID = 0
        volumeListenerBlock = nil
    }

    // MARK: - Volume Polling (fallback for when listeners don't fire)

    private var volumePollTimer: Timer?

    private func startVolumePolling() {
        stopVolumePolling()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioQueue.async {
                guard !self.isRepairingMuteCycle else { return }
                self.loadVolume()
                self.loadCurrentDevice()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        volumePollTimer = timer
    }

    private func stopVolumePolling() {
        volumePollTimer?.invalidate()
        volumePollTimer = nil
    }

    // MARK: - Core Audio Helpers

    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    func setMute(_ mute: Bool) {
        audioQueue.async {
            self.setMuteNow(mute)
        }
    }

    private func setMuteNow(_ mute: Bool) {
        guard let device = getDefaultOutputDevice() else {
            setMuteViaAppleScript(mute)
            return
        }

        var muteValue: UInt32 = mute ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, size, &muteValue
        )

        if status == noErr {
            DispatchQueue.main.async { self.isMuted = mute }
        } else {
            setMuteViaAppleScript(mute)
        }
    }

    private func setMuteViaAppleScript(_ mute: Bool) {
        let script = mute
            ? "set volume with output muted"
            : "set volume without output muted"

        runMuteAppleScript(script, mutedValue: mute)
    }

    @discardableResult
    private func setMuteViaAppleScriptNow(_ mute: Bool) -> Bool {
        let script = mute
            ? "set volume with output muted"
            : "set volume without output muted"

        return runMuteAppleScript(script, mutedValue: mute)
    }

    @discardableResult
    private func runMuteAppleScript(_ script: String, mutedValue: Bool) -> Bool {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if error == nil {
                DispatchQueue.main.async { self.isMuted = mutedValue }
                return true
            }
        }

        return false
    }

    func performMuteUnmuteCycle() {
        guard !isProcessing else { return }
        isProcessing = true
        repairState = .running
        let originalMuteState = isMuted
        let repairID = UUID()
        activeRepairID = repairID

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self,
                  self.activeRepairID == repairID,
                  self.isProcessing else { return }

            self.activeRepairID = nil
            self.isProcessing = false
            self.isRepairingMuteCycle = false
            self.repairState = .failed("Mute toggle timed out. Try Deep Fix for this output device.")
        }

        audioQueue.async {
            guard self.activeRepairID == repairID else { return }
            let intermediateMuteState = !originalMuteState
            self.isRepairingMuteCycle = true
            let firstToggleSucceeded = self.setMuteViaAppleScriptNow(intermediateMuteState)

            self.audioQueue.asyncAfter(deadline: .now() + 0.5) {
                guard self.activeRepairID == repairID else { return }
                if firstToggleSucceeded, self.isMuted == intermediateMuteState {
                    _ = self.setMuteViaAppleScriptNow(originalMuteState)
                }

                self.isRepairingMuteCycle = false
                self.loadVolume()
                self.loadCurrentDevice()

                DispatchQueue.main.async {
                    guard self.activeRepairID == repairID else { return }
                    self.activeRepairID = nil
                    self.isProcessing = false
                    if firstToggleSucceeded {
                        self.lastRepairDate = Date()
                        self.repairState = .idle
                    } else {
                        self.repairState = .failed("System mute toggle failed. Try Deep Fix for this output device.")
                    }
                }
            }
        }
    }
}
