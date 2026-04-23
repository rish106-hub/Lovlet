import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw),
            !raw.isEmpty
        else {
            fatalError("Missing SUPABASE_URL in Info.plist build settings.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !value.isEmpty
        else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist build settings.")
        }
        return value
    }

    static let momentsBucket = SharedConstants.momentsBucket
    static let appGroupID = SharedConstants.appGroupID
    static let widgetCacheFile = SharedConstants.widgetCacheFile
}
