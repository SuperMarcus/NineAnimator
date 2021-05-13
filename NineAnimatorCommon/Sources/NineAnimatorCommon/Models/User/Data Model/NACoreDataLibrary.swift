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

import CoreData
import Foundation

public class NACoreDataLibrary {
    private let _container: NSPersistentContainer
    
    /// Library context used on main threads
    public internal(set) lazy var mainContext = Context(withContext: self._container.viewContext)
    
    internal init() {
        guard let modelUrl = Bundle.module.url(
                forResource: "UserLibrary",
                withExtension: "momd"),
              let managedObjectModel = NSManagedObjectModel(
                contentsOf: modelUrl
              ) else { fatalError("NineAnimator CoreData model not found.") }
        
        self._container = NSPersistentContainer(
            name: "UserLibrary",
            managedObjectModel: managedObjectModel
        )
        self._container.loadPersistentStores {
            _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    public func createBackgroundContext() -> Context {
        let managedContext = self._container.newBackgroundContext()
        return Context(withContext: managedContext)
    }
}

// MARK: - Dangerous
public extension NACoreDataLibrary {
    /// Deletes everything in the CoreData library
    func reset() {
        do {
            Log.info("[NACoreDataLibrary.Context] Resetting CoreData library...")
            let persistentStoreCoordinator = self._container
                .persistentStoreCoordinator
            let fs = FileManager.default
            
            for store in persistentStoreCoordinator.persistentStores where !store.isReadOnly {
                if let storeUrl = store.url, storeUrl.isFileURL {
                    Log.info("[NACoreDataLibrary.Context] Resetting persistent store at: %@", storeUrl)
                    try persistentStoreCoordinator.remove(store)
                    try fs.removeItem(at: storeUrl)
                }
            }
            
            Log.info("[NACoreDataLibrary.Context] Reloading CoreData persistent containers...")
            self._container.loadPersistentStores {
                _, error in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        } catch {
            Log.error("[NACoreDataLibrary.Context] Unable to reset library because of error: %@", error)
        }
    }
}
