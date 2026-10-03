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
    let trafficReadableCount: Int?
    let trafficPendingCount: Int?
    let previewRemainingBytes: Double?
    let previewUnlimited: Bool?
    let otherState: String?
    let otherRemainingBytes: Double?
    let otherPendingCount: Int?

    var id: String { accountId }
    var queryDate: Date? { queriedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }

    private func hasPartialPreview(at now: Date = Date()) -> Bool {
        let knownStatuses = ["notConnected", "loading", "success", "authExpired", "error"]
        guard carrier == "telecom", knownStatuses.contains(status), status != "notConnected",
              let queriedAt, queriedAt.isFinite, queriedAt > 0,
              queriedAt <= 4_102_444_800_000,
              let date = queryDate, date <= now.addingTimeInterval(300), primaryValue == nil,
              let readable = trafficReadableCount, (1...200).contains(readable),
              let pending = trafficPendingCount, (1...200).contains(pending),
              readable + pending <= 200 else { return false }
        if previewUnlimited == true { return previewRemainingBytes == nil }
        guard let previewRemainingBytes else { return false }
        return previewRemainingBytes.isFinite && previewRemainingBytes >= 0 &&
            previewRemainingBytes <= 9_000_000_000_000_000_000
    }

    var labelText: String { hasPartialPreview() ? "部分套餐" : primaryLabel }

    var otherPartialText: String? {
        guard carrier == "telecom", otherState == "partial",
              ["success", "loading", "authExpired", "error"].contains(status),
              let time = queriedAt, time.isFinite, time > 0, time <= 4_102_444_800_000,
              let date = queryDate, date <= Date().addingTimeInterval(300),
              let amount = otherRemainingBytes, amount.isFinite, amount >= 0,
              amount <= 9_000_000_000_000_000_000,
              let count = otherPendingCount, (1...200).contains(count) else { return nil }
        return String(format: "其他已读约 %.2f GB · %d项待确认", amount / 1_073_741_824, count)
    }

    static func parse(_ row: [String: Any]) -> TrafficAccountSnapshot? {
        if let enabled = row["enabled"] as? NSNumber,
           CFGetTypeID(enabled) == CFBooleanGetTypeID(), !enabled.boolValue { return nil }
        let carriers = ["mobile", "unicom", "telecom", "broadnet"]
        guard let carrier = row["carrier"] as? String, carriers.contains(carrier),
              let id = row["accountId"] as? String,
              [carrier, "\(carrier)_2", "\(carrier)_3", "\(carrier)_4"].contains(id) else { return nil }
        let statuses = ["notConnected", "loading", "success", "authExpired", "error"]
        let rawStatus = row["status"] as? String ?? "notConnected"
        func finiteNumber(_ raw: Any?) -> Double? {
            guard let number = raw as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let value = number.doubleValue
            return value.isFinite && value >= 0 ? value : nil
        }
        func boundedCount(_ raw: Any?) -> Int? {
            guard let number = raw as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let value = number.doubleValue
            guard value.isFinite, value.rounded(.towardZero) == value,
                  value >= 1, value <= 200 else { return nil }
            return Int(value)
        }
        let amount = finiteNumber(row["primaryValue"])
        let time = finiteNumber(row["queriedAt"])
        let validTime = time.flatMap { $0 > 0 && $0 <= 4_102_444_800_000 ? $0 : nil }
        let readableCount = boundedCount(row["trafficReadableCount"])
        let pendingCount = boundedCount(row["trafficPendingCount"])
        let validCounts: Bool
        if let readableCount, let pendingCount {
            validCounts = readableCount + pendingCount <= 200
        } else {
            validCounts = false
        }
        let knownStatus = statuses.contains(rawStatus)
        let previewAmount = finiteNumber(row["previewRemainingBytes"])
            .flatMap { $0 <= 9_000_000_000_000_000_000 ? $0 : nil }
        let rawPreviewUnlimited = row["previewUnlimited"] as? NSNumber
        let previewUnlimited = rawPreviewUnlimited.map {
            CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue
        } ?? false
        let hasPreview = previewUnlimited ? previewAmount == nil : previewAmount != nil
        let otherAmount = finiteNumber(row["otherRemainingBytes"])
            .flatMap { $0 <= 9_000_000_000_000_000_000 ? $0 : nil }
        let otherPending = boundedCount(row["otherPendingCount"])
        let otherPartial = knownStatus && carrier == "telecom" && (row["otherState"] as? String) == "partial" &&
            otherAmount != nil && otherPending != nil
        return TrafficAccountSnapshot(
            accountId: id,
            carrier: carrier,
            accountLabel: String((row["accountLabel"] as? String ?? carrier).prefix(40)),
            status: knownStatus ? rawStatus : "error",
            primaryValue: amount.flatMap { $0 <= 9_000_000_000_000_000_000 ? $0 : nil },
            primaryLabel: String((row["primaryLabel"] as? String ?? "余额待确认").prefix(40)),
            queriedAt: validTime,
            isUnlimited: row["isUnlimited"] as? Bool == true,
            trafficReadableCount: validCounts && knownStatus ? readableCount : nil,
            trafficPendingCount: validCounts && knownStatus ? pendingCount : nil,
            previewRemainingBytes: hasPreview ? previewAmount : nil,
            previewUnlimited: hasPreview && previewUnlimited ? true : nil,
            otherState: otherPartial ? "partial" : nil,
            otherRemainingBytes: otherPartial ? otherAmount : nil,
            otherPendingCount: otherPartial ? otherPending : nil
        )
    }

    var valueText: String {
        guard queriedAt != nil else { return "待查询" }
        if let value = primaryValue {
            let prefix = primaryLabel.contains("估算") ? "约 " : ""
            return prefix + String(format: "%.2f GB", value / 1_073_741_824)
        }
        if hasPartialPreview() {
            if previewUnlimited == true { return "单项不限量" }
            if let value = previewRemainingBytes {
                return String(format: "单项约 %.2f GB", value / 1_073_741_824)
            }
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
            if now.timeIntervalSince(date) >= 3600 { return "数据较早" }
            if hasPartialPreview(at: now),
               let readable = trafficReadableCount,
               let pending = trafficPendingCount {
                return "\(readable)项可读 · \(pending)项待确认"
            }
            return "上次查询"
        default: return queriedAt == nil ? "查询未成功" : "保留上次记录"
        }
    }
}
