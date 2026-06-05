import Foundation
import WatchConnectivity
import os

/// Um ditado de áudio recebido do Apple Watch (captura complementar).
struct WatchDitado: Identifiable, Equatable {
    let id: String
    let url: URL
    let receivedAt: Date
    let duration: TimeInterval?
}

/// Caixa de entrada dos áudios gravados no Apple Watch (modelo COMPLEMENTO).
/// O watch grava → `WCSession.transferFile` → aqui. Entrega é oportunística
/// (enfileirada, chega mesmo com o iPhone bloqueado quando reconecta). Sem auth:
/// o pareamento watch↔iPhone já é a confiança. Áudio é transitório (LGPD).
@Observable @MainActor
final class WatchAudioInbox: NSObject {
    static let shared = WatchAudioInbox()
    private let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "watch-inbox")

    private(set) var pending: [WatchDitado] = []

    /// Pasta persistente da inbox (o arquivo temp do WCSession é apagado após o delegate).
    nonisolated static var inboxDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchDitados", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Ativa cedo (no launch do app), nos dois lados. Não usa isReachable.
    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        loadExisting()
    }

    func remove(_ d: WatchDitado) {
        try? FileManager.default.removeItem(at: d.url)
        pending.removeAll { $0.id == d.id }
    }

    /// Carrega ditados já na pasta (recebidos com o app fechado).
    private func loadExisting() {
        let dir = Self.inboxDir
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for f in files where f.pathExtension == "m4a" {
            let id = f.deletingPathExtension().lastPathComponent
            guard !pending.contains(where: { $0.id == id }) else { continue }
            let date = (try? f.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            pending.append(WatchDitado(id: id, url: f, receivedAt: date, duration: nil))
        }
        pending.sort { $0.receivedAt > $1.receivedAt }
    }

    fileprivate func addPending(id: String, url: URL, duration: TimeInterval?, receivedAt: Date) {
        guard !pending.contains(where: { $0.id == id }) else { return }   // dedup por id
        pending.insert(WatchDitado(id: id, url: url, receivedAt: receivedAt, duration: duration), at: 0)
        log.info("ditado do watch recebido: \(id, privacy: .public)")
    }
}

extension WatchAudioInbox: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let meta = file.metadata ?? [:]
        let id = (meta["id"] as? String) ?? UUID().uuidString
        let dur = meta["duration"] as? Double
        // Copia SÍNCRONO aqui — o arquivo temp é removido após o retorno do delegate.
        let dest = Self.inboxDir.appendingPathComponent("\(id).m4a")
        if !FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.copyItem(at: file.fileURL, to: dest)
        }
        let when = Date()
        Task { @MainActor in self.addPending(id: id, url: dest, duration: dur, receivedAt: when) }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reativa pra continuar recebendo (troca de watch etc.).
        WCSession.default.activate()
    }
}
