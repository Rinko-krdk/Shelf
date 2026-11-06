import Combine
import Foundation
import ServiceManagement

@MainActor
protocol LoginItemClient {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
struct SystemLoginItemClient: LoginItemClient {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() async throws { try await SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var isChanging = false
    @Published private(set) var lastError: String?
    private let client: any LoginItemClient

    init(client: (any LoginItemClient)? = nil) {
        let client = client ?? SystemLoginItemClient()
        self.client = client
        status = client.status
    }

    /// A pending registration is still cancellable, but isn't eligible to launch yet.
    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    var canChange: Bool {
        switch status {
        case .enabled, .notRegistered, .requiresApproval, .notFound: return !isChanging
        default: return false
        }
    }

    func refresh() {
        let newStatus = client.status
        if newStatus != status { lastError = nil }
        status = newStatus
    }

    func setEnabled(_ enabled: Bool) async {
        guard canChange, enabled != isRegistered else { return }
        isChanging = true
        lastError = nil
        defer { isChanging = false }
        do {
            if enabled { try client.register() }
            else { try await client.unregister() }
            refresh()
        } catch {
            refresh()
            lastError = L10n.string("Could not change login startup: %@", error.localizedDescription)
        }
    }

    func openSystemSettings() { client.openSystemSettings() }
}
