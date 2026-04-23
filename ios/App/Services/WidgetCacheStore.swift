import Foundation
import WidgetKit

enum WidgetCacheStore {
    static func save(_ state: WidgetMomentState) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConfig.appGroupID
        ) else { return }

        let url = container.appendingPathComponent(AppConfig.widgetCacheFile)
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Widget cache write failed: \(error)")
        }
    }

    static func read() -> WidgetMomentState {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConfig.appGroupID
        ) else { return .noPair }

        let url = container.appendingPathComponent(AppConfig.widgetCacheFile)
        guard
            let data = try? Data(contentsOf: url),
            let state = try? JSONDecoder().decode(WidgetMomentState.self, from: data)
        else {
            return .noPair
        }
        return state
    }
}
