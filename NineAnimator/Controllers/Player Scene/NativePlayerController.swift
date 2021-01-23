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

import AppCenterAnalytics
import AVKit
import UIKit

/**
 This class handles native video playback events such as picture in
 picture restoration and background playbacks.
 
 Everything that has busnesses with native players is implemented
 by this class.
 
 When accessing this class, always use the singleton
 `NativePlayerController.default`.
 */
class NativePlayerController: NSObject, AVPlayerViewControllerDelegate, NSUserActivityDelegate {
    static let `default` = NativePlayerController()
    
    // Background DispatchQueue shared by the native player controller
    private let queue = DispatchQueue(label: "com.marcuszhou.nineanimator.player.background", qos: .background)
    
    // AVPlayer related
    private let player = AVQueuePlayer()
    
    // AVPlayerViewController
    private var playerViewController = AVPlayerViewController()
    
    private var playerRateObservation: NSKeyValueObservation?
    
    private var playerExternalPlaybackObservation: NSKeyValueObservation?
    
    private var playerStatusObservation: NSKeyValueObservation?
    
    private var playerPeriodicObservation: Any?
    
    var currentPlaybackTime: CMTime { player.currentTime() }
    
    var currentPlaybackPercentage: Float {
        guard let item = currentItem else { return 0 }
        return currentPlaybackTime.seconds / item.duration.seconds
    }
    
    var currentPlaybackTMinus: Float {
        guard let item = currentItem else { return 0 }
        return item.duration.seconds - currentPlaybackTime.seconds
    }
    
    // Media queue and AVPlayerItem observations
    private(set) var mediaQueue = [PlaybackMedia]()
    
    private var mediaItemsObervations = [AVPlayerItem: NSKeyValueObservation]()
    
    var currentMedia: PlaybackMedia? { mediaQueue.first }
    
    var currentItem: AVPlayerItem? { player.currentItem }
    
    // State of the player
    private(set) var state: State = .idle
    
    // Timer used to automatically hide the mouse cursor after 2 second of inactivity
    #if targetEnvironment(macCatalyst)
    private var mouseTimer: Timer?
    #endif
    
    override private init() {
        super.init()
        
        // Observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppEntersBackground(notification:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppEntersForeground(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserPreferenceDidChange(notification:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Configurate AVPlayerViewController
        configurePlayerViewController()
        
        // Observers
        playerRateObservation = player.observe(\.rate, changeHandler: self.onPlayerRateChange)
        playerExternalPlaybackObservation =
            player.observe(\.isExternalPlaybackActive, changeHandler: self.onPlayerExternalPlaybackChange)
        playerStatusObservation =
            player.observe(\.status, changeHandler: self.onPlayerStatusChange)
    }
}

// MARK: - Playing medias
extension NativePlayerController {
    /// Reset the playback queue and start playing the current item
    func play(media: PlaybackMedia) {
        // This will stop any playbacks (PiP)
        clearQueue()
        append(media: media)
        
        setupPlaybackSession()
        RootViewController.shared?.presentOnTop(playerViewController, animated: true) {
            self.state = .fullscreen
            self.player.play()
            
            NotificationCenter.default.post(name: .playbackDidStart, object: self, userInfo: [
                "media": media
            ])
        }
        
        playerViewController.userActivity = Continuity.activity(for: media)
        playerViewController.userActivity?.delegate = self
        
        // Track the server that's being used the most
        Analytics.trackEvent("Playback", withProperties: [
            "source_server": "\(media.link.parent.source.name) (\(media.link.server))"
        ])
    }
    
    /// Reset the player view controller
    func reset() {
        Log.debug("[NativePlayerController] Forcefully resetting the player. Current state is %@.", self.state)
        
        // Send playback end notification if there are still items in the queue.
        if let firstMedia = mediaQueue.first {
            Log.debug("[NativePlayerController] Resetting player while still having media in queue. Sending playback end notification...")
            NotificationCenter.default.post(
                name: .playbackDidEnd,
                object: self,
                userInfo: [ "media": firstMedia ]
            )
        }
        
        // Remove mouse movement timer
        #if targetEnvironment(macCatalyst)
        mouseTimer?.invalidate()
        mouseTimer = nil
        #endif
        
        // Clear the queue and dismiss the old player view controller
        clearQueue()
        playerViewController.dismiss(animated: true, completion: nil)
        
        // Create and configure the new player view controller
        playerViewController = AVPlayerViewController()
        configurePlayerViewController()
    }
    
