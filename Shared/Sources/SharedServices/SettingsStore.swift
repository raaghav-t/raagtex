import Foundation

public protocol SettingsStore {
    func load(projectRootPath: String) -> UserSettings
    func save(_ settings: UserSettings, projectRootPath: String)
}

public final class UserDefaultsSettingsStore: SettingsStore {
    private let prefix = "projectSettings.v1"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load(projectRootPath: String) -> UserSettings {
        let key = cacheKey(projectRootPath)
        guard
            let data = userDefaults.data(forKey: key),
            let settings = try? decoder.decode(UserSettings.self, from: data)
        else {
            return UserSettings()
        }
        return settings
    }

    public func save(_ settings: UserSettings, projectRootPath: String) {
        let key = cacheKey(projectRootPath)
        guard let encoded = try? encoder.encode(settings) else { return }
        userDefaults.set(encoded, forKey: key)
    }

    private func cacheKey(_ path: String) -> String {
        "\(prefix).\(path)"
    }
}
