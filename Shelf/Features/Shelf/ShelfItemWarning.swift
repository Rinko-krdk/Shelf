import SwiftUI

extension ShelfItem {
    @MainActor var warningDescription: String? {
        switch status {
        case .missing:
            return L10n.string("File not found")
        case .inaccessible:
            return L10n.string("Cannot access file")
        case .staleBookmark:
            return L10n.string("File reference is stale")
        case .bookmarkResolutionFailed:
            return L10n.string("Could not restore file reference")
        case .available:
            return hasOpenFailure
                ? L10n.string("Could not open %@. Check file permissions and whether an app is available to open it.", displayName)
                : nil
        }
    }

    @MainActor var hoverDescription: String {
        warningDescription.map { "\(displayName)\n\($0)" } ?? displayName
    }
}

struct ShelfItemWarningBadge: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(2)
            .background(.background, in: Circle())
            // The native drag view supplies the accessible description and receives all gestures.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
