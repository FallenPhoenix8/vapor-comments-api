import Vapor

// enum WebSocketManager {
//     static func addConnection(_ ws: WebSocket) {
//         ws.onClose.whenComplete { _ in
//             removeConnection(ws)
//         }

//         GlobalStorage.wsConnections.append(ws)
//     }

//     private static func removeConnection(_ ws: WebSocket) {
//         GlobalStorage.wsConnections = GlobalStorage.wsConnections.filter { $0 !== ws }
//     }

//     static func broadcast(_ message: Data) {
//         for ws in GlobalStorage.wsConnections {
//             ws.send(message)
//         }
//     }
// }

final class WebSocketManager: @unchecked Sendable {
    nonisolated(unsafe) static var wsConnections: [WebSocket] = []
    static let queue = DispatchQueue(label: "wsConnections")

    static func addConnection(_ ws: WebSocket) {
        ws.onClose.whenComplete { _ in
            self.removeConnection(ws)
        }

        queue.sync {
            self.wsConnections.append(ws)
        }
    }

    private static func removeConnection(_ ws: WebSocket) {
        queue.sync {
            self.wsConnections = self.wsConnections.filter { $0 !== ws }
        }
    }

    static func broadcast(_ message: Data) {
        queue.sync {
            for ws in self.wsConnections {
                ws.send(message)
            }
        }
    }
}
