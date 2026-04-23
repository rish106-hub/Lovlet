import SwiftUI
import WidgetKit

private enum WidgetConfig {
    static let appGroupID = SharedConstants.appGroupID
    static let cacheFile = SharedConstants.widgetCacheFile
}

private enum WidgetCacheReader {
    static func read() -> WidgetMomentState {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetConfig.appGroupID
        ) else { return .noPair }

        let url = container.appendingPathComponent(WidgetConfig.cacheFile)
        guard
            let data = try? Data(contentsOf: url),
            let state = try? JSONDecoder().decode(WidgetMomentState.self, from: data)
        else {
            return .noPair
        }
        return state
    }
}

struct PartnerMomentEntry: TimelineEntry {
    let date: Date
    let state: WidgetMomentState
}

struct PartnerMomentProvider: TimelineProvider {
    func placeholder(in context: Context) -> PartnerMomentEntry {
        PartnerMomentEntry(date: .now, state: .noMoment)
    }

    func getSnapshot(in context: Context, completion: @escaping (PartnerMomentEntry) -> Void) {
        completion(PartnerMomentEntry(date: .now, state: WidgetCacheReader.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PartnerMomentEntry>) -> Void) {
        let entry = PartnerMomentEntry(date: .now, state: WidgetCacheReader.read())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct PartnerMomentWidgetView: View {
    let entry: PartnerMomentProvider.Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            switch entry.state {
            case .noPair:
                Color.gray.opacity(0.12)
                Text("Connect with your partner")
                    .font(.caption)
                    .padding(10)
            case .noMoment:
                Color.gray.opacity(0.12)
                Text("No moment yet")
                    .font(.caption)
                    .padding(10)
            case .moment(let moment):
                AsyncImage(url: URL(string: moment.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.2)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.2)
                    @unknown default:
                        Color.gray.opacity(0.2)
                    }
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                Text(moment.text)
                    .foregroundStyle(.white)
                    .font(.caption2)
                    .lineLimit(2)
                    .padding(8)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct PartnerMomentWidget: Widget {
    let kind: String = "PartnerMomentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PartnerMomentProvider()) { entry in
            PartnerMomentWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner Moment")
        .description("Shows your partner's latest shared moment.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
