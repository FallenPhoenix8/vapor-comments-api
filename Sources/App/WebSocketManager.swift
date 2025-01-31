import Vapor

final class WebSocketManager: @unchecked Sendable {
    nonisolated(unsafe) static var wsConnections: [WebSocket] = []

    let queue: DispatchQueue
    init(threadLabel: String) {
        queue = .init(label: threadLabel)
    }

    func addConnection(_ ws: WebSocket) {
        ws.onClose.whenComplete { _ in
            self.removeConnection(ws)
        }

        queue.sync {
            type(of: self).wsConnections.append(ws)
        }
    }

    private func removeConnection(_ ws: WebSocket) {
        queue.sync {
            type(of: self).wsConnections = type(of: self).wsConnections.filter { $0 !== ws }
        }
    }

    func broadcast(_ message: Data) {
        queue.sync {
            for ws in type(of: self).wsConnections {
                ws.send(message)
            }
        }
    }
}
