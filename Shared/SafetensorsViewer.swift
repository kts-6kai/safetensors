//
//  SafetensorsViewer.swift
//  safetensors
//
//  Shared by the app and QuickLook extension.
//

import Cocoa

enum SafetensorsDebug {

    nonisolated(unsafe)
    static var loggingEnabled = true

    nonisolated(unsafe)
    static var artificialLoadDelayNanoseconds: UInt64 = 1_000_000_000
//    static var artificialLoadDelayNanoseconds: UInt64 = 0

    nonisolated(unsafe)
    static var parserErrorMessage: String? = nil
//    static var parserErrorMessage: String? = "Failed to parse."
}

nonisolated func safetensorsDebugLog(_ message: String) {
    guard SafetensorsDebug.loggingEnabled else {
        return
    }

    NSLog("[SafetensorsViewer] %@", message)
}

struct SafetensorsSettings {
    static let autoMakeNestedKey = "autoMakeNested"
    static let defaults: [String: Any] = [
        autoMakeNestedKey: true
    ]
}

private struct SafetensorsViewerSnapshot {
    let fileSize: String
    let headerSize: UInt64
    let tensorRows: [SafetensorsViewerView.TensorRow]
}

@MainActor
final class ToastView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setMessage(_ message: String) {
        label.stringValue = message
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.cornerRadius = 8
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        alphaValue = 0
        isHidden = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }
}

@MainActor
final class SafetensorsViewerView: NSView {
    private struct SummaryItem {
        let label: String
        let value: String
    }

    /*
     STTensor stores what is in the .safetensors file.
     This adds some more fields.
     */
    fileprivate struct TensorRow {
        let name:   String
        let dtype:  String
        let shape:  [Int]
        
        let params: Int //== prod(shape)
        let bytes : Int //== params * bytesPerValue

        //
        //let offset: String
    }
    /*
     
     */

    private let sidebarWidth: CGFloat = 220
    private let toolbar = NSStackView()
    private let toggleSidebarButton = NSButton()
    private let contentStack = NSStackView()
    private let sidebarView = NSView()
    private let summaryStack = NSStackView()
    private let mainContentView = NSView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let errorView = NSView()
    private let errorMessageLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let toastView = ToastView()

    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var isSidebarVisible = true
    private var isLoading = false
    private var parserErrorMessage: String?
    private var summaryItems: [SummaryItem] = []
    private var detailsWindowController: NSWindowController?
    private var toastTask: Task<Void, Never>?
    
    /*
     should we store tensors[] here or have some
     kind of datasource?
     */
    private var tensorRows: [TensorRow] = []
//    private var tensors: [STTensor] = []
    
