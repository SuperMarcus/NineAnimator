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

/// The evaluation result from the request retrier
enum SourceRequestRetryDirective {
    /// Evaluate the next retrier in the Source's retrier chain
    case evaluateNext
    
    /// Stop evaluating the retrier chain and retry the request after `delay` seconds
    case retry(delay: TimeInterval = 0)
    
    /// Stop evaluating the retrier chain and do not retry. An error is optionally returned.
    case fail(error: Error? = nil)
}

/// The evaluation result from the request adapter
enum SourceRequestAdaptingResult {
    /// Evaluate the next adapter in the evaluation chain
    case evaluateNext(request: URLRequest)
    
    /// Initiate the request with the provided `URLRequest` object without evaluating anymore `SourceRequestAdapter` in the adater chain
    case interceptEvaluation(request: URLRequest)
    
    /// Intercept the request and fail with an error
    case fail(error: Error? = nil)
}

/// An asynchronous retrier object that wraps around Alamofire's `Request Retrier`
protocol SourceRequestRetrier: AnyObject {
    /// Evaluate for the `Source` if an request should be retried
    func retry(_ request: Alamofire.Request,
               for session: Alamofire.Session,
               dueTo error: Error) -> NineAnimatorPromise<SourceRequestRetryDirective>
}

/// An asynchronous adapter object that wraps around Alamofire's `RequestAdapter`
protocol SourceRequestAdapter: AnyObject {
    /// Asynchronously adapt an `URLRequest`
    func adapt(_ urlRequest: URLRequest, for session: Session) -> NineAnimatorPromise<SourceRequestAdaptingResult>
}

// MARK: Adding Adapter & Retrier
extension BaseSource {
    /// Add a `SourceRequestAdapter` to the end of the adapter chain
    func enqueueAdapter(_ adapter: SourceRequestAdapter) {
        _internalAdapterChain.append(.init(adapter))
    }
    
    /// Add a `SourceRequestRetrier` to the end of the retrier chain
    func enqueueRetrier(_ retrier: SourceRequestRetrier) {
        _internalRetrierChain.append(.init(retrier))
    }
}

// MARK: - RequestInterceptor
extension BaseSource: Alamofire.RequestInterceptor {
    /// `Alamofire.RequestAdapter` implementation
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let adapters = _internalAdapterChain.compactMap {
            $0.object as? SourceRequestAdapter
        }
        
        rExecuteAdapterChain(
            adapters: adapters.dropFirst(0),
            request: urlRequest,
            for: session,
            completion: completion
        )
    }
    
    /// `Alamofire.RequestRetrier` implementation
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if (error as NSError).domain == NSURLErrorDomain,
            (error as NSError).code == NSURLErrorCancelled {
            return completion(.doNotRetry)
        }
        
        let retriers = _internalRetrierChain.compactMap {
            $0.object as? SourceRequestRetrier
        }
        
        rExecuteRetrierChain(
            retriers: retriers.dropFirst(0),
            request: request,
            for: session,
            dueTo: error,
            completion: completion
        )
    }
}

// MARK: - RedirectHandler
extension BaseSource: Alamofire.RedirectHandler {
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void) {
        var modifiedNewRequest = request
        
        // If the request is redirected to a http schemed url, make the
        // scheme https in order to conform to ATS.
        if modifiedNewRequest.url?.scheme == "http" {
            var urlBuilder = URLComponents(
                url: modifiedNewRequest.url!,
                resolvingAgainstBaseURL: true
            )
            urlBuilder?.scheme = "https"
            
            Log.info("[BaseSource] Received a redirection that points to a non-secure location (%@). Modifying the scheme to https.", modifiedNewRequest.url!.absoluteString)
            modifiedNewRequest.url = urlBuilder?.url ?? modifiedNewRequest.url
        }
        
        if response.url?.path == "/cdn-cgi/l/chk_jschl" {
            return completion(nil)
        } else { return completion(modifiedNewRequest) }
    }
}

// MARK: - Interceptor Chain Execution
private extension BaseSource {
    private func rExecuteAdapterChain(adapters: ArraySlice<SourceRequestAdapter>, request urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if let currentAdapter = adapters.first {
            let executingTask = currentAdapter.adapt(urlRequest, for: session).error {
                completion(.failure($0))
            }
            retainInternalTask(executingTask)
            _ = executingTask.defer {
                self.releaseInternalTask($0)
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
    
    private func rExecuteRetrierChain(retriers: ArraySlice<SourceRequestRetrier>, request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if let currentRetrier = retriers.first {
            let executingTask = currentRetrier.retry(
                request,
                for: session,
                dueTo: error
            ) .error {
                completion(.doNotRetryWithError($0))
            }
            retainInternalTask(executingTask)
            _ = executingTask.defer {
                self.releaseInternalTask($0)
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
            _internalRetryPolicy.retry(
                request,
                for: session,
                dueTo: error,
                completion: completion
            )
        }
    }
}
