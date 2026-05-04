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
    static let openMostRecentFileOnStartupKey = "openMostRecentFileOnStartup"
    static let hiddenTableColumnsKey = "hiddenTableColumns"
    static let defaults: [String: Any] = [
        autoMakeNestedKey: true,
        openMostRecentFileOnStartupKey: false
    ]
}

private struct SafetensorsViewerSnapshot {
    let fileSize: String
    let headerSize: UInt64
    let tensorRows: [SafetensorsViewerView.TensorRow]
}

@MainActor
final class SidebarResizeHandle: NSView {
    var onDrag: ((CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event.deltaX)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }
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

/*
 "Summary View"
 - left-side view.
 
 */

@MainActor
final class SafetensorsViewerView: NSView {
    private struct SummaryItem {
        let label: String
        let value: String
    }

    /*
     STTensor stores what is in the .safetensors file.
     This adds some more fields.
     
     todo:
     - computed fields: min, max, #NaN, etc.
     - should we store things that are easily derived? e.g. "ndim"
     */
    fileprivate struct TensorRow {
        
        let index: Int

        let name:   String
        let dtype:  String
        let shape:  [Int]
        
        let ndim :  Int //== shape.count
        
        let params: Int //== prod(shape)
        let bytes : Int //== params * bytesPerValue

        init(index: Int, name: String, dtype: String, shape: [Int], bytes: Int) {
            self.index  = index
            self.name   = name
            self.dtype  = dtype
            self.shape  = shape
            self.bytes  = bytes

            self.ndim   = shape.count
            self.params = shape.product()
        }

        //
        //let offset: String
    }
    /*
     
     */

    private let minimumSidebarWidth: CGFloat = 160
    private let maximumSidebarWidth: CGFloat = 420
    private let toolbar = NSStackView()
    private let toggleSidebarButton = NSButton()
    private let actionsButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private let searchField = NSSearchField()
    private let contentStack = NSStackView()
    private let sidebarView = NSVisualEffectView()
    private let sidebarResizeHandle = SidebarResizeHandle()
    private let summaryStack = NSStackView()
    private let mainContentView = NSView()
    private let tableView = NSTableView()
    private let tableHeaderMenu = NSMenu()
    private let scrollView = NSScrollView()
    private let statusBarView = NSView()
    private let statusBarLabel = NSTextField(labelWithString: "")
    private let errorView = NSView()
    private let errorMessageLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let toastView = ToastView()

    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var currentSidebarWidth: CGFloat = 220
    private var isSidebarVisible = true
    private var isLoading = false
    private var parserErrorMessage: String?
    private var summaryItems: [SummaryItem] = []
    private var detailsWindowController: NSWindowController?
    private var toastTask: Task<Void, Never>?
    private var searchString = ""
    
    /*
     should we store tensors[] here or have some
     kind of datasource?
     */
    private var allTensorRows: [TensorRow] = []
    private var tensorRows: [TensorRow] = []
//    private var tensors: [STTensor] = []
    
    var loadedSTFile:STFile? = nil

    var hasLoadedFile: Bool {
        loadedSTFile != nil
    }

    var hasSelection: Bool {
        !tableView.selectedRowIndexes.isEmpty
    }

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
        loadedSTFile = nil
        parserErrorMessage = nil
        summaryItems = [
            /*
            SummaryItem(label: "File size",    value: "-"),
            SummaryItem(label: "Header size",  value: "-"),
            SummaryItem(label: "Tensor count", value: "-"),
            SummaryItem(label: "Metadata",     value: "-")
             */
        ]
        allTensorRows = []
        tensorRows = []
        reloadContent()
    }

    func showLoading() {
        isLoading = true
        loadedSTFile = nil
        parserErrorMessage = nil
        summaryItems = [
            
            /*
            SummaryItem(label: "File size",    value: "Loading"),
            SummaryItem(label: "Header size",  value: "Loading"),
            SummaryItem(label: "Tensor count", value: "Loading"),
            SummaryItem(label: "Metadata",     value: "Loading")
             */
        ]
        allTensorRows = []
        tensorRows = []
        reloadContent()
    }

