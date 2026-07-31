import Foundation

public enum ModelPerformancePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case fast, balanced, quality, coding, custom
    public var id: String { rawValue }
}

/// Hardware and task measurements used to select a model. Callers may leave unavailable values nil;
/// selection remains deterministic and never assumes a network service.
public struct ModelSelectionContext: Equatable, Sendable {
    public var batteryLevel: Double?
    public var cpuUsage: Double?
    public var memoryPressure: Double?
    public var bundleIdentifier: String?
    public var textLength: Int
    public var promptComplexity: Double
    public var typingCharactersPerSecond: Double
    public init(batteryLevel: Double? = nil, cpuUsage: Double? = nil, memoryPressure: Double? = nil, bundleIdentifier: String? = nil, textLength: Int = 0, promptComplexity: Double = 0, typingCharactersPerSecond: Double = 0) {
        self.batteryLevel = batteryLevel; self.cpuUsage = cpuUsage; self.memoryPressure = memoryPressure; self.bundleIdentifier = bundleIdentifier; self.textLength = textLength; self.promptComplexity = promptComplexity; self.typingCharactersPerSecond = typingCharactersPerSecond
    }
}

public struct ModelSelectionPreferences: Equatable, Sendable {
    public var preset: ModelPerformancePreset
    public var preferredModelFilenames: [ModelPerformancePreset: String]
    public init(preset: ModelPerformancePreset = .balanced, preferredModelFilenames: [ModelPerformancePreset: String] = [:]) { self.preset = preset; self.preferredModelFilenames = preferredModelFilenames }
}

public struct SmartModelManager {
    public init() {}

    /// Chooses only from installed candidates. It never hardcodes a specific catalog name, so future
    /// models join automatically through their metadata and the user's preset assignments.
    public func selectModel(from installed: [DownloadableRuntimeModel], preferences: ModelSelectionPreferences, context: ModelSelectionContext) -> DownloadableRuntimeModel? {
        guard !installed.isEmpty else { return nil }
        let effectivePreset = constrainedPreset(preferences.preset, context: context)
        if let filename = preferences.preferredModelFilenames[effectivePreset], let assigned = installed.first(where: { $0.filename == filename }) { return assigned }
        let ordered = installed.sorted { estimatedSize($0) < estimatedSize($1) }
        switch effectivePreset {
        case .fast: return ordered.first
        case .quality: return ordered.last
        case .coding: return ordered.last ?? ordered.first
        case .balanced, .custom: return ordered[ordered.count / 2]
        }
    }

    private func constrainedPreset(_ requested: ModelPerformancePreset, context: ModelSelectionContext) -> ModelPerformancePreset {
        if context.batteryLevel.map({ $0 < 0.2 }) == true || context.cpuUsage.map({ $0 > 0.85 }) == true || context.memoryPressure.map({ $0 > 0.8 }) == true || context.typingCharactersPerSecond > 8 { return .fast }
        if context.bundleIdentifier?.lowercased().contains("xcode") == true || context.bundleIdentifier?.lowercased().contains("code") == true { return requested == .custom ? .custom : .coding }
        if context.promptComplexity > 0.7 || context.textLength > 2_000 { return requested == .fast ? .fast : .quality }
        return requested
    }

    private func estimatedSize(_ model: DownloadableRuntimeModel) -> Int64 {
        model.expectedSizeBytes ?? Int64(model.approximateSizeLabel.filter(\.isNumber)) ?? 0
    }
}
