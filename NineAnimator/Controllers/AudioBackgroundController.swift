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
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources
import UIKit

/// Controller used to play background audio to keep the app alive in the background
class AudioBackgroundController {
    private lazy var audioPlayer: AVAudioPlayer = {
        let silentAudio = NSDataAsset(name: "Silence Audio")!
        let player = try! AVAudioPlayer(
            data: silentAudio.data,
            fileTypeHint: AVFileType.wav.rawValue
        )
        player.volume = .zero
        player.numberOfLoops = -1
        return player
    }()
    
    func startBackgroundAudio() {
        guard !audioPlayer.isPlaying else { return }
        do {
            Log.debug("Starting Background Audio")
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
            audioPlayer.play()
        } catch {
            Log.error("Failed to setup audio session for background: %@", error)
        }
    }
    
    func stopBackgroundAudio() {
        guard audioPlayer.isPlaying else { return }
        Log.debug("Stopping Background Audio")
        audioPlayer.stop()
    }
}
