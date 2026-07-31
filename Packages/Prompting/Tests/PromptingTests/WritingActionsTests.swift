import AutocompleteCore
@testable import Prompting
import XCTest

final class WritingActionsTests: XCTestCase {
    func testActionPromptIncludesActionAndSelectedText() {
        let context = TextFieldContext(beforeCursor: "", target: AppTarget(bundleIdentifier: "com.example.Editor", appName: "Editor"))
        let request = WritingActionRequest(action: .improveClarity, selectedText: "A confusing sentence.", context: context, styleInstructions: ["Prefer concise sentences."])
        let prompt = WritingActionPromptBuilder().build(request).prompt

        XCTAssertTrue(prompt.contains("Rewrite for clear, direct understanding."))
        XCTAssertTrue(prompt.contains("A confusing sentence."))
        XCTAssertTrue(prompt.contains("Prefer concise sentences."))
    }
}
