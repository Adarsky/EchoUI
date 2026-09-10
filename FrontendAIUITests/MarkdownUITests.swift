import XCTest

final class MarkdownUITests: XCTestCase {
    @MainActor
    func testFormattedBlocksAppearBeforeStreamFinishes() {
        let app = XCUIApplication()
        app.launchArguments = ["--markdown-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Live Markdown"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Formatted while streaming"].exists)
        XCTAssertFalse(app.staticTexts["# Live Markdown"].exists)
        app.buttons["markdown.append"].tap()
        XCTAssertTrue(app.staticTexts["Blocks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed task"].exists)
        attachScreenshot(app, name: "Streaming Markdown blocks")
        app.swipeUp()
        XCTAssertTrue(app.buttons["markdown.copy-code"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        attachScreenshot(app, name: "Markdown table and code")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
