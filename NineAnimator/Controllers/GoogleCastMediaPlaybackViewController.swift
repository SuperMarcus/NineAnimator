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
import Kingfisher
import AVFoundation
import MediaPlayer

enum CastDeviceState {
    case idle
    case connected
    case connecting
}

class GoogleCastMediaPlaybackViewController: UIViewController, HalfFillViewControllerProtocol, UITableViewDataSource, UIGestureRecognizerDelegate {
    weak var castController: CastController!
    
    @IBOutlet weak var playbackControlView: UIView!
    
    @IBOutlet weak var coverImage: UIImageView!
    
    @IBOutlet weak var deviceListTableView: UITableView!
    
    @IBOutlet weak var playbackProgressSlider: UISlider!
    
    @IBOutlet weak var tPlusIndicatorLabel: UILabel!
    
    @IBOutlet weak var tMinusIndicatorLabel: UILabel!
    
    @IBOutlet weak var volumeSlider: UISlider!
    
    @IBOutlet weak var playPauseButton: UIButton!
    
    @IBOutlet weak var rewindButton: UIButton!
    
    @IBOutlet weak var fastForwardButton: UIButton!
    
    @IBOutlet weak var playbackTitleLabel: UILabel!
    
    var isPresenting = false
    
    private var isSeeking = false
    
    private var volumeIsChanging = false
    
    private var sharedNowPlayingInfo = [String: Any]()
    
    private var castDummyAudioPlayer: AVAudioPlayer?
    
    //The amount of time (in seconds) that fast forward and rewind button seeks
    private var fastSeekAmount: Float = 15.0
    
    @IBAction func onDoneButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deviceListTableView.dataSource = self
        deviceListTableView.rowHeight = 48
        deviceListTableView.tableFooterView = UIView()
        
        if castController.isAttached {
            showPlaybackControls(animated: false)
        } else {
            hidePlaybackControls(animated: false)
        }
        
        playbackProgressSlider.setThumbImage(normalThumbImage, for: .normal)
        playbackProgressSlider.setThumbImage(highlightedThumbImage, for: .highlighted)
        volumeSlider.minimumValue = 0.0
        volumeSlider.maximumValue = 1.0
        
        let grayBackgroundHighlight = buttonBackgroundImage
        playPauseButton.setBackgroundImage(grayBackgroundHighlight, for: .highlighted)
        rewindButton.setBackgroundImage(grayBackgroundHighlight, for: .highlighted)
        fastForwardButton.setBackgroundImage(grayBackgroundHighlight, for: .highlighted)
        
        castController.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        castController.stop()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        view.setNeedsLayout()
        halfFillController?.layoutBackgroundView(with: size)
    }
}

//MARK: - User Interface
extension GoogleCastMediaPlaybackViewController {
    var needsTopInset: Bool { return false }
    
    func circle(ofSideLength length: CGFloat, color: UIColor) -> UIImage {
        let size = CGSize(width: length, height: length)
        let color = UIColor.gray
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { _ in
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            color.setFill()
            path.fill()
        }
        
        return image
    }
    
    var normalThumbImage: UIImage? {
        return circle(ofSideLength: 8, color: .gray)
    }
    
    var highlightedThumbImage: UIImage? {
        return circle(ofSideLength: 12, color: .gray)
    }
    
    var buttonBackgroundImage: UIImage {
        return circle(ofSideLength: 128, color: UIColor.gray.withAlphaComponent(0.15))
    }
    
    func format(seconds input: Int) -> String {
        var tmp = input
        let s = tmp % 60 >= 10 ? "\(tmp % 60)" : "0\(tmp % 60)"; tmp /= 60
        let m = tmp % 60 >= 10 ? "\(tmp % 60)" : "0\(tmp % 60)"; tmp /= 60
        if tmp > 0 { return "\(tmp):\(m):\(s)" }
        return "\(m):\(s)"
    }
    
    func updateUI(playbackProgress progress: Float?, volume: Float?, isPaused: Bool?) {
        guard let duration = castController.contentDuration else { return }
        
        if let progress = progress, !isSeeking {
            tPlusIndicatorLabel.text = "\(format(seconds: Int(progress)))"
            tMinusIndicatorLabel.text = "-\(format(seconds: Int(Float(duration) - progress)))"
            playbackProgressSlider.minimumValue = 0
            playbackProgressSlider.maximumValue = Float(duration)
            playbackProgressSlider.value = progress
        }
        
        if let volume = volume, !volumeIsChanging {
            if volumeSlider.value != volume {
                debugPrint("Info: Cast device volume updated to \(volume)")
                volumeSlider.value = volume
            }
        }
        
        if let isPaused = isPaused {
            let image = isPaused ? #imageLiteral(resourceName: "Play Icon") : #imageLiteral(resourceName: "Pause Icon")
            playPauseButton.setImage(image, for: .normal)
            playPauseButton.setImage(image, for: .highlighted)
        }
    }
    
