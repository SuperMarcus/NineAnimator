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
import JavaScriptCore
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

@available(iOS 13, *)
@objc class NACoreEngineProxiesContentProvider: NSObject, ContentProvider {
    typealias TypeConversionCallback = (NACoreEngine, JSValue) -> AnyLink?
    
    var title: String {
        proxiedObject?.value?.objectForKeyedSubscript("title")?.toString() ?? "Unknown Title"
    }
    
    var totalPages: Int? {
        if let totalPages = proxiedObject?.value?.objectForKeyedSubscript("totalPages")?.toNumber()?.intValue, totalPages >= 0 {
            return totalPages
        }
        
        return nil
    }
    
    var availablePages: Int {
        let expectedPageNumber = fetchedPages.count
        
        if let availablePages = proxiedObject?.value?.objectForKeyedSubscript("availablePages")?.toNumber()?.intValue, availablePages == expectedPageNumber {
            return availablePages
        }
        
        Log.error("[NACoreEngineProxiesContentProvider] ContentProvider.availablePages is either undefined or contains an unexpected value.")
        
        return expectedPageNumber
    }
    
    var moreAvailable: Bool {
        if let totalPages = self.totalPages {
            return totalPages > self.availablePages
        }
        
        return true
    }
    
    weak var delegate: ContentProviderDelegate?
    
    private var proxiedObject: JSManagedValue?
    private var conversionCallback: TypeConversionCallback
    private var fetchedPages = [[AnyLink]]()
    private var executingTask: NineAnimatorAsyncTask?
    
    private weak var engine: NACoreEngine?
    
    init(proxying proxiedObject: JSValue, engine: NACoreEngine, converter conversionCallback: @escaping TypeConversionCallback) {
        self.engine = engine
        self.conversionCallback = conversionCallback
        
        super.init()
        
        self.proxiedObject = .init(value: proxiedObject, andOwner: self)
    }
    
    func links(on page: Int) -> [AnyLink] {
        fetchedPages.count > page ? fetchedPages[page] : []
    }
    
    func more() {
        guard case .none = executingTask else {
            return
        }
        
        guard let engine = self.engine else {
            delegate?.onError(NineAnimatorError.unknownError("CoreEngine has been unexpectedly released."), from: self)
            return
        }
        
        guard let coreProxiedValue = self.proxiedObject?.value else {
            delegate?.onError(NineAnimatorError.unknownError("Proxied NineAnimatorCore value has been unexpectedly released."), from: self)
            return
        }
        
        // Next page should always be availablePages + 1
        let nextPageIndex = self.availablePages
        
        guard let coreNextPageResult = coreProxiedValue.invokeMethod("fetchNextPage", withArguments: []),
              coreProxiedValue.isArray || coreProxiedValue.isInstance(of: engine.promiseType) else {
            delegate?.onError(NineAnimatorError.unknownError("Proxied ContentProvider returned an invalid value."), from: self)
            return
        }
        
        if coreProxiedValue.isArray {
            _handlePageFetchResult(coreProxiedValue, pageIndex: nextPageIndex)
        } else {
            self.executingTask = engine.toNativePromise(coreNextPageResult).defer {
                [weak self] _ in self?.executingTask = nil
            } .error {
                [weak self] error in self?._handlePageFetchError(error)
            } .finally {
                [weak self] result in self?._handlePageFetchResult(result, pageIndex: nextPageIndex)
            }
        }
    }
    
    private func _handlePageFetchError(_ error: Error) {
        self.delegate?.onError(error, from: self)
    }
    
    private func _handlePageFetchResult(_ arrayResult: JSValue, pageIndex: Int) {
        guard let engine = self.engine else {
            delegate?.onError(NineAnimatorError.unknownError("CoreEngine has been unexpectedly released."), from: self)
            return
        }
        
        guard self.fetchedPages.count == pageIndex else {
            return Log.error("[NACoreEngineProxiesContentProvider] Unexpected page result index %@. Expecting %@. The results will be ignored.", pageIndex, self.fetchedPages.count)
        }
        
        guard let nativeArrayResults = arrayResult.toArray() else {
            return Log.error("[NACoreEngineProxiesContentProvider] Result is not convertible to the excepted array type.")
        }
        
        let pageContent = nativeArrayResults.compactMap {
            resultElement -> AnyLink? in
            let jsElementValue = engine.convertToJSValue(resultElement)
            
            if let element = self.conversionCallback(engine, jsElementValue) {
                return element
            } else {
                Log.error("[NACoreEngineProxiesContentProvider] An element from the result (%@) cannot be converted. This element will be removed from the result list.", jsElementValue)
                return nil
            }
        }
        
        self.fetchedPages.append(pageContent)
        self.delegate?.pageIncoming(pageIndex, from: self)
    }
}

// MARK: - Converters
@available(iOS 13, *)
extension NACoreEngineProxiesContentProvider {
    /// Convert elements from a NACoreEngineExportsAnimeLink object
    static var animeLinkConverter: TypeConversionCallback {
        {
            engine, value in
            if let nativeAnimeLink = engine.toNativeObject(value, type: NACoreEngineExportsAnimeLink.self)?.nativeAnimeLink {
                return .anime(nativeAnimeLink)
            }
            
            return nil
        }
    }
    
    /// Convert elements from a NACoreEngineExportsEpisodeLink object
    static var episodeLinkConverter: TypeConversionCallback {
        {
            engine, value in
            if let nativeEpisodeLink = engine.toNativeObject(value, type: NACoreEngineExportsEpisodeLink.self)?.nativeEpisodeLink {
                return .episode(nativeEpisodeLink)
            }
            
            return nil
        }
    }
}
