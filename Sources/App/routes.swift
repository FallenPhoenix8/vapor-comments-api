import Vapor

let fileManager: FileManager = .init()
let wsManagerComments: WebSocketManager = .init(threadLabel: "wsManagerComments")

func routes(_ app: Application) throws {
    app.get("api", "comments") { req throws -> Response in
        if !fileManager.fileExists(atPath: "Sources/comments.json") {
            _ = fileManager.createFile(atPath: "Sources/comments.json", contents: "[]".data(using: String.Encoding.utf8))
        }

        let res = req.fileio.streamFile(at: "Sources/comments.json")
        return res
    }

    app.delete("api", "delete-comment") { req async throws -> Response in
        var comments: [Comment] = []
        do {
            let id = try req.query.get(Double.self, at: "id")
            let comment = try Comment(id: id)
            comments = try await comment.delete()
        } catch let err {
            _ = Abort(.internalServerError, reason: "Error deleting comment: \(err)")
        }

        do {
            try wsManagerComments.broadcast(JSONEncoder().encode(comments))
        } catch {
            _ = Abort(.badRequest, reason: "Invalid JSON data")
        }

        return req.fileio.streamFile(at: "Sources/comments.json")
    }

    app.post("api", "add-comment") { req async throws -> Response in
        let content = try req.query.get(String.self, at: "content")

        let comment = Comment(content: content)
        let comments = try await comment.add()

        try wsManagerComments.broadcast(JSONEncoder().encode(comments))

        return req.fileio.streamFile(at: "Sources/comments.json")
    }

    app.webSocket("ws", "comments") { _, ws in
        wsManagerComments.addConnection(ws)
    }
}
