//
//  PreviewViewController.swift
//  safetensors_quicklook
//
//  Created by Ken Schutte on 4/27/26.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    
    private let viewerView = SafetensorsViewerView()

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
        safetensorsDebugLog("QuickLook loadView")
        configureViewerView()
        viewerView.showLoading()
    }

    /*
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?) async throws {
        // Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.

        // Perform any setup necessary in order to prepare the view.
        // Quick Look will display a loading spinner until this returns.
    }
    */

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        safetensorsDebugLog("QuickLook preparePreviewOfFile: \(url.path)")

        Task { [viewerView] in
            await viewerView.loadFile(at: url)
            safetensorsDebugLog("QuickLook preparePreviewOfFile completed")
            handler(nil)
        }
    }

    private func configureViewerView() {
        viewerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewerView)

        NSLayoutConstraint.activate([
            viewerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewerView.topAnchor.constraint(equalTo: view.topAnchor),
            viewerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
