import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    private static let shakeKey = "shelf.shakeToShowEnabled"
    private let defaults: UserDefaults

    @Published var shakeToShowEnabled: Bool {
        didSet { defaults.set(shakeToShowEnabled, forKey: Self.shakeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shakeToShowEnabled = defaults.object(forKey: Self.shakeKey) == nil
            ? true : defaults.bool(forKey: Self.shakeKey)
    }
}
