import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable(String)

    var isAvailable: Bool {
        if case .unavailable = self {
            return false
        }
        return true
    }
}

protocol LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginStatus
}

enum LaunchAtLoginServiceStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case unknown
}

final class LaunchAtLogin: LaunchAtLoginManaging {
    private let bundleURL: URL
    private let installedURL: URL

    init(bundleURL: URL = Bundle.main.bundleURL, installedURL: URL = URL(fileURLWithPath: "/Applications/Audiyo.app")) {
        self.bundleURL = bundleURL
        self.installedURL = installedURL
    }

    var status: LaunchAtLoginStatus {
        Self.resolve(serviceStatus: serviceStatus, isInstalledInApplications: isInstalledInApplications)
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginStatus {
        guard isInstalledInApplications else {
            return status
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        return status
    }

    static func resolve(serviceStatus: LaunchAtLoginServiceStatus, isInstalledInApplications: Bool) -> LaunchAtLoginStatus {
        guard isInstalledInApplications else {
            return .unavailable("Install Audiyo in /Applications before enabling Launch at Login.")
        }

        switch serviceStatus {
        case .enabled:
            return .enabled
        case .disabled:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .disabled
        case .unknown:
            return .unavailable("Unknown login item status.")
        }
    }

    private var serviceStatus: LaunchAtLoginServiceStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unknown
        }
    }

    private var isInstalledInApplications: Bool {
        bundleURL.standardizedFileURL.path == installedURL.standardizedFileURL.path
    }
}
