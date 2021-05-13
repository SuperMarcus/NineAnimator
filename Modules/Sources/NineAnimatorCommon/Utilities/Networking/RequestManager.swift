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

import Alamofire
import Foundation
import SwiftSoup

/// NARequestManager provides an additional abstraction layer on top of Alamofire and URLSession.
///
/// NARequestManager modernizes the legacy APIs used in the BaseSource class. All of the request methods in this class are promise-based.
open class NARequestManager: NSObject {
    /// Alamofire session used internally
    public private(set) lazy var session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        
        return Session(
            configuration: configuration,
            interceptor: self._interceptor,
            redirectHandler: self._redirectHandler
        )
    }()
    
    /// Current User-Agent for requests made from this request manager
    public private(set) var currentIdentity = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Safari/605.1.15"
    
    /// Retrieve/set the credential manager for this request manager
    public var credentialManager: NACredentialManager?
    
    /// Additional headers that will be added to the requests
    public var additionalHeaders: HTTPHeaders = [:]
    
    private lazy var _interceptor = NARequestManagerRequestInterceptor(parent: self)
    private lazy var _redirectHandler = NARequestManagerRedirectHandler(parent: self)
    private lazy var _cfResolver = CloudflareWAFResolver(parent: self)
    
    @AtomicProperty private var _internalTaskReferences = [ObjectIdentifier: NineAnimatorAsyncTask]()
    @AtomicProperty fileprivate var _requestCustomRedirectionHandlers = [(WeakRef<Alamofire.Request>, RequestBuilding.RedirectionHandler)]()
    fileprivate var _internalAdapterChain = [WeakRef<AnyObject>]()
    fileprivate var _internalRetrierChain = [WeakRef<AnyObject>]()
    fileprivate var _internalRetryPolicy = Alamofire.RetryPolicy(retryLimit: 3)
    private var _validations = [Alamofire.DataRequest.Validation]()
    
    override public init() {
        super.init()
        self._registerBuiltinMiddlewares()
    }
}

// MARK: - Making Requests
public extension NARequestManager {
    /// Generate a request builder with a request making closure
    func request(makeRequest: @escaping (Alamofire.Session) throws -> Alamofire.DataRequest?) -> RequestBuilding {
        RequestBuilding(
            parent: self,
            makeRequest: makeRequest
        )
    }
    
    /// Generate a request builder with an URLRequest convertible object
    func request(_ requestConvertible: Alamofire.URLRequestConvertible, handling: NARequestHandlingDirective = .default) -> RequestBuilding {
        self.request {
            session in
            var mutableRequest = try requestConvertible.asURLRequest()
            
            // Modify the request according to handling directives
            switch handling {
            case .none: break
            case .browsing:
                if case .none = mutableRequest.headers.value(for: "Accept") {
                    mutableRequest.headers.add(name: "Accept", value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
                }
                
                if case .none = mutableRequest.headers.value(for: "Accept-Language") {
                    mutableRequest.headers.add(name: "Accept-Language", value: "en-us")
                }
            case .ajax:
                if case .none = mutableRequest.headers.value(for: "X-Requested-With") {
                    mutableRequest.headers.add(name: "X-Requested-With", value: "XMLHttpRequest")
                }
                
                if case .none = mutableRequest.headers.value(for: "Accept-Language") {
                    mutableRequest.headers.add(name: "Accept-Language", value: "en-us")
                }
            }
            
            return session.request(mutableRequest)
        }
    }
    
    /// Generate a request builder with an URLRequest.
    ///
    /// This method is meant for classes that don't have access to Alamofire.
    func request(urlRequest: URLRequest, handling: NARequestHandlingDirective = .default) -> RequestBuilding {
        self.request(urlRequest, handling: handling)
    }
    
    /// Generate a request builder with an URLConvertible
    ///
    /// - Parameters:
    ///     - query: The query items to be encoded to the url. If the url specified already contains query components, items specified by this dictionary will override the items with the same key in the url.
    func request(url: URLConvertible, handling: NARequestHandlingDirective = .default, method: HTTPMethod = .get, query: URLQueryParameters? = nil, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil) -> RequestBuilding {
        let convertible = RequestConvertible(
            url: url,
            method: method,
            query: query,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )
        return self.request(convertible, handling: handling)
    }
}

// MARK: - Adapter & Retrier & Validation
public extension NARequestManager {
    /// Add a `SourceRequestAdapter` to the end of the adapter chain
    func enqueueAdapter(_ adapter: NARequestAdapter) {
        _internalAdapterChain.append(.init(adapter))
    }
    
