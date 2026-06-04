import Foundation
import Testing
@testable import BenchmarkKit

@Suite("BenchmarkTitleComposer")
struct BenchmarkTitleComposerTests {
    private let composer = DefaultBenchmarkTitleComposer()

    private let canonicalSequence: [BenchmarkActionTag] = [
        BenchmarkActionTag(id: "action.import.fourKHEVC", phrase: "Imported 4K HEVC"),
        BenchmarkActionTag(id: "action.filter.warmLUT", phrase: "applied warm LUT"),
        BenchmarkActionTag(id: "action.export.h264_1080p", phrase: "exported 1080p")
    ]

    @Test("Composer joins phrases into a human title")
    func composerJoinsPhrasesIntoTitle() {
        let result = composer.compose(actions: canonicalSequence)
        #expect(result.text == "Imported 4K HEVC, applied warm LUT, exported 1080p")
    }

    @Test("Composer hash is deterministic across composer instances")
    func composerHashIsDeterministic() {
        let first = composer.compose(actions: canonicalSequence).hash
        let second = DefaultBenchmarkTitleComposer().compose(actions: canonicalSequence).hash

        #expect(first == second)
        // Pin the digest so the wire format change is loud, not silent.
        #expect(first == "2f37fc2fc69797860a6b3489c856f1b06bce1462c55b08beba0d8b8bc0f4188a")
    }

    @Test("Different phrases do not change the hash when ids match")
    func composerHashIgnoresPhraseSpelling() {
        let respelled: [BenchmarkActionTag] = canonicalSequence.map {
            BenchmarkActionTag(id: $0.id, phrase: $0.phrase + " v2")
        }
        let original = composer.compose(actions: canonicalSequence).hash
        let restyled = composer.compose(actions: respelled).hash
        #expect(original == restyled)
    }

    @Test("Reordered actions produce a different hash")
    func composerHashHonorsOrder() {
        let reversed = Array(canonicalSequence.reversed())
        let original = composer.compose(actions: canonicalSequence).hash
        let reorderedHash = composer.compose(actions: reversed).hash
        #expect(original != reorderedHash)
    }

    @Test("Empty action sequence produces an empty title and a stable hash")
    func composerHandlesEmptyInput() {
        let empty = composer.compose(actions: [])
        #expect(empty.text == "")
        #expect(empty.hash == composer.compose(actions: []).hash)
        #expect(!empty.hash.isEmpty)
    }

    @Test("Hash input embeds the versioned prefix")
    func composerHashInputHasVersionPrefix() {
        let input = DefaultBenchmarkTitleComposer.hashInput(for: canonicalSequence)
        #expect(input.hasPrefix(DefaultBenchmarkTitleComposer.hashVersion))
    }
}
