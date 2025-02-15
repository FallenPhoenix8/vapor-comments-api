import Vapor

actor WebSocketManagerStore {
    private var websockets: [UUID: WebSocketManager] = [:]

    func addWebSocket(for discussionId: UUID, manager: WebSocketManager) {
        websockets[discussionId] = manager
    }

    func getWebSocket(for discussionId: UUID) -> WebSocketManager? {
        return websockets[discussionId]
    }
}