    func loadFile(at url: URL) async {
        safetensorsDebugLog("loadFile started: \(url.path)")
        showLoading()
        
        /*
         note: STFile(path:) handles both
         .safetensor and .json loading.
         */
                
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
        allTensorRows = snapshot.tensorRows
        applyCurrentFilterAndSort()
        reloadContent()
    }
    
    /*
     newer version using STFile
     */
    private func showSTFile(_ stfile:STFile) {
        isLoading = false
        parserErrorMessage = nil
                
        let summary = STSummary(stfile:stfile)
        
        /*
         construct a text table of counts of dtypes:
         */
        var tt:[String] = []
        for pair in summary.dtypes.sortedByValueDescending() {
            tt.append(pair.key)
            tt.append(" : ")
            tt.append(String(pair.value))
            tt.append("\n")
        }
        let dtypes_string = tt.joined(separator:"")

        /*
         */
        //let headerSizeString = (summary.headerSize == nil) ? "-" : String(summary.headerSize!)

        let headerSizeString:String = summary.headerSize.string(or:"-")

        summaryItems = [

            SummaryItem(
                label: "File size",
                value: summary.fileSize.string(or:"-")),

            SummaryItem(label: "Header size",  value: "\(headerSizeString)"),
            SummaryItem(label: "Tensor count", value: "\(summary.tensorCount)"),
            SummaryItem(label: "dtypes", value: "\(dtypes_string)"),

            //?
            //SummaryItem(label: "Auto make nested", value: UserDefaults.standard.bool(forKey: SafetensorsSettings.autoMakeNestedKey) ? "On" : "Off")
        ]
        
        if let metadata = stfile.metadata {
            
            /*
             short text of 'metadata'.

             temp: just do String(describing:)
             */
            let metadataString = String(describing:metadata)
            
            summaryItems.append(
                SummaryItem(label: "metadata",
                            value: metadataString))
        }
        
        allTensorRows = stfile.tensors.enumerated().map { index, tensor in
            
            let bytes = tensor.dataOffsetEnd - tensor.dataOffsetStart
            // could check against:
            //  bytes : params * bytesPerValue

            return TensorRow(
                index : index,
                name  : tensor.name,
                dtype : tensor.dtype,
                shape : tensor.shape,
                bytes : bytes,
            )
            
        }

        applyCurrentFilterAndSort()
        reloadContent()
    }

    func showError(_ error: Error) {
        showError(string:error.localizedDescription)
    }
    
    func showError(string:String) {
        safetensorsDebugLog("showError: \(string)")
        isLoading = false
        loadedSTFile = nil
        parserErrorMessage = string
        summaryItems = []
        allTensorRows = []
        tensorRows = []
        reloadContent()
    }


