@testable import App

import Testing
import VaporTesting

nonisolated(unsafe) var authToken: String?
nonisolated(unsafe) var discussionId: String?
nonisolated(unsafe) var commentId: String?

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

    @Test("Test migrating database")
    func testMigrateDatabase() async throws {
        try await withApp { app in
            try await app.autoRevert()
            try await app.autoMigrate()
        }
    }

    @Test("Test register user")
    mutating func testCreateUser() async throws {
        try await withApp { app in
            let json: [String: Any] = [
                "username": "testUsername",
                "password": "testPassword",
                "confirmPassword": "testPassword",
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: json)

            try await app.testing().test(.POST, "/auth/register", beforeRequest: { req in
                req.headers.contentType = .json
                req.body = .init(data: jsonData)
            }, afterResponse: { res in

                authToken = try res.content.decode([String: String].self)["token"]
                if let token = authToken {
                    print("Token: \(token)")
                } else {
                    print("TOKEN NOT FOUND")
                }

                #expect(res.status == .created && authToken != nil)
            })
        }
    }

    @Test("Test logging user out")
    func testLogout() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "/auth/logout", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                authToken = nil
                #expect(res.status == .seeOther)
            })
        }
    }

    @Test("Test logging user in")
    func testLogin() async throws {
        try await withApp { app in
            let json: [String: Any] = [
                "username": "testUsername",
                "password": "testPassword",
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: json)

            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                req.headers.contentType = .json
                req.body = .init(data: jsonData)
            }, afterResponse: { res in
                authToken = try res.content.decode([String: String].self)["token"]
                #expect(res.status == .ok && authToken != nil)
            })
        }
    }

    @Test("Test getting current user")
    func testGetMe() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "/auth/me", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)

            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test adding discussion")
    func testAddDiscussion() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "/api/discussions/create/test", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                discussionId = try res.content.decode([String: String].self)["id"]
                print("DiscussionId: \(discussionId ?? "NOT FOUND")")
                #expect(res.status == .created)
            })
        }
    }

    @Test("Test getting all discussions")
    func testGetDiscussions() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "/api/discussions", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test adding comment")
    func testAddComment() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/comments/add?content=test", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                commentId = try res.content.decode([String: String].self)["id"]
                print("CommentId: \(commentId ?? "NOT FOUND")")
                #expect(res.status == .created)
            })
        }
    }

    @Test("Test getting all comments")
    func testGetComments() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/comments", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test deleting comment")
    func testDeleteComment() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/comments/delete/\(commentId ?? "COMMENT ID NOT FOUND")", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                commentId = nil
                #expect(res.status == .seeOther)
            })
        }
    }

    @Test("Test deleting discussion")
    func testDeleteDiscussion() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/api/discussions/delete/\(discussionId ?? "DISCUSSION ID NOT FOUND")", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                discussionId = nil
                #expect(res.status == .seeOther)
            })
        }
    }

    @Test("Test deleting user")
    func testDeleteMe() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/auth/me", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                #expect(res.status == .seeOther)
            })
        }
    }
}
