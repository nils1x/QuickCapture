// QuickCapture.swift
// ⌥Q → capture a bullet to today's Obsidian daily note.
// Build: bash build.sh

import AppKit
import Carbon.HIToolbox
import Foundation

// MARK: - Config
// All user-specific settings live in ~/.config/quickcapture/config
// The file is created automatically on first launch with instructions inside.

enum Config {
    // Window / hotkey constants (not user-configurable at runtime)
    static let hotkeyMods: UInt32 = 0x0800   // ⌥  (cmd=0x0100 ctrl=0x1000 shift=0x0200)
    static let hotkeyCode: UInt32 = UInt32(kVK_ANSI_Q)
    static let W: CGFloat = 460
    static let H: CGFloat = 76
    static let R: CGFloat = 22

    // Loaded from config file at launch
    static let vault:      String = UserConfig.load().vault
    static let journalDir: String = vault + "/" + UserConfig.load().journalFolder
    static let template:   String = vault + "/" + UserConfig.load().templatePath
}

// Reads/writes ~/.config/quickcapture/config (simple key=value format)
struct UserConfig {
    var vault:          String
    var journalFolder:  String
    var templatePath:   String

    static let configPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/.config/quickcapture/config"
    }()

    static func load() -> UserConfig {
        let defaults = UserConfig(
            vault:         defaultVault(),
            journalFolder: "10_Journal",
            templatePath:  "00_Inbox/templates/Daily Template.md"
        )
        guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            write(defaults)   // first launch — create config file
            return defaults
        }
        var cfg = defaults
        for line in raw.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let val = parts.dropFirst().joined(separator: "=")
                           .trimmingCharacters(in: .whitespaces)
            switch key {
            case "vault":          cfg.vault          = val
            case "journal_folder": cfg.journalFolder  = val
            case "template_path":  cfg.templatePath   = val
            default: break
            }
        }
        return cfg
    }

    static func write(_ cfg: UserConfig) {
        let dir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir,
                                                  withIntermediateDirectories: true)
        let content = """
        # QuickCapture config
        # Absolute path to your Obsidian vault root
        vault=\(cfg.vault)

        # Folder inside the vault where daily notes live
        journal_folder=\(cfg.journalFolder)

        # Path inside the vault to the daily note template
        template_path=\(cfg.templatePath)
        """
        try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    // Best-effort: find the first Obsidian vault via iCloud or local Documents
    private static func defaultVault() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let icloud = home + "/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        if let vaults = try? FileManager.default.contentsOfDirectory(atPath: icloud),
           let first = vaults.first(where: { !$0.hasPrefix(".") }) {
            return icloud + "/" + first
        }
        return home + "/Documents/ObsidianVault"
    }
}

// MARK: - App

let app  = NSApplication.shared
let root = Root()
app.delegate = root
app.setActivationPolicy(.accessory)
app.run()

// MARK: - Root (AppDelegate)

final class Root: NSObject, NSApplicationDelegate {
    private var panel: Panel!
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ n: Notification) {
        // Menu bar icon
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.and.pencil",
                                     accessibilityDescription: nil)
        let menu = NSMenu()
        menu.addItem(withTitle: "Show  (⌥Q)", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        // Build panel once, reuse forever
        panel = Panel(root: self)

        // Carbon global hotkey — fires on any app, any space
        let target = GetApplicationEventTarget()
        let spec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind:  UInt32(kEventHotKeyPressed))]
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        let cb: EventHandlerUPP = { _, _, ud in
            guard let ud else { return noErr }
            Unmanaged<Root>.fromOpaque(ud).takeUnretainedValue().toggle()
            return noErr
        }
        InstallEventHandler(target, cb, 1, spec, ptr, &eventHandler)
        RegisterEventHotKey(Config.hotkeyCode, Config.hotkeyMods,
                            EventHotKeyID(signature: 0x51435054, id: 1),
                            target, 0, &hotkeyRef)
    }

    @objc func toggle() {
        if panel.isVisible { dismiss() } else { present() }
    }

    func present() {
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrameOrigin(NSPoint(x: f.midX - Config.W / 2,
                                     y: f.midY - Config.H / 2 + 80))
        panel.captureView.reset()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.captureView)
    }

    func dismiss() {
        panel.orderOut(nil)
    }

    func commit(text: String) {
        dismiss()
        // File I/O off main thread — zero perceived latency
        let t = text
        DispatchQueue.global(qos: .userInitiated).async { self.write(t) }
    }

    // MARK: File I/O

    private func write(_ text: String) {
        guard let path = notePathEnsured() else { return }
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "- " + $0 }
        guard !lines.isEmpty else { return }
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let base = existing.hasSuffix("\n") ? existing : existing + "\n"
        try? (base + "\n" + lines.joined(separator: "\n") + "\n")
            .write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func notePathEnsured() -> String? {
        let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"
        let path = Config.journalDir + "/" + df.string(from: Date()) + ".md"
        guard !FileManager.default.fileExists(atPath: path) else { return path }

        let dfW = DateFormatter(); dfW.dateFormat = "EEEE"
        let dmy = df.string(from: Date()), day = dfW.string(from: Date())
        let body: String
        if let t = try? String(contentsOfFile: Config.template, encoding: .utf8) {
            body = t
                .replacingOccurrences(of: "{{date:DD-MM-YYYY}}", with: dmy)
                .replacingOccurrences(of: "{{date:dddd}}", with: day)
                .replacingOccurrences(of: "{{date}}", with: dmy)
        } else { body = "# \(dmy) - \(day)\n***\n" }
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
}

