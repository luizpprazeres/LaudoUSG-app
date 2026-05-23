import Foundation

enum SSEStreamer {
    static func stream<Event: Decodable & Sendable>(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var frameBytes: [UInt8] = []
                var previousWasNewline = false

                do {
                    for try await byte in bytes {
                        guard !Task.isCancelled else {
                            continuation.finish()
                            return
                        }

                        guard byte != 13 else { continue }

                        frameBytes.append(byte)

                        if byte == 10 {
                            if previousWasNewline {
                                frameBytes.removeLast(2)
                                decodeFrame(frameBytes, continuation: continuation)
                                frameBytes.removeAll(keepingCapacity: true)
                                previousWasNewline = false
                            } else {
                                previousWasNewline = true
                            }
                        } else {
                            previousWasNewline = false
                        }
                    }

                    if !frameBytes.isEmpty {
                        decodeFrame(frameBytes, continuation: continuation)
                    }

                    continuation.finish()
                } catch {
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func decodeFrame<Event: Decodable & Sendable>(
        _ frameBytes: [UInt8],
        continuation: AsyncThrowingStream<Event, Error>.Continuation
    ) {
        guard let frame = String(bytes: frameBytes, encoding: .utf8) else {
            print("SSEStreamer: frame UTF-8 inválido ignorado.")
            return
        }

        let trimmed = frame.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else { return }

        let dataLines = frame
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { dataValue(from: String($0)) }

        guard !dataLines.isEmpty else { return }

        let dataString = dataLines.joined(separator: "\n")
        guard let data = dataString.data(using: .utf8) else {
            print("SSEStreamer: payload SSE inválido ignorado.")
            return
        }

        do {
            let event = try JSONDecoder.api.decode(Event.self, from: data)
            continuation.yield(event)
        } catch {
            print("SSEStreamer: falha ao decodificar frame SSE: \(error)")
        }
    }

    private static func dataValue(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }

        var value = String(line.dropFirst(5))
        if value.first == " " {
            value.removeFirst()
        }
        return value
    }
}
