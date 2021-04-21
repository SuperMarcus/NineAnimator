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

import CryptoKit
import Foundation

@available(iOS 13.0, *)
extension NACoreEngineBundle {
    typealias SigningKey = Curve25519.Signing.PublicKey
    
    struct Manifest: Codable, Hashable {
        var name: String
        var uuid: UUID
        var services: [Service]
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }
    }
    
    enum ServiceType: String, Codable {
        case source
        case mediaParser
    }
    
    struct Service: Codable, Hashable {
        var name: String
        var uuid: UUID
        var type: ServiceType
        var path: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }
    }
    
    struct SignedEvaluable {
        var content: Data
        var signature: Data
        var sourceUrl: URL?
    }
    
    struct SignedResource {
        var content: Data
        var signature: Data
    }
}
