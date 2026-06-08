import Foundation

enum AppAboutInfo {
    static let taglines: [String] = [
        "Activity Monitor shows what's leaking. We send you the bill.",
        "Your RAM came with a price tag. So did every app.",
        "Finally, an itemized receipt for background processes.",
        "No refunds on RAM.",
        "Making idle Chrome tabs feel personally responsible.",
        "Every megabyte pays rent. Most apps are squatting.",
        "Quit pretending that Electron app is \"basically free.\"",
        "Shame, but make it financial.",
        "Activity Monitor counts bytes. We count regrets.",
        "Same processes. Different currency.",
        "Activity Monitor for your wallet.",
        "What Activity Monitor won't put on a receipt.",
        "Stop the leak. Or at least invoice it.",
        "Your memory is dripping money. We measured the puddle.",
        "Small leaks. Big bills.",
        "Drip by drip, your RAM is funding someone's side project.",
        "$25/GB of \"I should really close that tab.\"",
        "Opportunity cost, now with process names.",
        "Your upgrade didn't fail. Your apps did the math for you.",
        "Finance for people who won't close Xcode.",
        "Personal budgeting, but the spender is logioptionsplus_agent.",
        "RAM: the subscription you never agreed to.",
        "Know your leaks. Know your bill.",
        "Memory has a cost. Ignorance doesn't.",
        "Bill your bytes.",
    ]

    static let creatorName = "Rubén de la Torre"
    static let socialURL = URL(string: "https://x.com/studiodelatorre")!
    static let socialHandle = "@studiodelatorre"

    static func randomTagline() -> String {
        taglines.randomElement() ?? taglines[0]
    }

    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              build != version else {
            return version
        }
        return "\(version) (\(build))"
    }
}