    func showPlaybackControls(animated: Bool) {
        guard playbackControlView.isHidden else { return }
        playbackControlView.isHidden = false
        if animated {
            playbackControlView.alpha = 0.01
            UIView.animate(withDuration: 0.3) {
                self.playbackControlView.alpha = 1.0
            }
        } else { playbackControlView.alpha = 1.0 }
        playbackControlView.setNeedsLayout()
    }
    
    func hidePlaybackControls(animated: Bool) {
        if !playbackControlView.isHidden {
            if animated {
                playbackControlView.alpha = 1.0
                UIView.animate(
                    withDuration: 0.3,
                    animations: { self.playbackControlView.alpha = 0 },
                    completion: { _ in self.playbackControlView.isHidden = true }
                )
            } else {
                playbackControlView.alpha = 0.0
                playbackControlView.isHidden = true
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == self.view
    }
    
    @IBAction func onBackgroundTapGestureRecognizer(sender: UITapGestureRecognizer) {
        dismiss(animated: true)
    }
    
    @IBAction func onPlaybackProgressSeek(_ sender: UISlider) {
        let duration = sender.maximumValue
        let current = sender.value
        tPlusIndicatorLabel.text = "\(format(seconds: Int(current)))"
        tMinusIndicatorLabel.text = "-\(format(seconds: Int(duration - current)))"
    }
    
    @IBAction func onSeekStart(_ sender: Any) { isSeeking = true }
    
    @IBAction func onSeekEnd(_ sender: Any) {
        isSeeking = false
        castController.seek(to: playbackProgressSlider.value)
    }
    
    @IBAction func onVolumeAttenuate(_ sender: Any) { }
    
    @IBAction func onVolumeAttenuateStart(_ sender: Any) { volumeIsChanging = true }
    
    @IBAction func onVolumeAttenuateEnd(_ sender: Any) {
        volumeIsChanging = false
        castController.setVolume(to: volumeSlider.value)
    }
    
    @IBAction func onPlayPauseButtonTapped(_ sender: UIButton) {
        if castController.isPaused {
            castController.play()
        } else {
            castController.pause()
        }
    }
    
    @IBAction func onRewindButtonTapped(_ sender: Any) {
        let current = playbackProgressSlider.value
        let seekTo = max(current - fastSeekAmount, 0.0)
        playbackProgressSlider.value = seekTo
        castController.seek(to: seekTo)
    }
    
    @IBAction func onFastForwardButtonTapped(_ sender: Any) {
        let current = playbackProgressSlider.value
        let max = playbackProgressSlider.maximumValue
        let seekTo = min(current + fastSeekAmount, max)
        playbackProgressSlider.value = seekTo
        castController.seek(to: seekTo)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        isPresenting = false
    }
}

//MARK: - Updates from media server
extension GoogleCastMediaPlaybackViewController {
    func playback(update media: CastMedia, mediaStatus status: CastMediaStatus) {
        coverImage.kf.setImage(with: media.poster) {
            result in
            guard let image = result.value?.image else { return }
            //Set poster image but let the updater to push it to the now playing center
            self.sharedNowPlayingInfo[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size)
                { _ in return image }
        }
        
        updateUI(playbackProgress: Float(status.currentTime), volume: nil, isPaused: status.playerState == .paused)
        
        nowPlaying(update: status)
    }
    
    func playback(update media: CastMedia, deviceStatus status: CastStatus) {
        updateUI(playbackProgress: nil, volume: Float(status.muted ? 0 : status.volume), isPaused: nil)
    }
    
    func playback(didStart media: CastMedia) {
        showPlaybackControls(animated: isPresenting)
        nowPlaying(setup: castController.currentEpisode!)
        playbackTitleLabel.text = "\(castController.currentEpisode!.name) - \(castController.currentEpisode!.parentLink.title)"
    }
    
    func playback(didEnd media: CastMedia) {
        hidePlaybackControls(animated: isPresenting)
        nowPlaying(teardown: castController.currentEpisode!)
        NineAnimator.default.user.push()
    }
}

//MARK: Device discovery
extension GoogleCastMediaPlaybackViewController {
    func deviceListUpdated() {
        deviceListTableView.reloadSections([0], with: .automatic)
    }
    
    func device(selected: Bool, from device: CastDevice, with cell: GoogleCastDeviceTableViewCell) {
        guard selected else { return }
        if device == castController.client?.device {
            castController.disconnect()
        } else {
            castController.connect(to: device)
        }
    }
}

//MARK: - Table view data source
extension GoogleCastMediaPlaybackViewController {
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return castController.devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cast.device", for: indexPath) as? GoogleCastDeviceTableViewCell else { fatalError() }
        let device = castController.devices[indexPath.item]
        cell.device = device
        cell.state = device == castController.client?.device
            ? castController.client?.isConnected == true
                ? .connected : .connecting
            : .idle
        cell.delegate = self
        return cell
    }
}

//MARK: - Dummy audio players for control center and lock screen controls
extension GoogleCastMediaPlaybackViewController {
    private func startDummyPlayer(){
        do{
            debugPrint("Info: Starting cast dummy audio player")
            guard let dummyAudioAsset = NSDataAsset(name: "CastDummyAudio")
                else { throw NineAnimatorError.urlError }
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
            
            self.castDummyAudioPlayer?.stop()
            
            try self.castDummyAudioPlayer = AVAudioPlayer(data: dummyAudioAsset.data, fileTypeHint: "wav")
            self.castDummyAudioPlayer?.numberOfLoops = -1
            self.castDummyAudioPlayer?.volume = 0.01
            self.castDummyAudioPlayer?.prepareToPlay()
            self.castDummyAudioPlayer?.play()
        }catch { debugPrint("Error: \(error)") }
    }
    
