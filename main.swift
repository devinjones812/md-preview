import AppKit
import WebKit
import UniformTypeIdentifiers

// Apple Silicon Homebrew, then Intel Homebrew.
let pandoc = ["/opt/homebrew/bin/pandoc", "/usr/local/bin/pandoc"]
    .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/pandoc"
let markdownType = UTType(filenameExtension: "md")!

let cssURL = Bundle.main.url(forResource: "style", withExtension: "css")!.absoluteString

func resource(_ n: String, _ e: String) -> String {
    (try? String(contentsOf: Bundle.main.url(forResource: n, withExtension: e)!, encoding: .utf8)) ?? ""
}

final class DocWindow: NSWindowController, NSWindowDelegate, NSToolbarDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    let url: URL
    var web: WKWebView!
    let scroll = NSTextView.scrollableTextView()
    var text: NSTextView { scroll.documentView as! NSTextView }
    let toggle = NSButton(title: "Edit", target: nil, action: nil)
    var editing = false
    var mtime: Date?
    var pendingScrollLine: Int?
    var previewScrollY: Double = 0
    static let toggleID = NSToolbarItem.Identifier("toggle")

    init(url: URL) {
        self.url = url
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 900),
                           styleMask: [.titled, .closable, .resizable, .miniaturizable],
                           backing: .buffered, defer: false)
        super.init(window: win)

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addUserScript(WKUserScript(source: resource("highlight.min", "js"), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        cfg.userContentController.addUserScript(WKUserScript(source: resource("page", "js"), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        cfg.userContentController.add(self, name: "edit")
        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self

        let tv = text
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .systemFont(ofSize: 15)
        tv.textContainerInset = NSSize(width: 24, height: 24)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false

        toggle.target = self
        toggle.action = #selector(toggleMode)
        toggle.bezelStyle = .rounded

        win.title = url.lastPathComponent
        win.representedURL = url
        win.delegate = self
        let tb = NSToolbar(identifier: "tb")
        tb.delegate = self
        win.toolbar = tb
        win.toolbarStyle = .unified
        win.setFrameAutosaveName("MDPreviewWindow")
        let root = NSView()
        win.contentView = root
        show(web)
        // builtbydevin tag, bottom right, above both modes.
        if let url = Bundle.main.url(forResource: "builtbydevin", withExtension: "png"), let img = NSImage(contentsOf: url) {
            let tag = NSImageView(image: img)
            tag.imageScaling = .scaleProportionallyUpOrDown
            tag.alphaValue = 0.85
            tag.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(tag, positioned: .above, relativeTo: nil)
            NSLayoutConstraint.activate([
                tag.widthAnchor.constraint(equalToConstant: 110),
                tag.heightAnchor.constraint(equalTo: tag.widthAnchor, multiplier: img.size.height / img.size.width),
                tag.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
                tag.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            ])
            self.tag = tag
        }
        loadFile()
        render()
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadFile() {
        text.string = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        mtime = modDate()
        window?.isDocumentEdited = false
    }
    func modDate() -> Date? { (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date }

    func save() {
        guard window?.isDocumentEdited == true else { return }
        do {
            try text.string.write(to: url, atomically: true, encoding: .utf8)
            mtime = modDate()
            window?.isDocumentEdited = false
        } catch { NSAlert(error: error).runModal() }
    }

    func render() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: pandoc)
        p.arguments = ["-f", "gfm+sourcepos", "-t", "html", "--mathml", "--syntax-highlighting=none"]
        let inp = Pipe(), out = Pipe()
        p.standardInput = inp; p.standardOutput = out; p.standardError = FileHandle.nullDevice
        var body: String
        do {
            try p.run()
            inp.fileHandleForWriting.write(text.string.data(using: .utf8)!)
            try inp.fileHandleForWriting.close()
            body = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            p.waitUntilExit()
        } catch {
            body = "<pre>pandoc not found at \(pandoc)</pre>"
        }
        let dir = url.deletingLastPathComponent().absoluteString
        let html = "<!doctype html><meta charset=utf-8><base href=\"\(dir)\"><link rel=stylesheet href=\"\(cssURL)\"><body><article class=markdown-body>\(body)</article></body>"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mdpreview-\(ObjectIdentifier(self).hashValue).html")
        try? html.write(to: tmp, atomically: true, encoding: .utf8)
        web.loadFileURL(tmp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        if let line = pendingScrollLine {
            w.evaluateJavaScript("scrollToLine(\(line))")
            pendingScrollLine = nil
        } else {
            w.evaluateJavaScript("window.scrollTo(0, \(previewScrollY))")
        }
    }
    // Open links in the browser.
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if a.navigationType == .linkActivated, let u = a.request.url {
            NSWorkspace.shared.open(u); decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    // Double-click in preview: go to edit mode at that spot.
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any],
              let line = d["line"] as? Int, let col = d["col"] as? Int, let off = d["off"] as? Int else { return }
        let s = text.string as NSString
        var loc = 0, l = 1
        while l < line && loc < s.length {
            loc = NSMaxRange(s.lineRange(for: NSRange(location: loc, length: 0))); l += 1
        }
        let lineStr = s.substring(from: loc)
        let prefix = String(lineStr.unicodeScalars.prefix(col - 1))
        loc = min(loc + (prefix as NSString).length + off, s.length)
        enterEdit(at: loc)
    }

    func enterEdit(at loc: Int?) {
        web.evaluateJavaScript("window.scrollY") { [weak self] y, _ in self?.previewScrollY = (y as? Double) ?? 0 }
        editing = true
        toggle.title = "Done"
        show(scroll)
        window?.makeFirstResponder(text)
        if let loc {
            text.setSelectedRange(NSRange(location: loc, length: 0))
            text.scrollRangeToVisible(NSRange(location: loc, length: 0))
        }
    }

    func enterPreview() {
        save()
        let s = text.string as NSString
        let cursor = min(text.selectedRange().location, s.length)
        pendingScrollLine = s.substring(to: cursor).components(separatedBy: "\n").count
        editing = false
        toggle.title = "Edit"
        render()
        show(web)
    }

    var tag: NSView?
    func show(_ v: NSView) {
        guard let root = window?.contentView else { return }
        (v === web ? scroll : web as NSView).removeFromSuperview()
        v.frame = root.bounds
        v.autoresizingMask = [.width, .height]
        if let tag { root.addSubview(v, positioned: .below, relativeTo: tag) } else { root.addSubview(v) }
    }

    @objc func toggleMode() { editing ? enterPreview() : enterEdit(at: nil) }
    @objc func saveDocument(_ s: Any?) { save() }

    func textDidChange() { window?.isDocumentEdited = true }

    // Reload if the file changed on disk while you were away.
    func windowDidBecomeKey(_ n: Notification) {
        guard !editing, modDate() != mtime else { return }
        web.evaluateJavaScript("window.scrollY") { [weak self] y, _ in
            self?.previewScrollY = (y as? Double) ?? 0
            self?.loadFile(); self?.render()
        }
    }
    func windowWillClose(_ n: Notification) {
        save()
        (NSApp.delegate as? AppDelegate)?.closed(self)
    }

    func toolbarAllowedItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, Self.toggleID] }
    func toolbarDefaultItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, Self.toggleID] }
    func toolbar(_ t: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar f: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        item.view = toggle
        return item
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [DocWindow] = []
    var observer: Any?
    func applicationDidFinishLaunching(_ n: Notification) {
        observer = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: nil, queue: .main) { [weak self] n in
            self?.windows.first { $0.text === n.object as AnyObject }?.textDidChange()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if self?.windows.isEmpty == true { self?.openDocument(nil) }
        }
    }
    func application(_ app: NSApplication, open urls: [URL]) {
        for u in urls {
            if let w = windows.first(where: { $0.url == u }) { w.showWindow(nil); continue }
            let w = DocWindow(url: u)
            windows.append(w)
            w.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openDocument(_ s: Any?) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [markdownType]
        p.allowsMultipleSelection = true
        if p.runModal() == .OK { application(NSApp, open: p.urls) }
    }
    @objc func makeDefault(_ s: Any?) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: markdownType) { err in
            DispatchQueue.main.async {
                let a = err.map { NSAlert(error: $0) } ?? NSAlert()
                if err == nil { a.messageText = "MD Preview now opens .md files." }
                a.runModal()
            }
        }
    }
    func closed(_ w: DocWindow) { windows.removeAll { $0 === w } }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) { windows.forEach { $0.save() } }
}

