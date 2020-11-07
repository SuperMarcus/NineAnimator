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

import AppCenterAnalytics
import UIKit

class SettingsAppIconController: MinFilledCollectionViewController {
    private lazy var availableAppIcons: [String] = {
        guard let declaredAltIcons = Bundle.main.infoDictionary?.value(at: "CFBundleIcons.CFBundleAlternateIcons") as? [String: Any] else {
            return []
        }
        
        return Array(declaredAltIcons.keys)
    }()
    
    private lazy var communityContributedIcons: [String] = {
        // A list of app icons contributed by our discord community
        [
            "Tydox's 9",
            "9 Testboi",
            "Nsxtop's 9",
            "NsxHalloween",
            "B'day by Nsx"
        ] .filter { availableAppIcons.contains($0) }
    }()
    
    private lazy var discoverableIcons: [String] = {
        availableAppIcons.filter {
            !communityContributedIcons.contains($0)
        } .sorted(by: <)
    }()
    
    private lazy var discoveredIconsSet = Set(NineAnimator.default.user.discoveredAppIcons)
    
    private var currentSelection: String? {
        UIApplication.shared.alternateIconName
    }
    
    private var currentSelectionCellPath: IndexPath {
        indexPath(forIconName: currentSelection)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setLayoutParameters(alwaysFillLine: false, minimalSize: .init(width: 80, height: 130))
        configureForTransparentScrollEdge()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int { 3 }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return communityContributedIcons.count
        case 2: return discoverableIcons.count
        default: return 0
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "settings.appIcon",
            for: indexPath
        ) as! SettingsAppIconAlternativeIconCell
        
        let iconName = self.iconName(forIndex: indexPath)
        cell.setPresenting(iconName, isUnlocked: self.isIconUnlocked(iconName: iconName))
        cell.setIsCurrentIcon(currentSelection == iconName, animated: false)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let sectionHeader = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "settings.appIcon.header",
            for: indexPath
        ) as! SettingsAppIconHeaderView
        
        switch indexPath.section {
        case 0: sectionHeader.setSectionName("DEFAULT ICON")
        case 1: sectionHeader.setSectionName("COMMUNITY CONTRIBUTED")
        case 2: sectionHeader.setSectionName("DISCOVERABLE ICONS")
        default:
            sectionHeader.setSectionName("UNKNOWN")
            Log.error("[SettingsAppIconController] Unknown section index %s", indexPath.section)
        }
        
        return sectionHeader
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedIconName = iconName(forIndex: indexPath)
        let previousIndex = currentSelectionCellPath
        
        // Of course...anyone can bypass this. But that wouldn't be fun would it?
        guard self.isIconUnlocked(iconName: selectedIconName) else {
            return Log.info("[SettingsAppIconController] Per uttiya's request, this icon cannot be used because it hasn't been discovered.")
        }
        
        MSAnalytics.trackEvent("App Magic #1001", withProperties: [
            "previousIcon": selectedIconName ?? "default",
            "currentIcon": currentSelection ?? "default"
        ])
        
        UIApplication.shared.setAlternateIconName(selectedIconName) {
            [weak self] error in
            guard error == nil else {
                return Log.error(error)
            }
            
            DispatchQueue.main.async {
                guard let self = self,
                      let cell = self.collectionView.cellForItem(at: indexPath) as? SettingsAppIconAlternativeIconCell else {
                    return
                }
                
                if let previousCell = self.collectionView.cellForItem(at: previousIndex) as? SettingsAppIconAlternativeIconCell {
                    previousCell.setIsCurrentIcon(false, animated: true)
                }
                
                cell.setIsCurrentIcon(true, animated: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        .init(top: 0, left: 12, bottom: 16, right: 12)
    }
    
    private func indexPath(forIconName iconName: String?) -> IndexPath {
        if let selection = iconName {
            if let index = communityContributedIcons.firstIndex(of: selection) {
                return .init(item: index, section: 1)
            } else if let index = discoverableIcons.firstIndex(of: selection) {
                return .init(item: index, section: 2)
            }
        }
        
        return .init(item: 0, section: 0)
    }
    
    private func iconName(forIndex indexPath: IndexPath) -> String? {
        switch indexPath.section {
        case 1: return communityContributedIcons[indexPath.item]
        case 2: return discoverableIcons[indexPath.item]
        default: return nil
        }
    }
    
    private func isIconUnlocked(iconName: String?) -> Bool {
        if let iconName = iconName, !communityContributedIcons.contains(iconName) {
            return discoveredIconsSet.contains(iconName)
        }
        
        return true
    }
}

// MARK: - Discover New Icon!
extension SettingsAppIconController {
    static func makeAvailable(_ iconName: String, from viewController: UIViewController, allowsSettingsPopup: Bool, completionHandler: (() -> Void)? = nil) -> Bool {
        var discoveredIcons = NineAnimator.default.user.discoveredAppIcons
        
        guard UIApplication.shared.supportsAlternateIcons, !discoveredIcons.contains(iconName) else {
            completionHandler?()
            return false
        }
        
        MSAnalytics.trackEvent("App Magic #1002", withProperties: [
            "unlockedIcon": iconName
        ])
        
        let alertController = UIAlertController(
            title: "App Icon Discovered",
            message: "You have discovered a new app icon: \(iconName).",
            preferredStyle: .alert
        )
        
        if allowsSettingsPopup {
            alertController.addAction(UIAlertAction(title: "View", style: .default) {
                [weak viewController] _ in
                guard let viewController = viewController,
                      let settingsPanel = SettingsSceneController.create(
                        navigatingTo: .appIcon,
                        onDismissal: completionHandler
                      ) else {
                    completionHandler?()
                    return
                }
                viewController.present(settingsPanel, animated: true)
            })
            
            alertController.addAction(UIAlertAction(title: "Later", style: .cancel) {
                _ in completionHandler?()
            })
        } else {
            alertController.addAction(UIAlertAction(title: "Okay", style: .cancel) {
                _ in completionHandler?()
            })
        }
        
        discoveredIcons.append(iconName)
        NineAnimator.default.user.discoveredAppIcons = discoveredIcons
        viewController.present(alertController, animated: true)
        
        return true
    }
}
