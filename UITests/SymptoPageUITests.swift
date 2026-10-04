import XCTest

final class SymptoPageUITests: XCTestCase {
  func testSymptomSaveEditAndDelete() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["firstVisit"].waitForExistence(timeout: 10))
    app.buttons["firstVisit"].tap()
    let reason = app.descendants(matching: .any).matching(identifier: "visitReason").firstMatch
    XCTAssertTrue(reason.waitForExistence(timeout: 5)); reason.tap(); reason.typeText("UI symptom flow")
    app.buttons["Save"].tap()
    XCTAssertTrue(app.buttons["recordSymptom"].waitForExistence(timeout: 5)); app.buttons["recordSymptom"].tap()
    app.buttons["symptom-pain"].tap()
    let note = app.descendants(matching: .any).matching(identifier: "eventNote").firstMatch
    note.tap(); note.typeText("Recorded note")
    app.buttons["Save"].tap(); app.buttons["openJournal"].tap()
    XCTAssertTrue(app.staticTexts["Recorded note"].waitForExistence(timeout: 5))
    app.buttons["Edit"].firstMatch.tap()
    let edit = app.descendants(matching: .any).matching(identifier: "eventNote").firstMatch
    edit.tap(); edit.typeText(" updated")
    app.buttons["Save"].tap()
    XCTAssertTrue(app.staticTexts["Recorded note updated"].waitForExistence(timeout: 5))
    app.buttons["Delete"].firstMatch.tap(); app.buttons["Delete event"].tap()
    XCTAssertTrue(app.staticTexts["No matching events"].waitForExistence(timeout: 5))
  }
  func launch() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--reset-test-data"]
    app.launch()
    return app
  }
  /// Fresh data opens the welcome screen first; it is shown again while no visit exists.
  func launchPastWelcome() -> XCUIApplication {
    let app = launch()
    XCTAssertTrue(app.buttons["startOnboarding"].waitForExistence(timeout: 10))
    app.buttons["startOnboarding"].tap()
    return app
  }
  func testThreeTabsAsInDesign() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.tabBars.buttons["Start"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.tabBars.buttons.count, 3)
    app.tabBars.buttons["Report"].tap()
    XCTAssertTrue(app.buttons["previewPDF"].waitForExistence(timeout: 5))
    app.buttons["reportJournal"].tap()
    XCTAssertTrue(app.staticTexts["No matching events"].waitForExistence(timeout: 5))
    app.tabBars.buttons["Settings"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["profileName"].waitForExistence(timeout: 5))
  }
  func testIntegrationsReachableFromStartAndSettings() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["connectPromo"].waitForExistence(timeout: 5))
    app.buttons["connectPromo"].tap()
    XCTAssertTrue(app.buttons["connectHealth"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["connectStrava"].isEnabled)
    app.tabBars.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["openIntegrations"].waitForExistence(timeout: 5))
  }
  func testWellbeingNoteFromStart() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["addNote"].waitForExistence(timeout: 5))
    app.buttons["addNote"].tap()
    app.buttons["mood-4"].tap()
    let text = app.descendants(matching: .any).matching(identifier: "noteText").firstMatch
    text.tap(); text.typeText("Walk helped")
    app.buttons["Save"].tap()
    XCTAssertTrue(app.staticTexts["Walk helped"].waitForExistence(timeout: 5))
    app.buttons["openJournal"].tap()
    XCTAssertTrue(app.staticTexts["Walk helped"].waitForExistence(timeout: 5))
  }
  func testQuickVisitAndDailyAnswer() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["quickAddVisit"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["quickAddVisit"].isEnabled)
    app.buttons["specialty-cardiologist"].tap()
    app.buttons["quickAddVisit"].tap()
    XCTAssertTrue(app.staticTexts["dailyQuestion"].waitForExistence(timeout: 5))
    app.buttons["answer-once"].tap()
    XCTAssertTrue(app.buttons["answer-once"].isSelected)
    app.terminate()
    app.launchArguments = ["--uitesting"]
    app.launch()
    XCTAssertTrue(app.buttons["answer-once"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["answer-once"].isSelected)
  }
  func testEmptyLaunchAndCancelKeepsNoVisit() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["firstVisit"].waitForExistence(timeout: 10))
    app.buttons["firstVisit"].tap()
    XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["firstVisit"].waitForExistence(timeout: 5))
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "Empty onboarding"
    shot.lifetime = .keepAlways
    add(shot)
  }
  func testCreateVisitPersistsAcrossRelaunch() {
    let app = launchPastWelcome()
    XCTAssertTrue(app.buttons["firstVisit"].waitForExistence(timeout: 5))
    app.buttons["firstVisit"].tap()
    let field = app.descendants(matching: .any).matching(identifier: "visitReason").firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("Questions for my appointment")
    app.buttons["Save"].tap()
    XCTAssertTrue(app.buttons["recordSymptom"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments = ["--uitesting"]
    app.launch()
    XCTAssertTrue(app.buttons["recordSymptom"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Questions for my appointment"].exists)
    app.buttons["recordSymptom"].tap()
    app.buttons["Cancel"].tap()
    app.buttons["openJournal"].tap()
    XCTAssertTrue(app.staticTexts["No matching events"].waitForExistence(timeout: 5))
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "Cancel does not save symptom"
    shot.lifetime = .keepAlways
    add(shot)
  }
}
