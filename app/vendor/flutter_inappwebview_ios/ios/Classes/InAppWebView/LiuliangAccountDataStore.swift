import Foundation
import WebKit

// Stable, app-owned identifiers. The primary accounts keep WebKit's default
// persistent store; only the second account of each carrier uses these stores.
enum LiuliangAccountDataStore {
    private static let identifiers: [String: UUID] = [
        "liuliang_mobile_2": UUID(uuidString: "f13a9282-cbb7-4b64-92ee-cbd7b884b4d1")!,
        "liuliang_broadnet_2": UUID(uuidString: "9edff2f4-8a39-46b8-95bb-480eaf0c7343")!,
        "liuliang_unicom_2": UUID(uuidString: "67213ad1-8e3e-4a6a-9af2-a130a3ca8c85")!,
        "liuliang_telecom_2": UUID(uuidString: "a5ece450-d97f-47d4-895d-9b921ed7c85d")!
    ]

    @available(iOS 17.0, *)
    static func persistentStore(for profile: String) -> WKWebsiteDataStore? {
        guard let identifier = identifiers[profile] else { return nil }
        // Record ownership before WebKit creates or reopens the store. The
        // fixed identifier list also lets cleanup find removed account cards.
        UserDefaults.standard.set(true, forKey: "liuliang_account_profiles_may_exist")
        return WKWebsiteDataStore(forIdentifier: identifier)
    }

    static func clearAll(completion: @escaping (Bool) -> Void) {
        guard #available(iOS 17.0, *) else {
            completion(false)
            return
        }
        let group = DispatchGroup()
        for identifier in identifiers.values {
            group.enter()
            WKWebsiteDataStore(forIdentifier: identifier).removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date(timeIntervalSince1970: 0)
            ) {
                group.leave()
            }
        }
        group.notify(queue: .main) {
            UserDefaults.standard.set(false, forKey: "liuliang_account_profiles_may_exist")
            completion(true)
        }
    }
}
