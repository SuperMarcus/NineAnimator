//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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
import AVKit

/**
 This class handles native video playback events such as picture in
 picture restoration and background playbacks.
 
 Everything that has busnesses with native players is implemented
 by this class.
 
 When accessing this class, always use the singleton
 `NativePlayerController.default`.
 */
class NativePlayerController: NSObject, AVPlayerViewControllerDelegate {
    static let `default` = NativePlayerController()
    
    //Background DispatchQueue shared by the native player controller
    private let queue = DispatchQueue(label: "com.marcuszhou.nineanimator.player.background", qos: .background)
    
    //AVPlayerViewController
    private let playerViewController = AVPlayerViewController()
    
    //AVPlayer related
    private let player = AVQueuePlayer()
    
    private var playerRateObservation: NSKeyValueObservation?
    
    private var playerPeriodicObservation: Any?
    
    var currentPlaybackTime: CMTime { return player.currentTime() }
    
    var currentPlaybackPercentage: Float {
        guard let item = currentItem else { return 0 }
        return currentPlaybackTime.seconds / item.duration.seconds
    }
    
    //Media queue and AVPlayerItem observations
    private(set) var mediaQueue = [PlaybackMedia]()
    
    private var mediaItemsObervations = [AVPlayerItem: NSKeyValueObservation]()
    
    var currentMedia: PlaybackMedia? { return mediaQueue.first }
    
    var currentItem: AVPlayerItem? { return player.currentItem }
    
    //State of the player
    private(set) var state: State = .idle
    
    override private init(){
        super.init()
        
        //Observers
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAppEntersBackground(notification:)),
            name: .appWillBecomeInactive,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAppEntersForeground(notification:)),
            name: .appDidBecameActive,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(onUserPreferenceDidChange(notification:)),
            name: .userPreferencesDidChange,
            object: nil)
        
        //Configurate AVPlayerViewController
        playerViewController.player = player
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = NineAnimator.default.user.allowPictureInPicturePlayback
        
        //Observers
        playerRateObservation = player.observe(\.rate, changeHandler: self.onPlayerRateChange)
    }
}

//MARK: - Playing medias
extension NativePlayerController {
    /**
     Reset the playback queue and start playing the current item
     */
    func play(media: PlaybackMedia) {
        //This will stop any playbacks (PiP)
        clearQueue()
        append(media: media)
        
        setupPlaybackSession()
        RootViewController.shared?.presentOnTop(playerViewController, animated: true) {
            self.state = .fullscreen
            self.player.play()
        }
    }
    
    func append(media: PlaybackMedia) {
        let item = media.avPlayerItem
        
        //Add item ready observation to restore playback progress
        mediaItemsObervations[item] = item.observe(\.status){
            [weak self] (_: AVPlayerItem, _: NSKeyValueObservedChange<AVPlayerItem.Status>) in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                //Seek to five seconds before the persisted progress
                item.seek(to: CMTime(seconds: max(media.progress * item.duration.seconds - 5, 0))){
                    //Remove the observer after progress has been restored
                    _ in self.mediaItemsObervations.removeValue(forKey: item)
                }
            }
        }
        
        player.insert(item, after: nil)
        //This needs to be changed
        mediaQueue.append(media)
    }
    
    func clearQueue() {
        mediaItemsObervations.forEach { $0.value.invalidate() }
        mediaItemsObervations.removeAll()
        mediaQueue.removeAll()
        player.removeAllItems()
        state = .idle
    }
}

//MARK: - Picture in Picture playback handling
extension NativePlayerController {
    //Check if picture in picture is supported and enabled
    private var shouldUsePictureInPicture: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported() && NineAnimator.default.user.allowPictureInPicturePlayback
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        RootViewController.shared?.presentOnTop(playerViewController, animated: true) { completionHandler(true) }
        state = .fullscreen
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        state = .pictureInPicture
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        if state == .pictureInPicture { state = .idle }
    }
}

//MARK: - AVPlayer & AVPlayerItem observers
extension NativePlayerController {
    private func onPlayerRateChange(player _: AVPlayer, change _: NSKeyValueObservedChange<Float>){
        updatePlaybackSession()
        persistProgress()
        
        if let observation = playerPeriodicObservation {
            player.removeTimeObserver(observation)
            playerPeriodicObservation = nil
        }
        
        if player.rate > 0 {
            playerPeriodicObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0), queue: queue) { [weak self] time in self?.updatePlaybackSession(); self?.persistProgress() }
        }
    }
}

//MARK: - Progress persistence
extension NativePlayerController {
    private var isCurrentItemPlaybackProgressRestored: Bool {
        guard let item = currentItem else { return false }
        return self.mediaItemsObervations[item] == nil
    }
    
    private func persistProgress(){
        //Only persist progress after progress restoration
        
        //Using a little shortcut here
        guard isCurrentItemPlaybackProgressRestored, var media = currentMedia else { return }
        //Setting the progress will update the entry in UserDefaults
        media.progress = currentPlaybackPercentage
    }
}

//MARK: - App state handlers
extension NativePlayerController {
    @objc func onAppEntersBackground(notification _: Notification){
        guard !shouldUsePictureInPicture else { return }
        
        if NineAnimator.default.user.allowBackgroundPlayback {
            playerViewController.player = nil
        } else { player.pause() }
    }
    
    @objc func onAppEntersForeground(notification _: Notification){
        playerViewController.player = player
    }
}

//MARK: - Update preferences
extension NativePlayerController {
    @objc func onUserPreferenceDidChange(notification _: Notification){
        playerViewController.allowsPictureInPicturePlayback = shouldUsePictureInPicture
        //Ignoring the others since those are retrived on app state changes
    }
}

//MARK: - AVAudioSession setup, update, teardown
extension NativePlayerController {
    private func setupPlaybackSession(){
        let audioSession = AVAudioSession.sharedInstance()
        
        do{
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [
                    .allowAirPlay,
                    .allowBluetooth,
                    .allowBluetoothA2DP
                ])
            try audioSession.setActive(true, options: [])
        }catch { debugPrint("Error: Unable to setup audio session - \(error)") }
    }
    
    private func updatePlaybackSession(){
        //Not doing anything right now
    }
    
    private func teardownPlaybackSession(){
        let audioSession = AVAudioSession.sharedInstance()
        
        do{
            try audioSession.setActive(false, options: [])
        }catch { debugPrint("Error: Unable to teardown audio session - \(error)") }
    }
}

//MARK: - States
extension NativePlayerController {
    enum State {
        case idle
        case fullscreen
        case pictureInPicture
    }
}
