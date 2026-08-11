//
//  ContextCaptureController.swift
//  KeyType
//
//  Owns the AX-notification-driven context tracker and the debug overlay window,
//  bridges them at the app target (so MacContextCapture and CompletionUI stay decoupled),
//  and logs each emitted TextFieldContext via os.Logger.
//

import AppKit
import AutocompleteCore
import CompletionUI
import Foundation
import MacContextCapture
import Observation
import os

@MainActor
@Observable
final class ContextCaptureController {
    
    private let tracker: AccessibilityContextTracker
    private let overlay: CaretDebugOverlayWindow
    private let log = Logger(subsystem: "com.pattonium.KeyType", category: "context-capture")

    private(set) var isRunning = false
    private(set) var lastSummary: String = ""
    private(set) var latestSnapshot: FocusedFieldSnapshot?
    private(set) var latestTunableSnapshot: FocusedFieldSnapshot?
    private(set) var lastTunableSummary: String = ""
    var debugOverlayEnabled: Bool = false {
        didSet { applyOverlayVisibility() }
    }

    private var listenerToken: UUID?
    private var lastLoggedSummary: String?

    init(
        tracker: AccessibilityContextTracker = AccessibilityContextTracker(),
        overlay: CaretDebugOverlayWindow = CaretDebugOverlayWindow()
    ) {
        self.tracker = tracker
        self.overlay = overlay
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        listenerToken = tracker.addListener { [weak self] snapshot in
            self?.handle(snapshot)
        }
        tracker.start()
        log.debug("Started AccessibilityContextTracker")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let listenerToken {
            tracker.removeListener(listenerToken)
        }
        listenerToken = nil
        tracker.stop()
        overlay.hide()
        log.debug("Stopped AccessibilityContextTracker")
    }

    private func handle(_ snapshot: FocusedFieldSnapshot?) {
        guard let snapshot else {
            overlay.hide()
            lastSummary = "(no focused field)"
            latestSnapshot = nil
            if !Self.shouldPreserveLatestTunableSnapshotOnMissingSnapshot(
                frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            ) {
                latestTunableSnapshot = nil
                lastTunableSummary = ""
            }
            log.debug("No focused field")
            return
        }

        latestSnapshot = snapshot
        lastSummary = Self.summary(for: snapshot)
        if !Self.isKeyTypeTarget(snapshot.context.target) {
            latestTunableSnapshot = snapshot
            lastTunableSummary = lastSummary
        }
        // The tracker re-emits on caret-geometry repolls even when nothing the user cares about
        // changed; only log when the summary actually changes to keep the debug log readable.
        if lastSummary != lastLoggedSummary {
            lastLoggedSummary = lastSummary
            log.debug("\(self.lastSummary, privacy: .public)")
        }

        if debugOverlayEnabled, let overlaySnapshot = Self.debugOverlaySnapshot(for: snapshot) {
            overlay.show(snapshot: overlaySnapshot)
        } else {
            overlay.hide()
        }
    }

    private func applyOverlayVisibility() {
        if !debugOverlayEnabled {
            overlay.hide()
            return
        }
        if let snapshot = tracker.currentSnapshot,
           let overlaySnapshot = Self.debugOverlaySnapshot(for: snapshot) {
            overlay.show(snapshot: overlaySnapshot)
        }
    }

    static func debugOverlaySnapshot(for snapshot: FocusedFieldSnapshot) -> CaretDebugOverlaySnapshot? {
        guard let caretRect = snapshot.caretRect, !caretRect.isEmpty else {
            return nil
        }

        let geometry = snapshot.context.geometry
        return CaretDebugOverlaySnapshot(
            caretRect: caretRect,
            fieldRect: geometry.fieldRect,
            isRightToLeft: geometry.isRightToLeft
        )
    }

    /// Compact, privacy-conscious one-line summary of a `TextFieldContext` for diagnostics.
    /// It deliberately excludes captured text and user-controlled labels/titles because this
    /// value is emitted through the macOS unified log.
    static func summary(for snapshot: FocusedFieldSnapshot) -> String {
        let ctx = snapshot.context
        let rect = snapshot.caretRect
            .map { "(\(Int($0.minX)),\(Int($0.minY))) \(Int($0.width))x\(Int($0.height))" }
            ?? "nil"
        let qual = snapshot.caretQuality ?? "n/a"
        let source = snapshot.caretSource ?? "n/a"
        return """
        AX[\(ctx.target.bundleIdentifier)] \
        before=\(ctx.beforeCursor.count)ch after=\(ctx.afterCursor.count)ch \
        selection=\(ctx.selection.selectedText?.count ?? 0)ch labels=\(ctx.labels.count) \
        languageDetected=\(ctx.detectedLanguage != nil) domainDetected=\(ctx.target.domain != nil) \
        eol=\(ctx.geometry.isAtEndOfLine) rtl=\(ctx.geometry.isRightToLeft) \
        rect=\(rect) caret=\(source)/\(qual)
        """
    }

    static func shouldPreserveLatestTunableSnapshotOnMissingSnapshot(frontmostBundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier = frontmostBundleIdentifier?.lowercased() else {
            return false
        }
        if let ownBundleIdentifier = Bundle.main.bundleIdentifier?.lowercased(),
           bundleIdentifier == ownBundleIdentifier {
            return true
        }
        return bundleIdentifier.hasPrefix("com.heer12354.writelong")
            || bundleIdentifier.hasPrefix("com.pattonium.keytype")
    }

    private static func isKeyTypeTarget(_ target: AppTarget) -> Bool {
        let bundleIdentifier = target.bundleIdentifier.lowercased()
        if let ownBundleIdentifier = Bundle.main.bundleIdentifier?.lowercased(),
           bundleIdentifier == ownBundleIdentifier {
            return true
        }
        if bundleIdentifier.hasPrefix("com.heer12354.writelong")
            || bundleIdentifier.hasPrefix("com.pattonium.keytype") {
            return true
        }
        return target.appName.localizedCaseInsensitiveContains("Writelong")
            || target.appName.localizedCaseInsensitiveContains("KeyType")
    }
    
}
