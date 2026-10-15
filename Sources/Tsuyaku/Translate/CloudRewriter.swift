import Foundation
import OSLog

/// The cloud client behind glossary correction: OpenCode Go, with
/// `GlossaryRewriter`'s instructions and prompt. One plain request per row, no
/// streaming: the corrector needs the whole line before it can judge it.
enum CloudRewriter {

    private static let log = Logger(subsystem: "com.loind.tsuyaku", category: "glossary-correction")

    /// (terms, previous row's Japanese, row's Japanese, row's English) ->
    /// the model's English. Throws so the corrector can say why it failed.
    typealias Call = @Sendable (Glossary, String, String, String) async throws -> String

    /// The glossary corrector's client, on the model the user chose
    /// (`Settings.correctionModel`). OpenCode Go refuses requests without a
    /// session to route by, so each call made from this gets the same one:
    /// one per Start.
    static func opencodeGo(key: String, model: String) -> Call {
        messages(endpoint: URL(string: "https://opencode.ai/zen/go/v1/messages")!,
                 key: key, model: model,
                 headers: ["x-opencode-session": UUID().uuidString])
    }

    // MARK: - Wire formats

    /// Anthropic Messages, as OpenCode Go speaks it.
    static func messages(endpoint: URL, key: String, model: String, headers: [String: String] = [:]) -> Call {
        { terms, previous, source, english in
            let body: [String: Any] = [
                "model": model,
                "max_tokens": 256,
                "temperature": 0,
                "thinking": ["type": "disabled"],
                "system": GlossaryRewriter.instructions(terms),
                "messages": [["role": "user",
                              "content": GlossaryRewriter.prompt(previous: previous, source: source, english: english)]],
            ]
            let obj = try await post(endpoint, body: body, headers: headers.merging([
                "x-api-key": key,
                "anthropic-version": "2023-06-01",
            ]) { $1 })
            let blocks = obj["content"] as? [[String: Any]] ?? []
            return blocks.filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
    }

    enum Failure: Error, LocalizedError {
        case http(Int, String)
        case unreadable
        var errorDescription: String? {
            switch self {
            case .http(let code, let body): "HTTP \(code): \(body.prefix(160))"
            case .unreadable:               "unreadable reply"
            }
        }
    }

    private static func post(_ url: URL, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let detail = String(decoding: data, as: UTF8.self)
            log.error("rewrite HTTP \(status) from \(url.host() ?? "", privacy: .public): \(detail.prefix(300), privacy: .public)")
            throw Failure.http(status, detail)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.unreadable
        }
        return obj
    }
}
