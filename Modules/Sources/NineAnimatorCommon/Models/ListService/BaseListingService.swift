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

import Alamofire
import Foundation

open class BaseListingService: SessionDelegate {
    open var identifier: String { "" }
    
    /// An internal structure that stores and maps the `ListingAnimeReference` to the `ListingAnimeTracking`
    private let referenceTrackingLock = NSLock()
    private var referenceToTrackingMap = [ListingAnimeReference: ListingAnimeTracking]()
    
    public var persistedProperties: [String: Any] {
        get {
            do {
                let fs = FileManager.default
                
                // Store the properties under the application support directory
                let applicationSupportDirectory = try fs.url(
                    for: .applicationSupportDirectory,
                    in: .allDomainsMask,
                    appropriateFor: nil,
                    create: true
                )
                let propertyPersistentFile = applicationSupportDirectory
                    .appendingPathComponent("\(identifier).plist")
                
                // Unserialize if the file exists
                if FileManager.default.fileExists(atPath: propertyPersistentFile.path),
                    (try? propertyPersistentFile.checkResourceIsReachable()) == true {
                    let persistedPropertiesData = try Data(contentsOf: propertyPersistentFile)
                    if let decodedProperties = try PropertyListSerialization.propertyList(
                            from: persistedPropertiesData,
                            options: [],
                            format: nil
                        ) as? [String: Any] {
                        return decodedProperties
                    }
                }
            } catch { Log.error("Cannot read listing service state: %@", error) }
            return [:]
        }
        set {
            do {
                let fs = FileManager.default
                
                // Store the properties under the application support directory
                let applicationSupportDirectory = try fs.url(
                    for: .applicationSupportDirectory,
                    in: .allDomainsMask,
                    appropriateFor: nil,
                    create: true
                )
                let propertyPersistentFile = applicationSupportDirectory
                    .appendingPathComponent("\(identifier).plist")
                
                // Write properties to file
                try PropertyListSerialization
                    .data(fromPropertyList: newValue, format: .binary, options: 0)
                    .write(to: propertyPersistentFile)
            } catch { Log.error("Cannot write listing service state: %@", error) }
        }
    }
    
    public unowned var parent: NineAnimator
    
    /// Ensure Alamofire Session does not get initilized more than once by synchronizing reads to `lazySession`
    private let sessionLock = NSLock()
    private var session: Alamofire.Session {
        sessionLock.lock { lazySession }
    }
    
    fileprivate lazy var lazySession: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        return Session(configuration: configuration, delegate: self)
    }()
    
    public required init(_ parent: NineAnimator) {
        self.parent = parent
        super.init()
    }
    
    /// Making a promisified request
    public func request(_ url: URL, method: HTTPMethod = .get, data: Data? = nil, headers: HTTPHeaders = [:]) -> NineAnimatorPromise<Data> {
        NineAnimatorPromise.firstly {
            var request = try URLRequest(url: url, method: method)
            // Copy headers from HTTPHeaders to URLRequest
            headers.dictionary.forEach {
                request.setValue($0.value, forHTTPHeaderField: $0.key)
            }
            request.httpBody = data
            request.cachePolicy = .reloadRevalidatingCacheData
            return request
        } .thenPromise {
            request in
            NineAnimatorPromise {
                callback in
                self.session.request(request).responseData {
                    response in
                    switch response.result {
                    case .success(let value): callback(value, nil)
                    case .failure(let error): callback(nil, error)
                    }
                }
            }
        }
    }
    
    /// Retrieve the episode number from the assigned episode name
    ///
    /// Typically the first portion of the episode name contains the
    /// episode number.
    open func suggestEpisodeNumber(from name: String) -> Int {
        if let nameFirstPortion = name.split(separator: " ").first,
            let episodeNumber = Int(String(nameFirstPortion)) {
            return episodeNumber
        } else {
            Log.info("Episode name \"%\" does not suggest an episode number. Using 1 as the progress.", name)
            return 1
        }
    }
    
    /// A template onRegister method
    open func onRegister() { }
    
    /// Retrieve the corresponding `ListingAnimeTracking` for the reference
    public func progressTracking(for reference: ListingAnimeReference) -> ListingAnimeTracking? {
        referenceTrackingLock.lock {
            referenceToTrackingMap[reference]
        }
    }
    
    /// Obtain the corresponding `ListingAnimeTracking` for the reference with an updated progress.
    ///
    /// - Note: If no previous `ListingAnimeTracking` is found, a new one is created with only the progress.
    /// - Important: Calling this method does not update the `ListingAnimeTracking` in the internal map.
    public func progressTracking(for reference: ListingAnimeReference, withUpdatedEpisodeProgress newProgress: Int) -> ListingAnimeTracking {
        progressTracking(for: reference)?.newTracking(withUpdatedProgress: newProgress)
            ?? ListingAnimeTracking(currentProgress: newProgress, episodes: nil)
    }
    
    /// Update the tracking state for the reference
    ///
    /// - Important: If the new tracking's `episodes` property is nil, the previous `episodes` value is used and stored.
    public func donateTracking(_ tracking: ListingAnimeTracking?, forReference reference: ListingAnimeReference) {
        // Obtain a mutable tracking
        var processedTracking = tracking
        referenceTrackingLock.lock {
            // If the episodes of the new tracking is not set, use the previous value
            if let tracking = tracking,
                let existingTracking = self.referenceToTrackingMap[reference] {
                processedTracking?.episodes = tracking.episodes ?? existingTracking.episodes
            }
        
            // Store the new tracking value in the interval structure
            referenceToTrackingMap[reference] = processedTracking
        }
    }
}
