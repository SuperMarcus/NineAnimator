//
//  NineAnimatePath.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/4/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation

struct NineAnimatePath : Hashable {
    static let home = NineAnimatePath("/")
    
    static func search(keyword: String, page: Int = 1) -> NineAnimatePath {
        let path = "/search"
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return NineAnimatePath("\(path)?keyword=\(encodedKeyword)&page=\(page)")
    }
    
    let value: String
    var hashValue: Int { return value.hashValue }
    
    private init(_ value: String) { self.value = value }
}
