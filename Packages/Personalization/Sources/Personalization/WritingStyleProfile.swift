import Foundation
import Prompting

/// A privacy-preserving summary of a person's writing habits. It deliberately contains no source
/// text, tokens, or recoverable phrases; all values are aggregate counters and ratios.
public struct WritingStyleFingerprint: Codable, Equatable, Sendable {
    public var acceptedSampleCount: Int = 0
    public var totalCharacters: Int = 0
    public var totalWords: Int = 0
    public var totalSentences: Int = 0
    public var uppercaseLetters: Int = 0
    public var letters: Int = 0
    public var punctuationCounts: [String: Int] = [:]
    public var emojiCount: Int = 0
    public var markdownCount: Int = 0
    public var codeSampleCount: Int = 0
    public var indentationCounts: [Int: Int] = [:]
    public var commentCount: Int = 0
    public var abbreviationCount: Int = 0
    public var phraseShapeCounts: [String: Int] = [:]

    public init() {}

    public mutating func absorb(acceptedText text: String) {
        guard !text.isEmpty else { return }
        acceptedSampleCount += 1
        totalCharacters += text.count

        let words = text.split { !$0.isLetter && !$0.isNumber }
        totalWords += words.count
        totalSentences += max(1, text.filter { ".!?".contains($0) }.count)
        letters += text.filter(\.isLetter).count
        uppercaseLetters += text.filter { $0.isLetter && $0.isUppercase }.count
        emojiCount += text.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count
        markdownCount += text.components(separatedBy: "#").count - 1
        markdownCount += text.components(separatedBy: "*").count - 1
        markdownCount += text.components(separatedBy: "`").count - 1
        commentCount += text.components(separatedBy: "//").count - 1
        commentCount += text.components(separatedBy: "/*").count - 1

        for character in text where ".,;:!?()[]{}-".contains(character) {
            punctuationCounts[String(character), default: 0] += 1
        }
        for word in words where word.count <= 5 && word.contains(where: \.isUppercase) {
            abbreviationCount += 1
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let indentation = line.prefix { $0 == " " || $0 == "\t" }.count
            if indentation > 0 { indentationCounts[indentation, default: 0] += 1 }
        }
        if text.contains("{") || text.contains(";") || text.contains("func ") || text.contains("let ") {
            codeSampleCount += 1
        }

        // A word-length shape supports aggregate phrase-pattern learning without storing words.
        for phrase in text.split(whereSeparator: { character in
            character == "." || character == "!" || character == "?" || character == "\n"
        }) {
            let phraseText = String(phrase)
            let shape = phraseText
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .prefix(5)
                .map { String($0.count) }
                .joined(separator: "-")
            if !shape.isEmpty { phraseShapeCounts[shape, default: 0] += 1 }
        }
    }

    public var averageSentenceLength: Double {
        Double(totalWords) / Double(max(totalSentences, 1))
    }

    public var uppercaseRatio: Double {
        Double(uppercaseLetters) / Double(max(letters, 1))
    }

    public var emojiRate: Double {
        Double(emojiCount) / Double(max(totalWords, 1))
    }

    public func promptInstructions() -> [String] {
        guard acceptedSampleCount >= 3 else { return [] }
        var instructions: [String] = []
        if averageSentenceLength <= 12 { instructions.append("Prefer concise sentences.") }
        if averageSentenceLength >= 24 { instructions.append("Prefer detailed, longer sentences when context supports them.") }
        if emojiRate >= 0.04 { instructions.append("Emoji use is welcome when it naturally matches the context.") }
        if uppercaseRatio < 0.03 { instructions.append("Avoid unnecessary capitalization.") }
        if (punctuationCounts["!"] ?? 0) > acceptedSampleCount { instructions.append("Use an energetic but natural punctuation style.") }
        if markdownCount >= acceptedSampleCount { instructions.append("Preserve a Markdown-friendly writing style when appropriate.") }
        if codeSampleCount * 2 >= acceptedSampleCount {
            instructions.append("When completing code, preserve the surrounding coding conventions and indentation.")
        }
        if commentCount > 0 { instructions.append("Keep code comments concise and consistent with surrounding code.") }
        return instructions
    }
}

public struct WritingProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var fingerprint: WritingStyleFingerprint

    public init(id: UUID = UUID(), name: String, isEnabled: Bool = true, fingerprint: WritingStyleFingerprint = .init()) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.fingerprint = fingerprint
    }
}

/// File-backed, local-only profile manager. The JSON contains aggregate statistics only and is safe
/// to export/import without exposing the text from which the profile was learned.
public final class WritingProfileStore: @unchecked Sendable {
    private struct State: Codable { var activeProfileID: UUID?; var profiles: [WritingProfile] }
    private let url: URL?
    private let lock = NSLock()
    private var state: State

    public static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("KeyType/Profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("writing-profiles.json")
    }

    public init(url: URL? = try? WritingProfileStore.defaultURL()) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            let profile = WritingProfile(name: "Personal")
            state = State(activeProfileID: profile.id, profiles: [profile])
        }
    }

    public func profiles() -> [WritingProfile] { lock.withLock { state.profiles } }
    public func activeProfile() -> WritingProfile? { lock.withLock { state.profiles.first { $0.id == state.activeProfileID } } }
    public func setActiveProfile(id: UUID?) { mutate { $0.activeProfileID = id } }
    public func createProfile(named name: String) -> WritingProfile {
        let profile = WritingProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Profile" : name)
        mutate { $0.profiles.append(profile); $0.activeProfileID = profile.id }
        return profile
    }
    public func setEnabled(_ enabled: Bool, profileID: UUID) { mutate { state in guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else { return }; state.profiles[index].isEnabled = enabled } }
    public func reset(profileID: UUID) { mutate { state in guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else { return }; state.profiles[index].fingerprint = .init() } }
    public func recordAcceptedCompletion(_ text: String) { mutate { state in guard let index = state.profiles.firstIndex(where: { $0.id == state.activeProfileID }), state.profiles[index].isEnabled else { return }; state.profiles[index].fingerprint.absorb(acceptedText: text) } }
    public func activePromptInstructions() -> [String] { activeProfile().flatMap { $0.isEnabled ? $0.fingerprint.promptInstructions() : nil } ?? [] }
    public func exportProfile(id: UUID) throws -> Data { try lock.withLock { guard let profile = state.profiles.first(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }; return try JSONEncoder().encode(profile) } }
    @discardableResult public func importProfile(data: Data) throws -> WritingProfile { let profile = try JSONDecoder().decode(WritingProfile.self, from: data); mutate { $0.profiles.removeAll { $0.id == profile.id }; $0.profiles.append(profile); $0.activeProfileID = profile.id }; return profile }

    private func mutate(_ change: (inout State) -> Void) { lock.withLock { change(&state); guard let url, let data = try? JSONEncoder().encode(state) else { return }; try? data.write(to: url, options: .atomic) } }
}

private extension NSLock { func withLock<T>(_ body: () throws -> T) rethrows -> T { lock(); defer { unlock() }; return try body() } }
