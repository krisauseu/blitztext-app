import Foundation

enum KeychainKey: String, CaseIterable, Codable {
    case geminiAPIKey = "geminiAPIKey"
    case openAIAPIKey = "openAIAPIKey"

    var label: String {
        switch self {
        case .geminiAPIKey: return "Gemini API Key"
        case .openAIAPIKey: return "OpenAI API Key"
        }
    }
}

/// Securely stores credentials in the user's Application Support directory (mode 0600) with in-memory caching.
enum KeychainService {
    private static var cache: [KeychainKey: String] = [:]
    private static var isLoaded = false
    private static let lock = NSLock()

    static func save(key: KeychainKey, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()
        cache[key] = value
        try persistToFile()
    }

    static func load(key: KeychainKey) -> String? {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()
        guard let value = cache[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    static func delete(key: KeychainKey) {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()
        cache.removeValue(forKey: key)
        try? persistToFile()
    }

    /// Force the next `load` to re-read credentials.
    static func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }

        isLoaded = false
        cache.removeAll()
    }

    static var hasGeminiKey: Bool {
        load(key: .geminiAPIKey) != nil
    }

    static var hasOpenAIKey: Bool {
        load(key: .openAIAPIKey) != nil
    }

    static var isConfigured: Bool {
        hasGeminiKey || hasOpenAIKey
    }

    private static func ensureLoaded() {
        guard !isLoaded else { return }
        isLoaded = true
        cache = [:]

        let url = AppSupportPaths.credentialsURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        for (rawKey, value) in decoded {
            if let key = KeychainKey(rawValue: rawKey) {
                cache[key] = value
            }
        }
    }

    private static func persistToFile() throws {
        try AppSupportPaths.ensureAppSupportDirectoryExists()
        let dict = cache.reduce(into: [String: String]()) { acc, pair in
            acc[pair.key.rawValue] = pair.value
        }
        let data = try JSONEncoder().encode(dict)
        let url = AppSupportPaths.credentialsURL

        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let msg):
            return "Zugangsdaten konnten nicht gespeichert werden: \(msg)"
        }
    }
}