    private func stopDummyPlayer(){
        debugPrint("Info: Stopping cast dummy audio player")
        self.castDummyAudioPlayer?.stop()
        self.castDummyAudioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }
    
    private func nowPlaying(setup episode: Episode){
        //Start the dummy player so we can control cast playback from lockscreen
        //and control center
        startDummyPlayer()
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        
        self.sharedNowPlayingInfo[MPMediaItemPropertyTitle] = "\(episode.name)"
//        self.sharedNowPlayingInfo[MPMediaItemPropertyMediaType] = MPNowPlayingInfoMediaType.video
        self.sharedNowPlayingInfo[MPMediaItemPropertyAlbumTitle] = episode.parentLink.title
        
        infoCenter.nowPlayingInfo = self.sharedNowPlayingInfo
        infoCenter.playbackState = .playing
        
        //Setup command center
        let commandCenter = MPRemoteCommandCenter.shared()
        
        //Seek
        commandCenter.changePlaybackPositionCommand.addTarget {
            event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.castController.seek(to: Float(event.positionTime))
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        //Play
        commandCenter.playCommand.addTarget {
            _ in self.castController.play()
            return .success
        }
        commandCenter.playCommand.isEnabled = true
        
        //Pause
        commandCenter.pauseCommand.addTarget {
            _ in self.castController.pause()
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        
        //Fast forward
        commandCenter.skipForwardCommand.addTarget {
            _ in self.onFastForwardButtonTapped(self)
            return .success
        }
        commandCenter.skipForwardCommand.isEnabled = true
        
        //Rewind
        commandCenter.skipBackwardCommand.addTarget {
            _ in self.onRewindButtonTapped(self)
            return .success
        }
        commandCenter.skipBackwardCommand.isEnabled = true
        
        //Add system volume change handler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemVolumeDidChange(notification:)),
            name: .init(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil)
    }
    
    private func nowPlaying(teardown: Episode){
        stopDummyPlayer()
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
        
        //Remove volume change observer
        NotificationCenter.default.removeObserver(self, name: .init(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
    }
    
    private func nowPlaying(update status: CastMediaStatus){
        let infoCenter = MPNowPlayingInfoCenter.default()
        
        self.sharedNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] =
            NSNumber(value: status.playerState == .paused ? 0.0 : 1.0)
        self.sharedNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
            NSNumber(value: status.currentTime)
        self.sharedNowPlayingInfo[MPMediaItemPropertyPlaybackDuration] =
            NSNumber(value: Double(playbackProgressSlider.maximumValue))
        
        infoCenter.nowPlayingInfo = self.sharedNowPlayingInfo
        infoCenter.playbackState = status.playerState == .paused ? .paused : .playing
    }
    
    @objc private func systemVolumeDidChange(notification: Notification) {
        guard let newVolume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
            debugPrint("Error: Received a volume change notification without new volume parameter.")
            return
        }
        castController.setVolume(to: newVolume)
    }
}
