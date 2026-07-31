import Foundation
@testable import Personalization
import XCTest

final class WritingStyleProfileTests: XCTestCase {
    func testFingerprintKeepsOnlyAggregateStyleSignals() {
        var fingerprint = WritingStyleFingerprint()
        fingerprint.absorb(acceptedText: "Hello team!\n\n- One concise update 😊")
        fingerprint.absorb(acceptedText: "Thanks! Here is another short update.")
        fingerprint.absorb(acceptedText: "Great work!")

        XCTAssertEqual(fingerprint.acceptedSampleCount, 3)
        XCTAssertGreaterThan(fingerprint.totalWords, 0)
        XCTAssertGreaterThan(fingerprint.emojiCount, 0)
        XCTAssertFalse(fingerprint.promptInstructions().isEmpty)
        XCTAssertFalse(String(describing: fingerprint).contains("Hello team"))
    }

    func testProfileExportAndImportRoundTripsWithoutText() throws {
        let source = WritingProfileStore(url: nil)
        let profile = source.createProfile(named: "Work")
        source.recordAcceptedCompletion("Professional update.")
        let data = try source.exportProfile(id: profile.id)
        let restored = WritingProfileStore(url: nil)
        let imported = try restored.importProfile(data: data)

        XCTAssertEqual(imported.name, "Work")
        XCTAssertEqual(restored.activeProfile()?.id, imported.id)
        XCTAssertFalse(String(data: data, encoding: .utf8)?.contains("Professional update") ?? true)
    }

    func testAdaptiveTunerRaisesConfidenceAfterPoorFeedback() {
        var snapshot = AdaptiveLearningSnapshot()
        snapshot.rejected = 18
        snapshot.ignored = 5
        snapshot.accepted = 1
        XCTAssertGreaterThan(AdaptiveLearningTuner.adjustments(for: snapshot).confidenceOffset, 0)
    }
}
