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

import AVFoundation
import UIKit

class AudioBackgroundController {
    private var updateTimer: Timer?
    
    private var audioPlayer: AVAudioPlayer
    
    init() {
        let silentAudio = NSDataAsset(name: "Silence Audio")!
        audioPlayer = try! AVAudioPlayer(data: silentAudio.data, fileTypeHint: AVFileType.wav.rawValue)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackEnd),
            name: .playbackDidEnd,
            object: nil
        )
    }
    
    func startBackgroundAudio() {
        // If NativePlayerController is playing content in PiP,
        // do not setup audio background
        guard NativePlayerController.default.state != .pictureInPicture else {
            return
        }

        do {
            audioPlayer.volume = 0.0
            audioPlayer.numberOfLoops = -1
            print(audioPlayer.duration)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
            audioPlayer.play()
            updateTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(1800), // Check for anime updates every 30mins
                target: self,
                selector: #selector(onUpdateTimer),
                userInfo: nil,
                repeats: true
            )
            // Allow the timer to be called 5 min before/after to improve battery life
            updateTimer?.tolerance = TimeInterval(300)
        } catch {
            Log.error("Failed to setup audio session for background: %@", error)
        }
    }
    
    func stopBackgroundAudio() {
        audioPlayer.stop()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc private func onUpdateTimer() {
        guard let appDelegate = AppDelegate.shared else { return }
        let taskContainer = StatefulAsyncTaskContainer {
            container in
            appDelegate.removeTask(container)
        }
        
        // Perform the fetch
        UserNotificationManager.default.performFetch(within: taskContainer)
        
        appDelegate.submitTask(taskContainer) // Save reference
        taskContainer.collect()
        
        // Ensure task ends after 30 seconds to prevent severe battery drain
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            [weak taskContainer] in
            taskContainer.unwrap {
                container in
                
                // Cancel the task
                container.cancel()
                appDelegate.removeTask(container)
            }
        }
    }
    
    @objc private func onPlaybackEnd() {
        guard let app = AppDelegate.shared, !app.isActive else {
            return
        }
        startBackgroundAudio()
    }
}