    private func configure() {
        configureToolbar()
        configureSidebar()
        configureTable()
        configureStatusBar()
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

        actionsButton.bezelStyle = .rounded
        actionsButton.menu = makeActionsMenu()

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter by name"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        toolbar.addArrangedSubview(toggleSidebarButton)
        toolbar.addArrangedSubview(actionsButton)
        toolbar.addArrangedSubview(spacer)
        toolbar.addArrangedSubview(searchField)

        NSLayoutConstraint.activate([
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 12),
            searchField.widthAnchor.constraint(equalToConstant: 240)
        ])
    }

    private func configureSidebar() {
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.material = .sidebar
        sidebarView.blendingMode = .withinWindow
        sidebarView.state = .followsWindowActiveState

        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryStack.orientation = .vertical
        summaryStack.alignment = .leading
        summaryStack.spacing = 14
        summaryStack.edgeInsets = NSEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        sidebarView.addSubview(summaryStack)
        sidebarView.addSubview(sidebarResizeHandle)

        sidebarResizeHandle.onDrag = { [weak self] deltaX in
            self?.resizeSidebar(by: deltaX)
        }

        NSLayoutConstraint.activate([
            summaryStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            summaryStack.trailingAnchor.constraint(equalTo: sidebarResizeHandle.leadingAnchor),
            summaryStack.topAnchor.constraint(equalTo: sidebarView.topAnchor),

            sidebarResizeHandle.widthAnchor.constraint(equalToConstant: 6),
            sidebarResizeHandle.topAnchor.constraint(equalTo: sidebarView.topAnchor),
            sidebarResizeHandle.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarResizeHandle.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor)
        ])
    }

    private func configureTable() {
        tableView.delegate = self
        tableView.dataSource = self

        tableView.usesAlternatingRowBackgroundColors = true
        
        tableView.allowsMultipleSelection = true
        
        let headerView = NSTableHeaderView()
        headerView.menu = tableHeaderMenu
        tableView.headerView = headerView
        tableView.menu = makeTableMenu()
        tableHeaderMenu.delegate = self

        //
        addColumn(identifier: "index",  title: "index",   width: 60)
        addColumn(identifier: "name",   title: "name",   width: 280)
        addColumn(identifier: "dtype",  title: "dtype",  width: 80)
        addColumn(identifier: "shape",  title: "shape",  width: 160)
        addColumn(identifier: "params", title: "params", width: 80)
        addColumn(identifier: "ndim",   title: "ndim",  width:  80)
        addColumn(identifier: "bytes",  title: "bytes",  width: 80)
        restoreHiddenTableColumns()

//        addColumn(identifier: "offset", title: "offset", width: 120)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
    }

    private func configureStatusBar() {
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.wantsLayer = true
        statusBarView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        statusBarLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBarLabel.font = .systemFont(ofSize: 11)
        statusBarLabel.textColor = .secondaryLabelColor
        statusBarLabel.lineBreakMode = .byTruncatingTail

        statusBarView.addSubview(separator)
        statusBarView.addSubview(statusBarLabel)

        NSLayoutConstraint.activate([
            statusBarView.heightAnchor.constraint(equalToConstant: 24),

            separator.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor),
            separator.topAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarLabel.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor, constant: 10),
            statusBarLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusBarView.trailingAnchor, constant: -10),
            statusBarLabel.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor)
        ])
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
        mainContentView.addSubview(statusBarView)
        mainContentView.addSubview(errorView)

        sidebarWidthConstraint = sidebarView.widthAnchor.constraint(equalToConstant: currentSidebarWidth)
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
            scrollView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            errorView.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

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
        column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
        tableView.addTableColumn(column)
    }

    private func updateTableHeaderMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let visibleColumnCount = tableView.tableColumns.filter { !$0.isHidden }.count
        for column in tableView.tableColumns {
            let item = NSMenuItem(
                title: column.title,
                action: #selector(toggleColumnVisibility),
                keyEquivalent: "")
            item.target = self
            item.representedObject = column.identifier.rawValue
            item.state = column.isHidden ? .off : .on
            item.isEnabled = column.isHidden || visibleColumnCount > 1
            menu.addItem(item)
        }
    }

    private func restoreHiddenTableColumns() {
        guard let hiddenColumnIDs = UserDefaults.standard.array(forKey: SafetensorsSettings.hiddenTableColumnsKey) as? [String] else {
            return
        }

        let hiddenColumnIDSet = Set(hiddenColumnIDs)
        for column in tableView.tableColumns {
            column.isHidden = hiddenColumnIDSet.contains(column.identifier.rawValue)
        }

        if tableView.tableColumns.allSatisfy({ $0.isHidden }),
           let firstColumn = tableView.tableColumns.first {
            firstColumn.isHidden = false
            saveHiddenTableColumns()
        }
    }

    private func saveHiddenTableColumns() {
        let hiddenColumnIDs = tableView.tableColumns
            .filter { $0.isHidden }
            .map { $0.identifier.rawValue }

        UserDefaults.standard.set(hiddenColumnIDs, forKey: SafetensorsSettings.hiddenTableColumnsKey)
    }

    private func applyCurrentFilterAndSort() {
        let sourceRows: [TensorRow]
        if searchString.isEmpty {
            sourceRows = allTensorRows
        } else {
            sourceRows = allTensorRows.filter { row in
                row.name.range(of: searchString, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        guard let sortDescriptor = tableView.sortDescriptors.first,
              let key = sortDescriptor.key else {
            tensorRows = sourceRows
            return
        }

        let ascending = sortDescriptor.ascending
        tensorRows = sourceRows.sorted { lhs, rhs in
            let comparison = compare(lhs, rhs, by: key)
            if comparison == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    private func compare(_ lhs: TensorRow, _ rhs: TensorRow, by key: String) -> ComparisonResult {
        switch key {
            
        //strings:
        case "name":  return lhs.name.localizedStandardCompare(rhs.name)
        case "dtype": return lhs.dtype.localizedStandardCompare(rhs.dtype)
        case "shape":
            return shapeString(lhs.shape).localizedStandardCompare(shapeString(rhs.shape))
            
        //integers:
        case "index":  return compare(lhs.index,  rhs.index)
        case "params": return compare(lhs.params, rhs.params)
        case "bytes":  return compare(lhs.bytes,  rhs.bytes)
        case "ndim":   return compare(lhs.ndim,   rhs.ndim)

        default:
            return .orderedSame
        }
    }

    private func compare(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
    }

    private func makeTableMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        updateTableMenu(menu)
        return menu
    }

    private func updateTableMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let selectedRowCount = tableView.selectedRowIndexes.count
        if selectedRowCount == 1 {
            addSingleRowItems(to: menu)
        } else if selectedRowCount > 1 {
            addMultipleRowItems(to: menu, selectedRowCount: selectedRowCount)
        }
    }

    private func addSingleRowItems(to menu: NSMenu) {
        let copyNameItem = NSMenuItem(
            title: "Copy name",
            action: #selector(copyTensorName),
            keyEquivalent: "")
        copyNameItem.target = self
        menu.addItem(copyNameItem)
        
        
        let item0 = NSMenuItem(
            title: "Copy tensor info as JSON",
            action: #selector(copyTensorInfoAsJSON),
            keyEquivalent: "")
        item0.target = self
        menu.addItem(item0)

        
        let item1 = NSMenuItem(
            title: "Copy data as JSON",
            action: #selector(copyDataAsJSON),
            keyEquivalent: "")
        item1.target = self
        menu.addItem(item1)

        
        let item2 = NSMenuItem(
            title: "Export tensor as .npy",
            action: #selector(exportTensorAsNpy),
            keyEquivalent: "")
        item2.target = self
        menu.addItem(item2)


        let detailsItem = NSMenuItem(
            title: "Details...",
            action: #selector(showTensorDetails),
            keyEquivalent: "")
        
        detailsItem.target = self
        menu.addItem(detailsItem)
    }

    private func addMultipleRowItems(to menu: NSMenu, selectedRowCount: Int) {
        
        /*
         */
        let rowString = (selectedRowCount > 1) ? "rows" : "row"
        
        let item = NSMenuItem(
            title: "Export \(selectedRowCount) \(rowString) to NPZ",
            action: #selector(exportToNpz),
            keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        
    }

    private func makeActionsMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Actions", action: nil, keyEquivalent: "")

        let convertToNestedItem = NSMenuItem(
            title: "Convert to nested",
            action: #selector(convertToNested),
            keyEquivalent: "")
        convertToNestedItem.target = self
        menu.addItem(convertToNestedItem)

        return menu
    }

    private func reloadContent() {
        rebuildSummary()
        tableView.reloadData()
        updateErrorView()
        updateProgressIndicator()
        updateStatusBar()
    }

    /*
     temp. simple just used a few times here.
     
     e.g. return
     "1 row"
     "2 rows"
     */
    private func stringCount(word:String, count:Int) -> String {
        return "\( count.formatted()  ) " + ((count == 1) ? word : word + "s")
    }

    private func updateStatusBar() {
        
        let count = tableView.selectedRowIndexes.count
        
        switch count {
        case 0:
            if searchString.isEmpty {
                statusBarLabel.stringValue = stringCount(word:"row", count: allTensorRows.count)
            } else {
                let s = stringCount(word:"row", count: allTensorRows.count)
                statusBarLabel.stringValue = "Showing \(tensorRows.count) of \(s)"
            }
        case 1:
            statusBarLabel.stringValue = "1 row selected"
        default:
            statusBarLabel.stringValue = "\(count) rows selected"
        }
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

            /*
             
             */
            let value = NSTextField(labelWithString: item.value)
            value.font = .systemFont(ofSize: 13, weight: .regular)
            value.lineBreakMode = .byTruncatingTail
            value.maximumNumberOfLines = 2
            
            // allow selection:
            value.isSelectable = true
            value.isEditable = false
            value.isBordered = false
            value.drawsBackground = false
            value.focusRingType = .none

            group.addArrangedSubview(label)
            group.addArrangedSubview(value)
            summaryStack.addArrangedSubview(group)
        }
    }

    @objc private func toggleSidebar() {
        isSidebarVisible.toggle()
        sidebarView.isHidden = !isSidebarVisible
        sidebarWidthConstraint?.constant = isSidebarVisible ? currentSidebarWidth : 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            layoutSubtreeIfNeeded()
        }
    }

    private func resizeSidebar(by deltaX: CGFloat) {
        guard isSidebarVisible else {
            return
        }

        currentSidebarWidth = min(maximumSidebarWidth, max(minimumSidebarWidth, currentSidebarWidth + deltaX))
        sidebarWidthConstraint?.constant = currentSidebarWidth
        layoutSubtreeIfNeeded()
    }

    @objc private func searchFieldChanged() {
        searchString = searchField.stringValue
        applySearch()
    }

    private func applySearch() {
        applyCurrentFilterAndSort()
        tableView.deselectAll(nil)
        tableView.reloadData()
        updateStatusBar()
    }

    func selectNone() {
        tableView.deselectAll(nil)
        updateStatusBar()
    }

    /*
     
     */
    @objc private func convertToNested() {
        print("todo....")
    }

    @objc private func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == identifier }) else {
            return
        }

        if !column.isHidden {
            let visibleColumnCount = tableView.tableColumns.filter { !$0.isHidden }.count
            guard visibleColumnCount > 1 else {
                return
            }
        }

        column.isHidden.toggle()
        saveHiddenTableColumns()
        tableView.sizeLastColumnToFit()
        tableView.tile()
        tableView.reloadData()
    }

    

