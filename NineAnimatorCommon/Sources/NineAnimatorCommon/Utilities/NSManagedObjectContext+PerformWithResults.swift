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

public extension NSManagedObjectContext {
    /// Perform an operation synchronously with return values.
    func performWithResults<ResultType>(_ block: () throws -> ResultType) throws -> ResultType {
        var result: Result<ResultType, Error> = .failure(NineAnimatorError.unknownError)
        self.performAndWait {
            do {
                result = .success(try block())
            } catch {
                result = .failure(error)
            }
        }
        
        switch result {
        case let .success(resultValue):
            return resultValue
        case let .failure(errorValue):
            throw errorValue
        }
    }
    
    /// Perform an operation synchronously with return values.
    func performWithResults<ResultType>(_ block: () -> ResultType) -> ResultType {
        var result: ResultType?
        self.performAndWait {
            result = block()
        }
        return result!
    }
}
