@testable import ModelManagement
import XCTest

final class SmartModelManagerTests: XCTestCase {
    func testLowBatteryUsesSmallestInstalledModel() {
        let selected = SmartModelManager().selectModel(
            from: RuntimeModelCatalog.models,
            preferences: ModelSelectionPreferences(preset: .quality),
            context: ModelSelectionContext(batteryLevel: 0.1)
        )
        XCTAssertEqual(selected?.filename, RuntimeModelCatalog.models.first?.filename)
    }

    func testPresetAssignmentWinsWhenConditionsAllowIt() {
        let model = RuntimeModelCatalog.models[1]
        let selected = SmartModelManager().selectModel(
            from: RuntimeModelCatalog.models,
            preferences: ModelSelectionPreferences(preset: .balanced, preferredModelFilenames: [.balanced: model.filename]),
            context: ModelSelectionContext()
        )
        XCTAssertEqual(selected?.filename, model.filename)
    }
}