//    func tensorAtRow(_ row:Int) -> STTensor? {
//        return tensors[safe:row]
//  }

    /*
     using .clickedRow
     - most recent?
     - what about on multiple?
     */
    func tensorForMenu() -> STTensor? {
        guard let stfile = loadedSTFile else {return nil}
        guard let row = tensorRows[safe:tableView.clickedRow] else {return nil}
        return stfile.tensors[safe:row.index]
    }


    /*
     
     */
    @objc private func exportTensorAsNpy() {
        guard let tensor = tensorForMenu() else {return}
        guard let stfile = loadedSTFile else {return}

        let savePanel = NSSavePanel()
        savePanel.title = "Export tensor as .npy"
        savePanel.nameFieldStringValue = tensor.name + ".npy"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden    = false

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        switch writeNPY(stfile: stfile, tensor: tensor, toPath: url.path) {
        case .success:
            showToast("Exported \(url.lastPathComponent)")
        case .failure(let message):
            showExportError(message)
        }
        
    }

    /*
     open Save panel and export to .npz
     */
    private func exportToNPZ(named names: [String]?) {
        guard let stfile = loadedSTFile else {return}

        let savePanel = NSSavePanel()
        savePanel.title = "Export .npz"
        
        /*
         if not set? It seems to use "Untitled"
         - could use STFile name OR concat of some tensor names, etc.
         */
//        savePanel.nameFieldStringValue = tensor.name + ".npy"
        
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden    = false

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        switch writeNPZ(stfile: stfile, toPath: url.path, names: names) {
        case .success:
            showToast("Exported \(url.lastPathComponent)")
        case .failure(let message):
            showExportError(message)
        }

    }


    
    /*
     similar to 'exportTensorAsNpy'
     */
    @objc private func exportToNpz() {
        exportSelectionToNPZ()
    }

    func exportAllToNPZ() {
        exportToNPZ(named: nil)
    }

    func exportSelectionToNPZ() {
        let selectedNames = tableView.selectedRowIndexes.compactMap { row -> String? in
            tensorRows[safe: row]?.name
        }

        guard !selectedNames.isEmpty else {
            return
        }

        exportToNPZ(named: selectedNames)
    }

    @objc private func copyTensorInfoAsJSON() {
        guard let tensor = tensorForMenu() else {return}
        let s = tensor.toJSONString()
        copyString(s, withMessage:"Copied data")
    }
    
    @objc private func copyDataAsJSON() {
        guard let tensor = tensorForMenu() else {return}
        guard let stfile = loadedSTFile else {return}
        
        if let jsonString = stfile.readArrayAsJSON(tensor: tensor) {
            copyString(jsonString, withMessage:"Copied data")
        }
        else {
            //more info?
            showToast("Failed body as JSON")
        }

    }
    
    func copyString(_ string:String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType:.string)
    }

    /*
     displays a Toast message: "{msg} [length {n}]"
     */
    func copyString(_ string:String, withMessage msg:String) {
        copyString(string)
        showToast("\(msg) [length \(string.count)]")
    }


    
    @objc private func copyTensorName() {
        guard let tensor = tensorForMenu() else {return}
        copyString(tensor.name, withMessage: "Copied name")
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

    private func showExportError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.alertStyle = .warning

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    
}

