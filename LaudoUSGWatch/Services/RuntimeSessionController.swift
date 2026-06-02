import Foundation
import WatchKit
import os

@MainActor
final class RuntimeSessionController: NSObject, @preconcurrency WKExtendedRuntimeSessionDelegate {
    private let log = Logger(subsystem: "com.laudousg.LaudoUSG.watch", category: "Runtime")
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        self.session = session
        // Usar start() simples. NÃO usar start(at:) — exclusivo de smart alarm.
        session.start()
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        log.info("Extended runtime started")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        log.info("Extended runtime will expire")
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        log.info("Extended runtime invalidated: \(reason.rawValue, privacy: .public)")
        if extendedRuntimeSession === session {
            session = nil
        }
    }
}
