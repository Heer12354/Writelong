import Foundation

/// Aggregate local interaction measurements. No completion text, app content, or user identifiers
/// are persisted. These signals tune ranking confidence and trigger cadence; they never train or
/// alter the model.
public struct AdaptiveLearningSnapshot: Codable, Equatable, Sendable {
    public var accepted: Int = 0
    public var rejected: Int = 0
    public var ignored: Int = 0
    public var manualEditCharacters: Int = 0
    public var backspaces: Int = 0
    public var acceptanceLatencyMillis: [Double] = []
    public var completionLengths: [Int] = []
    public init() {}
    public var acceptanceRate: Double { Double(accepted) / Double(max(accepted + rejected + ignored, 1)) }
}

public struct AdaptiveLearningAdjustments: Equatable, Sendable {
    public var confidenceOffset: Double
    public var debounceMillis: Int
    public var preferredMaximumTokens: Int
    public static let neutral = AdaptiveLearningAdjustments(confidenceOffset: 0, debounceMillis: 0, preferredMaximumTokens: 0)
}

public enum AdaptiveLearningTuner {
    public static func adjustments(for snapshot: AdaptiveLearningSnapshot, minimumSamples: Int = 20) -> AdaptiveLearningAdjustments {
        guard snapshot.accepted + snapshot.rejected + snapshot.ignored >= minimumSamples else { return .neutral }
        let confidenceOffset = snapshot.acceptanceRate < 0.2 ? 0.12 : (snapshot.acceptanceRate > 0.6 ? -0.04 : 0)
        let editsPerAcceptance = Double(snapshot.manualEditCharacters) / Double(max(snapshot.accepted, 1))
        let tokens = editsPerAcceptance > 8 ? 4 : 0
        return AdaptiveLearningAdjustments(confidenceOffset: confidenceOffset, debounceMillis: snapshot.backspaces > snapshot.accepted ? 80 : 0, preferredMaximumTokens: tokens)
    }
}

public final class AdaptiveLearningStore: @unchecked Sendable {
    private let url: URL?
    private let lock = NSLock()
    private var snapshot: AdaptiveLearningSnapshot
    public init(url: URL? = nil) { self.url = url; self.snapshot = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(AdaptiveLearningSnapshot.self, from: $0) } ?? .init() }
    public func currentSnapshot() -> AdaptiveLearningSnapshot { lock.withLock { snapshot } }
    public func recordAccepted(latencyMillis: Double, completionLength: Int) { mutate { $0.accepted += 1; $0.acceptanceLatencyMillis.append(latencyMillis); $0.completionLengths.append(completionLength); $0.acceptanceLatencyMillis = Array($0.acceptanceLatencyMillis.suffix(500)); $0.completionLengths = Array($0.completionLengths.suffix(500)) } }
    public func recordRejected() { mutate { $0.rejected += 1 } }
    public func recordIgnored() { mutate { $0.ignored += 1 } }
    public func recordManualEdit(characters: Int) { mutate { $0.manualEditCharacters += max(0, characters) } }
    public func recordBackspace() { mutate { $0.backspaces += 1 } }
    private func mutate(_ change: (inout AdaptiveLearningSnapshot) -> Void) { lock.withLock { change(&snapshot); guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }; try? data.write(to: url, options: .atomic) } }
}
