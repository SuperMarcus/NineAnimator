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

import CoreBluetooth
import Foundation

let NANearbyProtocolVersion = 0x01

/**
 NineAnimator nearby device syncing protocol version
 */
struct NABluetoothCharacteristicVersion: Codable {
    static let uuid = CBUUID(string: "bc0042ff-2dc5-453a-81d4-957b8317efdc")
    
    var protocolVersion: Int = NANearbyProtocolVersion
}

/**
 The configurations
 */
struct NABluetoothCharacteristicConfigurations: Codable {
    static let uuid = CBUUID(string: "639cafdc-ce09-4c43-b50e-a10a5603a21d")
    
    var magic: Int = 31415926
}