func menu(_ title: String, _ items: [(String, Selector, String)]) -> NSMenuItem {
    let top = NSMenuItem()
    let m = NSMenu(title: title)
    for (t, a, k) in items { m.addItem(withTitle: t, action: a, keyEquivalent: k) }
    top.submenu = m
    return top
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
let main = NSMenu()
main.addItem(menu("MD Preview", [
    ("Set as Default for .md Files", #selector(AppDelegate.makeDefault(_:)), ""),
    ("Quit MD Preview", #selector(NSApplication.terminate(_:)), "q"),
]))
main.addItem(menu("File", [
    ("Open…", #selector(AppDelegate.openDocument(_:)), "o"),
    ("Save", #selector(DocWindow.saveDocument(_:)), "s"),
    ("Close Window", #selector(NSWindow.performClose(_:)), "w"),
]))
main.addItem(menu("Edit", [
    ("Undo", Selector(("undo:")), "z"),
    ("Redo", Selector(("redo:")), "Z"),
    ("Cut", #selector(NSText.cut(_:)), "x"),
    ("Copy", #selector(NSText.copy(_:)), "c"),
    ("Paste", #selector(NSText.paste(_:)), "v"),
    ("Select All", #selector(NSText.selectAll(_:)), "a"),
]))
main.addItem(menu("View", [("Toggle Edit / Preview", #selector(DocWindow.toggleMode), "e")]))
app.mainMenu = main
app.setActivationPolicy(.regular)
app.run()
