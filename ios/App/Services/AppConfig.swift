import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        else {
            fatalError("Missing SUPABASE_URL in Info.plist build settings.")
        }
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.contains("$("), let url = URL(string: raw) else {
            fatalError("SUPABASE_URL is not set correctly. Check ios/Config/Secrets.xcconfig and project generation.")
        }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host?.isEmpty == false else {
            fatalError("SUPABASE_URL must be a valid absolute URL (for example https://your-project.supabase.co).")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            fatalError("Missing or unexpanded SUPABASE_ANON_KEY. Check ios/Config/Secrets.xcconfig and project generation.")
        }
        return value
    }

    static let momentsBucket = SharedConstants.momentsBucket
    static let appGroupID = SharedConstants.appGroupID
    static let widgetCacheFile = SharedConstants.widgetCacheFile
}