// MARK: - Panel

final class Panel: NSPanel {
    let captureView: CaptureView

    init(root: Root) {
        captureView = CaptureView(root: root)
        super.init(contentRect: NSRect(x: 0, y: 0, width: Config.W, height: Config.H),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)   // defer: true = faster init
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isFloatingPanel = true
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        appearance = NSAppearance(named: .vibrantDark)

        // Replace the default grey content view with a fully transparent wrapper
        // so nothing bleeds outside our rounded CaptureView.
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: Config.W, height: Config.H))
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = CGColor.clear
        super.contentView = wrapper
        wrapper.addSubview(captureView)
        captureView.frame = wrapper.bounds
        captureView.autoresizingMask = [.width, .height]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - CaptureView
// One view does everything: background blur, text input, date label.
// Vertical centering is pure frame math in layout() — no Auto Layout.

final class CaptureView: NSVisualEffectView, NSTextViewDelegate {
    private weak var root: Root?

    // Subviews
    private let tv   = NSTextView()
    private let clip = NSClipView()   // needed to host NSTextView properly
    private let date = NSTextField(labelWithString: {
        let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"
        return df.string(from: Date())
    }())

    // Cached font metrics — computed once
    private let fontSize: CGFloat = 17
    private lazy var lineH: CGFloat = {
        let f = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        return ceil(f.ascender + abs(f.descender) + f.leading)
    }()

    init(root: Root) {
        self.root = root
        super.init(frame: NSRect(x: 0, y: 0, width: Config.W, height: Config.H))

        // Blur background
        blendingMode = .behindWindow
        material = .hudWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Config.R
        layer?.masksToBounds = true

        setupTV()
        setupDate()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupTV() {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)

        tv.font = font
        tv.textColor = .white
        tv.insertionPointColor = .controlAccentColor
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.isContinuousSpellCheckingEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainerInset = .zero
        tv.delegate = self
        addSubview(tv)
    }

    private func setupDate() {
        date.font = .systemFont(ofSize: 9, weight: .regular)
        date.textColor = NSColor(white: 1, alpha: 0.28)
        date.drawsBackground = false
        date.isBezeled = false
        date.isEditable = false
        addSubview(date)
    }

    // MARK: - Frame-based layout — called once on first show and on resize

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        let hPad: CGFloat = 20

        // Text view: one line, vertically centered in the full height
        let tvW = w - hPad * 2
        let tvY = (h - lineH) / 2
        tv.frame = NSRect(x: hPad, y: tvY, width: tvW, height: lineH)
        tv.textContainer?.size = NSSize(width: tvW, height: .greatestFiniteMagnitude)

        // Date label: bottom-right
        let dlW: CGFloat = 72
        date.frame = NSRect(x: w - dlW - 14, y: 6, width: dlW, height: 12)
    }

    // MARK: - First responder

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        return window?.makeFirstResponder(tv) ?? false
    }

    // MARK: - Esc key on the view itself (fallback)

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { root?.dismiss() }
        else { super.keyDown(with: event) }
    }

    // MARK: - NSTextViewDelegate

    func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.insertNewline(_:)):
            let text = tv.string
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                root?.commit(text: text)
            } else {
                root?.dismiss()
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            root?.dismiss()
            return true
        default:
            return false
        }
    }

    // MARK: - Reset

    func reset() {
        tv.string = ""
        needsLayout = true
    }
}
