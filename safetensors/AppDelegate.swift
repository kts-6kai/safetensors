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
        guard let url = urls.first else {
            return
        }

        application.activate(ignoringOtherApps: true)
        viewerController()?.displayFile(at: url)
    }

    @IBAction func openDocument(_ sender: Any?) {
        safetensorsDebugLog("AppDelegate openDocument")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType("io.util.safetensors.file") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            safetensorsDebugLog("AppDelegate openDocument selected: \(url.path)")
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            viewerController()?.displayFile(at: url)
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
        if let viewController = NSApp.windows.first?.contentViewController as? ViewController {
            safetensorsDebugLog("AppDelegate using existing viewerController")
            return viewController
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let windowController = storyboard.instantiateInitialController() as? NSWindowController else {
            safetensorsDebugLog("AppDelegate failed to instantiate initial window controller")
            return nil
        }

        windowController.showWindow(nil)
        safetensorsDebugLog("AppDelegate created viewerController from storyboard")
        return windowController.contentViewController as? ViewController
    }
}
