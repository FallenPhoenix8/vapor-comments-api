import Fluent
import FluentPostgresDriver
import JWT
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    // app.middleware.use(NoCacheMiddleware())
    // register routes
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    // cors middleware should come before default error middleware using `at: .beginning`
    app.middleware.use(cors, at: .beginning)

    app.sessions.configuration.cookieName = "vapor-comments"

    app.sessions.configuration.cookieFactory = { sessionId in
        .init(string: sessionId.string, isSecure: true)
    }

    app.middleware.use(app.sessions.middleware)

    app.databases.use(
        .postgres(
            configuration: .init(
                hostname: Environment.get("DB_HOST") ?? "localhost",
                username: Environment.get("DB_USERNAME") ?? "vapor",
                password: Environment.get("DB_PASSWORD") ?? "vapor",
                database: Environment.get("DB_NAME") ?? "vapor",
                tls: .disable
            )
        ),
        as: .psql
    )

    app.migrations.add(User.Migration(), to: .psql)
    app.migrations.add(CreateDiscussion(), to: .psql)
    app.migrations.add(CreateComments(), to: .psql)

    await app.jwt.keys.add(hmac: HMACKey(stringLiteral: Environment.get("JWT_SECRET") ?? "secret"), digestAlgorithm: .sha256)

    if let port = Environment.get("PORT") {
        app.http.server.configuration.port = Int(port) ?? 8080
    } else {
        app.http.server.configuration.port = 8080
    }

    try routes(app)
}
