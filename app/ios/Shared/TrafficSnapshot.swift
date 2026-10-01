import Foundation
import CoreFoundation

/// Only display fields cross the App Group boundary. Never store carrier sessions here.
struct TrafficSnapshot: Codable {
    static let appGroup = "group.cn.liuliang.liuliangApp"
    static let storageKey = "traffic_widget_snapshot_v2"
    static let widgetKind = "LiuliangTrafficWidget"
    let schema: Int
    let instances: [TrafficAccountSnapshot]

    static let empty = TrafficSnapshot(schema: 2, instances: [])

    static func parse(_ payload: [String: Any]) -> TrafficSnapshot? {
        guard payload["schema"] as? Int == 2,
              let rows = payload["instances"] as? [[String: Any]] else { return nil }
        var seen = Set<String>()
        var records: [TrafficAccountSnapshot] = []
        for row in rows {
            guard let record = TrafficAccountSnapshot.parse(row),
                  seen.insert(record.accountId).inserted else { continue }
            records.append(record)
            if records.count == 4 { break }
        }
        return TrafficSnapshot(schema: 2, instances: records)
    }

    static func read(from defaults: UserDefaults?) -> TrafficSnapshot {
        guard let data = defaults?.data(forKey: storageKey),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let snapshot = parse(value) else { return .empty }
        return snapshot
    }

    func encoded() throws -> Data { try JSONEncoder().encode(self) }
}

struct TrafficAccountSnapshot: Codable, Identifiable {
    let accountId: String
    let carrier: String
    let accountLabel: String
    let status: String
    let primaryValue: Double?
    let primaryLabel: String
    let queriedAt: Double?
    let isUnlimited: Bool

    var id: String { accountId }
    var queryDate: Date? { queriedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }

    static func parse(_ row: [String: Any]) -> TrafficAccountSnapshot? {
        let carriers = ["mobile", "unicom", "telecom", "broadnet"]
        guard let carrier = row["carrier"] as? String, carriers.contains(carrier),
              let id = row["accountId"] as? String,
              id == carrier || id == "\(carrier)_2" else { return nil }
        let statuses = ["notConnected", "loading", "success", "authExpired", "error"]
        let rawStatus = row["status"] as? String ?? "notConnected"
        func finiteNumber(_ raw: Any?) -> Double? {
            guard let number = raw as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let value = number.doubleValue
            return value.isFinite && value >= 0 ? value : nil
        }
        let amount = finiteNumber(row["primaryValue"])
        let time = finiteNumber(row["queriedAt"])
        let validTime = time.flatMap { $0 > 0 && $0 <= 4_102_444_800_000 ? $0 : nil }
        return TrafficAccountSnapshot(
            accountId: id,
            carrier: carrier,
            accountLabel: String((row["accountLabel"] as? String ?? carrier).prefix(40)),
            status: statuses.contains(rawStatus) ? rawStatus : "error",
            primaryValue: amount.flatMap { $0 <= 9_000_000_000_000_000_000 ? $0 : nil },
            primaryLabel: String((row["primaryLabel"] as? String ?? "余额待确认").prefix(40)),
            queriedAt: validTime,
            isUnlimited: row["isUnlimited"] as? Bool == true
        )
    }

    var valueText: String {
        guard queriedAt != nil else { return "待查询" }
        if let value = primaryValue {
            let prefix = primaryLabel.contains("估算") ? "约 " : ""
            return prefix + String(format: "%.2f GB", value / 1_073_741_824)
        }
        return isUnlimited ? "不限量" : "待确认"
    }

    func stateText(at now: Date) -> String {
        switch status {
        case "authExpired": return "需打开验证"
        case "loading": return "打开应用查看"
        case "notConnected": return "待连接"
        case "success":
            guard let date = queryDate else { return "待查询" }
            return now.timeIntervalSince(date) >= 3600 ? "数据较早" : "上次查询"
        default: return queriedAt == nil ? "查询未成功" : "保留上次记录"
        }
    }
}
