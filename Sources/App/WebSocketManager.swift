import Vapor

/// Manages multiple connections to a WebSocket, allowing for messages to be broadcast to all connected clients.
///
/// This class is thread-safe and can be used to manage connections to a single WebSocket from multiple threads.
///
/// To use this class:
///
/// 1. Create an instance of `WebSocketManager`.
/// 2. When a new WebSocket connection is made, call `addConnection(_:)` with the new WebSocket.
/// 3. When a message is sent to the WebSocket, call `broadcast(_:)` with the message.
final class WebSocketManager: @unchecked Sendable {
    /// The array of WebSocket connections managed by this manager.
    private nonisolated(unsafe) static var wsConnections: [WebSocket] = []

    /// The dispatch queue used to synchronize access to the `wsConnections` array.
    private let queue: DispatchQueue

    /// Initializes a new instance of `WebSocketManager`.
    /// - Parameter threadLabel: This is the label used to create the dispatch queue. It is used to identify the queue.
    init(threadLabel: String) {
        queue = .init(label: threadLabel)
    }

    /// Adds a new WebSocket connection to the manager.
    /// - Parameter ws: The WebSocket connection to add.
    public func addConnection(_ ws: WebSocket) {
        ws.onClose.whenComplete { _ in
            self.removeConnection(ws)
        }

        queue.sync {
            type(of: self).wsConnections.append(ws)
        }
    }

    /// Removes a WebSocket connection from the manager.
    /// - Parameter ws: The WebSocket connection to remove.
    private func removeConnection(_ ws: WebSocket) {
        queue.sync {
            type(of: self).wsConnections = type(of: self).wsConnections.filter { $0 !== ws }
        }
    }

    /// Broadcasts a message to all connected WebSocket clients.
    /// - Parameter message: The message to broadcast.
    public func broadcast(_ message: Data) {
        queue.sync {
            for ws in type(of: self).wsConnections {
                ws.send(message)
            }
        }
    }
}
