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

import AppCenterCrashes
import Foundation

class NAAppCenterCrashesDelegate: NSObject, CrashesDelegate {
    func attachments(with crashes: Crashes, for errorReport: ErrorReport) -> [ErrorAttachmentLog]? {
        do {
            let fs = FileManager.default
            let tempDir = fs.temporaryDirectory
            
            Log.info("[NAAppCenterCrashesDelegate] Collecting pre-crash logs for the crash report...")
            
            return try NineAnimatorLogger.findUnsentRuntimeLogs().map {
                originalUrl -> URL in // Move logs from ApplicationSupport to tmp folder
                let targetUrl = tempDir.appendingPathComponent(originalUrl.lastPathComponent)
                try fs.moveItem(at: originalUrl, to: targetUrl)
                return targetUrl
            } .reduce(into: [ErrorAttachmentLog]()) {
                result, currentLogFile in
                let logData = try Data(contentsOf: currentLogFile)
                let attachment = ErrorAttachmentLog(
                    filename: currentLogFile.lastPathComponent,
                    attachmentBinary: logData,
                    contentType: "application/json"
                )
                
                if let attachment = attachment {
                    Log.info("[NAAppCenterCrashesDelegate] Sending pre-crash log '%@' with the crash report...", currentLogFile.lastPathComponent)
                    result.append(attachment)
                }
            }
        } catch {
            Log.error("[NAAppCenterCrashesDelegate] Unable to attach pre-crash runtime logs: %@", error)
        }
        
        return []
    }
}
