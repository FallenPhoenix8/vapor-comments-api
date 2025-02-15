@testable import App

import Fluent
import Testing
import VaporTesting

nonisolated(unsafe) var authToken: String?
nonisolated(unsafe) var discussionId: String?
nonisolated(unsafe) var commentId: String?
nonisolated(unsafe) var authToken2: String?

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
                #expect(res.status == .seeOther)
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
                let discussions = try res.content.decode([Discussion].self)
                discussionId = discussions.last!.id!.uuidString
                #expect(discussionId != nil)
            })
        }
    }

    @Test("Register 2nd user")
    mutating func testCreateUser2() async throws {
        try await withApp { app in
            let json: [String: Any] = [
                "username": "someoneElse",
                "password": "testPassword",
                "confirmPassword": "testPassword",
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: json)

            try await app.testing().test(.POST, "/auth/register", beforeRequest: { req in
                req.headers.contentType = .json
                req.body = .init(data: jsonData)
            }, afterResponse: { res in

                authToken2 = try res.content.decode([String: String].self)["token"]
                if let token = authToken {
                    print("Token: \(token)")
                } else {
                    print("TOKEN NOT FOUND")
                }

                #expect(res.status == .created && authToken != nil)
            })
        }
    }

    @Test("Test joining discussion")

    func testJoinDiscussion() async throws {
        try await withApp { app in
            try await app.testing().test(.POST,
                                         "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/join",
                                         beforeRequest: { req in
                                             print(authToken2 ?? "TOKEN NOT FOUND")
                                             req.headers.bearerAuthorization = .init(token: authToken2!)
                                         },
                                         afterResponse: { res in
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
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test getting discussion details")
    func testGetComments() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/details",
                                         beforeRequest: { req in
                                             print(authToken ?? "TOKEN NOT FOUND")
                                             req.headers.bearerAuthorization = .init(token: authToken!)
                                         },
                                         afterResponse: { res in
                                             let discussion = try await Discussion.query(on: app.db)
                                                 .filter(\.$id == UUID(uuidString: discussionId!) ?? UUID())
                                                 .with(\.$comments)
                                                 .first()

                                             guard let discussion = discussion else {
                                                 throw Abort(.notFound, reason: "Discussion not found")
                                             }

                                             commentId = discussion.$comments.value!.last!.$id.value!.uuidString
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

    @Test("Test leaving discussion")
    func testLeaveDiscussion() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/leave", beforeRequest: { req in
                print(authToken ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken!)
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test leaving discussion 2nd user")
    func testLeaveDiscussion2() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/leave", beforeRequest: { req in
                print(authToken2 ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken2!)
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test deleting discussion")
    func testDeleteDiscussion() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/api/discussions/\(discussionId ?? "DISCUSSION ID NOT FOUND")/delete", beforeRequest: { req in
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

    @Test("Test deleting 2nd user")
    func testDeleteMe2() async throws {
        try await withApp { app in
            try await app.testing().test(.DELETE, "/auth/me", beforeRequest: { req in
                print(authToken2 ?? "TOKEN NOT FOUND")
                req.headers.bearerAuthorization = .init(token: authToken2!)
            }, afterResponse: { res in
                #expect(res.status == .seeOther)
            })
        }
    }
}
