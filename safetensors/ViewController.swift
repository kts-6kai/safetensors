//
//  ViewController.swift
//  safetensors
//
//  Created by Ken Schutte on 4/27/26.
//

import Cocoa

class ViewController: NSViewController, NSMenuItemValidation {
    private let viewerView = SafetensorsViewerView()
    private var loadTask: Task<Void, Never>?
    private(set) var displayedFileURL: URL?

    var hasDisplayedFile: Bool {
        displayedFileURL != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        safetensorsDebugLog("ViewController viewDidLoad")
        title = "safetensors"
        configureViewerView()
        viewerView.showPlaceholder()
    }

    func displayFile(at url: URL) {
        safetensorsDebugLog("ViewController displayFile: \(url.path)")
        loadTask?.cancel()
        displayedFileURL = url
        view.window?.title = url.lastPathComponent
        loadTask = Task { [weak self] in
            safetensorsDebugLog("ViewController starting load task")
            await self?.viewerView.loadFile(at: url)
        }
    }

    @IBAction func selectNone(_ sender: Any?) {
        viewerView.selectNone()
    }

    @IBAction func exportAllToNPZ(_ sender: Any?) {
        viewerView.exportAllToNPZ()
    }

    @IBAction func exportSelectionToNPZ(_ sender: Any?) {
        viewerView.exportSelectionToNPZ()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(exportAllToNPZ(_:)):
            return viewerView.hasLoadedFile
        case #selector(exportSelectionToNPZ(_:)):
            return viewerView.hasLoadedFile && viewerView.hasSelection
        default:
            return true
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