    var loadedSTFile:STFile? = nil

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
        showPlaceholder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
        showPlaceholder()
    }

    func showPlaceholder() {
        parserErrorMessage = nil
        summaryItems = [
            SummaryItem(label: "File size", value: "-"),
            SummaryItem(label: "Header size", value: "-"),
            SummaryItem(label: "Tensor count", value: "-"),
            SummaryItem(label: "Metadata", value: "-")
        ]
        tensorRows = [] //Self.placeholderRows
        reloadContent()
    }

    func showLoading() {
        isLoading = true
        parserErrorMessage = nil
        summaryItems = [
            SummaryItem(label: "File size", value: "Loading"),
            SummaryItem(label: "Header size", value: "Loading"),
            SummaryItem(label: "Tensor count", value: "Loading"),
            SummaryItem(label: "Metadata", value: "Loading")
        ]
        tensorRows = [] //Self.placeholderRows
        reloadContent()
    }

    func loadFile(at url: URL) async {
        safetensorsDebugLog("loadFile started: \(url.path)")
        showLoading()
        
        if let stfile = STFile(path:url.path) {

            //?
/*
            guard !Task.isCancelled else {
                safetensorsDebugLog("loadFile cancelled after loader returned")
                return
            }
*/
            

            self.loadedSTFile = stfile
            
            safetensorsDebugLog("STFile init success")
            
            showSTFile(stfile)
            
        }
        else {
            safetensorsDebugLog("STFile fail")
            showError(string:"Read Fail")
        }

        /*
        do {
            let snapshot = try await SafetensorsFileLoader.load(url: url)
            guard !Task.isCancelled else {
                safetensorsDebugLog("loadFile cancelled after loader returned")
                return
            }
            safetensorsDebugLog("loadFile succeeded with \(snapshot.tensorRows.count) tensor rows")
            showSnapshot(snapshot)
            
        } catch is CancellationError {
            safetensorsDebugLog("loadFile cancelled")
            return
            
        } catch {
            safetensorsDebugLog("loadFile caught error: \(error.localizedDescription)")
            showError(error)
        }
         */
        
    }

    private func showSnapshot(_ snapshot: SafetensorsViewerSnapshot) {
        isLoading = false
        parserErrorMessage = nil
        summaryItems = [
            SummaryItem(label: "File size", value: snapshot.fileSize),
            SummaryItem(label: "Header size", value: "\(snapshot.headerSize)"),
            SummaryItem(label: "Tensor count", value: "\(snapshot.tensorRows.count)"),
            SummaryItem(label: "Auto make nested", value: UserDefaults.standard.bool(forKey: SafetensorsSettings.autoMakeNestedKey) ? "On" : "Off")
        ]
        tensorRows = snapshot.tensorRows
        reloadContent()
    }
    
    /*
     newer version using STFile
     */
    private func showSTFile(_ stfile:STFile) {
        isLoading = false
        parserErrorMessage = nil
        summaryItems = [
            SummaryItem(label: "File size", value: "?"),
            SummaryItem(label: "Header size", value: "\(stfile.headerSize)"),
            SummaryItem(label: "Tensor count", value: "\(stfile.tensors.count)"),
            
            //?
            //SummaryItem(label: "Auto make nested", value: UserDefaults.standard.bool(forKey: SafetensorsSettings.autoMakeNestedKey) ? "On" : "Off")
        ]
        
        //tensorRows = snapshot.tensorRows
        tensorRows = stfile.tensors.map {
            
            let params = $0.shape.product()
            
            /*
             temp
             */
            let bytesPerValue:Int
            switch $0.dtype {
            case "I32": bytesPerValue = 4
            case "F64": bytesPerValue = 8
            default:
                //temp:
                bytesPerValue = 1
            }
            
            return TensorRow(
                name:   $0.name,
                dtype:  $0.dtype,
                shape:  $0.shape,
                params: params,
                bytes : params * bytesPerValue
            )
            
        }
        

        
        reloadContent()
    }

    func showError(_ error: Error) {
        showError(string:error.localizedDescription)
    }
    
    func showError(string:String) {
        safetensorsDebugLog("showError: \(string)")
        isLoading = false
        parserErrorMessage = string
        summaryItems = [
            SummaryItem(label: "File size", value: "-"),
            SummaryItem(label: "Header size", value: "-"),
            SummaryItem(label: "Tensor count", value: "-"),
            SummaryItem(label: "Error", value: string)
        ]
        tensorRows = []
        reloadContent()
    }


    private func configure() {
        configureToolbar()
        configureSidebar()
        configureTable()
        configureErrorView()
        configureProgressIndicator()
        configureToast()
        configureLayout()
    }

    private func configureToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        toggleSidebarButton.title = "Sidebar"
        toggleSidebarButton.bezelStyle = .rounded
        toggleSidebarButton.target = self
        toggleSidebarButton.action = #selector(toggleSidebar)

        toolbar.addArrangedSubview(toggleSidebarButton)
        toolbar.addArrangedSubview(NSView())
    }

    private func configureSidebar() {
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.wantsLayer = true
        sidebarView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryStack.orientation = .vertical
        summaryStack.alignment = .leading
        summaryStack.spacing = 14
        summaryStack.edgeInsets = NSEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        sidebarView.addSubview(summaryStack)

        NSLayoutConstraint.activate([
            summaryStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            summaryStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            summaryStack.topAnchor.constraint(equalTo: sidebarView.topAnchor)
        ])
    }

    private func configureTable() {
        tableView.delegate = self
        tableView.dataSource = self

        tableView.usesAlternatingRowBackgroundColors = true
        
        tableView.allowsMultipleSelection = true
        
        tableView.headerView = NSTableHeaderView()
        tableView.menu = makeTableMenu()

        //
        addColumn(identifier: "name",   title: "name",   width: 280)
        addColumn(identifier: "dtype",  title: "dtype",  width: 80)
        addColumn(identifier: "shape",  title: "shape",  width: 160)
        addColumn(identifier: "params", title: "params", width: 80)
        addColumn(identifier: "bytes",  title: "bytes",  width: 80)

//        addColumn(identifier: "offset", title: "offset", width: 120)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
    }

    private func configureErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10

        let title = NSTextField(labelWithString: "Unable to parse file")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.alignment = .center

        errorMessageLabel.font = .systemFont(ofSize: 13)
        errorMessageLabel.textColor = .secondaryLabelColor
        errorMessageLabel.alignment = .center
        errorMessageLabel.lineBreakMode = .byWordWrapping
        errorMessageLabel.maximumNumberOfLines = 0

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(errorMessageLabel)
        errorView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -32),
            errorMessageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 520)
        ])
    }

    private func configureProgressIndicator() {
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .large
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.isHidden = true
    }

    private func configureToast() {
        toastView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureLayout() {
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = 0

        addSubview(toolbar)
        addSubview(contentStack)
        addSubview(progressIndicator)
        addSubview(toastView)
        contentStack.addArrangedSubview(sidebarView)
        contentStack.addArrangedSubview(mainContentView)
        mainContentView.addSubview(scrollView)
        mainContentView.addSubview(errorView)

        sidebarWidthConstraint = sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth)
        sidebarWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            sidebarView.heightAnchor.constraint(equalTo: contentStack.heightAnchor),
            mainContentView.heightAnchor.constraint(equalTo: contentStack.heightAnchor),

            scrollView.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            errorView.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            progressIndicator.centerXAnchor.constraint(equalTo: mainContentView.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: mainContentView.centerYAnchor),

            toastView.centerXAnchor.constraint(equalTo: centerXAnchor),
            toastView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 12),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    private func addColumn(identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    /*
     check for single or multiple selection???
     */
    private func makeTableMenu() -> NSMenu {
        let menu = NSMenu()

        let copyNameItem = NSMenuItem(
            title: "Copy name",
            action: #selector(copyTensorName),
            keyEquivalent: "")
        copyNameItem.target = self
        menu.addItem(copyNameItem)
        
        
        let item1 = NSMenuItem(
            title: "Copy data as JSON",
            action: #selector(copyDataAsJSON),
            keyEquivalent: "")
        item1.target = self
        menu.addItem(item1)
        

        let detailsItem = NSMenuItem(
            title: "Details...",
            action: #selector(showTensorDetails),
            keyEquivalent: "")
        
        detailsItem.target = self
        menu.addItem(detailsItem)

        return menu
    }

    private func reloadContent() {
        rebuildSummary()
        tableView.reloadData()
        updateErrorView()
        updateProgressIndicator()
    }

    private func updateErrorView() {
        if let parserErrorMessage {
            safetensorsDebugLog("updateErrorView showing error: \(parserErrorMessage)")
            errorMessageLabel.stringValue = parserErrorMessage
            errorView.isHidden = false
            scrollView.isHidden = true
        } else {
            safetensorsDebugLog("updateErrorView hiding error view")
            errorMessageLabel.stringValue = ""
            errorView.isHidden = true
            scrollView.isHidden = false
        }
    }

    private func updateProgressIndicator() {
        progressIndicator.isHidden = !isLoading
        if isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }

    private func rebuildSummary() {
        summaryStack.arrangedSubviews.forEach { view in
            summaryStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for item in summaryItems {
            let group = NSStackView()
            group.orientation = .vertical
            group.alignment = .leading
            group.spacing = 3

            let label = NSTextField(labelWithString: item.label)
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabelColor

            let value = NSTextField(labelWithString: item.value)
            value.font = .systemFont(ofSize: 13, weight: .regular)
            value.lineBreakMode = .byTruncatingTail
            value.maximumNumberOfLines = 2

            group.addArrangedSubview(label)
            group.addArrangedSubview(value)
            summaryStack.addArrangedSubview(group)
        }
    }

    @objc private func toggleSidebar() {
        isSidebarVisible.toggle()
        sidebarView.isHidden = !isSidebarVisible
        sidebarWidthConstraint?.constant = isSidebarVisible ? sidebarWidth : 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            layoutSubtreeIfNeeded()
        }
    }

//    func tensorAtRow(_ row:Int) -> STTensor? {
//        return tensors[safe:row]
//  }

    func tensorForMenu() -> STTensor? {
        guard let stfile = loadedSTFile else {return nil}
        return stfile.tensors[safe:tableView.clickedRow]
    }

    @objc private func copyDataAsJSON() {
        guard let tensor = tensorForMenu() else {return}
        
        guard let stfile = loadedSTFile else {return}

        
        if let jsonString = stfile.readArrayAsJSON(tensor: tensor) {
            
            let n = jsonString.count
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType:.string)
            showToast("Copied data (length \(n))")

        }
        else {
            //more info?
            showToast("Failed body as JSON")
        }

    }
    
    @objc private func copyTensorName() {
        guard let tensor = tensorForMenu() else {return}
        
        let n = tensor.name.count
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tensor.name, forType:.string)
        showToast("Copied name [length \(n)]")
    }

    @objc private func showTensorDetails() {
        guard let tensor = tensorForMenu() else {return}

//        let tensor = tensorRows[row]
        let viewController = NSViewController()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        let title = NSTextField(labelWithString: tensor.name)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        title.maximumNumberOfLines = 1

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(NSTextField(labelWithString: "mean: 0.0"))
        stack.addArrangedSubview(NSTextField(labelWithString: "min: 0.0"))
        stack.addArrangedSubview(NSTextField(labelWithString: "max: 00"))
        viewController.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: viewController.view.bottomAnchor)
        ])

        let window = NSPanel(contentViewController: viewController)
        window.title = "Tensor Details"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 320, height: 150))
        window.center()

        detailsWindowController = NSWindowController(window: window)
        detailsWindowController?.showWindow(nil)
        detailsWindowController?.window?.makeKeyAndOrderFront(nil)

    }

    /*
    private func menuTargetRow() -> Int? {
        let clickedRow = tableView.clickedRow
        
        print("clickedRow? \(clickedRow)")
        
        /*
        if tensorRows.indices.contains(clickedRow) {
            return clickedRow
        }

        let selectedRow = tableView.selectedRow
        if tensorRows.indices.contains(selectedRow) {
            return selectedRow
        }
*/
        return nil
    }
