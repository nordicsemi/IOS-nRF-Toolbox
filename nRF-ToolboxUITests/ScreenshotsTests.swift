//
//  Screenshots.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 28/11/2025.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import XCTest

@MainActor
final class ScreenshotsTests: XCTestCase {
    
    var app: XCUIApplication!
    let sleepTime: UInt32 = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func setUp() {
        super.setUp()

        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testSnapshots() throws {
        let scannerButton = app/*@START_MENU_TOKEN@*/.staticTexts["Connect to Device"]/*[[".buttons[\"scannerButton\"].staticTexts",".buttons.staticTexts[\"Connect to Device\"]",".staticTexts[\"Connect to Device\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch
        scannerButton.tap()
        
        sleep(sleepTime)
        
        snapshot("ScannerScreen")
        
        sleep(sleepTime)
        app.staticTexts["Cycling Speed and Cadence sensor"].firstMatch.tap()
        
        sleep(sleepTime)
        snapshot("CSCSScreen")
        sleep(sleepTime)
        if app.buttons["nRF Toolbox"].firstMatch.exists {
            app.buttons["nRF Toolbox"].firstMatch.tap()
        }
        
        sleep(sleepTime)
        scannerButton.tap()
        
        sleep(sleepTime)
        app.staticTexts["Heart rate"].firstMatch.tap()
        
        sleep(sleepTime)
        snapshot("HRSScreen")
        sleep(sleepTime)
        if app.buttons["nRF Toolbox"].firstMatch.exists {
            app.buttons["nRF Toolbox"].firstMatch.tap()
        }

        app.buttons["scannerButton"].firstMatch.tap()
        
        sleep(sleepTime)
        app.staticTexts["Blood pressure"].firstMatch.tap()
        
        sleep(sleepTime)
        snapshot("BPSScreen")
        sleep(sleepTime)
        if app.buttons["nRF Toolbox"].firstMatch.exists {
            app.buttons["nRF Toolbox"].firstMatch.tap()
            snapshot("MainScreen") // Only for phones (not tablets)
        }
    }
}