    /// Add a `SourceRequestRetrier` to the end of the retrier chain
    func enqueueRetrier(_ retrier: NARequestRetrier) {
        _internalRetrierChain.append(.init(retrier))
    }
    
    /// Add an Alamofire validation middleware
    func enqueueValidation(_ validation: @escaping Alamofire.DataRequest.Validation) {
        _validations.append(validation)
    }
}

// MARK: - Promise making
public extension NARequestManager {
    /// A helper struct used to construct promises
    /// - Note: This struct holds strong reference to the parent request manager.
    struct RequestBuilding {
        public typealias ResponseHandler = (Response) throws -> Void
        public typealias RedirectionHandler = (_ request: Alamofire.Request,
            _ response: HTTPURLResponse, _ redirectingTo: URLRequest) -> URLRequest?
        
        fileprivate var parent: NARequestManager
        fileprivate var makeRequest: (Alamofire.Session) throws -> Alamofire.DataRequest?
        fileprivate var customResponseHandler: ResponseHandler?
        fileprivate var customRedirectionHandler: RedirectionHandler?
        
        private func _makePromise<S, E>(withResponseGenerator makeResponse: @escaping (Alamofire.DataRequest, @escaping (Alamofire.DataResponse<S, E>) -> Void) -> Alamofire.DataRequest) -> NineAnimatorPromise<S> {
            NineAnimatorPromise {
                [weak parent] callback in
                do {
                    let request = try self._makeRequestApplyingMiddlewares()
                    let onResponse = self.customResponseHandler
                    
                    if let parent = parent {
                        parent.onCreateRequest(self, request: request)
                    } else {
                        callback(
                            nil,
                            NineAnimatorError.responseError("RequestManager deinitialized while creating the request")
                        )
                        return nil
                    }
                    
                    return makeResponse(request) {
                        response in
                        do {
                            let error: Error?
                            
                            if let afError = response.error as? AFError,
                                let underlyingError = afError.underlyingError {
                                error = underlyingError
                            } else { error = response.error }
                            
                            if let naError = error as? NineAnimatorError {
                                naError.relatedRequestManager = parent
                            }
                            
                            if let onResponse = onResponse {
                                let responseObject = Response(
                                    request: response.request,
                                    response: request.response
                                )
                                try onResponse(responseObject)
                            }
                            
                            callback(response.value, error)
                        } catch {
                            callback(nil, error)
                        }
                        
                        // Guarentee that we'll call the request conclusion handler
                        parent?.onConcludeRequest(request: request)
                    }
                } catch {
                    callback(nil, error)
                    return nil
                }
            }
        }
        
        private func _makeRequestApplyingMiddlewares() throws -> Alamofire.DataRequest {
            let request = try self
                .makeRequest(self.parent.session)
                .tryUnwrap()
            return parent._applyValidations(forRequest: request)
        }
    }
}

public extension NARequestManager.RequestBuilding {
    /// Create a promise that resolves the response to a Data
    var responseData: NineAnimatorPromise<Data> {
        self._makePromise { $0.responseData(completionHandler: $1) }
    }
    
    /// Create a promise that resolves into a string
    var responseString: NineAnimatorPromise<String> {
        self.responseString(interpretAs: UTF8.self)
    }
    
    /// Create a promise that receives and decodes a JSON-encoded response
    var responseJSON: NineAnimatorPromise<Any> {
        self._makePromise { $0.responseJSON(completionHandler: $1) }
    }
    
    /// Create a promise that receives and decodes a JSON-encoded dictionary
    var responseDictionary: NineAnimatorPromise<NSDictionary> {
        self.responseJSON.then { $0 as? NSDictionary }
    }
    
    /// Create a promise that does not produce a response object
    var responseVoid: NineAnimatorPromise<Void> {
        self._makePromise { $0.response(completionHandler: $1) }
            .then { _ in () }
    }
    
    /// Create a promise that resolves into a parsed SwiftSoup.Document
    var responseBowl: NineAnimatorPromise<SwiftSoup.Document> {
        self.responseString.then {
            documentString in try SwiftSoup.parse(documentString)
        }
    }
    
