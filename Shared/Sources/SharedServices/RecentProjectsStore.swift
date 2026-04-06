import Foundation

public protocol RecentProjectsStore {
    func load() -> [ProjectReference]
    func save(_ projects: [ProjectReference])
}

public final class UserDefaultsRecentProjectsStore: RecentProjectsStore {
    private enum Keys {
        static let recentProjects = "recentProjects.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> [ProjectReference] {
        guard
            let data = userDefaults.data(forKey: Keys.recentProjects),
            let decoded = try? decoder.decode([ProjectReference].self, from: data)
        else {
            return []
        }

        return decoded.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })
    }

    public func save(_ projects: [ProjectReference]) {
        guard let encoded = try? encoder.encode(projects) else { return }
        userDefaults.set(encoded, forKey: Keys.recentProjects)
    }
}
