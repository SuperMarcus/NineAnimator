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

import AVKit
import SwiftUI

@available(iOS 14.0, *)
extension ImageSearchResultsView {
    struct LoopingVideoPlayer: UIViewRepresentable {
        let videoURL: URL

        func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<LoopingVideoPlayer>) {
        }

        func makeUIView(context: Context) -> UIView {
            LoopingPlayerUIView(frame: .zero, url: videoURL)
        }
    }
    
    private class LoopingPlayerUIView: UIView {
        private let playerLayer = AVPlayerLayer()
        private let loadingIndicator = UIActivityIndicatorView()
        private var playerLooper: AVPlayerLooper?
        private var player = AVQueuePlayer()

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        init(frame: CGRect, url: URL) {
            super.init(frame: frame)

            // Show progress indicator until video has loaded
            addSubview(loadingIndicator)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            loadingIndicator.startAnimating()

            // Load the resource
            let asset = AVAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            
            // Setup the player
            player.isMuted = true
            player.allowsExternalPlayback = false
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)

            // Manually pause video playback when app goes to background
            // This fixes an issue where the playerLayer will become blank
            let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(
                    self,
                    selector: #selector(appMovedToBackground),
                    name: UIApplication.willResignActiveNotification,
                    object: nil
                )
            notificationCenter.addObserver(
                self,
                selector: #selector(appMovedToForeground),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            // Create a new player looper with the queue player and template item
            self.playerLooper = AVPlayerLooper(player: self.player, templateItem: item)

            // Start the video
            self.player.play()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
            loadingIndicator.frame = bounds
        }

        @objc func appMovedToBackground() {
            player.pause()
        }

        @objc func appMovedToForeground() {
            player.seek(to: .zero)
            player.play()
        }
    }
}
