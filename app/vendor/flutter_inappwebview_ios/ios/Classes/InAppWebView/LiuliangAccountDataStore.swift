import Foundation
import WebKit

// Stable, app-owned identifiers. The primary accounts keep WebKit's default
// persistent store; additional accounts use these stable independent stores.
enum LiuliangAccountDataStore {
    private static let identifiers: [String: UUID] = [
        "liuliang_mobile_2": UUID(uuidString: "f13a9282-cbb7-4b64-92ee-cbd7b884b4d1")!,
        "liuliang_broadnet_2": UUID(uuidString: "9edff2f4-8a39-46b8-95bb-480eaf0c7343")!,
        "liuliang_unicom_2": UUID(uuidString: "67213ad1-8e3e-4a6a-9af2-a130a3ca8c85")!,
        "liuliang_telecom_2": UUID(uuidString: "a5ece450-d97f-47d4-895d-9b921ed7c85d")!,
        "liuliang_mobile_3": UUID(uuidString: "f1ca176e-27c5-4ab8-9f04-4b79686e98a5")!,
        "liuliang_mobile_4": UUID(uuidString: "1a5f5021-9fd1-4f3a-abe5-cffadb7aac14")!,
        "liuliang_broadnet_3": UUID(uuidString: "ff2b41a8-7dc4-429c-bb4a-3faad0311edc")!,
        "liuliang_broadnet_4": UUID(uuidString: "17e06769-63d4-488f-ab6a-892e007659ab")!,
        "liuliang_unicom_3": UUID(uuidString: "17ee4f7e-549a-44a1-adee-fb20b37c9bf9")!,
        "liuliang_unicom_4": UUID(uuidString: "e200e146-6b38-40fd-bcaf-efe30b487846")!,
        "liuliang_telecom_3": UUID(uuidString: "92cb7bfd-d158-4cfb-a0ee-3a63f6518ad6")!,
        "liuliang_telecom_4": UUID(uuidString: "68f49e26-c71f-4eed-bfcf-8bc4394bb0aa")!
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
