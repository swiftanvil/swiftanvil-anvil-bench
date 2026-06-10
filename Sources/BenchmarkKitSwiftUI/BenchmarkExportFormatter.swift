import BenchmarkKit
import Foundation

enum BenchmarkExportFormatter {
    static func summary(for rows: [BenchmarkComparisonRow]) -> String {
        guard rows.isEmpty == false else {
            return "Benchmark comparison export\nNo benchmark comparisons are available for the current filters."
        }

        let header = "Benchmark comparison export"
        let overview = [
            "Comparisons: \(rows.count)",
            "Improved: \(rows.count(where: { $0.status == .improved }))",
            "Regressed: \(rows.count(where: { $0.status == .regressed }))",
            "Missing data: \(rows.count(where: { $0.status.isMissingData }))"
        ]
        .joined(separator: "\n")
        let rowSummaries = rows.map(summaryLine(for:)).joined(separator: "\n\n")

        return [header, overview, rowSummaries].joined(separator: "\n\n")
    }

    static func summary(for row: BenchmarkComparisonRow) -> String {
        [
            "Benchmark metric export",
            summaryLine(for: row),
            "Confidence: \(row.confidence.level.title). \(row.confidence.summary)",
            matrixContextSection(for: row),
            exportBlockingSection(for: row),
            notesSection(for: row)
        ]
        .filter { $0.isEmpty == false }
        .joined(separator: "\n\n")
    }

