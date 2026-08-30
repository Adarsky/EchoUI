import XCTest

final class FrontendAIUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testLongPersonaPromptStaysInsideTheCompactEditor() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["person.fill"].tap()
        XCTAssertTrue(app.navigationBars["Your personas"].waitForExistence(timeout: 3))
        app.buttons.matching(identifier: "plus").element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars["New Persona"].waitForExistence(timeout: 3))

        let promptEditor = app.textViews.firstMatch
        promptEditor.tap()
        promptEditor.typeText(String(repeating: "long prompt word ", count: 40) + "END_MARKER")

        let createButton = app.buttons["Create Persona"]
        let controlGap = createButton.frame.minY - promptEditor.frame.maxY
        XCTAssertLessThan(
            controlGap,
            120,
            "Long text must scroll inside the editor instead of expanding the outer form."
        )

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(promptEditor.frame.maxY, keyboard.frame.minY)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
