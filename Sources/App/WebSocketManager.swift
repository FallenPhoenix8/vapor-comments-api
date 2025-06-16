import Fluent
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

  private var heartbeatTimers: [(WebSocket, Timer)] = []
  private let heartbeatTimeout: TimeInterval = 60  // 60 seconds -> 1 minute

  /// Initializes a new instance of `WebSocketManager`.
  /// - Parameter threadLabel: This is the label used to create the dispatch queue. It is used to identify the queue.
  init(threadLabel: String) {
    queue = .init(label: threadLabel)
  }

  func handleHeartbeat(
    from ws: WebSocket, participantOnlineHandler: @escaping @Sendable () async -> Void
  ) async {
    // Reset heartbeat timer
    if let index = heartbeatTimers.firstIndex(where: { $0.0 === ws }) {
      heartbeatTimers[index].1.invalidate()
    }

    // Set up a new heartbeat timer
    let timer = Timer.scheduledTimer(withTimeInterval: heartbeatTimeout, repeats: false) {
      [weak self] _ in
      Task.init {
        await participantOnlineHandler()
      }
      self?.removeConnection(ws)
    }

    heartbeatTimers.append((ws, timer))
  }

  /// Adds a new WebSocket connection to the manager.
  /// - Parameter ws: The WebSocket connection to add.
  public func addConnection(_ ws: WebSocket, req: Request) {

    ws.onClose.whenComplete { _ in
      self.removeConnection(ws)
    }

    ws.eventLoop.execute {
      ws.onText { ws, text in
        let dict =
          try? JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: [])
          as? [String: Any]

        switch dict?["type"] as? String {
        case "heartbeat":
          let participantId = dict?["participantId"] as? String
          guard let participantId = participantId else {
            return
          }

          guard let participantUUID = UUID(uuidString: participantId) else {
            return
          }
          Task.init {

            await self.handleHeartbeat(from: ws) {
              try? await Participant.updateLastActive(participantUUID, on: req.db)
              try? await Participant.updateStatus(participantUUID, status: .inactive, on: req.db)
            }

            try? await Participant.updateLastActive(participantUUID, on: req.db)
            try? await Participant.updateStatus(participantUUID, status: .active, on: req.db)

            let participant =
              try await Participant
              .query(on: req.db)
              .filter(\.$id == participantUUID)
              .with(\.$discussion)
              .first()

            guard let participant = participant else {
              throw Abort(.notFound, reason: "Participant not found")
            }

            ws.onClose.whenComplete { _ in
              Task.init {
                try? await Participant.updateStatus(participantUUID, status: .inactive, on: req.db)
                self.removeConnection(ws)
              }
            }

            try await broadcastUpdate(req, discussionId: participant.discussion.requireID())
          }
        default:
          print("Unknown message type: \(dict?["type"] ?? "nil")")
        }

      }

      type(of: self).wsConnections.append(ws)

      // Set up heartbeat timer

    }
  }

  /// Removes a WebSocket connection from the manager.
  /// - Parameter ws: The WebSocket connection to remove.
  private func removeConnection(_ ws: WebSocket) {
    queue.sync {
      type(of: self).wsConnections = type(of: self).wsConnections.filter { $0 !== ws }
    }

    // Invalidate heartbeat timer
    if let index = heartbeatTimers.firstIndex(where: { $0.0 === ws }) {
      heartbeatTimers[index].1.invalidate()
      heartbeatTimers.remove(at: index)
    }
  }

  /// Broadcasts a message to all connected WebSocket clients.
  /// - Parameter message: The message to broadcast.
  public func broadcast(_ message: Data, messageType: String) {
    guard
      var jsonMessage = try? JSONSerialization.jsonObject(with: message, options: [])
        as? [String: Any]
    else {
      print("Failed to convert message to JSON", message)
      return
    }

    jsonMessage["type"] = messageType

    let fullJSONData = try? JSONSerialization.data(withJSONObject: jsonMessage, options: [])

    guard let fullJSONData = fullJSONData else {
      print("Failed to convert message to JSON", message)
      return
    }

    queue.sync {
      for ws in type(of: self).wsConnections {
        ws.send(fullJSONData)
      }
    }
  }
}
