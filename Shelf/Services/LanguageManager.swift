import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
}

nonisolated enum LanguagePreference {
    static let defaultsKey = "shelf.appLanguage"
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var language: AppLanguage

    private init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: LanguagePreference.defaultsKey) ?? "en") ?? .english
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: LanguagePreference.defaultsKey)
    }
}

enum L10n {
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let language = LanguageManager.shared.language
        let bundle: Bundle
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            bundle = localizedBundle
        } else {
            bundle = .main
        }
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return arguments.isEmpty ? format : String(format: format, locale: Locale(identifier: language.rawValue), arguments: arguments)
    }
}
