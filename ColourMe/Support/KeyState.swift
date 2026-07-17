import Foundation
import Observation

/// Observable wrapper around Keychain key presence, shared between the
/// Settings scene and the main window so saving a key updates the form
/// immediately.
@MainActor
@Observable
final class KeyState {
    static let shared = KeyState()

    private(set) var hasKey: Bool

    private init() {
        hasKey = KeychainStore.load()?.isEmpty == false
    }

    func refresh() {
        hasKey = KeychainStore.load()?.isEmpty == false
    }
}
