import UIKit
import XCTest

/// Walks every control in the demo and the pairing screens, checking what each one does and saving a screenshot of
/// each state (attached to the test, and written to dist/review/phone when the Mac's folder is reachable).
final class NocturnalPhoneUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testDemoWalkthrough() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()

        let headline = app.staticTexts["headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(headline.label.contains("Keeps working"), headline.label)
        sleep(1)
        shot(app, "01-home")

        // The band: tap the 2 hour stop.
        let band = app.descendants(matching: .any)["band"].firstMatch
        XCTAssertTrue(band.exists, app.debugDescription)
        tapStop(band, 3)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Until"), app.staticTexts["readout"].label)
        shot(app, "02-two-hours")

        // Drag the lens to Always.
        let from = band.coordinate(withNormalizedOffset: CGVector(dx: 3.5 / 7, dy: 0.5))
        let to = band.coordinate(withNormalizedOffset: CGVector(dx: 6.5 / 7, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Always"), app.staticTexts["readout"].label)
        shot(app, "03-always")

        // Sleep now waits with an Undo; the band already shows where it lands (When busy, not Always).
        app.buttons["main"].tap()
        let undo = app.buttons["undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Sleeps in"), app.staticTexts["readout"].label)
        shot(app, "04-sleep-undo")
        undo.tap()
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Always"), app.staticTexts["readout"].label)

        // Sleep for real: once the Undo runs out it says Asleep straight away, the ground goes to night and the
        // band rests until it wakes.
        app.buttons["main"].tap()
        XCTAssertTrue(wait(headline, contains: "Asleep", timeout: 8), headline.label)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Asleep"), app.staticTexts["readout"].label)
        XCTAssertTrue((band.value as? String ?? "").contains("unavailable"), "\(band.value ?? "")")
        sleep(1)
        shot(app, "05-asleep")

        // Settings say it's asleep and stay put until it wakes.
        app.buttons["settings"].tap()
        XCTAssertTrue(app.staticTexts["It's asleep. Settings change once it wakes."].waitForExistence(timeout: 3), app.debugDescription)
        sleep(1)
        shot(app, "05b-asleep-settings")
        app.buttons["closeSettings"].tap()
        sleep(1)

        // Wake it: the demo answers at once (a real sleeping computer picks it up at its next check-in).
        XCTAssertEqual(app.buttons["main"].label, "Wake it")
        app.buttons["main"].tap()
        XCTAssertTrue(wait(headline, contains: "Keeps working", timeout: 4), headline.label)
        sleep(1)
        shot(app, "06-woken")

        // Settings: a sheet out of the gear; pull up for the whole screen; close it.
        app.buttons["settings"].tap()
        XCTAssertTrue(app.staticTexts["Keeps it awake"].waitForExistence(timeout: 3), app.debugDescription)
        sleep(1)
        shot(app, "07-settings-half")
        let sheetPoint = app.staticTexts["Keeps it awake"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        sheetPoint.press(forDuration: 0.05, thenDragTo: sheetPoint.withOffset(CGVector(dx: 0, dy: -380)))
        sleep(1)
        shot(app, "08-settings-full")
        app.swipeUp()
        sleep(1)
        shot(app, "09-settings-scrolled")
        app.swipeUp()
        sleep(1)
        shot(app, "10-settings-bottom")
        XCTAssertTrue(app.buttons["forget"].exists)
        XCTAssertTrue(app.staticTexts["Busy apps"].exists || app.staticTexts["On the computer"].exists, app.debugDescription)
        app.buttons["closeSettings"].tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts["Keeps it awake"].isHittable)
        shot(app, "11-settings-closed")

        // Exit the demo.
        app.buttons["exitDemo"].tap()
        XCTAssertTrue(app.buttons["next"].waitForExistence(timeout: 3), app.debugDescription)
        sleep(1)
        shot(app, "12-after-demo")
    }

    @MainActor
    func testPairScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-unpaired"]
        app.launch()
        XCTAssertTrue(app.buttons["next"].waitForExistence(timeout: 5), app.debugDescription)
        sleep(1)
        shot(app, "20-welcome")
        app.buttons["next"].tap()
        XCTAssertTrue(app.buttons["type"].waitForExistence(timeout: 3), app.debugDescription)
        sleep(1)
        shot(app, "21-pair")
        UIPasteboard.general.string = "not a code"
        app.buttons["paste"].tap()
        // iOS asks once whether the app may paste.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Paste", "Allow"] where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
            break
        }
        shot(app, "21b-after-paste")
        // Either the pasted text is refused, or (if the simulator kept the clipboard to itself) it asks for a copy.
        XCTAssertTrue(wait(app.staticTexts["pairError"], contains: "code"), app.debugDescription)
        app.buttons["type"].tap()
        let field = app.textFields["codeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("hello\n")
        XCTAssertTrue(wait(app.staticTexts["pairError"], contains: "isn't a Nocturnal pairing code"), app.debugDescription)
        shot(app, "22-pair-error")
        // The welcome offers only pairing; typing "demo" is the way in for App Review.
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["next"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["demo"].exists)
        app.buttons["next"].tap()
        XCTAssertTrue(app.buttons["type"].waitForExistence(timeout: 3))
        app.buttons["type"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("demo\n")
        XCTAssertTrue(app.staticTexts["headline"].waitForExistence(timeout: 3), app.debugDescription)
    }

    /// Clean screenshots for the website and the App Store: the demo without Exit Demo, reading "Live".
    @MainActor
    func testMarketingShots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-marketing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["headline"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["exitDemo"].exists)
        sleep(2)
        shot(app, "m1-home")
        let band = app.descendants(matching: .any)["band"].firstMatch
        tapStop(band, 3)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Until"), app.staticTexts["readout"].label)
        sleep(2)
        shot(app, "m4-two-hours")
        tapStop(band, 1)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "When busy"), app.staticTexts["readout"].label)
        sleep(1)
        app.buttons["settings"].tap()
        XCTAssertTrue(app.staticTexts["Keeps it awake"].waitForExistence(timeout: 3), app.debugDescription)
        sleep(2)
        shot(app, "m2-settings")
        app.buttons["closeSettings"].tap()
        sleep(1)
        app.buttons["main"].tap()
        XCTAssertTrue(wait(app.staticTexts["headline"], contains: "Asleep", timeout: 8), app.debugDescription)
        sleep(2)
        shot(app, "m3-asleep")
    }

    /// A timed keep-awake starts the Live Activity: it shows in the Dynamic Island once the app is in the background.
    @MainActor
    func testLiveActivity() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-marketing"]
        app.launch()
        let band = app.descendants(matching: .any)["band"].firstMatch
        XCTAssertTrue(band.waitForExistence(timeout: 5), app.debugDescription)
        tapStop(band, 3)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "Until"), app.staticTexts["readout"].label)
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(2)
        let board = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        shot(board, "30-live-activity-island")
        // Held, the island opens up.
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).press(forDuration: 1.2)
        sleep(1)
        shot(board, "31-live-activity-expanded")
        XCUIDevice.shared.press(.home)
        sleep(1)
        // The Lock Screen: lock, then wake the screen without unlocking.
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(2)
        shot(board, "32-live-activity-lock")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
        XCTAssertTrue(band.waitForExistence(timeout: 5))
        sleep(1)
        tapStop(band, 1)
        XCTAssertTrue(wait(app.staticTexts["readout"], contains: "When busy"), app.staticTexts["readout"].label)
    }

    /// Adds the medium widget to the Home Screen (the demo feeds it) and shoots it, as proof it draws on a real
    /// Home Screen. Springboard's edit flow, step by step; it prints the screen if a step can't be found.
    @MainActor
    func testWidgetOnHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-marketing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["headline"].waitForExistence(timeout: 5))
        sleep(1)
        XCUIDevice.shared.press(.home)
        let board = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        sleep(1)
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 1.6)
        let edit = board.buttons["Edit"]
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            let add = board.buttons["Add Widget"]
            XCTAssertTrue(add.waitForExistence(timeout: 3), "no Add Widget in the Edit menu")
            add.tap()
        } else {
            let plus = board.buttons["Add Widget"].exists ? board.buttons["Add Widget"] : board.buttons["add-button"]
            XCTAssertTrue(plus.waitForExistence(timeout: 3), "no way into the widget gallery")
            plus.tap()
        }
        let search = board.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4), "no widget search")
        search.tap()
        search.typeText("Nocturnal")
        sleep(2)
        let result = board.cells.containing(.staticText, identifier: "Nocturnal").firstMatch
        if result.exists { result.tap() } else { board.staticTexts["Nocturnal"].firstMatch.tap() }
        sleep(1)
        board.swipeLeft()   // small → medium
        sleep(1)
        // The sheet's button reads "+ Add Widget" with a symbol and its own spacing, so match the end of it.
        let addButton = board.buttons.matching(NSPredicate(format: "label ENDSWITH 'Widget'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "no Add Widget button")
        addButton.tap()
        sleep(2)
        if board.buttons["Done"].exists { board.buttons["Done"].tap() }
        sleep(3)
        shot(board, "40-home-widget")

        // Its buttons work without opening the app.
        let always = board.buttons["Always awake"].firstMatch
        XCTAssertTrue(always.waitForExistence(timeout: 4), "no Always awake button on the widget")
        always.tap()
        sleep(3)
        shot(board, "41-home-widget-always")
        board.buttons["Always awake"].firstMatch.tap()
        sleep(2)
    }

    // MARK: Helpers

    @MainActor private func tapStop(_ band: XCUIElement, _ i: Int) {
        band.coordinate(withNormalizedOffset: CGVector(dx: (Double(i) + 0.5) / 7, dy: 0.5)).tap()
    }

    @MainActor private func wait(_ e: XCUIElement, contains text: String, timeout: TimeInterval = 3) -> Bool {
        let p = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: timeout) == .completed
    }

    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        let s = app.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        // The simulator shares the Mac's disk: also drop it where the review can be picked up.
        let dir = URL(fileURLWithPath: NSHomeDirectory().components(separatedBy: "/Library/Developer").first ?? NSHomeDirectory())
            .appendingPathComponent("Developer/Nocturnal/dist/review/phone")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: dir.appendingPathComponent(name + ".png"))
        // Every element's frame too, so the layout can be checked where a picture can't be taken.
        try? app.debugDescription.write(to: dir.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
    }
}