*/
    
    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastView.setMessage(message)
        toastView.isHidden = false
        toastView.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            toastView.animator().alphaValue = 1
        }

        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled else {
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                self.toastView.animator().alphaValue = 0
            } completionHandler: {
                self.toastView.isHidden = true
            }
        }
    }

    /*
    private static let placeholderRows = [
        /*
        TensorRow(name: "tensor_a.weight", dtype: "F32", shape: "[1024, 1024]", offset: "0"),
        TensorRow(name: "tensor_b.bias", dtype: "F16", shape: "[1024]", offset: "4194304"),
        TensorRow(name: "tensor_c.scale", dtype: "I32", shape: "[256]", offset: "4196352")
         */
    ]
     */
}

extension SafetensorsViewerView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tensorRows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // tensors[safe:row] vs tensors.indices.contains(row)
        
        guard let tensorRow = tensorRows[safe:row] else {return nil}
        
        guard let column = tableColumn else {return nil}
        
        let t:String
        switch column.identifier.rawValue {

        case "name":  t = tensorRow.name
        case "dtype": t = tensorRow.dtype
        case "shape":
            t = shapeString(tensorRow.shape)
        case "params":
            t = String(tensorRow.params)
            
        case "bytes":
            t = String(tensorRow.bytes)

        default:
            t = "?"
        }

        /*
         init each time?
         */

        //let textField = NSTextField(labelWithString: value(for: tableColumn.identifier.rawValue, in: tensorRows[row]))
        let textField = NSTextField(labelWithString: t)

        textField.lineBreakMode = .byTruncatingMiddle
        textField.maximumNumberOfLines = 1
        textField.font = .systemFont(ofSize: 12)
        return textField
    }

    /*
    private func value(for column: String, in row: TensorRow) -> String {
        switch column {
        case "name":
            return row.name
        case "dtype":
            return row.dtype
        case "shape":
            return row.shape
        case "offset":
            return row.offset
        default:
            return ""
        }
    }
     */
}

