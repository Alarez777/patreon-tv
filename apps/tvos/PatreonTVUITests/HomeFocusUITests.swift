//
//  HomeFocusUITests.swift
//  PatreonTVUITests
//
//  Reproduces the reported Home focus trap with real Siri Remote presses:
//  from a card in a shelf, swiping up must eventually reach the top tab bar.
//  Runs fully offline against GalleryMockURLProtocol (GALLERY_MOCK=1).
//

import XCTest

final class HomeFocusUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GALLERY_SCREEN"] = "home"
        app.launchEnvironment["GALLERY_MOCK"] = "1"
        app.launch()
        return app
    }

    /// Press a direction and give the focus engine time to settle + scroll.
    private func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times {
            XCUIRemote.shared.press(button)
            usleep(400_000)   // 0.4s — focus animation + scroll settle
        }
    }

    /// Home is loaded once the leading shelf's header is on screen.
    private func waitForHome(_ app: XCUIApplication) {
        let header = app.staticTexts["New from Your Creators"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 20), "Home never loaded (mock feed missing?)")
        sleep(2)   // let initial focus settle
    }

    /// The user's exact repro: land on Home, move down into the shelves,
    /// move right a few cards (so we're NOT directly above the leading edge),
    /// then swipe up repeatedly. Focus must reach the tab bar.
    func test_up_from_mid_shelf_card_reaches_tab_bar() {
        let app = launchHome()
        waitForHome(app)

        // Down into a shelf, then right a couple of cards.
        press(.down, times: 2)
        press(.right, times: 2)

        // Now try to come back up to the tab bar. Generous press budget; the
        // assertion is what matters.
        let homeTab = app.buttons["Home"].firstMatch
        var reachedTabBar = false
        for _ in 0..<8 {
            press(.up)
            if homeTab.exists && homeTab.hasFocus {
                reachedTabBar = true
                break
            }
        }

        XCTAssertTrue(
            reachedTabBar,
            """
            Focus never reached the tab bar. Focused element after presses: \
            \(app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.debugDescription)
            """
        )
    }

    /// On launch, focus should land in the leading shelf's first card rather
    /// than sitting on the tab bar.
    func test_opens_focused_in_leading_shelf() {
        let app = launchHome()
        waitForHome(app)

        let homeTab = app.buttons["Home"].firstMatch
        XCTAssertFalse(
            homeTab.hasFocus,
            "Launch focus should move off the tab bar into Home's content"
        )

        let focused = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
        XCTAssertTrue(focused.exists, "A leading-shelf card should hold focus on launch")
        XCTAssertTrue(
            focused.label.contains("Episode"),
            "Expected a leading-shelf card focused, got: \(focused.debugDescription)"
        )
    }
}

/// The creator page had the same trap: a tall non-focusable hero above the
/// posts grid meant "up" from the grid dead-ended at the Posts header and the
/// hero could never be scrolled back into view. The hero is now a focusable
/// (inert) anchor, so up from the grid must reach it.
final class CreatorFocusUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times {
            XCUIRemote.shared.press(button)
            usleep(400_000)
        }
    }

    func test_up_from_posts_grid_reaches_hero() {
        let app = XCUIApplication()
        app.launchEnvironment["GALLERY_SCREEN"] = "creator"
        app.launchEnvironment["GALLERY_MOCK"] = "1"
        app.launch()

        let hero = app.buttons.matching(identifier: "creator-hero").firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 20), "Creator page never loaded")
        sleep(2)

        // Down into the posts grid and across a column, then come back up.
        press(.down, times: 2)
        press(.right, times: 1)

        var reachedHero = false
        for _ in 0..<8 {
            press(.up)
            if hero.hasFocus {
                reachedHero = true
                break
            }
        }

        XCTAssertTrue(
            reachedHero,
            """
            Up from the posts grid never reached the creator hero. Focused: \
            \(app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.debugDescription)
            """
        )
    }

    /// A pushed creator page otherwise leaves focus on the tab bar. It must open
    /// focused on the search button (banner stays visible, one swipe to posts).
    func test_opens_focused_on_search() {
        let app = XCUIApplication()
        app.launchEnvironment["GALLERY_SCREEN"] = "creator"
        app.launchEnvironment["GALLERY_MOCK"] = "1"
        app.launch()

        let search = app.buttons.matching(identifier: "creator-search").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 20), "Creator page never loaded")
        sleep(2)

        XCTAssertTrue(search.hasFocus, "Creator page should open focused on the search button")
    }
}
