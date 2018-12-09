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
import WebKit
import AVKit
import SafariServices

class AnimeViewController: UITableViewController, ServerPickerSelectionDelegate {
    var avPlayerController: AVPlayerViewController!
    
    var link: AnimeLink?
    
    var serverSelectionButton: UIBarButtonItem! {
        return navigationItem.rightBarButtonItem
    }
    
    var anime: Anime? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.informationCell?.animeDescription = self.anime?.description
                
                let sectionsNeededReloading: IndexSet = [1]
                
                if self.anime == nil && oldValue != nil {
                    self.tableView.deleteSections(sectionsNeededReloading, with: .fade)
                }
                
                guard let anime = self.anime else { return }
                if let recentlyUsedServer = UserDefaults.standard.string(forKey: "server.recent"),
                    anime.servers[recentlyUsedServer] != nil {
                    self.server = recentlyUsedServer
                } else { self.server = anime.servers.first!.key }
                
                self.serverSelectionButton.title = anime.servers[self.server!]
                self.serverSelectionButton.isEnabled = true
                
                if oldValue == nil {
                    self.tableView.insertSections(sectionsNeededReloading, with: .fade)
                } else {
                    self.tableView.reloadSections(sectionsNeededReloading, with: .fade)
                }
            }
        }
    }
    
    var server: Anime.ServerIdentifier?
    
    //Set episode will update the server identifier as well
    var episode: Episode? {
        didSet { server = episode?.link.server }
    }
    
    var displayedPlayer: AVPlayer?
    
    var playbackProgressRestored = false
    
    var informationCell: AnimeDescriptionTableViewCell?
    
    var selectedEpisodeCell: EpisodeTableViewCell?
    
    var episodeRequestTask: NineAnimatorAsyncTask?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //If episode is set, use episode's anime link as the anime for display
        if let episode = episode {
            link = episode.parentLink
        }
        
        guard let link = link else { return }
        
        //Update anime title
        title = link.title
        
        // Fetch anime if anime does not exists
        guard anime == nil else { return }
        serverSelectionButton.title = "Select Server"
        serverSelectionButton.isEnabled = false
        NineAnimator.default.anime(with: link) {
            [weak self] anime, error in
            guard let anime = anime else {
                debugPrint("Error: \(error!)")
                return
            }
            self?.anime = anime
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return anime == nil ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            guard let serverIdentifier = server,
                let episodes = anime?.episodes[serverIdentifier]
                else { return 0 }
            return episodes.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "anime.description") as? AnimeDescriptionTableViewCell
                else { fatalError("cell with wrong type is dequeued") }
            cell.link = link
            cell.animeDescription = anime?.description
            cell.animeViewController = self
            informationCell = cell
            return cell
        case 1:
            //            guard let cell = tableView.dequeueReusableCell(withIdentifier: "anime.serverPicker") as? ServerPickerTableViewCell else { fatalError("cell with wrong type is dequeued") }
            //            cell.delegate = self
            //            cell.servers = anime?.servers
            //            return cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "anime.episode") as? EpisodeTableViewCell
                else { fatalError("unable to dequeue reuseable cell") }
            let episodes = anime!.episodes[server!]!
            let episode = episodes[indexPath.item]
            let playbackProgressKey = "\(episode.identifier).progress"
            cell.episodeLink = episode
            cell.progressIndicator.percentage = CGFloat(UserDefaults.standard.float(forKey: playbackProgressKey))
            return cell
        default:
            fatalError()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? EpisodeTableViewCell else {
            debugPrint("Warning: Cell selection event received when the cell selected is not an EpisodeTableViewCell")
            return
        }
        
        if cell != selectedEpisodeCell {
            episodeRequestTask?.cancel()
            selectedEpisodeCell = cell
            
            episodeRequestTask = anime!.episode(with: cell.episodeLink!) {
                [weak self] episode, error in
                guard let self = self else { return }
                guard let episode = episode else {
                    debugPrint("Error: \(error!)")
                    return
                }
                self.episode = episode
                
                debugPrint("Info: Episode target retrived for '\(episode.name)'")
                debugPrint("- Playback target: \(episode.target)")
                
                let playbackProgressKey = "\(episode.link.identifier).progress"
                
                if episode.nativePlaybackSupported {
                    self.episodeRequestTask = episode.retrive {
                        [weak self] item, error in
                        guard let self = self else { return }
                        self.episodeRequestTask = nil
                        
                        guard let item = item else {
                            debugPrint("Warn: Item not retrived \(error!), fallback to web access")
                            DispatchQueue.main.async { [weak self] in
                                let playbackController = SFSafariViewController(url: episode.target)
                                self?.present(playbackController, animated: true)
                            }
                            return
                        }
                        
                        let playerController = AVPlayerViewController()
                        playerController.player = AVPlayer(playerItem: item)
                        
                        #warning("Need to removeObserver")
                        item.addObserver(self, forKeyPath: "status", options: [], context: nil)
                        self.displayedPlayer = playerController.player
                        self.playbackProgressRestored = false
                        
                        #warning("Need to removeTimeObserver")
                        playerController.player?.addPeriodicTimeObserver(
                            forInterval: CMTime(seconds: 5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                            queue: DispatchQueue.main) {
                                [weak self] time in
                                if self?.playbackProgressRestored == true {
                                    let percentComplete = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(item.duration))
                                    UserDefaults.standard.set(percentComplete, forKey: playbackProgressKey)
                                }
                        }
                        
                        //Initialize audio session to movie playback
                        let audioSession = AVAudioSession.sharedInstance()
                        try? audioSession.setCategory(
                            .playback,
                            mode: .moviePlayback,
                            options: [
                                .allowAirPlay,
                                .allowBluetooth,
                                .allowBluetoothA2DP
                            ])
                        try? audioSession.setActive(true, options: [])
                        
                        DispatchQueue.main.async { [weak self] in
                            playerController.player?.play()
                            self?.present(playerController, animated: true)
                        }
                    }
                } else {
                    let playbackController = SFSafariViewController(url: episode.target)
                    self.present(playbackController, animated: true)
                    self.episodeRequestTask = nil
                    
                    UserDefaults.standard.set(1 as Float, forKey: playbackProgressKey)
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if !playbackProgressRestored, let item = object as? AVPlayerItem, item == displayedPlayer?.currentItem, keyPath == "status", item.status == .readyToPlay {
            let playbackProgressKey = "\(episode!.link.identifier).progress"
            let storedProgress = UserDefaults.standard.float(forKey: playbackProgressKey)
            let progressSeconds = max(Float64(storedProgress) * CMTimeGetSeconds(item.duration) - 5, 0)
            let time = CMTimeMakeWithSeconds(progressSeconds, preferredTimescale: Int32(NSEC_PER_SEC))
            displayedPlayer?.seek(to: time)
            debugPrint("Info: Restoring playback progress to \(storedProgress), \(progressSeconds) seconds.")
            playbackProgressRestored = true
        }
    }
    
    func didSelectServer(_ server: Anime.ServerIdentifier) {
        self.server = server
        UserDefaults.standard.set(server, forKey: "server.recent")
        tableView.reloadSections([1], with: .automatic)
        serverSelectionButton.title = anime!.servers[server]
    }
    
    @IBAction func onServerButtonTapped(_ sender: Any) {
        let alertView = UIAlertController(title: "Select Server", message: nil, preferredStyle: .actionSheet)
        
        if let popover = alertView.popoverPresentationController {
            popover.barButtonItem = serverSelectionButton
            popover.permittedArrowDirections = .up
        }
        
        for server in anime!.servers {
            let action = UIAlertAction(title: server.value, style: .default, handler: {
                [weak self] _ in
                self?.didSelectServer(server.key)
            })
            if self.server == server.key {
                action.setValue(true, forKey: "checked")
            }
            alertView.addAction(action)
        }
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertView, animated: true)
    }
}
