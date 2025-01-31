import Vapor

let fileManager: FileManager = .init()

func routes(_ app: Application) throws {
    app.get { req async -> Response in
        req.fileio.streamFile(at: "Public/index.html")
    }

    app.get("hello") { _ async -> String in
        "Hello, world!"
    }

    app.get("comments") { req async throws -> Response in
        let res = req.fileio.streamFile(at: "Sources/comments.json")
        return res
    }

    app.delete("delete-comment") { req async throws -> Response in
        let id = try req.query.get(Double.self, at: "id")
        let comments = try await Comment.deleteComment(id: id)

        try WebSocketManager.broadcast(JSONEncoder().encode(comments))

        return req.fileio.streamFile(at: "Sources/comments.json")
    }

    app.patch("add-comment") { req async throws -> Response in
        let content = try req.query.get(String.self, at: "content")

        let comment = Comment(content: content)
        let comments = try await comment.addComment()

        try WebSocketManager.broadcast(JSONEncoder().encode(comments))

        return req.fileio.streamFile(at: "Sources/comments.json")
    }

    app.webSocket("ws") { _, ws in
        WebSocketManager.addConnection(ws)
    }
}
