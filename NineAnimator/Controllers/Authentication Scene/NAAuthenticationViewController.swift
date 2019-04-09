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

class NAAuthenticationViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, Themable {
    @IBOutlet private weak var webView: WKWebView!
    @IBOutlet private weak var loadingProgressIndicator: UIProgressView!
    @IBOutlet private weak var tipContainerView: UIVisualEffectView!
    @IBOutlet private weak var tipLabel: UILabel!
    
    private var originalRequest: URLRequest?
    private var userAgent: String?
    private var onDismissal: (() -> Void)?
    private var loadingProgressObserver: NSKeyValueObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assign delegates
        webView.navigationDelegate = self
        webView.uiDelegate = self
        loadingProgressObserver = webView.observe(\.estimatedProgress) {
            [weak self] _, _ in
            DispatchQueue.main.async { self?.updateProgressIndicator() }
        }
        
        // Cookie changes
        let store = webView.configuration.websiteDataStore
        store.httpCookieStore.add(self)
        
        // Copy cookies
        HTTPCookieStorage.shared.cookies?.forEach {
            store.httpCookieStore.setCookie($0, completionHandler: nil)
        }
        
        // Make themable
        Theme.provision(self)
    }
    
    func theme(didUpdate theme: Theme) {
        loadingProgressIndicator.trackTintColor = theme.secondaryBackground
        loadingProgressIndicator.progressTintColor = theme.tint
        tipLabel.textColor = theme.primaryText
        tipContainerView.effect = UIBlurEffect(style: theme.blurStyle)
    }
    
    @IBAction private func onDismissal(_ sender: Any) {
        let store = webView.configuration.websiteDataStore
        store.httpCookieStore.getAllCookies {
            [weak self] cookies in
            let sharedCookieStore = HTTPCookieStorage.shared
            sharedCookieStore.removeCookies(since: .distantPast)
            cookies.forEach { sharedCookieStore.setCookie($0) }
            
            // Dismiss the view controller
            DispatchQueue.main.async {
                self?.dismiss(animated: true, completion: self?.onDismissal)
            }
        }
    }
    
    @IBAction private func onReloadButtonTapped(_ sender: Any) {
        self.webView.reloadFromOrigin()
    }
    
    private func updateProgressIndicator() {
        let progress = self.webView.estimatedProgress
        self.loadingProgressIndicator.setProgress(Float(progress), animated: true)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        title = "Loading..."
        loadingProgressIndicator.isHidden = false
        loadingProgressIndicator.progress = 0
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        title = webView.url?.absoluteString ?? "Complete Authentication"
        loadingProgressIndicator.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let request = originalRequest else { return }
        webView.customUserAgent = userAgent
        webView.load(request)
        
        tipContainerView.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 1,
            options: [ .curveEaseInOut ],
            animations: { self.tipContainerView.alpha = 1.0 },
            completion: nil
        )
    }
    
    @IBAction private func onTipContainerTapped(_ sender: Any) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [ .curveEaseInOut ],
            animations: { self.tipContainerView.alpha = 0.0 },
            completion: nil
        )
    }
    
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
//        cookieStore.getAllCookies {
//            cookies in cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
//        }
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
