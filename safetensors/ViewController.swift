//
//  ViewController.swift
//  safetensors
//
//  Created by Ken Schutte on 4/27/26.
//

import Cocoa

class ViewController: NSViewController {
    private let viewerView = SafetensorsViewerView()
    private var loadTask: Task<Void, Never>?

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
        view.window?.title = url.lastPathComponent
        loadTask = Task { [weak self] in
            safetensorsDebugLog("ViewController starting load task")
            await self?.viewerView.loadFile(at: url)
        }
    }

    @IBAction func selectNone(_ sender: Any?) {
        viewerView.selectNone()
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
