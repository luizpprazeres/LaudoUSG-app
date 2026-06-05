import Foundation
import WatchConnectivity
import os

/// Envia os áudios gravados no Watch pro iPhone pareado (modelo COMPLEMENTO).
/// `transferFile` é oportunístico: enfileira e entrega quando o iPhone reconecta
/// (mesmo bloqueado). Sem auth — o pareamento já é a confiança.
@Observable @MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()
    private let log = Logger(subsystem: "com.laudousg.watch", category: "wcsession")

    private(set) var pending = 0
    private(set) var lastSentAt: Date?

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    func send(fileURL: URL, duration: TimeInterval) {
        let id = fileURL.deletingPathExtension().lastPathComponent
        let meta: [String: Any] = ["id": id, "duration": duration]
        WCSession.default.transferFile(fileURL, metadata: meta)
        pending += 1
        lastSentAt = Date()
        log.info("transfer iniciado: \(id, privacy: .public)")
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            self.pending = max(0, self.pending - 1)
            if let error { self.log.error("transfer falhou: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
