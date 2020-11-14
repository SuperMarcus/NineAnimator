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
    
    static let maximalInMemoryMessagesCache = 512
    
    private let _systemLogger: OSLog
    private var _cachedLogMessagesHead: LogMessageListItem?
    private var _cachedLogMessagesTail: LogMessageListItem?
    private var _cachedLogMessagesCount: Int = 0
    
    fileprivate init() {
        let logObject = OSLog(subsystem: "com.marcuszhou.NineAnimator", category: "log")
        
        // Maintains a reference to the system log object
        _systemLogger = logObject
    }
}

// MARK: - Logging Methods
extension NineAnimatorLogger {
    func debug(_ message: StaticString, functionName: String = #function, fileName: String = #file, _ arguments: Any...) {
        _log(
            message,
            level: .debug,
            metadata: LogMetadata(
                symbols: Thread.callStackSymbols,
                function: functionName,
                file: (fileName as NSString).lastPathComponent
            ),
            arguments: arguments
        )
    }
    
    func info(_ message: StaticString, functionName: String = #function, fileName: String = #file, _ arguments: Any...) {
        _log(
            message,
            level: .info,
            metadata: LogMetadata(
                function: functionName,
                file: (fileName as NSString).lastPathComponent
            ),
            arguments: arguments
        )
    }
    
    func error(_ message: StaticString, functionName: String = #function, fileName: String = #file, _ arguments: Any...) {
        _log(
            message,
            level: .error,
            metadata: LogMetadata(
                symbols: Thread.callStackSymbols,
                function: functionName,
                file: (fileName as NSString).lastPathComponent
            ),
            arguments: arguments
        )
    }
    
    func error(_ error: Error?, functionName: String = #function, fileName: String = #file) {
        if let error = error {
            self.error("%@", functionName: functionName, fileName: fileName, error)
        } else { self.error("Unknown error", functionName: functionName, fileName: fileName) }
    }
    
    func fault(_ message: StaticString, functionName: String = #function, fileName: String = #file, _ arguments: Any...) {
        _log(
            message,
            level: .fault,
            metadata: LogMetadata(
                symbols: Thread.callStackSymbols,
                function: functionName,
                file: (fileName as NSString).lastPathComponent
            ),
            arguments: arguments
        )
    }
}

// MARK: - Exporting Logs
extension NineAnimatorLogger {
    /// Dump logs from the current session to a file
    func exportRuntimeLogs(maxItems: Int = NineAnimatorLogger.maximalInMemoryMessagesCache, privacyOptions: ExportPrivacyOption = []) throws -> URL {
        // Redact messages
        let messages = retrieveMostRecentMessages(maxItems: maxItems).map {
            message -> LogMessage in
            var mutatedMessage = message
            
            if privacyOptions.contains(.redactParameters) {
                mutatedMessage.parameters = mutatedMessage.parameters.map {
                    _ in "<redacted>"
                }
            }
            
            return mutatedMessage
        }
        
        let outputFileStruct = ExportFile(exportPrivacyOptions: privacyOptions, messages: messages)
        let outputFileName = "NineAnimatorLog-\(Int(outputFileStruct.exportDate.timeIntervalSince1970)).json"
        let outputFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let serializedLogData = try encoder.encode(outputFileStruct)
        try serializedLogData.write(to: outputFileUrl)
        
        return outputFileUrl
    }
    
    /// Retrieve the most recent log messages
    func retrieveMostRecentMessages(maxItems: Int = NineAnimatorLogger.maximalInMemoryMessagesCache) -> [LogMessage] {
        var result = [LogMessage]()
        var currentItem = _cachedLogMessagesTail
        
        while let unwrappedCurrentItem = currentItem {
            result.append(unwrappedCurrentItem.message)
            currentItem = unwrappedCurrentItem.previousItem
        }
        
        return result
    }
}

extension NineAnimatorLogger {
    /// Representing a level of the logging message
    struct LogLevel: Codable {
        static let debug = LogLevel(osLogTypeValue: OSLogType.debug.rawValue, description: "debug")
        static let info = LogLevel(osLogTypeValue: OSLogType.info.rawValue, description: "info")
        static let error = LogLevel(osLogTypeValue: OSLogType.error.rawValue, description: "error")
        static let fault = LogLevel(osLogTypeValue: OSLogType.fault.rawValue, description: "fault")
        
