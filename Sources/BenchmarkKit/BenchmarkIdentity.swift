import Foundation

/// A stable string-backed identifier scoped to a BenchmarkKit model type.
public struct BenchmarkID<Owner>: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The persisted identifier value.
    public let rawValue: String

    /// Creates an identifier from a raw string value.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a raw string value.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the identifier.
    public var description: String {
        rawValue
    }
}

/// A label that can be attached to suites, scenarios, metrics, runs, or samples.
public struct BenchmarkTag: Identifiable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    /// The tag identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable tag identifier.
    public var id: ID

    /// The display name for the tag.
    public var name: String

    /// Creates a benchmark tag.
    public init(id: ID, name: String? = nil) {
        self.id = id
        self.name = name ?? id.rawValue
    }

    /// Creates a benchmark tag from a string literal.
    public init(stringLiteral value: String) {
        self.init(id: ID(value))
    }
}

/// A stable dimension name used by scenario fingerprints.
///
/// Dimensions are intentionally string-backed so app-specific workflows can add
/// gates and buckets without changing BenchmarkKit's persisted schema.
public struct BenchmarkScenarioFingerprintDimension: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The persisted dimension key.
    public let rawValue: String

    /// Creates a fingerprint dimension from a raw key.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a fingerprint dimension from a raw key.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates a fingerprint dimension from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the dimension.
    public var description: String {
        rawValue
    }

    /// The workflow family, such as collage export or reels export.
    public static let workflow: Self = "workflow"

    /// The broad media family, such as image, video, or mixed media.
    public static let mediaKind: Self = "media.kind"

    /// The export family, such as H.264, HEVC, PNG, or JPEG.
    public static let exportKind: Self = "export.kind"

    /// The export container or file format.
    public static let exportFormat: Self = "export.format"

    /// The export preset or named quality tier.
    public static let exportPreset: Self = "export.preset"

    /// A coarse media count bucket.
    public static let mediaCountBucket: Self = "media.count.bucket"

    /// A coarse duration bucket.
    public static let durationBucket: Self = "duration.bucket"

    /// A coarse pixel or layout-size bucket.
    public static let sizeBucket: Self = "size.bucket"
}