    func append(media: PlaybackMedia) {
        let item = media.avPlayerItem
        
        // Add item ready observation to restore playback progress
        mediaItemsObervations[item] = item.observe(\.status) {
            [weak self] (_: AVPlayerItem, _: NSKeyValueObservedChange<AVPlayerItem.Status>) in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                // Seek to five seconds before the persisted progress
                item.seek(to: CMTime(seconds: max(Float(media.progress) * item.duration.seconds - 5, 0))) {
                    // Remove the observer after progress has been restored
                    _ in self.mediaItemsObervations.removeValue(forKey: item)
                }
            }
        }
        
        // Add observer for did reach end notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlayerDidReachEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        player.insert(item, after: nil)
        // This needs to be changed
        mediaQueue.append(media)
        
        Log.debug("[NativePlayerController] New item \"%@\" added to queue.", media.name)
    }
    
    func clearQueue() {
        // Remove all player item observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        mediaItemsObervations.forEach { $0.value.invalidate() }
        mediaItemsObervations.removeAll()
        mediaQueue.removeAll()
        player.removeAllItems()
        state = .idle
    }
    
    private func configurePlayerViewController() {
        // Configure the player view controller
        playerViewController.player = player
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = NineAnimator.default.user.allowPictureInPicturePlayback
    }
}

// MARK: - Picture in Picture playback handling
extension NativePlayerController {
    // Check if picture in picture is supported and enabled
    private var shouldUsePictureInPicture: Bool {
        AVPictureInPictureController.isPictureInPictureSupported() && NineAnimator.default.user.allowPictureInPicturePlayback
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Do not restore to fullscreen if PiP ended because the video has finished playing
        guard self.currentPlaybackTMinus != 0.0 else {
            Log.debug("[NativePlayerController] PiP playback will end because video has finished playing")
            return completionHandler(false)
        }
        
        Log.debug("[NativePlayerController] Restoring from PiP playback...")
        RootViewController.shared?.presentOnTop(playerViewController, animated: true) { completionHandler(true) }
        state = .fullscreen
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Log.debug("[NativePlayerController] PiP playback did start. Previous state is %@", self.state)
        state = .pictureInPicture
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Log.debug("[NativePlayerController] PiP playback will end. Previous state is %@", self.state)
        if state == .pictureInPicture {
            state = .idle
        }
    }
}

// MARK: - Interactive Dismissal
extension NativePlayerController {
    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) {
            context in
            if !context.isCancelled, case .fullscreen = self.state {
                Log.debug("[NativePlayerController] Player interactive dismissal detected. Resetting...")
                self.reset()
            }
        }
    }
    #if targetEnvironment(macCatalyst)
    func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        // Hide cursor during fullscreen playback after inactivity
        if mouseTimer == nil {
            mouseTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(2), // Check inactivity every 2 sec
                target: self,
                selector: #selector(shouldHideMouse),
                userInfo: nil,
                repeats: true
            )
        }
    }
    #endif
}

// MARK: - AVPlayer & AVPlayerItem observers
extension NativePlayerController {
    #if targetEnvironment(macCatalyst)
    @objc private func shouldHideMouse() {
        let secondsSinceLastMouseMovement = Float(CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.combinedSessionState, eventType: CGEventType.mouseMoved))
        // Hide the cursor after 2 seconds of inactivity
        if secondsSinceLastMouseMovement > 2 {
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }
    #endif
    
    private func onPlayerStatusChange(player _: AVPlayer, change _: NSKeyValueObservedChange<AVPlayer.Status>) {
        Log.debug("[NativePlayerController] Player status changed to %@.", player.status.rawValue)
    }
    
    private func onPlayerRateChange(player _: AVPlayer, change _: NSKeyValueObservedChange<Float>) {
        DispatchQueue.main.async {
            self.updatePlaybackSession()
            self.persistProgress()
            
            if let observation = self.playerPeriodicObservation {
                self.player.removeTimeObserver(observation)
                self.playerPeriodicObservation = nil
            }
            
            if self.player.rate > 0 {
                self.playerPeriodicObservation = self.player.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 1.0),
                    queue: self.queue) {
                    [weak self] _ in
                    self?.updatePlaybackSession()
                    self?.persistProgress()
                }
            }
            
