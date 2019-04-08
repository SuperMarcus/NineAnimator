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

class NAAuthenticationViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    @IBOutlet private weak var webView: WKWebView!
    
    private var originalRequest: URLRequest?
    private var userAgent: String?
    private var onDismissal: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assign delegates
        webView.navigationDelegate = self
        webView.uiDelegate = self
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
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
            let url = response.url,
            let responseHeaders = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: responseHeaders, for: url)
            HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
        }
        decisionHandler(.allow)
    }
    
    private func initialize(_ request: URLRequest, withUserAgent userAgent: String, onDismissal callback: @escaping () -> Void) {
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
            withUserAgent: userAgent ?? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36",
            onDismissal: callback
        )
        return rootViewController
    }
}
