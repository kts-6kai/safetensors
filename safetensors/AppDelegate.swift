//
//  AppDelegate.swift
//  safetensors
//
//  Created by Ken Schutte on 4/27/26.
//

import Cocoa
import UniformTypeIdentifiers

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: SettingsWindowController?
    private var helpWindowController: HelpWindowController?
    private var viewerWindowControllers: [NSWindowController] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        safetensorsDebugLog("AppDelegate applicationDidFinishLaunching")
        UserDefaults.standard.register(defaults: SafetensorsSettings.defaults)
        _ = viewerController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        safetensorsDebugLog("AppDelegate open urls: \(urls.map(\.path).joined(separator: ", "))")
        application.activate(ignoringOtherApps: true)
        urls.forEach(openFileInViewerWindow)
    }

    @IBAction func openDocument(_ sender: Any?) {
        safetensorsDebugLog("AppDelegate openDocument")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType("io.util.safetensors.file") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            safetensorsDebugLog("AppDelegate openDocument selected: \(url.path)")
            openFileInViewerWindow(url)
        }
    }

    @IBAction func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func showHelp(_ sender: Any?) {
        if helpWindowController == nil {
            helpWindowController = HelpWindowController()
        }

        helpWindowController?.showWindow(sender)
        helpWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func viewerController() -> ViewController? {
        if let viewController = viewerControllers.first {
            safetensorsDebugLog("AppDelegate using existing viewerController")
            return viewController
        }

        return createViewerController()
    }

    private func openFileInViewerWindow(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        viewerControllerForOpeningFile()?.displayFile(at: url)
    }

    private func viewerControllerForOpeningFile() -> ViewController? {
        if let emptyViewerController = viewerControllers.first(where: { !$0.hasDisplayedFile }) {
            safetensorsDebugLog("AppDelegate using empty viewerController")
            return emptyViewerController
        }

        return createViewerController()
    }

    private var viewerControllers: [ViewController] {
        NSApp.windows.compactMap { $0.contentViewController as? ViewController }
    }

    private func createViewerController() -> ViewController? {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let windowController = storyboard.instantiateInitialController() as? NSWindowController else {
            safetensorsDebugLog("AppDelegate failed to instantiate initial window controller")
            return nil
        }

        trackViewerWindowController(windowController)
        windowController.showWindow(nil)
        safetensorsDebugLog("AppDelegate created viewerController from storyboard")
        return windowController.contentViewController as? ViewController
    }

    private func trackViewerWindowController(_ windowController: NSWindowController) {
        guard !viewerWindowControllers.contains(where: { $0 === windowController }) else {
            return
        }

        viewerWindowControllers.append(windowController)

        if let window = windowController.window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(viewerWindowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }

    @objc private func viewerWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        viewerWindowControllers.removeAll { $0.window === window }
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
}
