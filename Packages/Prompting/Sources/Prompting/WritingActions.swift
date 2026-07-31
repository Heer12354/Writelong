import AutocompleteCore
import Foundation

/// Transformations supported by the local writing assistant. The action only defines intent; one
/// shared prompt pipeline continues to own context budgeting and rendering.
public enum WritingAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case continueWriting, rewriteShorter, rewriteLonger, fixGrammar, improveClarity
    case professionalTone, friendlyTone, simplify, summarize, explain, translate
    case bulletPoints, paragraph, email, documentation

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .continueWriting: "Continue Writing"
        case .rewriteShorter: "Rewrite Shorter"
        case .rewriteLonger: "Rewrite Longer"
        case .fixGrammar: "Fix Grammar"
        case .improveClarity: "Improve Clarity"
        case .professionalTone: "Professional Tone"
        case .friendlyTone: "Friendly Tone"
        case .simplify: "Simplify"
        case .summarize: "Summarize"
        case .explain: "Explain"
        case .translate: "Translate"
        case .bulletPoints: "Convert to Bullet Points"
        case .paragraph: "Convert to Paragraph"
        case .email: "Convert to Email"
        case .documentation: "Convert to Documentation"
        }
    }

    var instruction: String {
        switch self {
        case .continueWriting: "Continue the text naturally."
        case .rewriteShorter: "Rewrite the text more concisely while preserving meaning."
        case .rewriteLonger: "Expand the text with useful detail while preserving meaning."
        case .fixGrammar: "Correct grammar, spelling, and punctuation while preserving voice."
        case .improveClarity: "Rewrite for clear, direct understanding."
        case .professionalTone: "Rewrite in a professional, respectful tone."
        case .friendlyTone: "Rewrite in a warm, friendly tone."
        case .simplify: "Simplify the wording without losing important meaning."
        case .summarize: "Summarize the key points concisely."
        case .explain: "Explain the text clearly for a general reader."
        case .translate: "Translate the text, preserving its meaning and formatting."
        case .bulletPoints: "Convert the content into concise bullet points."
        case .paragraph: "Convert the content into a cohesive paragraph."
        case .email: "Convert the content into a clear, professional email."
        case .documentation: "Convert the content into concise technical documentation."
        }
    }
}

public struct WritingActionRequest: Equatable, Sendable {
    public var action: WritingAction
    public var selectedText: String
    public var context: TextFieldContext
    public var styleInstructions: [String]

    public init(action: WritingAction, selectedText: String, context: TextFieldContext, styleInstructions: [String] = []) {
        self.action = action
        self.selectedText = selectedText
        self.context = context
        self.styleInstructions = styleInstructions
    }
}

public struct WritingActionPromptBuilder {
    public init() {}

    /// Action prompts use the same local model runtime and tokenizer budget as completions. They are
    /// deliberately isolated from the live cursor-completion prompt so an action can be cancelled or
    /// disabled without changing autocomplete behavior.
    public func build(_ request: WritingActionRequest) -> PromptBuildResult {
        let safeText = request.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let actionContext = TextFieldContext(
            beforeCursor: "Task: \(request.action.instruction)\n\nText:\n\(safeText)\n\nResult:\n",
            target: request.context.target,
            detectedLanguage: request.context.detectedLanguage,
            typingContext: request.context.typingContext
        )
        return PromptBuilder().buildPrompt(
            context: actionContext,
            customInstructions: request.styleInstructions,
            mode: .baseContinuation,
            includeEnvironmentContext: false
        )
    }
}
