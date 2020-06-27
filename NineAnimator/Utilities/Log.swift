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

import Foundation
import os

/// The logger class that is used to wrap around the os unified logging system
class NineAnimatorLogger {
    typealias Logger = ((StaticString, Any...) -> Void)
    
    private let customLog: OSLog
    
    // The basic four levels of logging
    let info: Logger
    let debug: Logger
    let error: Logger
    let fault: Logger
    
    // Some convenient accesses
    func error(_ error: Error?) {
        if let error = error {
            self.error("%@", error)
        } else { self.error("Unknown error") }
    }
    
    fileprivate init() {
        let logObject = OSLog(subsystem: "com.marcuszhou.NineAnimator", category: "log")
        
        //Maintains a reference to the log object
        customLog = logObject
        
        info = generateLogger(logObject, for: .info)
        debug = generateLogger(logObject, for: .debug)
        error = generateLogger(logObject, for: .error)
        fault = generateLogger(logObject, for: .fault)
    }
}

/// The public log object that should be used
let Log = NineAnimatorLogger()

/*
 
 '##:::::'##::::'###::::'########::'##::: ##:'####:'##::: ##::'######:::
  ##:'##: ##:::'## ##::: ##.... ##: ###:: ##:. ##:: ###:: ##:'##... ##::
  ##: ##: ##::'##:. ##:: ##:::: ##: ####: ##:: ##:: ####: ##: ##:::..:::
  ##: ##: ##:'##:::. ##: ########:: ## ## ##:: ##:: ## ## ##: ##::'####:
  ##: ##: ##: #########: ##.. ##::: ##. ####:: ##:: ##. ####: ##::: ##::
  ##: ##: ##: ##.... ##: ##::. ##:: ##:. ###:: ##:: ##:. ###: ##::: ##::
 . ###. ###:: ##:::: ##: ##:::. ##: ##::. ##:'####: ##::. ##:. ######:::
 :...::...:::..:::::..::..:::::..::..::::..::....::..::::..:::......::::
 
 For anyone who is annoyed to see "switch on numbers", please stop reading
 this file, as it will sure arous a strong discus in your mind.
 
 After this comment, the ugly starts.
 
 */

// We shall start by disabling all lintings
// swiftlint:disable all

extension NineAnimatorLogger {
    private func generateLogger(_ customLog: OSLog, for level: OSLogType)
        -> NineAnimatorLogger.Logger {
            return { [unowned customLog] (message: StaticString, arguments: Any...) in
                let args = arguments.map { String(describing: $0) }
                switch args.count { // I'm really curious to know if there is any better way of wrapping os_log
                case 0: os_log(message, log: customLog, type: level)
                case 1: os_log(message, log: customLog, type: level, args[0])
                case 2: os_log(message, log: customLog, type: level, args[0], args[1])
                case 3: os_log(message, log: customLog, type: level, args[0], args[1], args[2])
                case 4: os_log(message, log: customLog, type: level, args[0], args[1], args[2], args[3])
                case 5: os_log(message, log: customLog, type: level, args[0], args[1], args[2], args[3], args[4])
                default:
                    os_log("[NineAnimatorLogger] Logger function is called with too many arguments.", log: customLog, type: .error)
                }
            }
    }
}