        var osLogTypeValue: UInt8
        var description: String
        
        var osLogType: OSLogType { .init(osLogTypeValue) }
    }
    
    /// Attributes of the log message
    struct LogMetadata: Codable {
        /// Callstack symbols for the message.
        /// - Note: Callstack symbols are not recorded for the `info` logging level.
        var symbols: [String]?
        var function: String
        var file: String
        var timestamp: Date = .init()
    }
    
    /// Representing a log message
    struct LogMessage: Codable {
        var level: LogLevel
        var message: String
        var parameters: [String]
        var meta: LogMetadata
    }
    
    /// Log messages export options
    struct ExportPrivacyOption: OptionSet, Codable {
        var rawValue: Int
        
        /// Remove message parameters before exporting
        static let redactParameters = ExportPrivacyOption(rawValue: 1 << 0)
    }
    
    /// Structure of the exported log messages
    struct ExportFile: Codable {
        var exportDate = Date()
        var version = NineAnimatorVersion.current.stringRepresentation
        var exportPrivacyOptions: ExportPrivacyOption
        var messages: [LogMessage]
    }
    
    /// Internal list for caching log messages in memory
    private class LogMessageListItem {
        var message: LogMessage
        var nextItem: LogMessageListItem?
        weak var previousItem: LogMessageListItem?
        
        init(_ message: LogMessage) {
            self.message = message
            self.nextItem = nil
            self.previousItem = nil
        }
        
        func nextItem(offset: Int = 1) -> LogMessageListItem? {
            if offset <= 0 {
                return self
            } else {
                return nextItem?.nextItem(offset: offset - 1)
            }
        }
        
        func previousItem(offset: Int = 1) -> LogMessageListItem? {
            if offset <= 0 {
                return self
            } else {
                return previousItem?.previousItem(offset: offset - 1)
            }
        }
    }
    
    private func _log(_ message: StaticString, level: LogLevel, metadata: LogMetadata, arguments: [Any]) {
        let logMessage = LogMessage(
            level: level,
            message: message.description,
            parameters: arguments.map { String(describing: $0) },
            meta: metadata
        )
        _logToSystemLogger(message, level: level, arguments: logMessage.parameters)
        
        // Store the message item in memory
        let logMessageItem = LogMessageListItem(logMessage)
        if let tail = _cachedLogMessagesTail {
            tail.nextItem = logMessageItem
            logMessageItem.previousItem = tail
            _cachedLogMessagesTail = logMessageItem
            
            if _cachedLogMessagesCount < NineAnimatorLogger.maximalInMemoryMessagesCache {
                _cachedLogMessagesCount += 1
            } else {
                // Remove the first item
                _cachedLogMessagesHead = _cachedLogMessagesHead?.nextItem
            }
        } else {
            _cachedLogMessagesHead = logMessageItem
            _cachedLogMessagesTail = logMessageItem
            _cachedLogMessagesCount = 1
        }
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
    fileprivate func _logToSystemLogger(_ message: StaticString, level: LogLevel, arguments args: [String]) {
        switch args.count { // I'm really curious to know if there is any better way of wrapping os_log
        case 0: os_log(message, log: _systemLogger, type: level.osLogType)
        case 1: os_log(message, log: _systemLogger, type: level.osLogType, args[0])
        case 2: os_log(message, log: _systemLogger, type: level.osLogType, args[0], args[1])
        case 3: os_log(message, log: _systemLogger, type: level.osLogType, args[0], args[1], args[2])
        case 4: os_log(message, log: _systemLogger, type: level.osLogType, args[0], args[1], args[2], args[3])
        case 5: os_log(message, log: _systemLogger, type: level.osLogType, args[0], args[1], args[2], args[3], args[4])
        default: os_log("[NineAnimatorLogger] Logger function is called with too many arguments.", log: _systemLogger, type: .fault)
        }
    }
}
