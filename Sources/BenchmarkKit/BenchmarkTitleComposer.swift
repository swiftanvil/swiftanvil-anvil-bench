import CryptoKit
import Foundation

/// A single action in an ordered sequence describing what a benchmark run did.
///
/// The composer treats an action as both an identity (`id`) for deterministic grouping
/// and a human phrase (`phrase`) for the rendered title. Two runs that share the same
/// ordered `id` sequence will produce the same title hash even if the phrase strings
/// differ across locales or builds.
public struct BenchmarkActionTag: Hashable, Codable, Sendable {
    /// The stable identifier used for hashing and cohort grouping.
    public var id: BenchmarkTag.ID

    /// The human-readable phrase rendered into the composed title.
    public var phrase: String

    /// Creates an action tag.
    public init(id: BenchmarkTag.ID, phrase: String) {
        self.id = id
        self.phrase = phrase
    }
}

/// The result of composing a title from an ordered action-tag sequence.
public struct BenchmarkComposedTitle: Hashable, Codable, Sendable {
    /// The rendered human title, e.g. `"Imported 4K HEVC, applied warm LUT, exported 1080p"`.
    public var text: String

    /// The deterministic hash of the action-tag identity sequence as a lowercase hex string.
    ///
    /// Identical ordered `BenchmarkActionTag.id` sequences produce the same hash in any
    /// process or build. Cohorts compare runs on this hash to group "the same workflow".
    public var hash: String

    /// Creates a composed title.
    public init(text: String, hash: String) {
        self.text = text
        self.hash = hash
    }
}

/// A pure function from an action-tag sequence to a rendered title and stable hash.
///
/// Conformers must be deterministic: the same input sequence produces the same `text`
/// and `hash` across processes, machines, and BenchmarkKit versions. Do not consult
/// the clock, locale, or random sources.
public protocol BenchmarkTitleComposer: Sendable {
    /// Composes a title from an ordered action sequence.
    func compose(actions: [BenchmarkActionTag]) -> BenchmarkComposedTitle
}

/// The default `BenchmarkTitleComposer`.
///
/// Renders the phrase list as a comma-joined sentence and computes a SHA-256 over the
/// `id` sequence (with a `0x1F` separator and a versioned prefix so the wire format
/// can evolve without silently changing existing hashes).
public struct DefaultBenchmarkTitleComposer: BenchmarkTitleComposer {
    /// The hash format version embedded into the digest input.
    public static let hashVersion: String = "v1"

    /// Creates the default composer.
    public init() { }

    /// Composes a title from an ordered action sequence.
    public func compose(actions: [BenchmarkActionTag]) -> BenchmarkComposedTitle {
        let text = actions.map(\.phrase).joined(separator: ", ")
        let hashInput = Self.hashInput(for: actions)
        let digest = SHA256.hash(data: Data(hashInput.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return BenchmarkComposedTitle(text: text, hash: hex)
    }

    /// The canonical hash-input string for an action sequence; exposed for tests.
    public static func hashInput(for actions: [BenchmarkActionTag]) -> String {
        let separator = "\u{1F}"
        return hashVersion + separator + actions.map(\.id.rawValue).joined(separator: separator)
    }
}
