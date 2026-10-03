import SwiftUI
import WidgetKit

private struct TrafficEntry: TimelineEntry {
    let date: Date
    let snapshot: TrafficSnapshot
}

private struct TrafficProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrafficEntry {
        TrafficEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrafficEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrafficEntry>) -> Void) {
        let entry = currentEntry()
        // This only ages the display. It does not fetch a new carrier balance.
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(3600))))
    }

    private func currentEntry() -> TrafficEntry {
        TrafficEntry(
            date: Date(),
            snapshot: TrafficSnapshot.read(from: UserDefaults(suiteName: TrafficSnapshot.appGroup))
        )
    }
}

private struct TrafficWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrafficEntry
    private let ink = Color(red: 0.32, green: 0.25, blue: 0.22)
    private let peach = Color(red: 0.91, green: 0.62, blue: 0.48)

    private var limit: Int { family == .systemSmall ? 1 : family == .systemMedium ? 2 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            HStack(spacing: 5) {
                Image(systemName: "cloud.fill").foregroundStyle(peach)
                Text("流量小伙伴").font(.system(.caption, design: .rounded, weight: .bold))
                Spacer(minLength: 0)
                if family != .systemSmall {
                    Image(systemName: "arrow.up.forward.app").foregroundStyle(peach)
                }
            }
            if entry.snapshot.instances.isEmpty {
                Spacer(minLength: 0)
                Text("让流量住进小卡片")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text("打开应用，连接号码并查询一次")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if family == .systemSmall {
                account(entry.snapshot.instances[0], compact: true)
                Spacer(minLength: 0)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(entry.snapshot.instances.prefix(limit))) { item in
                        account(item, compact: false)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(footer)
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(ink)
        .containerBackground(for: .widget) {
            Color(red: 1, green: 0.96, blue: 0.88)
        }
        .widgetURL(URL(string: "liuliang://refresh"))
    }

    private var footer: String {
        let extra = entry.snapshot.instances.count - limit
        return extra > 0 ? "另 \(extra) 张卡 · 轻点打开查询" : "上次查询记录 · 轻点更新"
    }

    private func account(_ item: TrafficAccountSnapshot, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 5 : 2) {
            Text(item.accountLabel)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
            Text(item.valueText)
                .font(.system(size: compact ? 23 : 22, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(item.labelText)
                .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
            if let other = item.otherPartialText {
                Text(other)
                    .font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.65)
            }
            Text(item.stateText(at: entry.date))
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.65)
            if let date = item.queryDate {
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("尚无成功查询时间")
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 0 : 6)
        .background(compact ? Color.clear : Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

@main
struct TrafficWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TrafficSnapshot.widgetKind, provider: TrafficProvider()) { entry in
            TrafficWidgetView(entry: entry)
        }
        .configurationDisplayName("流量小伙伴")
        .description("查看号码上次查询的流量和时间，轻点打开应用更新。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
