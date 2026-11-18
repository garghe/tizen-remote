import Foundation

/// Persists pairing tokens and known TVs in UserDefaults.
enum Storage {
    private static let defaults = UserDefaults.standard
    private static let knownTVsKey = "knownTVs"
    private static let lastTVKey = "lastTVId"

    static func token(for tvId: String) -> String? {
        defaults.string(forKey: "token.\(tvId)")
    }

    static func setToken(_ token: String, for tvId: String) {
        defaults.set(token, forKey: "token.\(tvId)")
    }

    static var knownTVs: [SamsungTV] {
        get {
            guard let data = defaults.data(forKey: knownTVsKey) else { return [] }
            return (try? JSONDecoder().decode([SamsungTV].self, from: data)) ?? []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: knownTVsKey)
        }
    }

    static func remember(_ tv: SamsungTV) {
        var list = knownTVs.filter { $0.id != tv.id }
        list.insert(tv, at: 0)
        knownTVs = list
        defaults.set(tv.id, forKey: lastTVKey)
    }

    static func forget(_ tv: SamsungTV) {
        knownTVs = knownTVs.filter { $0.id != tv.id }
        defaults.removeObject(forKey: "token.\(tv.id)")
    }

    static var lastTVId: String? { defaults.string(forKey: lastTVKey) }
}
