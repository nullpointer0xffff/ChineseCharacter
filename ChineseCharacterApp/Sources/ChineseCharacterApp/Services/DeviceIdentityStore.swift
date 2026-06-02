import Foundation

@MainActor
final class DeviceIdentityStore: ObservableObject {
    let deviceID: String

    private let storageKey = "device_identity_id"

    init() {
        if let existingID = UserDefaults.standard.string(forKey: storageKey) {
            deviceID = existingID
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: storageKey)
            deviceID = newID
        }
    }
}
