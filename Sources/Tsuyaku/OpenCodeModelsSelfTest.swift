import Foundation

/// Checks how the Correction Model menu reads OpenCode Go's model list, and
/// what it lists. No network.
///
/// Run with `Tsuyaku --store-selftest` (via `make test`).
@MainActor
enum OpenCodeModelsSelfTest {

    private static var failures = 0

    static func run() -> Int {
        failures = 0
        print("\n=== OpenCode Go model list self-test ===")
        replyGivesIDsInOrder()
        nothingToOfferGivesNoList()
        duplicatesAreListedOnce()
        currentModelIsAlwaysListed()
        return failures
    }

    private static func replyGivesIDsInOrder() {
        let body = """
            {"object":"list","data":[
              {"id":"kimi-k2.7-code","object":"model","created":0,"owned_by":"opencode"},
              {"id":"deepseek-v4.1-flash","object":"model","created":0,"owned_by":"opencode"},
              {"id":"glm-5.3-flash","object":"model","created":0,"owned_by":"opencode"}
            ]}
            """
        expect("the reply gives its IDs, in order",
               OpenCodeModels.parse(Data(body.utf8)) == ["kimi-k2.7-code", "deepseek-v4.1-flash", "glm-5.3-flash"])
    }

    private static func nothingToOfferGivesNoList() {
        expect("an empty data gives no list",
               OpenCodeModels.parse(Data(#"{"object":"list","data":[]}"#.utf8)) == nil)
        expect("a missing data gives no list",
               OpenCodeModels.parse(Data(#"{"object":"list"}"#.utf8)) == nil)
        expect("a body that isn't JSON gives no list",
               OpenCodeModels.parse(Data("<html>502 Bad Gateway</html>".utf8)) == nil)
    }

    private static func duplicatesAreListedOnce() {
        let body = #"{"data":[{"id":"a"},{"id":"b"},{"id":"a"}]}"#
        expect("duplicate IDs are listed once", OpenCodeModels.parse(Data(body.utf8)) == ["a", "b"])
    }

    private static func currentModelIsAlwaysListed() {
        expect("with no saved list, the built-in one",
               OpenCodeModels.listed(saved: nil, current: "deepseek-v4.1-flash") == OpenCodeModels.builtIn)
        expect("a model set from the CLI is listed too",
               OpenCodeModels.listed(saved: ["a", "b"], current: "z") == ["a", "b", "z"])
    }

    private static func expect(_ what: String, _ ok: Bool) {
        print("  \(ok ? "ok  " : "FAIL") \(what)")
        if !ok { failures += 1 }
    }
}
