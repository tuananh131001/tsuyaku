import Foundation
import OSLog

/// The OpenCode Go models the Correction Model menu offers. Fetched once per
/// launch, in the background; the last list that came back is kept, so the
/// menu still has it offline.
enum OpenCodeModels {

    private static let log = Logger(subsystem: "com.loind.tsuyaku", category: "glossary-correction")

    /// Needs no key.
    static let endpoint = URL(string: "https://opencode.ai/zen/go/v1/models")!

    /// For a first launch with no network.
    static let builtIn = ["deepseek-v4.1-flash", "qwen3.8-flash", "glm-5.3-flash", "kimi-k2.7-code", "minimax-m3"]

    /// The IDs in an OpenAI-style list (`{"object":"list","data":[{"id":…}]}`),
    /// in the order given, each once. Nil when there are none to offer, so the
    /// saved or built-in list stays.
    static func parse(_ body: Data) -> [String]? {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = obj["data"] as? [[String: Any]] else { return nil }
        var seen = Set<String>()
        let ids = data.compactMap { $0["id"] as? String }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return ids.isEmpty ? nil : ids
    }

    /// What the menu lists: the saved list, or the built-in one, with the
    /// current model added if it isn't there, so the tick is never wrong.
    static func listed(saved: [String]?, current: String) -> [String] {
        let list = saved ?? builtIn
        return list.contains(current) ? list : list + [current]
    }

    /// Fetches the list and saves it. True if it changed what the menu shows.
    /// Failures are only logged: the menu keeps the last list.
    static func refresh() async -> Bool {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                log.error("model list HTTP \(status)")
                return false
            }
            guard let ids = parse(data) else {
                log.error("model list unreadable")
                return false
            }
            log.info("model list: \(ids.count) models")
            guard ids != Settings.correctionModels else { return false }
            Settings.correctionModels = ids
            return true
        } catch {
            log.error("model list failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
