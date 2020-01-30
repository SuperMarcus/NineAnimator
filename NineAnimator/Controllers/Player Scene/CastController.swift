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

import OpenCastSwift
import UIKit

class CastController: CastDeviceScannerDelegate, CastClientDelegate {
    static var `default` = CastController()
    
    private let scanner: CastDeviceScanner
    
    /// The tracking context for the current playback media
    private var trackingContext: TrackingContext?
    
    private(set) var devices = [CastDevice]()
    
    private(set) var client: CastClient?
    
    private(set) var content: CastMedia?
    
    private(set) var currentEpisode: Episode?
    
    private(set) var contentDuration: Double?
    
    private(set) var currentApp: CastApp?
    
    private(set) var updateTimer: Timer?
    
    lazy var viewController: GoogleCastMediaPlaybackViewController = {
        let storyboard = UIStoryboard(name: "GoogleCastMediaControl", bundle: Bundle.main)
        let vc = storyboard.instantiateInitialViewController() as! GoogleCastMediaPlaybackViewController
        vc.castController = self
        return vc
    }()
    
    init() {
        scanner = CastDeviceScanner()
        scanner.delegate = self
    }
    
    /**
     Present cast device selector and playback controller in parent controller
     */
    func present(from source: UIViewController) -> AnyObject {
        let vc = viewController
        let delegate = setupHalfFillView(for: vc, from: source)
        source.present(vc, animated: true)
        vc.isPresenting = true
        return delegate
    }
    
    /**
     Dismiss the controller
     */
    func dismiss() {
        viewController.dismiss(animated: true)
    }
}

// MARK: - Accessing CastController
extension CastController {
    var isReady: Bool { client?.isConnected ?? false }
    
    var isAttached: Bool { isReady && currentApp != nil }
    
    var isPaused: Bool { client?.currentMediaStatus?.playerState == .paused }
    
    func isAttached(to link: EpisodeLink) -> Bool {
        isAttached && currentEpisode?.link == link
    }
    
    /**
     Present the cast controller interface in RootViewController
     */
    func presentPlaybackController() {
        RootViewController.shared?.showCastController()
    }
}

// MARK: - Media Playback Control
extension CastController {
    func setVolume(to volume: Float) {
        Log.info("Setting Cast device volume to %@", volume)
        client?.setVolume(volume)
        client?.setMuted(volume < 0.001)
    }
    
    func pause() { client?.pause() }
    
    func play() { client?.play() }
    
    func seek(to time: Float) {
        if isAttached, let client = client {
            client.seek(to: time)
        }
    }
    
    func initiate(playbackMedia media: PlaybackMedia, with episode: Episode) {
        guard let client = client else { return }
        guard let castMedia = media.castMedia else { return }
        
        self.currentEpisode = episode
        self.trackingContext = episode.trackingContext
        
        /// NineAnimator cast application identifier
        /// See the NineAnimatorCloud project for cast receiver sources
        client.launch(appId: "48A09E00") {
            result in
            switch result {
            case let .success(app):
                self.currentApp = app
                client.load(media: castMedia, with: app) {
                    mediaResult in
                    switch mediaResult {
                    case .success(let status):
                        self.content = castMedia
                        if let duration = status.media?.duration {
                            Log.info("Media duration is %@", duration)
                            self.contentDuration = duration
                        }
                        self.viewController.playback(didStart: castMedia)
                        if let deviceStatus = client.currentStatus { self.viewController.playback(update: castMedia, deviceStatus: deviceStatus) }
                        self.viewController.playback(update: castMedia, mediaStatus: status)
                        
                        let storedPctProgress = Float(episode.progress)
                        
                        if storedPctProgress != 0, let duration = status.media?.duration {
                            // Restore playback progress
                            self.seek(to: max(storedPctProgress * Float(duration) - 5.0, 0))
                        }
                        
                        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: self.timerUpdateProgressTask)
                        
                        // Notify tracking context
                        self.trackingContext?.beginWatching(episode: episode.link)
                        
                        Log.info("Playback status @%", status)
                    case .failure(let error):
                        self.viewController.playback(didEnd: castMedia)
                        Log.error("Error on playback %@", error)
                    }
                }
            case let .failure(error):
                Log.error(error)
            }
        }
    }
}

// MARK: - Session Control and Discovery
extension CastController {
    func connect(to device: CastDevice) {
        if client != nil { disconnect() }
        
        Log.info("Connecting to %@", device)
        
        currentApp = nil
        
        // Reset the native player so it doesn't interfere with the now playing center
        NativePlayerController.default.reset()
        
        client = CastClient(device: device)
        client?.delegate = self
        client?.connect()
        viewController.deviceListUpdated()
    }
    
    func disconnect() {
        if isAttached { viewController.playback(didEnd: content!) }
        client?.disconnect()
        client = nil
        content = nil
        currentApp = nil
        viewController.deviceListUpdated()
    }
    
    func start() { scanner.startScanning() }
    
    func stop() { scanner.stopScanning() }
}

// MARK: - Media State Delegate
extension CastController {
    var timerUpdateProgressTask: ((Timer) -> Void) { {
            [weak self] timer in
            guard let self = self else {
                return timer.invalidate()
            }
            
            if self.isAttached, let app = self.currentApp {
                self.client?.requestMediaStatus(for: app)
            } else {
                timer.invalidate()
                self.updateTimer = nil
            }
        }
    }
    
    func castClient(_ client: CastClient, didConnectTo device: CastDevice) {
        Log.info("Connected to %@", device)
        viewController.deviceListUpdated()
    }
    
    func castClient(_ client: CastClient, didDisconnectFrom device: CastDevice) {
        guard client != self.client else { return }
        
        Log.info("Disconnected from %@", device)
        if currentApp != nil, let content = content {
            currentApp = nil
            self.client = nil
            updateTimer?.invalidate()
            updateTimer = nil
            viewController.playback(didEnd: content)
        }
        viewController.deviceListUpdated()
        
        // Notify tracking context
        if let trackingContext = trackingContext {
            trackingContext.endWatching()
            self.trackingContext = nil
        }
    }
    
    func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus) {
        guard let content = content else { return }
        viewController.playback(update: content, mediaStatus: status)
        
        if let episode = currentEpisode, let duration = contentDuration {
            let playbackProgress = Float(status.currentTime / duration)
            NineAnimator.default.user.update(progress: playbackProgress, for: episode.link)
            
            // Notify tracking context
            if playbackProgress > 0.7, let trackingContext = trackingContext {
                trackingContext.endWatching()
                // This will make sure the endWatching only gets called once
                self.trackingContext = nil
            }
        }
    }
    
    func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus) {
        guard let content = content else { return }
        viewController.playback(update: content, deviceStatus: status)
    }
}

// MARK: - Device State Delegate
extension CastController {
    func deviceDidComeOnline(_ device: CastDevice) {
        devices.append(device)
        viewController.deviceListUpdated()
    }
    
    func deviceDidChange(_ device: CastDevice) {
        viewController.deviceListUpdated()
    }
    
    func deviceDidGoOffline(_ device: CastDevice) {
        devices.removeAll { $0.id == device.id }
        viewController.deviceListUpdated()
    }
}
