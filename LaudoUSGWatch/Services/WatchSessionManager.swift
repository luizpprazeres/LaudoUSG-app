import Foundation
import WatchConnectivity
import WidgetKit
import os

/// Um ditado gravado na sessão atual do Watch + seu status de entrega.
struct QueuedDitado: Identifiable, Equatable {
    let id: String
    let recordedAt: Date
    let duration: TimeInterval
    var delivered: Bool
}

/// Envia os áudios gravados no Watch pro iPhone pareado (modelo COMPLEMENTO) e
/// mantém a FILA da sessão com status de entrega. `transferFile` é persistente:
/// o sistema enfileira e reentrega sozinho quando o iPhone reconecta.
@Observable @MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()
    private let log = Logger(subsystem: "com.laudousg.watch", category: "wcsession")

    private(set) var queue: [QueuedDitado] = []
    var pendingCount: Int { queue.lazy.filter { !$0.delivered }.count }

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    func send(fileURL: URL, duration: TimeInterval) {
        let id = fileURL.deletingPathExtension().lastPathComponent
        WCSession.default.transferFile(fileURL, metadata: ["id": id, "duration": duration])
        queue.insert(QueuedDitado(id: id, recordedAt: Date(), duration: duration, delivered: false), at: 0)
        log.info("transfer iniciado: \(id, privacy: .public)")
        syncComplication()
    }

    /// Escreve a contagem no App Group + recarrega a complication da carátula.
    private func syncComplication() {
        let d = UserDefaults(suiteName: "group.com.laudousg.watch")
        d?.set(pendingCount, forKey: "pendingDitados")
        d?.set(queue.count, forKey: "sessionDitados")
        // Só este kind (respeita o budget de reloads do watchOS); chamado só em
        // mudança real (send + didFinish), não em loop.
        WidgetCenter.shared.reloadTimelines(ofKind: "LaudoUSGDitados")
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
        let id = fileTransfer.file.metadata?["id"] as? String
        let ok = error == nil
        Task { @MainActor in
            if let id, let i = self.queue.firstIndex(where: { $0.id == id }) {
                self.queue[i].delivered = ok
            }
            self.syncComplication()
            if let error { self.log.error("transfer falhou: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
