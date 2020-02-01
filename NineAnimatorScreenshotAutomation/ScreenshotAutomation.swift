//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
//
//  NineAnimator is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  NineAnimator is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with NineAnimator.  If not, see <http://www.gnu.org/licenses/>.
//

import XCTest

class ScreenshotAutomation: XCTestCase {
    func testLibraryScene() {
        let app = launchApplication()
        
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["Watch Next"].tap()
        tabBarsQuery.buttons["Library"].tap()
        snapshot("Library")
    }
    
    func testAnimeInformationScene() {
        let app = launchApplication()
        
        app.tabBars.buttons["Watch Next"].tap()
        
        app.tables/*@START_MENU_TOKEN@*/.buttons["Show Schedule"]/*[[".cells.buttons[\"Show Schedule\"]",".buttons[\"Show Schedule\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        snapshot("AnimeSchedule", waitForLoadingIndicator: true)
        
        app.collectionViews.cells.firstMatch.tap()
        snapshot("AnimeInformation", waitForLoadingIndicator: true)
    }
    
    func testLinkServices() {
        let app = launchApplication()
        
        let watchNextButton = app.tabBars.buttons["Watch Next"]
        watchNextButton.tap()
        
        let tablesQuery = app.tables
        tablesQuery.buttons["Preferences"].tap()
        tablesQuery.staticTexts["Third-Party Anime Lists"].tap()
        
        snapshot("TrackingServices")
    }
    
    private func launchApplication(useDarkMode: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        
        // Disable Launch Screen and Animations
        app.launchEnvironment["NINEANIMATOR_NO_SETUP_SCENE"] = "true"
        app.launchEnvironment["NINEANIMATOR_NO_ANIMATIONS"] = "true"
        app.launchEnvironment["NINEANIMATOR_APPEARANCE_OVERRIDE"] = useDarkMode ? "dark" : "light"
        app.launchEnvironment["NINEANIMATOR_CREATE_DUMMY_RECORDS"] = "true"
        
        setupSnapshot(app)
        app.launch()
        
        return app
    }
}