    /// Add a custom response handler which will be invoked before resolving the promise.
    ///
    /// The response handler will be called regardless of whether the request was made successfully. If an error was caught to be thrown by the handler block, the error will be passed on to the promise, masking the request results.
    func onReceivingResponse(handler: @escaping ResponseHandler) -> Self {
        var copyOfSelf = self
        copyOfSelf.customResponseHandler = handler
        return copyOfSelf
    }
    
    /// Add a custom redirction handler to this request.
    ///
    /// The default behavior is to follow the requests.
    func onRedirection(handler: @escaping RedirectionHandler) -> Self {
        var copyOfSelf = self
        copyOfSelf.customRedirectionHandler = handler
        return copyOfSelf
    }
    
    /// Create a promise that resolves an encoded response
    func responseDecodable<T: Decodable>(type: T.Type, decoder: Alamofire.DataDecoder = JSONDecoder()) -> NineAnimatorPromise<T> {
        self._makePromise {
            $0.responseDecodable(of: type, decoder: decoder, completionHandler: $1)
        }
    }
    
    /// Create a promise that interprets the response data as a specific string type
    func responseString<Encoding>(interpretAs encoding: Encoding.Type) -> NineAnimatorPromise<String> where Encoding: _UnicodeEncoding, Encoding.CodeUnit == Data.Element {
        self.responseData.then {
            .init(decoding: $0, as: encoding)
        }
    }
    
    /// Create a promise that interprets the response data based on response header
    ///
    /// This used to be the default solution. However, many website seems to include non-standard characteres in responses, which seriously messes with swift's String.
    func responseString(decodeWithCharsetFromHeader: Bool) -> NineAnimatorPromise<String> {
        decodeWithCharsetFromHeader ? self._makePromise {
            $0.responseString(completionHandler: $1)
        } : self.responseString
    }
}

// MARK: - Type-erased Response Object
public extension NARequestManager {
    /// A type-erased wrapper for Alamofire's DataResponse object
    struct Response {
        public var request: URLRequest?
        public var response: HTTPURLResponse?
    }
}

// MARK: - Internal Structs & Helpers
public extension NARequestManager {
    /// Helper struct used to convert url request method parameters.
    ///
    /// Partically from https://github.com/Alamofire/Alamofire/blob/ad1ebf1/Source/Session.swift#L230
    fileprivate struct RequestConvertible: URLRequestConvertible {
        var url: URLConvertible
        var method: HTTPMethod
        var query: URLQueryParameters?
        var parameters: Parameters?
        var encoding: ParameterEncoding
        var headers: HTTPHeaders?

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            if let query = self.query {
                try query.appendTo(request: &request)
            }
            return try encoding.encode(request, with: parameters)
        }
    }
    
    private func _registerBuiltinMiddlewares() {
        // Register Cloudflare WAF validations
        self.enqueueValidation(CloudflareWAFResolver.middleware(request:response:body:))
        
        // Register CredentialManager validations
        self.enqueueValidation {
            [weak self] _, response, body in
            do {
                try self?
                    .credentialManager?
                    .credentialManager(validateResponse: response, data: body)
                return .success(())
            } catch {
                return .failure(error)
            }
        }
    }
    
    /// Apply validation middlewares to request
    fileprivate func _applyValidations(forRequest request: Alamofire.DataRequest) -> Alamofire.DataRequest {
        _validations.reduce(request) {
            request, validation in request.validate(validation)
        }
    }
    
    /// Keep a reference to an internal task
    fileprivate func retainInternalTask(_ task: NineAnimatorAsyncTask) {
        __internalTaskReferences.mutate {
            $0[ObjectIdentifier(task)] = task
        }
    }
    
    /// Release a reference to an internal task
    fileprivate func releaseInternalTask(_ task: NineAnimatorAsyncTask) {
        _ = __internalTaskReferences.mutate {
            $0.removeValue(forKey: ObjectIdentifier(task))
        }
    }
    
    /// Called when the request is created by the request builder
    fileprivate func onCreateRequest(_ requestBuilder: RequestBuilding, request: Alamofire.Request) {
        // Add custom redirection handler
        if let redirectionHandler = requestBuilder.customRedirectionHandler {
            __requestCustomRedirectionHandlers.mutate {
                list in list.append((WeakRef(request), redirectionHandler))
            }
        }
    }
    
