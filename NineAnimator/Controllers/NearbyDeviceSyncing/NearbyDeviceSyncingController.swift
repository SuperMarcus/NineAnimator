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
import UIKit

class NearbyDeviceSyncingController: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    static let syncingServiceUUID = CBUUID(string: "5d2abe26-6631-4a62-a18f-88ca9154dd70")
    
    private let queue = DispatchQueue(
        label: "com.marcuszhou.NineAnimator.bluetooth",
        qos: .background,
        attributes: .concurrent
    )
    
    private lazy var central = CBCentralManager(delegate: self, queue: self.queue)
    
    private lazy var peripheral = CBPeripheralManager(delegate: self, queue: self.queue)
    
    private var characteristicsPool = [CBUUID: CBMutableCharacteristic]()
    
    private var peersPool = [CBPeripheral]()
    
    override init() {
        super.init()
        
        // Initialize the central and peripheral managers
        _ = central
        _ = peripheral
    }
}

extension NearbyDeviceSyncingController {
    private func updateConfigurations() {
        do {
            let configuration = NABluetoothCharacteristicConfigurations()
            let serializedData = try PropertyListEncoder().encode(configuration)
            
            let configurationCharacteristic = characteristicsPool[NABluetoothCharacteristicConfigurations.uuid]!
            
            configurationCharacteristic.value = serializedData
            peripheral.updateValue(serializedData,
                                   for: configurationCharacteristic,
                                   onSubscribedCentrals: nil)
        } catch { Log.error(error) }
    }
}

// MARK: - Publishing services
extension NearbyDeviceSyncingController {
    private func publish() {
        Log.info("Setting up bluetooth for NineAnimator peer discovery")
        
        do {
            let service = CBMutableService(type: type(of: self).syncingServiceUUID, primary: true)
            
            // Protocol version characteristic
            characteristicsPool[NABluetoothCharacteristicVersion.uuid] = try {
                let version = NABluetoothCharacteristicVersion()
                
                let encodedVersionData = try PropertyListEncoder().encode(version)
                
                let characteristic = CBMutableCharacteristic(
                    type: NABluetoothCharacteristicVersion.uuid,
                    properties: [.read],
                    value: encodedVersionData,
                    permissions: [.readable]
                )
                
                return characteristic
            }()
            
            // Actual configurations
            characteristicsPool[NABluetoothCharacteristicConfigurations.uuid] = {
                let characteristic = CBMutableCharacteristic(
                    type: NABluetoothCharacteristicConfigurations.uuid,
                    properties: [.notifyEncryptionRequired],
                    value: nil,
                    permissions: [.readEncryptionRequired]
                )
                
                return characteristic
            }()
            
            service.characteristics = characteristicsPool.map { $0.value }
            
            // Remove all services first
            peripheral.removeAllServices()
            peripheral.add(service)
            
            // Start advertising the NineAnimator service
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [ type(of: self).syncingServiceUUID ],
                CBAdvertisementDataLocalNameKey: "NineAnimator - \(UIDevice.current.name)"
            ])
            
            // Update values for configurations
            updateConfigurations()
        } catch { Log.error("Cannot register bluetooth services - %@", error) }
    }
    
    private func unpublish() {
        peripheral.removeAllServices()
    }
}

// MARK: - Subscribing services
extension NearbyDeviceSyncingController {
    private func subscribe() {
        central.scanForPeripherals(withServices: [ type(of: self).syncingServiceUUID ], options: nil)
        
        Log.info("Begin to scan for NineAnimator bluetooth services")
    }
    
    private func unsubscribe() {
        central.stopScan()
    }
}

// MARK: - CBCentralManagerDelegate
extension NearbyDeviceSyncingController {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            subscribe()
        } else { unsubscribe() }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peer: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if peersPool.contains(where: { $0.identifier == peer.identifier }) {
            return
        }
        
        Log.info("New peer discovered '%@' (%@), RSSI: %@", peer.name ?? "Unknown Name", peer.identifier.uuidString, RSSI)
        
        peer.delegate = self
        central.connect(peer, options: nil)
        peersPool.append(peer)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peer: CBPeripheral) {
        Log.info("Connected to peer '%@' (%@)", peer.name ?? "Unknown Name", peer.identifier.uuidString)
        peer.discoverServices([ type(of: self).syncingServiceUUID ])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peer: CBPeripheral,
                        error: Error?) {
        Log.info("Disconnected from peer '%@' (%@)", peer.name ?? "Unknown Name", peer.identifier.uuidString)
        peersPool.removeAll { $0.identifier == peer.identifier }
    }
}

// MARK: - CBPeripheralDelegate
extension NearbyDeviceSyncingController {
    func peripheral(_ peer: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Log.error("Failed to disocvery services for peer '%@' (%@) - %@", peer.name ?? "Unknown Name", peer.identifier.uuidString, error)
            return
        }
        
        guard let services = peer.services else {
            Log.error("Services for peer is undefined")
            return
        }
        
        if let versionService = services.first(where: { $0.uuid.isEqual(type(of: self).syncingServiceUUID) }) {
            peer.discoverCharacteristics([ NABluetoothCharacteristicVersion.uuid ], for: versionService)
        }
    }
    
    func peripheral(_ peer: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            if let configurations = characteristics
                .first(where: { $0.uuid.isEqual(NABluetoothCharacteristicConfigurations.uuid) }) {
                if configurations.value == nil {
                    Log.info("Subscribing configuration changes from '%@' (%@)", peer.name ?? "Unknown Name", peer.identifier.uuidString)
                    peer.readValue(for: configurations)
                    peer.setNotifyValue(true, for: configurations)
                }
                return
            }
            
            if let protocolVersion = characteristics
                .first(where: { $0.uuid.isEqual(NABluetoothCharacteristicVersion.uuid) }) {
                if protocolVersion.value == nil { peer.readValue(for: protocolVersion) }
                return
            }
        }
    }
    
    func peripheral(_ peer: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if characteristic.uuid.isEqual(NABluetoothCharacteristicVersion.uuid) {
            do {
                if let encodedVersionData = characteristic.value {
                    let protocolInformation = try PropertyListDecoder()
                        .decode(NABluetoothCharacteristicVersion.self, from: encodedVersionData)
                    
                    if protocolInformation.protocolVersion == NANearbyProtocolVersion {
                        peer.discoverCharacteristics([ NABluetoothCharacteristicConfigurations.uuid ], for: characteristic.service)
                    } else {
                        Log.info("Peer '%@' (%@) is using a different protocol than what we are using. Aborting connection.", peer.name ?? "Unknown Name", peer.identifier.uuidString)
                        central.cancelPeripheralConnection(peer)
                    }
                }
            } catch { Log.error(error) }
        }
        
        if characteristic.uuid.isEqual(NABluetoothCharacteristicConfigurations.uuid) {
            do {
                if let encodedConfigurationData = characteristic.value {
                    let configuration = try PropertyListDecoder()
                        .decode(NABluetoothCharacteristicConfigurations.self, from: encodedConfigurationData)
                    
                    Log.info("Received configuration updates from peer '%@' (%@)", peer.name ?? "Unknown Name", peer.identifier.uuidString)
                }
            } catch { Log.error(error) }
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension NearbyDeviceSyncingController {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            publish()
        } else { unpublish() }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        Log.info("Advertising NineAnimator peer service")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        updateConfigurations()
        peripheral.respond(to: request, withResult: .success)
    }
}
