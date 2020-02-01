//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2020 Marcus Zhou. All rights reserved.
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

import UIKit

extension AppDelegate {
    /// Update NineAnimator settings based on environment variable values
    func configureEnvironment() {
        // NINEANIMATOR_NO_ANIMATIONS: Disable Animations
        if ProcessInfo.processInfo.environment.keys.contains("NINEANIMATOR_NO_ANIMATIONS") {
            Log.info("[AppDelegate.Environment] Disabling animations...")
            UIView.setAnimationsEnabled(false)
        }
        
        // NINEANIMATOR_APPEARANCE_OVERRIDE: Theme Override
        if let overridingTheme = ProcessInfo.processInfo.environment["NINEANIMATOR_APPEARANCE_OVERRIDE"] {
            if let theme = Theme.availableThemes[overridingTheme] {
                Log.info("[AppDelegate.Environment] Updating appearance to '%@' (note this will not change the preferences in the user settings)...", overridingTheme)
                Theme.setTheme(theme)
            } else {
                Log.error("[AppDelegate.Environment] Appearance '%@' is undefined.", overridingTheme)
            }
        }
        
        // NINEANIMATOR_CREATE_DUMMY_RECORDS: Dummy Records
        if ProcessInfo.processInfo.environment.keys.contains("NINEANIMATOR_CREATE_DUMMY_RECORDS") {
            createDummyRecords()
        }
    }
    
    /// Append a predefined list of anime links to the user's records
    private func createDummyRecords() {
        #if DEBUG
        do {
            Log.info("[AppDelegate.Environment] Generating and adding dummy records to the user's profile...")
            let dummyRecordsJson = "[{\"title\":\"A Certain Scientific Railgun T\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2020\\/01\\/d59661e6999d2e708e68e521a01f1841.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/a-certain-scientific-railgun-t.5q20\"},{\"title\":\"Drifting Dragons\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2020\\/01\\/db46b3dfa04367a5d834e3eff5880a72.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/drifting-dragons.pnq9\"},{\"title\":\"Welcome to Demon School! Iruma-kun\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2019\\/10\\/7c9d5445b1671097699281d9695c3b9c.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/welcome-to-demon-school-iruma-kun.3on8\"},{\"title\":\"Weathering With You\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2019\\/05\\/f96bc7c7f41d0652b437068c88dcd1bc.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/weathering-with-you.9xqn\"},{\"title\":\"Plunderer\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2020\\/01\\/3a6cacd4ec426119692ab40d1ca3998a.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/plunderer.55jj\"},{\"title\":\"The Seven Deadly Sins: Wrath of the Gods\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2019\\/10\\/7f5f1bcedbf8646d0d45aba070d11117.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/the-seven-deadly-sins-wrath-of-the-gods.7qmj\"},{\"title\":\"One Piece\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2018\\/04\\/bf8047a0e1074c5c04c46d73fd5dd462.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/one-piece.ov8\"},{\"title\":\"My Hero Academia 4\",\"source\":\"9anime.ru\",\"image\":\"https:\\/\\/static.akacdn.ru\\/files\\/images\\/2019\\/10\\/9164593e4fddee5bdcafd68e248fb525.jpg\",\"link\":\"https:\\/\\/9anime.ru\\/watch\\/my-hero-academia-4.y4kz\"}]"
            let dummyRecords = try JSONDecoder().decode(
                [AnimeLink].self,
                from: try dummyRecordsJson.data(using: .utf8).tryUnwrap()
            )
            
            // Add to NineAnimatorUser
            for recordAnime in dummyRecords {
                NineAnimator.default.user.entering(anime: recordAnime)
                let context = NineAnimator.default.trackingContext(for: recordAnime)
                context.updateRecord(
                    0.9, // Update random episode number
                    forEpisodeNumber: Int.random(in: 1...5)
                )
            }
        } catch {
            Log.error("[AppDelegate.Environment] Unable to generate dummy records: %@", error)
        }
        #else
        Log.error("[AppDelegate.Environment] Not generating dummy records for the user: this feature should only be used in DEBUG environment.")
        #endif
    }
}