    /// Called when the request is concluded
    fileprivate func onConcludeRequest(request: Alamofire.Request) {
        __requestCustomRedirectionHandlers.mutate {
            list in list.removeAll {
                handlerTuple in
                if let iteratingRequest = handlerTuple.0.object,
                    iteratingRequest != request {
                    return false
                }
                return true
            }
        }
    }
}

// MARK: - Redirection Handler
private class NARequestManagerRedirectHandler: Alamofire.RedirectHandler {
    weak var parent: NARequestManager?
    
    fileprivate init(parent: NARequestManager) {
        self.parent = parent
    }
    
    func task(_ task: URLSessionTask, willBeRedirectedTo request: URLRequest, for response: HTTPURLResponse, completion: @escaping (URLRequest?) -> Void) {
        guard let parent = parent else {
            return completion(nil)
        }
        
        var modifiedNewRequest = request
        
        // If the request is redirected to a http schemed url, make the
        // scheme https in order to conform to ATS.
        if modifiedNewRequest.url?.scheme == "http" {
            var urlBuilder = URLComponents(
                url: modifiedNewRequest.url!,
                resolvingAgainstBaseURL: true
            )
            urlBuilder?.scheme = "https"
            
            Log.info("Received a redirection that points to a non-secure location (%@). Modifying the scheme to https.", modifiedNewRequest.url!.absoluteString)
            modifiedNewRequest.url = urlBuilder?.url ?? modifiedNewRequest.url
        }
        
        if response.url?.path == "/cdn-cgi/l/chk_jschl" {
            return completion(nil)
        } else if let customRedirectionHandlerTuple = parent._requestCustomRedirectionHandlers.first(where: {
            handlerTuple in
            // Find matching request
            if let afRequest = handlerTuple.0.object,
                afRequest.tasks.contains(task) {
                return true
            }
            return false
        }), let afRequest = customRedirectionHandlerTuple.0.object {
            // Pass the results from the custom redirection handler
            return completion(customRedirectionHandlerTuple.1(
                afRequest,
                response,
                modifiedNewRequest
            ))
        } else { return completion(modifiedNewRequest) }
    }
}

// MARK: - Alamofire.RequestInterceptor
private class NARequestManagerRequestInterceptor: Alamofire.RequestInterceptor {
    weak var parent: NARequestManager?
    
    fileprivate init(parent: NARequestManager) {
        self.parent = parent
    }
    
    /// `Alamofire.RequestAdapter` implementation
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let parent = parent else {
            return completion(.failure(NineAnimatorError.unknownError))
        }
        
        var mutatingUrlRequest = urlRequest
        
        // Set request user-agent
        if !mutatingUrlRequest.headers.contains(where: {
            $0.name.lowercased() == "user-agent"
        }) {
            mutatingUrlRequest.headers.add(
                name: "user-agent",
                value: parent.currentIdentity
            )
        }
        
        // Set additional headers
        let additionalHeaders = parent.additionalHeaders
        mutatingUrlRequest.headers = mutatingUrlRequest.headers.reduce(into: additionalHeaders) {
            headers, value in
            headers.add(value)
        }
        
        // Call CredentialManager to authorize the request
        mutatingUrlRequest = parent
            .credentialManager?
            .credentialManager(authorizeRequest: mutatingUrlRequest) ?? mutatingUrlRequest
        
        // Run adapter chain
        let adapters = parent._internalAdapterChain.compactMap {
            $0.object as? NARequestAdapter
        }
        
