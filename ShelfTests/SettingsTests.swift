import AppKit
import Foundation
import ServiceManagement
import Testing
@testable import Shelf

@MainActor
struct SettingsTests {
    @Test func loginStartupReadsSystemStateWithoutRegistering() {
        let client = TestLoginItemClient()
        let service = LoginItemService(client: client)
        #expect(service.status == .notRegistered)
        #expect(!service.isRegistered)
        #expect(client.registerCalls == 0)
        client.status = .enabled
        service.refresh()
        #expect(service.isRegistered)
        #expect(client.registerCalls == 0)
    }

    @Test func loginStartupCanRegisterAndUnregister() async {
        let client = TestLoginItemClient()
        let service = LoginItemService(client: client)
        await service.setEnabled(true)
        #expect(service.status == .enabled)
        #expect(client.registerCalls == 1)
        await service.setEnabled(true)
        #expect(client.registerCalls == 1)
        await service.setEnabled(false)
        #expect(service.status == .notRegistered)
        #expect(client.unregisterCalls == 1)
        #expect(service.lastError == nil)
    }

    @Test func pendingLoginRegistrationCanOpenSettingsAndBeCancelled() async {
        let client = TestLoginItemClient()
        client.registrationResult = .requiresApproval
        let service = LoginItemService(client: client)
        await service.setEnabled(true)
        #expect(service.status == .requiresApproval)
        #expect(service.isRegistered)
        service.openSystemSettings()
        #expect(client.settingsCalls == 1)
        await service.setEnabled(false)
        #expect(service.status == .notRegistered)
        #expect(client.unregisterCalls == 1)
    }

    @Test func missingLoginItemCanAttemptRegistration() async {
        let client = TestLoginItemClient()
        client.status = .notFound
        let service = LoginItemService(client: client)
        #expect(service.canChange)
        await service.setEnabled(true)
        #expect(client.registerCalls == 1)
        #expect(service.isRegistered)
    }

    @Test func deniedRegistrationReadsPendingApprovalAndRemainsCancellable() async {
        let client = TestLoginItemClient()
        client.registrationError = CocoaError(.fileWriteNoPermission)
        client.failedRegistrationStatus = .requiresApproval
        let service = LoginItemService(client: client)
        await service.setEnabled(true)
        #expect(service.status == .requiresApproval)
        #expect(service.isRegistered)
        #expect(service.canChange)
        #expect(service.lastError != nil)
        await service.setEnabled(false)
        #expect(service.status == .notRegistered)
        #expect(service.lastError == nil)
    }

    @Test func loginErrorsPreserveActualStateAndRecoverOnSystemChange() async {
        let client = TestLoginItemClient()
        client.registrationError = CocoaError(.fileWriteNoPermission)
        let service = LoginItemService(client: client)
        await service.setEnabled(true)
        #expect(service.lastError != nil)
        #expect(service.status == .notRegistered)
        #expect(!service.isRegistered)
        #expect(!service.isChanging)
        client.status = .enabled
        service.refresh()
        #expect(service.lastError == nil)
        client.unregistrationError = CocoaError(.fileWriteNoPermission)
        await service.setEnabled(false)
        #expect(service.lastError != nil)
        #expect(service.isRegistered)
        #expect(!service.isChanging)
    }

    @Test func changingLoginStartupRejectsOverlappingRequests() async throws {
        let client = TestLoginItemClient()
        client.status = .enabled
        client.waitForUnregister = true
        let service = LoginItemService(client: client)
        let task = Task { await service.setEnabled(false) }
        for _ in 0..<1000 {
            if client.unregisterContinuation != nil { break }
            await Task.yield()
        }
        #expect(service.isChanging)
        #expect(!service.canChange)
        await service.setEnabled(false)
        await service.setEnabled(true)
        #expect(client.unregisterCalls == 1)
        #expect(client.registerCalls == 0)
        let continuation = try #require(client.unregisterContinuation)
        continuation.resume()
        await task.value
        #expect(!service.isChanging)
        #expect(service.status == .notRegistered)
    }

    @Test func shakePreferenceDefaultsOnAndPersistsChanges() throws {
        let suite = "Shelf.SettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        #expect(preferences.shakeToShowEnabled)
        preferences.shakeToShowEnabled = false
        #expect(!AppPreferences(defaults: defaults).shakeToShowEnabled)
        preferences.shakeToShowEnabled = true
        #expect(AppPreferences(defaults: defaults).shakeToShowEnabled)
    }

    @Test func shakePreferenceSwitchesMonitoringAndRejectsQueuedEvents() async throws {
        let suite = "Shelf.SettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        var handlers: [(NSEvent) -> Void] = []
        var removeCalls = 0
        var point = NSPoint.zero
        var activations = 0
        let monitor = MouseShakeMonitor(
            installMonitor: { handler in handlers.append(handler); return NSObject() },
            removeMonitor: { _ in removeCalls += 1 },
            cursorLocation: { point }
        )
        monitor.onShake = { activations += 1 }
        monitor.bind(to: preferences)
        #expect(monitor.isRunning)
        #expect(handlers.count == 1)

        func sendShake(using handler: (NSEvent) -> Void, at time: TimeInterval) throws {
            for (index, x) in [0.0, 60, 0, 60, 0].enumerated() {
                point = NSPoint(x: x, y: 0)
                let event = try #require(NSEvent.mouseEvent(
                    with: .leftMouseDragged, location: point, modifierFlags: [],
                    timestamp: time + Double(index) * 0.1, windowNumber: 0,
                    context: nil, eventNumber: index, clickCount: 1, pressure: 1
                ))
                handler(event)
            }
        }

        // These callbacks are queued on the main actor, then invalidated before they execute.
        try sendShake(using: handlers[0], at: 10)
        preferences.shakeToShowEnabled = false
        #expect(!monitor.isRunning)
        #expect(removeCalls == 1)
        preferences.shakeToShowEnabled = false
        #expect(removeCalls == 1)
        preferences.shakeToShowEnabled = true
        #expect(handlers.count == 2)
        for _ in 0..<20 { await Task.yield() }
        #expect(activations == 0)
        try sendShake(using: handlers[0], at: 20)
        for _ in 0..<20 { await Task.yield() }
        #expect(activations == 0)
        try sendShake(using: handlers[1], at: 30)
        for _ in 0..<20 { await Task.yield() }
        #expect(activations == 1)
        monitor.stop()
        #expect(removeCalls == 2)
    }
}

@MainActor
private final class TestLoginItemClient: LoginItemClient {
    var status: SMAppService.Status = .notRegistered
    var registrationResult: SMAppService.Status = .enabled
    var registrationError: Error?
    var failedRegistrationStatus: SMAppService.Status?
    var unregistrationError: Error?
    var registerCalls = 0
    var unregisterCalls = 0
    var settingsCalls = 0
    var waitForUnregister = false
    var unregisterContinuation: CheckedContinuation<Void, Never>?

    func register() throws {
        registerCalls += 1
        if let registrationError {
            if let failedRegistrationStatus { status = failedRegistrationStatus }
            throw registrationError
        }
        status = registrationResult
    }

    func unregister() async throws {
        unregisterCalls += 1
        if waitForUnregister {
            await withCheckedContinuation { unregisterContinuation = $0 }
        }
        if let unregistrationError { throw unregistrationError }
        status = .notRegistered
    }

    func openSystemSettings() { settingsCalls += 1 }
}
