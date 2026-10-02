import Foundation

@main
enum TrafficSnapshotTests {
    static func main() throws {
        func row(_ id: String = "mobile", value: Any = 1_073_741_824, time: Any = 1_700_000_000_000) -> [String: Any] {
            ["accountId": id, "carrier": "mobile", "accountLabel": "中国移动",
             "status": "success", "primaryValue": value, "primaryLabel": "通用剩余",
             "queriedAt": time, "isUnlimited": false]
        }
        func partialRow(
            status: String = "success",
            value: Any = NSNull(),
            time: Any = Date().timeIntervalSince1970 * 1000,
            readable: Any = 3,
            pending: Any = 12,
            preview: Any = 1_073_741_824,
            previewUnlimited: Any = false
        ) -> [String: Any] {
            ["accountId": "telecom", "carrier": "telecom", "accountLabel": "电信",
             "status": status, "primaryValue": value, "primaryLabel": "余额待确认",
             "queriedAt": time, "isUnlimited": false,
             "trafficReadableCount": readable, "trafficPendingCount": pending,
             "previewRemainingBytes": preview, "previewUnlimited": previewUnlimited]
        }
        func snapshot(_ rows: [[String: Any]]) -> TrafficSnapshot {
            TrafficSnapshot.parse(["schema": 2, "instances": rows])!
        }
        let two = snapshot([row(), row("mobile_2", value: 2_147_483_648)])
        let fourIds = ["mobile", "mobile_2", "mobile_3", "mobile_4"]
        precondition(snapshot(fourIds.map { row($0) }).instances.map { $0.accountId } == fourIds)
        for invalid in ["mobile_1", "mobile_5", "unicom_3"] {
            precondition(snapshot([row(invalid)]).instances.isEmpty)
        }
        var disabled = row("mobile_3")
        disabled["enabled"] = false
        precondition(snapshot([disabled, row("mobile_3")]).instances.count == 1)
        precondition(snapshot([disabled]).instances.isEmpty)
        precondition(two.instances.count == 2)
        precondition(two.instances[0].valueText == "1.00 GB")
        precondition(two.instances[1].valueText == "2.00 GB")
        precondition(snapshot([row(), row()]).instances.count == 1)
        precondition(snapshot([row("broadnet")]).instances.isEmpty)
        precondition(TrafficSnapshot.parse(["schema": 99, "instances": []]) == nil)
        precondition(snapshot([row(value: -1)]).instances[0].valueText == "待确认")
        precondition(snapshot([row(value: true)]).instances[0].primaryValue == nil)
        precondition(snapshot([row(time: NSNull())]).instances[0].valueText == "待查询")
        let partial = snapshot([partialRow()]).instances[0]
        precondition(partial.valueText == "单项约 1.00 GB")
        precondition(partial.labelText == "部分套餐")
        precondition(partial.stateText(at: Date()) == "3项可读 · 12项待确认")
        var nonTelecomPartial = partialRow()
        nonTelecomPartial["carrier"] = "mobile"
        nonTelecomPartial["accountId"] = "mobile"
        let nonTelecom = snapshot([nonTelecomPartial]).instances[0]
        precondition(nonTelecom.valueText == "待确认")
        precondition(nonTelecom.labelText == "余额待确认")
        let disconnected = snapshot([partialRow(status: "notConnected")]).instances[0]
        precondition(disconnected.valueText == "待确认")
        precondition(disconnected.labelText == "余额待确认")
        precondition(disconnected.stateText(at: Date()) == "待连接")
        let unknownPartial = snapshot([partialRow(status: "futureStatus")]).instances[0]
        precondition(unknownPartial.valueText == "待确认")
        precondition(unknownPartial.labelText == "余额待确认")
        precondition(unknownPartial.stateText(at: Date()) == "保留上次记录")
        let excessiveCountTotal = snapshot([partialRow(readable: 100, pending: 101)]).instances[0]
        precondition(excessiveCountTotal.valueText == "待确认")
        precondition(excessiveCountTotal.labelText == "余额待确认")
        precondition(excessiveCountTotal.trafficReadableCount == nil)
        precondition(excessiveCountTotal.trafficPendingCount == nil)
        let countTotalBoundary = snapshot([partialRow(readable: 100, pending: 100)]).instances[0]
        precondition(countTotalBoundary.valueText == "单项约 1.00 GB")
        precondition(countTotalBoundary.stateText(at: Date()) == "100项可读 · 100项待确认")
        var partialUnlimited = partialRow(preview: NSNull(), previewUnlimited: true)
        partialUnlimited["isUnlimited"] = true
        let partialUnlimitedSnapshot = snapshot([partialUnlimited]).instances[0]
        precondition(partialUnlimitedSnapshot.valueText == "单项不限量")
        precondition(partialUnlimitedSnapshot.labelText == "部分套餐")

        let invalidPartialCounts: [[String: Any]] = [
            partialRow(readable: 0),
            partialRow(pending: 0),
            partialRow(readable: 201),
            partialRow(pending: 201),
            partialRow(readable: 1.5),
            partialRow(readable: true),
            partialRow(pending: 201, preview: NSNull(), previewUnlimited: true)
        ]
        for invalid in invalidPartialCounts {
            let parsed = snapshot([invalid]).instances[0]
            precondition(parsed.valueText == "待确认")
            precondition(parsed.labelText == "余额待确认")
            precondition(parsed.trafficReadableCount == nil && parsed.trafficPendingCount == nil)
        }
        let invalidPreviewRows: [[String: Any]] = [
            partialRow(preview: true),
            partialRow(preview: -1),
            partialRow(preview: 9_100_000_000_000_000_000),
            partialRow(preview: Double.infinity)
        ]
        for invalid in invalidPreviewRows {
            let parsed = snapshot([invalid]).instances[0]
            precondition(parsed.valueText == "待确认")
            precondition(parsed.labelText == "余额待确认")
        }
        let numericTotal = snapshot([partialRow(value: 0)]).instances[0]
        precondition(numericTotal.valueText == "0.00 GB")
        precondition(numericTotal.labelText == "余额待确认")
        precondition(numericTotal.stateText(at: Date()) == "上次查询")
        let missingPartialDate = snapshot([partialRow(time: NSNull())]).instances[0]
        precondition(missingPartialDate.valueText == "待查询")
        precondition(missingPartialDate.labelText == "余额待确认")
        precondition(missingPartialDate.stateText(at: Date()) == "待查询")
        let stalePartial = snapshot([partialRow(
            time: Date().addingTimeInterval(-3601).timeIntervalSince1970 * 1000
        )]).instances[0]
        precondition(stalePartial.valueText == "单项约 1.00 GB")
        precondition(stalePartial.stateText(at: Date()) == "数据较早")

        for (status, expectedState) in [
            ("loading", "打开应用查看"),
            ("authExpired", "需打开验证"),
            ("error", "保留上次记录")
        ] {
            let preserved = snapshot([partialRow(status: status, value: 2_147_483_648)]).instances[0]
            precondition(preserved.valueText == "2.00 GB")
            precondition(preserved.labelText == "余额待确认")
            precondition(preserved.stateText(at: Date()) == expectedState)
            let preservedPartial = snapshot([partialRow(status: status)]).instances[0]
            precondition(preservedPartial.valueText == "单项约 1.00 GB")
            precondition(preservedPartial.labelText == "部分套餐")
            precondition(preservedPartial.stateText(at: Date()) == expectedState)
        }
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
        let partialRoundTrip = try snapshot([partialRow()]).encoded()
        let decodedPartial = try JSONDecoder().decode(TrafficSnapshot.self, from: partialRoundTrip)
        precondition(decodedPartial.instances[0].trafficReadableCount == 3)
        precondition(decodedPartial.instances[0].trafficPendingCount == 12)
        precondition(decodedPartial.instances[0].previewRemainingBytes == 1_073_741_824)
        precondition(decodedPartial.instances[0].valueText == "单项约 1.00 GB")
        let legacyData = try JSONSerialization.data(withJSONObject: [
            "schema": 2,
            "instances": [row()]
        ])
        let legacyDecoded = try JSONDecoder().decode(TrafficSnapshot.self, from: legacyData)
        precondition(legacyDecoded.instances[0].trafficReadableCount == nil)
        precondition(legacyDecoded.instances[0].previewUnlimited == nil)
        var unsafeDirectRow = partialRow()
        unsafeDirectRow["queriedAt"] = Date().addingTimeInterval(600).timeIntervalSince1970 * 1000
        let unsafeDirectData = try JSONSerialization.data(withJSONObject: [
            "schema": 2,
            "instances": [unsafeDirectRow]
        ])
        let unsafeDirect = try JSONDecoder().decode(TrafficSnapshot.self, from: unsafeDirectData)
        precondition(unsafeDirect.instances[0].valueText == "待确认")
        precondition(unsafeDirect.instances[0].labelText == "余额待确认")
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
