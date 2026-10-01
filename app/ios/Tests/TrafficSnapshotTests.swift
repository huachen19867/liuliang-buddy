import Foundation

@main
enum TrafficSnapshotTests {
    static func main() throws {
        func row(_ id: String = "mobile", value: Any = 1_073_741_824, time: Any = 1_700_000_000_000) -> [String: Any] {
            ["accountId": id, "carrier": "mobile", "accountLabel": "中国移动",
             "status": "success", "primaryValue": value, "primaryLabel": "通用剩余",
             "queriedAt": time, "isUnlimited": false]
        }
        func snapshot(_ rows: [[String: Any]]) -> TrafficSnapshot {
            TrafficSnapshot.parse(["schema": 2, "instances": rows])!
        }
        let two = snapshot([row(), row("mobile_2", value: 2_147_483_648)])
        precondition(two.instances.count == 2)
        precondition(two.instances[0].valueText == "1.00 GB")
        precondition(two.instances[1].valueText == "2.00 GB")
        precondition(snapshot([row(), row()]).instances.count == 1)
        precondition(snapshot([row("broadnet")]).instances.isEmpty)
        precondition(TrafficSnapshot.parse(["schema": 99, "instances": []]) == nil)
        precondition(snapshot([row(value: -1)]).instances[0].valueText == "待确认")
        precondition(snapshot([row(value: true)]).instances[0].primaryValue == nil)
        precondition(snapshot([row(time: NSNull())]).instances[0].valueText == "待查询")
        var unlimited = row(value: NSNull())
        unlimited["isUnlimited"] = true
        unlimited["status"] = "authExpired"
        let kept = snapshot([unlimited]).instances[0]
        precondition(kept.valueText == "不限量")
        precondition(kept.stateText(at: Date()) == "需打开验证")
        precondition(kept.queriedAt == 1_700_000_000_000)
        let old = two.instances[0]
        precondition(old.stateText(at: old.queryDate!.addingTimeInterval(3601)) == "数据较早")
        var secret = row()
        secret["cookie"] = "MUST_NOT_PERSIST"
        let data = try snapshot([secret]).encoded()
        precondition(!String(data: data, encoding: .utf8)!.contains("MUST_NOT_PERSIST"))
        let restored = try JSONDecoder().decode(TrafficSnapshot.self, from: data)
        precondition(restored.instances[0].queriedAt == old.queriedAt)
        precondition(restored.instances[0].primaryValue == old.primaryValue)
        let many = ["mobile", "unicom", "telecom", "broadnet"].flatMap { carrier in
            [carrier, "\(carrier)_2"].map { id -> [String: Any] in
                var value = row(id)
                value["carrier"] = carrier
                return value
            }
        }
        precondition(snapshot(many).instances.count == 4)
        let testSuite = "liuliang.widget.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: testSuite)!
        defer { defaults.removePersistentDomain(forName: testSuite) }
        defaults.set(Data("broken json".utf8), forKey: TrafficSnapshot.storageKey)
        precondition(TrafficSnapshot.read(from: defaults).instances.isEmpty)
        defaults.set(data, forKey: TrafficSnapshot.storageKey)
        precondition(TrafficSnapshot.read(from: defaults).instances.first?.queriedAt == old.queriedAt)
        defaults.removeObject(forKey: TrafficSnapshot.storageKey)
        precondition(TrafficSnapshot.read(from: defaults).instances.isEmpty)
        precondition(TrafficSnapshot.read(from: nil).instances.isEmpty)
        print("TrafficSnapshot model checks passed")
    }
}
