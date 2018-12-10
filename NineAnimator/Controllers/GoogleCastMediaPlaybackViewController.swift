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

enum CastDeviceState {
    case idle
    case connected
    case connecting
}

class GoogleCastMediaPlaybackViewController: UIViewController, HalfFillViewControllerProtocol, UITableViewDataSource {
    weak var castController: CastController!
    
    @IBOutlet weak var deviceListTableView: UITableView!
    
    @IBAction func onDoneButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deviceListTableView.dataSource = self
        deviceListTableView.rowHeight = 48
        castController.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        castController.stop()
    }
}

extension GoogleCastMediaPlaybackViewController {
    func deviceListUpdated(){
        deviceListTableView.reloadSections([0], with: .automatic)
    }
    
    func device(selected: Bool, from device: CastDevice, with cell: GoogleCastDeviceTableViewCell) {
        if selected {
            if device == castController.client?.device {
                castController.disconnect()
            } else {
                castController.connect(to: device)
            }
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
        cell.state = device == castController.client?.device ? castController.client?.isConnected == true ? .connected : .connecting : .idle
        cell.delegate = self
        return cell
    }
}
