import Foundation

public struct Comment: Decodable, Encodable, Sendable {
    public nonisolated(unsafe) static var comments: [Comment] = []
    private static let queue = DispatchQueue(label: "comments")

    let id: Double
    let content: String

    init(content: String) {
        id = Date().timeIntervalSince1970
        self.content = content
    }

    static func updateCommentGlobalStorage() throws -> [Comment] {
        if !fileManager.fileExists(atPath: "Sources/comments.json") {
            _ = fileManager.createFile(atPath: "Sources/comments.json", contents: "[]".data(using: String.Encoding.utf8))
        }
        let savedComments = try JSONDecoder().decode([Comment].self, from: Data(contentsOf: URL(fileURLWithPath: "Sources/comments.json")))
        queue.sync {
            comments = savedComments
        }

        return comments
    }

    private static func writeComments(comments: [Comment]) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(comments)
        try data.write(to: URL(fileURLWithPath: "Sources/comments.json"))
        return data
    }

    func addComment() async throws -> [Comment] {
        var comments = try type(of: self).updateCommentGlobalStorage()
        comments.append(self)

        _ = try await type(of: self).writeComments(comments: comments)
        _ = try Comment.updateCommentGlobalStorage()

        return comments
    }

    static func deleteComment(id: Double) async throws -> [Comment] {
        var comments = try updateCommentGlobalStorage()
        comments = comments.filter { $0.id != id }
        _ = try await writeComments(comments: comments)
        _ = try Comment.updateCommentGlobalStorage()
        return comments
    }
}
