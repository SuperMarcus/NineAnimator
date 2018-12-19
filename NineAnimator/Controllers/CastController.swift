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
import OpenCastSwift

class CastController: CastDeviceScannerDelegate, CastClientDelegate {
    static var `default` = CastController()
    
    private let scanner: CastDeviceScanner
    
    var devices = [CastDevice]()
    
    var client: CastClient?
    
    var content: CastMedia?
    
    var currentEpisode: Episode?
    
    var contentDuration: Double? = nil
    
    var isReady: Bool { return client?.isConnected ?? false }
    
    var isAttached: Bool { return isReady && currentApp != nil }
    
    var isPaused: Bool { return client?.currentMediaStatus?.playerState == .paused }
    
    var currentApp: CastApp?
    
    var updateTimer: Timer?
    
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
    func present(from source: UIViewController) -> Any {
        let vc = viewController
        let delegate = setupHalfFillView(for: vc, from: source)
        source.present(vc, animated: true)
        vc.isPresenting = true
        return delegate
    }
}

//MARK: - Media Playback Control
extension CastController {
    func setVolume(to volume: Float) {
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
        
        client.launch(appId: CastAppIdentifier.defaultMediaPlayer) {
            result in
            guard let app = result.value else {
                return debugPrint("Error: \(result.error!)")
            }
            
            self.currentApp = app
            client.load(media: castMedia, with: app) {
                mediaResult in
                switch mediaResult {
                case .success(let status):
                    self.content = castMedia
                    if let duration = status.media?.duration {
                        debugPrint("Info: Media duration is \(duration)")
                        self.contentDuration = duration
                    }
                    self.viewController.playback(didStart: castMedia)
                    if let deviceStatus = client.currentStatus { self.viewController.playback(update: castMedia, deviceStatus: deviceStatus) }
                    self.viewController.playback(update: castMedia, mediaStatus: status)
                    
                    let storedPctProgress = NineAnimator.default.user.playbackProgress(for: episode.link)
                    
                    if storedPctProgress != 0, let duration = status.media?.duration {
                        //Restore playback progress
                        self.seek(to: max(storedPctProgress * Float(duration) - 5.0, 0))
                    }
                    
                    self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: self.timerUpdateProgressTask)
                    
                    debugPrint("Info: Playback status \(status)")
                case .failure(let error):
                    self.viewController.playback(didEnd: castMedia)
                    debugPrint("Warn: Error on playback \(error)")
                }
            }
        }
    }
}

//MARK: - Session Control and Discovery
extension CastController {
    func connect(to device: CastDevice) {
        if client != nil { disconnect() }
        
        debugPrint("Info: Connecting to \(device)")
        
        currentApp = nil
        
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

//MARK: - Media State Delegate
extension CastController {
    var timerUpdateProgressTask: ((Timer) -> ()) {
        return {
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
        debugPrint("Info: Connected to \(device)")
        viewController.deviceListUpdated()
    }
    
    func castClient(_ client: CastClient, didDisconnectFrom device: CastDevice) {
        guard client != self.client else { return }
        
        debugPrint("Info: Disconnected from \(device)")
        if isAttached, let content = content {
            currentApp = nil
            self.client = nil
            updateTimer?.invalidate()
            updateTimer = nil
            viewController.playback(didEnd: content)
        }
        viewController.deviceListUpdated()
    }
    
    func castClient(_ client: CastClient, mediaStatusDidChange status: CastMediaStatus) {
        guard let content = content else { return }
        viewController.playback(update: content, mediaStatus: status)
        
        if let episode = currentEpisode, let duration = contentDuration {
            NineAnimator.default.user.update(progress: Float(status.currentTime / duration), for: episode.link)
        }
    }
    
    func castClient(_ client: CastClient, deviceStatusDidChange status: CastStatus) {
        guard let content = content else { return }
        viewController.playback(update: content, deviceStatus: status)
    }
}

//MARK: - Device State Delegate
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