/*
 
 */
enum WriteResult {
    case success
    case failure(String)
}

/*
 
 */
func writeNPY(stfile: STFile, tensor: STTensor, toPath: String) -> WriteResult {
    let magic = Data([0x93]) + Data("NUMPY".utf8)
    let url = URL(fileURLWithPath: toPath)

    do {
        try magic.write(to: url, options: .atomic)
        return .success
    } catch {
        return .failure("Could not export \(tensor.name): \(error.localizedDescription)")
    }
}

/*
 
 */
func writeNPZ(stfile: STFile, toPath: String, names:[String]? = nil) -> WriteResult {
    
    //TEMP. here, we will implement NPZ writer.
    let tempData = Data([0x00])
    
    let url = URL(fileURLWithPath: toPath)

    do {
        try tempData.write(to: url, options: .atomic)
        return .success
    } catch {
        return .failure("Could not export \(error.localizedDescription)")
    }
    
}




extension SafetensorsViewerView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tensorRows.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applyCurrentFilterAndSort()
        tableView.reloadData()
        updateStatusBar()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatusBar()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        guard let tensorRow = tensorRows[safe:row] else {return nil}
        guard let column = tableColumn else {return nil}
        

        /*
         init each time?
         */

        //let textField = NSTextField(labelWithString: value(for: tableColumn.identifier.rawValue, in: tensorRows[row]))
        
        let columnName = column.identifier.rawValue
        
        let label:String = labelFor(tensorRow:tensorRow, columnName:columnName)

        let textField = NSTextField(labelWithString:label)
        
        textField.lineBreakMode = .byTruncatingMiddle
        textField.maximumNumberOfLines = 1
        textField.font = .systemFont(ofSize: 12)
        return textField
    }
    
    fileprivate func labelFor(tensorRow:TensorRow, columnName:String) -> String {
        
        switch columnName {
        case "index":  return String(tensorRow.index)
        case "name":   return tensorRow.name
        case "dtype":  return tensorRow.dtype
        case "shape":  return shapeString(tensorRow.shape)
        case "params": return tensorRow.params.formatted()
        case "ndim":   return String(tensorRow.ndim)

        case "bytes":
            // format bytes?
            let nb = tensorRow.bytes
            /*
             raw + format?
             */
            return nb.formatted(.byteCount(style:.file))

        default:
            return "?"
        }

    }

}

extension SafetensorsViewerView: NSSearchFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === searchField else {
            return
        }

        searchFieldChanged()
    }
}

extension SafetensorsViewerView: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === tableView.menu {
            updateTableMenu(menu)
        } else if menu === tableHeaderMenu {
            updateTableHeaderMenu(menu)
        }
    }
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
    
    /*
     Is this no longer used?
     */
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
