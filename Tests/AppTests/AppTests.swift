@testable import App
import Testing
import VaporTesting

@Suite("App Tests", .serialized)
struct AppTests {
    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("Test Adding a Comment")
    func addComment() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "add-comment?content=test", afterResponse: { res async in

                #expect(res.status == .ok)

                let comments = Comment.updateCommentGlobalStorage()
                #expect(comments[comments.count - 1].content == "test")
            })
        }
    }

    @Test("Test Deleting a Comment")
    func deleteComment() async throws {
        try await withApp { app in
            let comments = Comment.updateCommentGlobalStorage()
            try await app.testing().test(.DELETE, "delete-comment?id=\(comments[0].id)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Cleanup...")
    func cleanup() async throws {
        try await withApp { _ in
            try fileManager.removeItem(atPath: "Sources/comments.json")
        }
    }
}
