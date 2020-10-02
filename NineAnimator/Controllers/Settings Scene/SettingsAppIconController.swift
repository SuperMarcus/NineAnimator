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

import UIKit

class SettingsAppIconController: MinFilledCollectionViewController {
    private lazy var availableAppIcons: [String] = {
        guard let declaredAltIcons = Bundle.main.infoDictionary?.value(at: "CFBundleIcons.CFBundleAlternateIcons") as? [String: Any] else {
            return []
        }
        
        return Array(declaredAltIcons.keys)
    }()
    
    private var currentSelection: String? {
        UIApplication.shared.alternateIconName
    }
    
    private var currentSelectionCellPath: IndexPath {
        if let selection = currentSelection,
           let index = availableAppIcons.firstIndex(of: selection) {
            return .init(item: index, section: 1)
        }
        
        return .init(item: 0, section: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setLayoutParameters(alwaysFillLine: false, minimalSize: .init(width: 80, height: 130))
        configureForTransparentScrollEdge()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return availableAppIcons.count
        default: return 0
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "settings.appIcon",
            for: indexPath
        ) as! SettingsAppIconAlternativeIconCell
        
        switch indexPath.section {
        case 0: // Default icon section
            cell.setPresenting(nil)
            cell.setIsCurrentIcon(currentSelection == nil, animated: false)
        case 1: // Alt icons
            let altIconName = availableAppIcons[indexPath.item]
            cell.setPresenting(altIconName)
            cell.setIsCurrentIcon(currentSelection == altIconName, animated: false)
        default:
            Log.error("[SettingsAppIconController] Cannot make cell for unknown section index %s", indexPath.section)
        }
        
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
        case 1: sectionHeader.setSectionName("ALTERNATIVE ICONS")
        default:
            sectionHeader.setSectionName("UNKNOWN")
            Log.error("[SettingsAppIconController] Unknown section index %s", indexPath.section)
        }
        
        return sectionHeader
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedIconName = indexPath.section == 1 ? availableAppIcons[indexPath.item] : nil
        let previousIndex = currentSelectionCellPath
        
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
}