        rExecuteAdapterChain(
            adapters: adapters.dropFirst(0),
            request: mutatingUrlRequest,
            for: session,
            completion: completion
        )
    }
    
    /// `Alamofire.RequestRetrier` implementation
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let parent = parent else {
            return completion(.doNotRetryWithError(NineAnimatorError.unknownError))
        }
        
        if (error as NSError).domain == NSURLErrorDomain,
            (error as NSError).code == NSURLErrorCancelled {
            return completion(.doNotRetry)
        }
        
        let retriers = parent._internalRetrierChain.compactMap {
            $0.object as? NARequestRetrier
        }
        
        rExecuteRetrierChain(
            retriers: retriers.dropFirst(0),
            request: request,
            for: session,
            dueTo: error,
            completion: completion
        )
    }
    
    private func rExecuteAdapterChain(adapters: ArraySlice<NARequestAdapter>, request urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let parent = parent else {
            return completion(.failure(NineAnimatorError.unknownError))
        }
        
        if let currentAdapter = adapters.first {
            let executingTask = currentAdapter.adapt(urlRequest, for: session).error {
                completion(.failure($0))
            }
            parent.retainInternalTask(executingTask)
            _ = executingTask.defer {
                [weak parent] in parent?.releaseInternalTask($0)
            } .finally {
                switch $0 {
                case let .evaluateNext(request: adaptedRequest):
                    self.rExecuteAdapterChain(
                        adapters: adapters.dropFirst(),
                        request: adaptedRequest,
                        for: session,
                        completion: completion
                    )
                case let .interceptEvaluation(request: adaptedRequest):
                    completion(.success(adaptedRequest))
                case let .fail(error: error):
                    completion(.failure(error ?? NineAnimatorError.unknownError))
                }
            }
        } else { completion(.success(urlRequest)) }
    }
    
    private func rExecuteRetrierChain(retriers: ArraySlice<NARequestRetrier>, request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let parent = parent else {
            return completion(.doNotRetryWithError(NineAnimatorError.unknownError))
        }
        
        if let currentRetrier = retriers.first {
            let executingTask = currentRetrier.retry(
                request,
                for: session,
                dueTo: error
            ) .error {
                completion(.doNotRetryWithError($0))
            }
            parent.retainInternalTask(executingTask)
            _ = executingTask.defer {
                [weak parent] in parent?.releaseInternalTask($0)
            } .finally {
                switch $0 {
                case let .fail(error: error):
                    if let error = error {
                        completion(.doNotRetryWithError(error))
                    } else { completion(.doNotRetry) }
                case let .retry(delay: delay):
                    completion(delay > 0 ? .retryWithDelay(delay) : .retry)
                case .evaluateNext:
                    self.rExecuteRetrierChain(
                        retriers: retriers.dropFirst(),
                        request: request,
                        for: session,
                        dueTo: error,
                        completion: completion
                    )
                }
            }
        } else {
            // Pipe the error to the internal retrier
            parent._internalRetryPolicy.retry(
                request,
                for: session,
                dueTo: error,
                completion: completion
            )
        }
    }
}

/// Tell the request manager to make the request in certain ways
public enum NARequestHandlingDirective: String {
    /// No special handling needed
    case none
    
    /// Mimic the behaviors of a browsing request
    case browsing
    
    /// Mimic the behaviors of an ajax request
    case ajax
    
    /// The default behavior of the request
    public static var `default`: NARequestHandlingDirective { .none }
}

/// The evaluation result from the request retrier
public enum NARequestRetryDirective {
    /// Evaluate the next retrier in the Source's retrier chain
    case evaluateNext
    
    /// Stop evaluating the retrier chain and retry the request after `delay` seconds
    case retry(delay: TimeInterval = 0)
    
    /// Stop evaluating the retrier chain and do not retry. An error is optionally returned.
    case fail(error: Error? = nil)
}

/// The evaluation result from the request adapter
public enum NARequestAdaptingResult {
    /// Evaluate the next adapter in the evaluation chain
    case evaluateNext(request: URLRequest)
    
    /// Initiate the request with the provided `URLRequest` object without evaluating anymore `SourceRequestAdapter` in the adater chain
    case interceptEvaluation(request: URLRequest)
    
    /// Intercept the request and fail with an error
    case fail(error: Error? = nil)
}

/// An asynchronous retrier object that wraps around Alamofire's `Request Retrier`
public protocol NARequestRetrier: AnyObject {
    /// Evaluate for the `Source` if an request should be retried
    func retry(_ request: Alamofire.Request,
               for session: Alamofire.Session,
               dueTo error: Error) -> NineAnimatorPromise<NARequestRetryDirective>
}

/// An asynchronous adapter object that wraps around Alamofire's `RequestAdapter`
public protocol NARequestAdapter: AnyObject {
    /// Asynchronously adapt an `URLRequest`
    func adapt(_ urlRequest: URLRequest, for session: Session) -> NineAnimatorPromise<NARequestAdaptingResult>
}
