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
    
    static func search(keyword: String?) -> NineAnimatePath {
        var path = "/search"
        
        if let keyword = keyword,
           let wrappedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        { path += wrappedKeyword }
        
        return NineAnimatePath(path)
    }
    
    let value: String
    var hashValue: Int { return value.hashValue }
    
    private init(_ value: String) { self.value = value }
}