            // Check if the video playback has stopped
            if self.player.rate == 0 && (
                (!self.playerViewController.isFirstResponder && self.state == .fullscreen) || // Fullscreen dismiss
                    (self.state == .idle) // PiP dismiss
                ) {
                Log.debug("[NativePlayerController] Recognized a playback end pattern. Current state is %@", self.state)
                self.state = .idle
                
                guard !self.mediaQueue.isEmpty else {
                    // This is now an expected behavior due to resetting
                    // in the interactive dismissal
                    return
                }
                
                // Post playback did end notification
                let media = self.mediaQueue.removeFirst()
                Log.debug("[NativePlayerController] Removing media \"%@\" from the playback queue.", media.name)
                NotificationCenter.default.post(
                    name: .playbackDidEnd,
                    object: self,
                    userInfo: [ "media": media ]
                )
            }
        }
    }
    
    private func onPlayerExternalPlaybackChange(player _: AVPlayer, change _: NSKeyValueObservedChange<Bool>) {
        // Deactivation is handled in the progress monitor
        if player.isExternalPlaybackActive {
            NotificationCenter.default.post(name: .externalPlaybackDidStart, object: self)
        } else {
            NotificationCenter.default.post(name: .externalPlaybackDidEnd, object: self)
        }
    }
    
    @objc private func onPlayerDidReachEnd(_ notification: Notification) {
        // Remove all did play to end time notificiation observer
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: notification.object
        )
        
        DispatchQueue.main.async {
            [weak self] in
            guard let self = self else { return }
            
            // Dismiss the player if no more item is in the queue
            if self.mediaQueue.count == 1 {
                self.playerViewController.dismiss(animated: true)
            }
        }
    }
}

// MARK: - Progress persistence
extension NativePlayerController {
    private var isCurrentItemPlaybackProgressRestored: Bool {
        guard let item = currentItem else { return false }
        return self.mediaItemsObervations[item] == nil
    }
    
    private func persistProgress() {
        // Only persist progress after progress restoration
        
        // Using a little shortcut here
        guard isCurrentItemPlaybackProgressRestored, var media = currentMedia else { return }
        // Setting the progress will update the entry in UserDefaults
        media.progress = Double(currentPlaybackPercentage)
        
        // Last 15 seconds, fire will end events
        if case 14.0...15.0 = currentPlaybackTMinus {
            NotificationCenter.default.post(name: .playbackWillEnd, object: self, userInfo: nil)
            
            if player.isExternalPlaybackActive {
                NotificationCenter.default.post(name: .externalPlaybackWillEnd, object: self, userInfo: nil)
            }
        }
    }
}

// MARK: - App state handlers
extension NativePlayerController {
    @objc func onAppEntersBackground(notification _: Notification) {
        guard !shouldUsePictureInPicture else { return }
        
        if NineAnimator.default.user.allowBackgroundPlayback {
            playerViewController.player = nil
        } else { player.pause() }
    }
    
    @objc func onAppEntersForeground(notification _: Notification) {
        playerViewController.player = player
    }
}

// MARK: - Update settings
extension NativePlayerController {
    @objc func onUserPreferenceDidChange(notification _: Notification) {
        playerViewController.allowsPictureInPicturePlayback = shouldUsePictureInPicture
        // Ignoring the others since those are retrived on app state changes
    }
}

// MARK: - AVAudioSession setup, update, teardown
extension NativePlayerController {
    private func setupPlaybackSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback)
            try audioSession.setActive(true, options: [])
        } catch { Log.error("Unable to setup audio session - %@", error) }
    }
    
    private func updatePlaybackSession() {
        // Not doing anything right now
    }
    
    private func teardownPlaybackSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false, options: [])
        } catch { Log.error("Unable to teardown audio session - %@", error) }
    }
}

// MARK: - States
extension NativePlayerController {
    enum State {
        case idle
        case fullscreen
        case pictureInPicture
    }
}

// MARK: - Continuity
extension NativePlayerController {
    func userActivityWillSave(_ userActivity: NSUserActivity) {
        guard let media = currentMedia else {
            return Log.error("Cannot save user activity: current media is undefined.")
        }
        
        do {
            let encoder = PropertyListEncoder()
            let encodedEpisodeData = try encoder.encode(media.link)
            
            userActivity.userInfo = [
                "link": encodedEpisodeData,
                "progress": media.progress
            ]
        } catch { return Log.error("Cannot encode episode data for handoff: %@", error) }
    }
    
    func userActivityWasContinued(_ userActivity: NSUserActivity) {
        // Pause the player when switched to new device
        player.pause()
    }
}