enum SafetensorsHeaderReader {
    nonisolated static func readFirstUInt64LittleEndian(from url: URL) throws -> UInt64 {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 8 else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "File is shorter than 8 bytes."
            ])
        }

        return data.prefix(8).enumerated().reduce(UInt64(0)) { value, byte in
            value | (UInt64(byte.element) << UInt64(byte.offset * 8))
        }
    }

    nonisolated static func fileSizeDescription(for url: URL) throws -> String {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resourceValues.fileSize else {
            return "-"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

private struct SafetensorsParserError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private enum SafetensorsFileLoader {
    static func load(url: URL) async throws -> SafetensorsViewerSnapshot {
        
        
        let artificialLoadDelayNanoseconds = SafetensorsDebug.artificialLoadDelayNanoseconds
        let parserErrorMessage = SafetensorsDebug.parserErrorMessage

        safetensorsDebugLog(
            "loader snapshot: artificialDelay=\(artificialLoadDelayNanoseconds), parserErrorMessage=\(parserErrorMessage ?? "nil")"
        )

        if artificialLoadDelayNanoseconds > 0 {
            safetensorsDebugLog("loader sleeping for \(artificialLoadDelayNanoseconds) ns")
            try await Task.sleep(nanoseconds: artificialLoadDelayNanoseconds)
        }

        return try await Task.detached(priority: .userInitiated) {
            if let parserErrorMessage {
                safetensorsDebugLog("loader forcing parser error: \(parserErrorMessage)")
                throw SafetensorsParserError(message: parserErrorMessage)
            }

            safetensorsDebugLog("loader reading header")
            let headerSize = try SafetensorsHeaderReader.readFirstUInt64LittleEndian(from: url)
            let fileSize = try SafetensorsHeaderReader.fileSizeDescription(for: url)

            return SafetensorsViewerSnapshot(
                fileSize: fileSize,
                headerSize: headerSize,
                tensorRows: [
                    /*
                    SafetensorsViewerView.TensorRow(name: "model.embed_tokens.weight", dtype: "F16", shape: "[32000, 4096]", offset: "0"),
                    SafetensorsViewerView.TensorRow(name: "model.layers.0.self_attn.q_proj.weight", dtype: "F16", shape: "[4096, 4096]", offset: "1048576"),
                    SafetensorsViewerView.TensorRow(name: "model.layers.0.mlp.gate_proj.weight", dtype: "F16", shape: "[11008, 4096]", offset: "2097152"),
                    SafetensorsViewerView.TensorRow(name: "lm_head.weight", dtype: "F16", shape: "[32000, 4096]", offset: "4194304")
                     */
                ]
            )
        }.value
    }
}
