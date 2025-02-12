import Fluent
import JWT
import Vapor

let fileManager: FileManager = .init()
let wsManagerComments: WebSocketManager = .init(threadLabel: "wsManagerComments")

func frontendProxy(_ req: Request) async throws -> Response {
    guard let frontendURLString = Environment.get("FRONTEND_URL") else {
        throw Abort(.internalServerError, reason: "FRONTEND_URL is not set")
    }

    let frontendURI = URI(string: frontendURLString + req.url.path)

    // Get the response from the frontendURI
    let clientResponse = try await req.client.get(frontendURI, headers: req.headers)

    let response: Response = .init(status: clientResponse.status, headers: clientResponse.headers)
    // Set the body of the Response
    if let body = clientResponse.body {
        response.body = .init(data: body.getData(at: 0, length: body.readableBytes) ?? Data())
    }

    return response
}

func routes(_ app: Application) throws {
    // let protected = app.grouped(AuthMiddleware())
    let authController = AuthController()
    let discussionController = DiscussionController()
    let commentController = CommentController()
    try app.register(collection: authController)
    try app.register(collection: discussionController)
    try app.register(collection: commentController)

    app.get { req async throws -> Response in
        return try await frontendProxy(req)
    }

    app.get("**") { req async throws -> Response in
        return try await frontendProxy(req)
    }

    app.webSocket("ws", "comments") { _, ws in
        wsManagerComments.addConnection(ws)
    }

    // app.post("auth", "register") { req async throws -> User in
    //     try User.Create.validate(content: req)
    //     let create = try req.content.decode(User.Create.self)

    //     guard create.password == create.confirmPassword else {
    //         throw Abort(.badRequest, reason: "Passwords do not match")
    //     }

    //     let user = try User(username: create.username, passwordHash: Bcrypt.hash(create.password))
    //     try await user.save(on: req.db)

    //     return user
    // }

    // app.post("auth", "login") { req async throws -> [String: String] in
    //     let loginData = try req.content.decode(User.Login.self)
    //     let expiration = Date().addingTimeInterval(60 * 60 * 24 * 7 /* 7 days */ )

    //     guard let user = try await User.query(on: req.db).filter(\.$username == loginData.username).first() else {
    //         throw Abort(.unauthorized, reason: "User not found")
    //     }

    //     guard try user.verify(password: loginData.password) else {
    //         throw Abort(.unauthorized, reason: "Incorrect password")
    //     }

    //     let payload = User.Payload(
    //         subject: SubjectClaim(value: user.id!.uuidString),
    //         expiration: .init(value: expiration)
    //     )
    //     let token = try await req.jwt.sign(payload)

    //     req.session.data["token"] = token

    //     return ["token": token]
    // }

    // auth.get("me") { req async throws -> String in
    //     let user = try await req.user()

    //     return "Hello, \(user.username)"
    // }
}
