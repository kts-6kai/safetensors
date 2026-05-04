//
//  SettingsWindowController.swift
//  safetensors
//
//  Created by OpenAI on 4/28/26.
//

import Cocoa

final class SettingsWindowController: NSWindowController {
    
    private let autoMakeNestedCheckbox = NSButton(
        checkboxWithTitle: "Auto make nested with dots",
        target: nil, action: nil)
    private let openMostRecentFileOnStartupCheckbox = NSButton(
        checkboxWithTitle: "Open most recent file on startup",
        target: nil, action: nil)

    convenience init() {
        let viewController = NSViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 360, height: 150))
        window.center()

        self.init(window: window)
        configureContent(in: viewController.view)
    }

    private func configureContent(in view: NSView) {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        autoMakeNestedCheckbox.state = UserDefaults.standard.bool(forKey: SafetensorsSettings.autoMakeNestedKey) ? .on : .off
        autoMakeNestedCheckbox.target = self
        autoMakeNestedCheckbox.action = #selector(autoMakeNestedChanged)

        openMostRecentFileOnStartupCheckbox.state = UserDefaults.standard.bool(forKey: SafetensorsSettings.openMostRecentFileOnStartupKey) ? .on : .off
        openMostRecentFileOnStartupCheckbox.target = self
        openMostRecentFileOnStartupCheckbox.action = #selector(openMostRecentFileOnStartupChanged)

        stack.addArrangedSubview(autoMakeNestedCheckbox)
        stack.addArrangedSubview(openMostRecentFileOnStartupCheckbox)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])
    }

    @objc private func autoMakeNestedChanged() {
        UserDefaults.standard.set(autoMakeNestedCheckbox.state == .on, forKey: SafetensorsSettings.autoMakeNestedKey)
    }

    @objc private func openMostRecentFileOnStartupChanged() {
        UserDefaults.standard.set(
            openMostRecentFileOnStartupCheckbox.state == .on,
            forKey: SafetensorsSettings.openMostRecentFileOnStartupKey
        )
    }
}
