import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class AppState {
    private let logger = Logger(subsystem: "local.audiyo.app", category: "app")
    private let hal: AudioHAL
    private let configStore: ConfigStore
    private let notifier: any Notifying
    private let launchAtLogin: any LaunchAtLoginManaging
    private let debouncer = Debouncer()
    private var guardState = EnforcementGuard()
    private var overrides = ActiveOverrides()
    private var pendingSnapshot: HALSnapshot?
    private var applyingSelectors: Set<DefaultSelector> = []
    private var isEditingOutputVolume = false

    var endpoints: [Endpoint] = []
    var defaultInputUID: String?
    var defaultOutputUID: String?
    var defaultSystemOutputUID: String?
    var lastRefresh: Date?
    var lastError: String?
    var config: PriorityConfig
    var badgeState: ReconcileBadgeState = .normal
    var recentSwitches: [SwitchRecord] = []
    var outputVolume = 0.0
    var outputMuted = false
    var outputVolumeEnabled = false
    var outputMuteEnabled = false
    var launchAtLoginStatus: LaunchAtLoginStatus
    var settingsTab: SettingsTab = .priorities

    var hasHFPWarning: Bool {
        badgeState == .hfpWarning
    }

    var masterAuto: Bool {
        config.masterAutoEnabled
    }

    var hasManualSelection: Bool {
        overrides != ActiveOverrides()
    }

    var menuBarIconVisible: Bool {
        config.menuBarIconVisible
    }

    var dockIconVisible: Bool {
        config.dockIconVisible
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var bundlePath: String {
        Bundle.main.bundleURL.path
    }

    var installStatusText: String {
        Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Audiyo.app"
            ? "Installed in /Applications"
            : "Running from development build"
    }

    init(hal: AudioHAL = AudioHAL(), configStore: ConfigStore = .live, notifier: any Notifying = Notifier(), launchAtLogin: any LaunchAtLoginManaging = LaunchAtLogin(), startHAL: Bool = true) {
        self.hal = hal
        self.configStore = configStore
        self.notifier = notifier
        self.launchAtLogin = launchAtLogin
        var loadedConfig = (try? configStore.load()) ?? PriorityConfig()
        loadedConfig.ensureControlSurfaceVisible()
        self.config = loadedConfig
        self.launchAtLoginStatus = launchAtLogin.status
        self.hal.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.apply(snapshot)
            }
        }
        self.hal.onVolumeChange = { [weak self] in
            Task { @MainActor in
                guard let self, !self.isEditingOutputVolume else { return }
                self.refreshOutputVolume()
            }
        }
        if startHAL {
            self.hal.start()
        }
        applyActivationPolicy()
    }

    func refresh() {
        hal.refresh()
    }

    func setAutoEnabled(_ enabled: Bool) {
        config.masterAutoEnabled = enabled
        persistConfig()
        reconcileNow()
    }

    func resumePriorities() {
        overrides = ActiveOverrides()
        setAutoEnabled(true)
    }

    func setAlertOutput(uid: String?) {
        config.alertOutputUID = uid
        if let uid, var device = config.knownDevice(uid: uid, direction: .output) {
            device.isUserConfigured = true
            config.upsert(device, direction: .output)
        }
        persistConfig()
        reconcileNow()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        config.notificationsEnabled = enabled
        persistConfig()
        if enabled {
            Task {
                _ = await notifier.requestAuthorization()
            }
        }
    }

    func addToPriority(_ device: PriorityDevice, direction: AudioDirection) {
        config.addToPriority(uid: device.uid, direction: direction)
        persistConfig()
        reconcileNow()
    }

    func removeFromPriority(_ device: PriorityDevice, direction: AudioDirection) {
        config.removeFromPriority(uid: device.uid, direction: direction)
        persistConfig()
        reconcileNow()
    }

    func setMenuBarIconVisible(_ visible: Bool) {
        guard config.menuBarIconVisible != visible else { return }
        config.setMenuBarIconVisible(visible)
        persistConfig()
        applyActivationPolicy()
    }

    func setDockIconVisible(_ visible: Bool) {
        guard config.dockIconVisible != visible else { return }
        config.setDockIconVisible(visible)
        persistConfig()
        applyActivationPolicy()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            launchAtLoginStatus = try launchAtLogin.setEnabled(enabled)
        } catch {
            launchAtLoginStatus = launchAtLogin.status
            lastError = String(describing: error)
        }
    }

    func diagnosticsReport(now: Date = Date()) -> DiagnosticsReport {
        DiagnosticsReport(
            generatedAt: now,
            bundleURL: Bundle.main.bundleURL,
            appVersion: appVersion,
            buildNumber: buildNumber,
            config: config,
            endpoints: endpoints,
            defaultInputUID: defaultInputUID,
            defaultOutputUID: defaultOutputUID,
            defaultSystemOutputUID: defaultSystemOutputUID,
            recentSwitches: recentSwitches,
            lastError: lastError
        )
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export Audiyo Diagnostics"
        panel.nameFieldStringValue = "Audiyo-Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try diagnosticsReport().render().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            lastError = String(describing: error)
        }
    }

    func setOutputVolume(_ volume: Double) {
        outputVolume = min(max(volume, 0), 1)
        guard let endpoint = defaultOutputEndpoint, outputVolumeEnabled else { return }
        hal.setVolume(Float(outputVolume), deviceID: endpoint.deviceID, direction: .output) { [weak self] result in
            Task { @MainActor in
                if case .failure(let error) = result {
                    self?.lastError = String(describing: error)
                }
            }
        }
    }

    func setOutputMuted(_ muted: Bool) {
        outputMuted = muted
        guard let endpoint = defaultOutputEndpoint, outputMuteEnabled else { return }
        hal.setMuted(muted, deviceID: endpoint.deviceID, direction: .output) { [weak self] result in
            Task { @MainActor in
                if case .failure(let error) = result {
                    self?.lastError = String(describing: error)
                }
            }
        }
    }

    func setOutputVolumeEditing(_ editing: Bool) {
        isEditingOutputVolume = editing
        if !editing {
            refreshOutputVolume()
        }
    }

    func movePriority(direction: AudioDirection, from source: IndexSet, to destination: Int) {
        var priority = config.priority(for: direction)
        guard source.allSatisfy({ priority.indices.contains($0) }), (0...priority.count).contains(destination) else { return }
        let movedUIDs = source.map { priority[$0] }
        priority.move(fromOffsets: source, toOffset: destination)
        config.setPriority(priority, for: direction)
        for uid in movedUIDs {
            if var device = config.knownDevice(uid: uid, direction: direction) {
                device.isUserConfigured = true
                config.upsert(device, direction: direction)
            }
        }
        persistConfig()
        reconcileNow()
    }

    func forget(_ device: PriorityDevice, direction: AudioDirection) {
        guard !endpoints.contains(where: { $0.uid == device.uid && $0.direction == direction }) else { return }
        config.remove(uid: device.uid, direction: direction)
        persistConfig()
        reconcileNow()
    }

    func userSelect(_ endpoint: Endpoint) {
        if endpoint.direction == .input {
            overrides.inputUID = endpoint.uid
        } else {
            overrides.outputUID = endpoint.uid
        }
        let selector: DefaultSelector = endpoint.direction == .input ? .input : .output
        applyDefault(uid: endpoint.uid, selector: selector, reason: "manual")
    }

    private func apply(_ snapshot: HALSnapshot) {
        endpoints = snapshot.endpoints.sorted()
        defaultInputUID = snapshot.defaultInputUID
        defaultOutputUID = snapshot.defaultOutputUID
        defaultSystemOutputUID = snapshot.defaultSystemOutputUID
        lastRefresh = snapshot.createdAt
        lastError = snapshot.error
        refreshOutputVolume()

        logger.info("snapshot endpoints=\(snapshot.endpoints.count) defaultInput=\(snapshot.defaultInputUID ?? "nil") defaultOutput=\(snapshot.defaultOutputUID ?? "nil") defaultSystemOutput=\(snapshot.defaultSystemOutputUID ?? "nil")")
        pendingSnapshot = snapshot
        debouncer.schedule { [weak self] in
            Task { @MainActor in
                self?.reconcileNow()
            }
        }
    }

    private func reconcileNow() {
        guard let snapshot = pendingSnapshot else { return }
        let decision = Reconciler().reconcile(
            snapshot: snapshot,
            config: config,
            overrides: overrides,
            masterAuto: masterAuto,
            suspendedDefaults: guardState.suspendedDefaults(at: Date())
        )
        config = decision.configAmendments
        badgeState = decision.badgeState
        persistConfig()

        if let change = decision.desiredInput {
            applyDefault(uid: change.uid, selector: .input, reason: "reconcile")
        }
        if let change = decision.desiredOutput {
            applyDefault(uid: change.uid, selector: .output, reason: "reconcile")
        }
        if let uid = decision.desiredSystemOutputUID {
            applyDefault(uid: uid, selector: .systemOutput, reason: "alert")
        }
    }

    private func applyDefault(uid: String, selector: DefaultSelector, reason: String) {
        guard !applyingSelectors.contains(selector), !guardState.isSuspended(selector: selector, uid: uid, at: Date()) else {
            return
        }

        applyingSelectors.insert(selector)
        _ = guardState.recordReassertion(selector: selector, uid: uid, at: Date())
        hal.setDefault(uid: uid, selector: selector) { [weak self] result in
            Task { @MainActor in
                self?.applyingSelectors.remove(selector)
                switch result {
                case .success:
                    self?.recordSwitch(selector: selector, uid: uid, reason: reason)
                case .failure(let error):
                    self?.lastError = String(describing: error)
                }
            }
        }
    }

    private func persistConfig() {
        do {
            try configStore.save(config)
        } catch {
            lastError = String(describing: error)
        }
    }

    private func applyActivationPolicy() {
        guard let app = NSApp else { return }
        _ = app.setActivationPolicy(config.dockIconVisible ? .regular : .accessory)
    }

    private func recordSwitch(selector: DefaultSelector, uid: String, reason: String) {
        let name = endpoints.first { $0.uid == uid && $0.direction == selector.direction }?.name ?? uid
        recentSwitches.insert(SwitchRecord(date: Date(), selector: selector, name: name, reason: reason), at: 0)
        recentSwitches = Array(recentSwitches.prefix(10))

        guard config.notificationsEnabled else { return }
        Task {
            await notifier.deliver(SwitchNotification(title: "Audiyo switched \(selector.label)", body: name))
        }
    }

    private var defaultOutputEndpoint: Endpoint? {
        endpoints.first { $0.uid == defaultOutputUID && $0.direction == .output }
    }

    private func refreshOutputVolume() {
        guard let endpoint = defaultOutputEndpoint else {
            outputVolumeEnabled = false
            outputMuteEnabled = false
            return
        }

        hal.volumeState(deviceID: endpoint.deviceID, direction: .output) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let state):
                    if let volume = state.volume, self?.isEditingOutputVolume != true {
                        self?.outputVolume = Double(volume)
                    }
                    if let muted = state.isMuted {
                        self?.outputMuted = muted
                    }
                    self?.outputVolumeEnabled = state.isVolumeSettable
                    self?.outputMuteEnabled = state.isMuteSettable
                case .failure:
                    self?.outputVolumeEnabled = false
                    self?.outputMuteEnabled = false
                }
            }
        }
    }
}

struct SwitchRecord: Identifiable, Equatable {
    let id = UUID()
    var date: Date
    var selector: DefaultSelector
    var name: String
    var reason: String
}
