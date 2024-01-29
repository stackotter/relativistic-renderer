import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    static let defaultCSS = """
        html {
            font-family: sans-serif;
        }
        
        h1 {
            margin-bottom: 0.5rem;
        }
        
        button, input {
            display: block;
            margin-bottom: 0.5rem;
        }
        """

    let url: URL
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.injectCSS(Self.defaultCSS)
        let webView = context.coordinator.webView
        webView.contentMode = .scaleAspectFit
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    let webView: WKWebView

    override init() {
        webView = WKWebView()
        super.init()
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url: URL = webView.url else {
            return
        }

        print(url)
    }
    
    func injectCSS(_ css: String) {
        let cssBase64 = css.data(using: .utf8)!.base64EncodedString()
        let cssInjectionScript = """
            var parent = document.getElementsByTagName('head').item(0);
            var style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = window.atob('\(cssBase64)');
            parent.appendChild(style)
            """
        
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: cssInjectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
    }
}
