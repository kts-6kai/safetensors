//
//  HelpWindowController.swift
//  safetensors
//
//  Created by OpenAI on 5/2/26.
//

import Cocoa
import WebKit

final class HelpWindowController: NSWindowController, WKNavigationDelegate {
    private let webView = WKWebView(frame: .zero)

    convenience init() {
        let viewController = NSViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "safetensors Help"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 760, height: 560))
        window.center()

        self.init(window: window)
        configureContent(in: viewController.view)
        loadHelpPage()
    }

    private func configureContent(in view: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadHelpPage() {
        guard let helpURL = Bundle.main.url(forResource: "help", withExtension: "html") else {
            showMissingHelpAlert()
            return
        }

        webView.loadFileURL(helpURL, allowingReadAccessTo: helpURL.deletingLastPathComponent())
    }

    private func showMissingHelpAlert() {
        let alert = NSAlert()
        alert.messageText = "Help Not Found"
        alert.informativeText = "The bundled help.html file could not be found."
        alert.alertStyle = .warning
        alert.runModal()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        safetensorsDebugLog("Help web content process terminated")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        safetensorsDebugLog("Help failed to load: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        safetensorsDebugLog("Help failed provisional load: \(error.localizedDescription)")
    }
}
