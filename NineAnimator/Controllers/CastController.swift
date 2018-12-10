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
    
    var isReady: Bool { return client?.isConnected ?? false }
    
    lazy var viewController: GoogleCastMediaPlaybackViewController = {
        let storyboard = UIStoryboard(name: "GoogleCastMediaControl", bundle: Bundle.main)
        let vc = storyboard.instantiateInitialViewController() as! GoogleCastMediaPlaybackViewController
        vc.castController = self
        return vc
    }()
    
    init(){
        scanner = CastDeviceScanner()
        scanner.delegate = self
    }
    
    func connect(to device: CastDevice){
        if let client = client {
            client.disconnect()
            client.delegate = nil
        }
        
        debugPrint("Info: Connecting to \(device)")
        
        client = CastClient(device: device)
        client?.delegate = self
        client?.connect()
        viewController.deviceListUpdated()
    }
    
    func disconnect(){
        client?.disconnect()
        client = nil
        viewController.deviceListUpdated()
    }
    
    func present(from source: UIViewController) -> Any {
        let vc = viewController
        let delegate = setupHalfFillView(for: vc, from: source)
        source.present(vc, animated: true)
        return delegate
    }
    
    func initiate(playbackMedia media: PlaybackMedia) {
        guard let client = client else { return }
        guard let castMedia = media.castMedia else { return }
        
        client.launch(appId: CastAppIdentifier.defaultMediaPlayer) {
            result in
            guard let app = result.value else {
                debugPrint("Error: \(result.error!)")
                return
            }
            
            client.load(media: castMedia, with: app){ _ in }
        }
    }
    
    func start(){ scanner.startScanning() }
    
    func stop(){ scanner.stopScanning() }
}

extension CastController {
    func castClient(_ client: CastClient, didConnectTo device: CastDevice) {
        debugPrint("Info: Connected to \(device)")
        viewController.deviceListUpdated()
    }
    
    func castClient(_ client: CastClient, didDisconnectFrom device: CastDevice) {
        debugPrint("Info: Disconnected from \(device)")
        viewController.deviceListUpdated()
    }
}

extension CastController {
    func deviceDidComeOnline(_ device: CastDevice){
        devices.append(device)
        viewController.deviceListUpdated()
    }
    
    func deviceDidChange(_ device: CastDevice){
        viewController.deviceListUpdated()
    }
    
    func deviceDidGoOffline(_ device: CastDevice){
        devices.removeAll { $0.id == device.id }
        viewController.deviceListUpdated()
    }
}
