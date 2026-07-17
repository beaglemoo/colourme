import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    enum TestState {
        case idle
        case testing
        case success(Int)
        case failure(String)
    }

    var apiKey = KeychainStore.load() ?? ""
    var testState: TestState = .idle
    var saveConfirmation = false

    private let client = OpenRouterClient()

    func saveKey() {
        do {
            try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            saveConfirmation = true
            testState = .idle
            KeyState.shared.refresh()
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }

    func testConnection() async {
        // The client reads the key from the Keychain, so persist the field first.
        saveKey()
        testState = .testing
        do {
            let models = try await client.listImageModels()
            testState = .success(models.count)
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }
}