    private static func summaryLine(for row: BenchmarkComparisonRow) -> String {
        [
            "\(row.suite.name) / \(row.scenario.name) / \(row.metric.name)",
            "State: \(row.status.title)",
            "Baseline: \(BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit)) (\(row.comparison.baseline.count) samples)",
            "Current: \(BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)) (\(row.comparison.current.count) samples)",
            "Delta: \(BenchmarkValueFormatter.delta(row.comparison.delta, unit: row.metric.unit))",
            "Trend: \(BenchmarkValueFormatter.trendDirection(row.trend.direction))",
            row.contextSummary.map { "Context: \($0)" },
            exportBlockingSummaryLine(for: row)
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    private static func matrixContextSection(for row: BenchmarkComparisonRow) -> String {
        guard row.matrixContexts.isEmpty == false else {
            return "Matrix context: Unavailable"
        }

        let contexts = row.matrixContexts.map { context in
            "\(context.scope.title): \(context.summary), \(BenchmarkValueFormatter.date(context.startedAt)), \(context.archiveState.rawValue)"
        }

        return (["Matrix context:"] + contexts).joined(separator: "\n")
    }

    private static func exportBlockingSummaryLine(for row: BenchmarkComparisonRow) -> String? {
        guard isExportBlockingRow(row) else {
            return nil
        }

        return preferredExportBlockingContext(in: row.matrixContexts)
            .flatMap(exportBlockingCompactSummary(for:))
    }

    private static func exportBlockingSection(for row: BenchmarkComparisonRow) -> String {
        guard isExportBlockingRow(row) else {
            return ""
        }

        let contexts = row.matrixContexts.compactMap(exportBlockingDetailedSummary(for:))
        guard contexts.isEmpty == false else {
            return ""
        }

        return (["Export blocking context:"] + contexts).joined(separator: "\n")
    }

    private static func notesSection(for row: BenchmarkComparisonRow) -> String {
        guard row.notes.isEmpty == false else {
            return "Notes: None"
        }

        return "Notes: \(row.notes.joined(separator: "; "))"
    }

    private static func isExportBlockingRow(_ row: BenchmarkComparisonRow) -> Bool {
        row.suite.id == BenchmarkExportBlocking.suiteID
    }

    private static func preferredExportBlockingContext(
        in contexts: [BenchmarkRunMatrixContext]
    ) -> BenchmarkRunMatrixContext? {
        contexts.last {
            exportShapeContext(from: $0.metadata) != nil || environmentSummary(from: $0.metadata, compact: true) != nil
        }
    }

    private static func exportBlockingCompactSummary(for context: BenchmarkRunMatrixContext) -> String? {
        let shape = exportShapeContext(from: context.metadata)
        let parts = [
            shape.map(compactShapeSummary(for:)),
            shape.map(samplingSummary(for:)),
            compactOutputSummary(for: shape),
            environmentSummary(from: context.metadata, compact: true).map { "Environment: \($0)" }
        ]
        .compactMap(\.self)

        guard parts.isEmpty == false else {
            return nil
        }

        return "Export: \(parts.joined(separator: " | "))"
    }

    private static func exportBlockingDetailedSummary(for context: BenchmarkRunMatrixContext) -> String? {
        let shape = exportShapeContext(from: context.metadata)
        let parts = [
            shape.map(compactShapeSummary(for:)),
            shape.map(samplingSummary(for:)),
            shape.map(sceneSummary(for:)),
            fullOutputSummary(for: shape),
            environmentSummary(from: context.metadata, compact: false).map { "Environment: \($0)" }
        ]
        .compactMap(\.self)

        guard parts.isEmpty == false else {
            return nil
        }

        return "\(context.scope.title): \(parts.joined(separator: " | "))"
    }

    private static func exportShapeContext(
        from metadata: [String: String]
    ) -> BenchmarkExportShapeContext? {
        guard let encoded = metadata[BenchmarkExportShapeContext.metadataKey] else {
            return nil
        }

        return try? BenchmarkExportShapeContext.decoded(from: encoded)
    }

    private static func compactShapeSummary(for context: BenchmarkExportShapeContext) -> String {
        "\(context.exportKind.rawValue.capitalized) via \(context.engineRoute.rawValue)"
    }

    private static func samplingSummary(for context: BenchmarkExportShapeContext) -> String {
        "Sampling: \(context.samplingProfile.rawValue)"
    }

    private static func sceneSummary(for context: BenchmarkExportShapeContext) -> String {
        var parts = [
            pluralized(context.pageCount, singular: "page"),
            pluralized(context.sceneItemCount, singular: "item"),
            pluralized(context.videoItemCount, singular: "video"),
            pluralized(context.imageItemCount, singular: "image"),
            pluralized(context.stickerItemCount, singular: "sticker"),
            pluralized(context.textItemCount, singular: "text")
        ]
        parts.append(context.hasAudio ? "audio" : "no audio")
        return "Scene: \(parts.joined(separator: ", "))"
    }

    private static func compactOutputSummary(for context: BenchmarkExportShapeContext?) -> String? {
        guard let context else {
            return nil
        }

        var parts: [String] = []

        if let outputWidth = context.outputWidth, let outputHeight = context.outputHeight {
            parts.append("\(outputWidth)x\(outputHeight) px")
        }

        if let outputContainer = context.outputContainer?.rawValue {
            parts.append(outputContainer)
        }

        guard parts.isEmpty == false else {
            return nil
        }

        return "Output: \(parts.joined(separator: ", "))"
    }

    private static func fullOutputSummary(for context: BenchmarkExportShapeContext?) -> String? {
        guard let context else {
            return nil
        }

        var parts: [String] = []

        if let outputWidth = context.outputWidth, let outputHeight = context.outputHeight {
            parts.append("\(outputWidth)x\(outputHeight) px")
        }

        if let outputDurationSeconds = context.outputDurationSeconds {
            parts.append("\(format(decimal: outputDurationSeconds)) s")
        }

        if let outputFrameRate = context.outputFrameRate {
            parts.append("\(format(decimal: outputFrameRate)) fps")
        }

        if let outputContainer = context.outputContainer?.rawValue {
            parts.append(outputContainer)
        }

        if let outputBitrateKbps = context.outputBitrateKbps {
            parts.append("\(outputBitrateKbps) kbps")
        }

        guard parts.isEmpty == false else {
            return nil
        }

        return "Output: \(parts.joined(separator: ", "))"
    }

    private static func environmentSummary(
        from metadata: [String: String],
        compact: Bool
    ) -> String? {
        var parts: [String] = []

        if let deviceModel = metadata[BenchmarkEnvironmentMetadataKey.deviceModel], deviceModel.isEmpty == false {
            parts.append(deviceModel)
        }

        if
            compact == false,
            let cpuClass = metadata[BenchmarkEnvironmentMetadataKey.cpuClass],
            cpuClass.isEmpty == false
        {
            parts.append(cpuClass)
        }

        if
            compact == false,
            let totalPhysicalMemoryBytes = metadata[BenchmarkEnvironmentMetadataKey.totalPhysicalMemoryBytes],
            let bytes = Double(totalPhysicalMemoryBytes)
        {
            parts.append(BenchmarkValueFormatter.value(bytes, unit: .bytes))
        }

        let osSummary = osSummary(from: metadata)
        if let osSummary {
            parts.append(osSummary)
        }

        let buildSummary = buildSummary(from: metadata)
        if let buildSummary {
            parts.append(buildSummary)
        }

        if let gitSHA = metadata[BenchmarkEnvironmentMetadataKey.gitSHA], gitSHA.isEmpty == false {
            parts.append("git \(gitSHA)")
        }

        if let scheme = metadata[BenchmarkEnvironmentMetadataKey.scheme], scheme.isEmpty == false {
            parts.append(scheme)
        }

        if
            compact == false,
            let localeIdentifier = metadata[BenchmarkEnvironmentMetadataKey.localeIdentifier],
            localeIdentifier.isEmpty == false
        {
            parts.append("locale \(localeIdentifier)")
        }

        if
            compact == false,
            let timeZoneIdentifier = metadata[BenchmarkEnvironmentMetadataKey.timeZoneIdentifier],
            timeZoneIdentifier.isEmpty == false
        {
            parts.append("tz \(timeZoneIdentifier)")
        }

        if let isSimulator = metadata[BenchmarkEnvironmentMetadataKey.isSimulator], isSimulator == "true" {
            parts.append("simulator")
        }

        guard parts.isEmpty == false else {
            return nil
        }

        return parts.joined(separator: ", ")
    }

    private static func osSummary(from metadata: [String: String]) -> String? {
        let version = metadata[BenchmarkEnvironmentMetadataKey.osVersion]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildNumber = metadata[BenchmarkEnvironmentMetadataKey.osBuildNumber]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch (version?.isEmpty == false ? version : nil, buildNumber?.isEmpty == false ? buildNumber : nil) {
        case let (version?, buildNumber?):
            return "\(version) (\(buildNumber))"
        case let (version?, nil):
            return version
        case let (nil, buildNumber?):
            return buildNumber
        case (nil, nil):
            return nil
        }
    }

    private static func buildSummary(from metadata: [String: String]) -> String? {
        let shortVersion = metadata[BenchmarkEnvironmentMetadataKey.bundleShortVersion]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildNumber = metadata[BenchmarkEnvironmentMetadataKey.bundleBuildNumber]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch (
            shortVersion?.isEmpty == false ? shortVersion : nil,
            buildNumber?.isEmpty == false ? buildNumber : nil
        ) {
        case let (shortVersion?, buildNumber?):
            return "\(shortVersion) (\(buildNumber))"
        case let (shortVersion?, nil):
            return shortVersion
        case let (nil, buildNumber?):
            return buildNumber
        case (nil, nil):
            return nil
        }
    }

    private static func pluralized(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }

    private static func format(decimal value: Double) -> String {
        String(format: "%.2f", value)
    }
}
