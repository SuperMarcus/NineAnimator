//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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
import WebKit

class NAAuthenticationViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    @IBOutlet private weak var webView: WKWebView!
    
    private var originalRequest: URLRequest?
    private var userAgent: String?
    private var onDismissal: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assign delegates
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Cookie changes
        let store = webView.configuration.websiteDataStore
        store.httpCookieStore.add(self)
    }
    
    @IBAction private func onDismissal(_ sender: Any) {
        self.dismiss(animated: true, completion: self.onDismissal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let request = originalRequest,
            let userAgent = userAgent else { return }
        webView.customUserAgent = userAgent
        webView.load(request)
    }
    
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies {
            cookies in cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
        }
    }
    
    private func initialize(_ request: URLRequest, withUserAgent userAgent: String?, onDismissal callback: @escaping () -> Void) {
        self.originalRequest = request
        self.userAgent = userAgent
        self.onDismissal = callback
    }
    
    class func create(_ url: URL, withUserAgent userAgent: String?, onDismissal callback: @escaping () -> Void) -> UIViewController {
        let rootViewController = UIStoryboard(
            name: "SelflessAuthenticationWebViewController",
            bundle: Bundle.main
        ) .instantiateInitialViewController() as! UINavigationController
        let viewController = rootViewController.topViewController as! NAAuthenticationViewController
        let request = URLRequest(url: url)
        viewController.initialize(
            request,
            withUserAgent: userAgent,
            onDismissal: callback
        )
        return rootViewController
    }
    
    class func create(from error: Error, onDismissal callback: @escaping () -> Void) -> UIViewController? {
        guard let error = error as? NineAnimatorError.AuthenticationRequiredError,
            let authenticationUrl = error.authenticationUrl else { return nil }
        
        // Retrieve the recommended user agent string
        let preferredUserAgent: String?
        if let source = error.sourceOfError as? BaseSource {
            preferredUserAgent = source.sessionUserAgent
        } else { preferredUserAgent = nil }
        
        // Create the view controller
        let viewController = create(authenticationUrl, withUserAgent: preferredUserAgent, onDismissal: callback)
        return viewController
    }
}
