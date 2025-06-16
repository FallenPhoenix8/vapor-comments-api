import Fluent
import Vapor

let store = WebSocketManagerStore()

func broadcastUpdate(_ req: Request, discussionId: UUID) async throws {
  let discussionDetails = try await Discussion.getDetails(request: req, discussionId: discussionId)

  let wsManager = await store.getWebSocket(for: discussionId)

  if let wsManager = wsManager {
    wsManager.broadcast(discussionDetails.getJSONData(), messageType: "discussion-update")
  }
}
/// Returns a list of all discussions.
///
/// - Returns: [Discussion]
///
/// - GET /api/discussions

/// Returns whether the given title is taken.
///
/// - Parameters:
///   - title: The title to check.
/// - Returns: Bool
///
/// - GET /api/discussions/is-title-taken/:title

/// Creates a new discussion with the given title.
///
/// - Parameters:
///   - title: The title of the discussion.
/// - Returns: Discussion
///
/// - POST /api/discussions/create/:title

/// Deletes the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion to delete.
/// - Returns: Void
///
/// - DELETE /api/discussions/:discussionId/delete

/// Leaves the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion to leave.
/// - Returns: Void
///
/// - DELETE /api/discussions/:discussionId/leave

/// Joins the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion to join.
/// - Returns: Void
///
/// - POST /api/discussions/:discussionId/join

/// Returns the details of the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion to get the details of.
/// - Returns: Discussion
///
/// - GET /api/discussions/:discussionId/details

/// Returns whether the user is a participant of the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion to check.
/// - Returns: Bool
///
/// - GET /api/discussions/:discussionId/is-participant

/// Returns the participant with the given id in the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion.
///   - participantId: The id of the participant.
/// - Returns: Participant
///
/// - GET /api/discussions/:discussionId/participants/:participantId

/// Returns the participant with the given user id in the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion.
///   - userId: The id of the user.
/// - Returns: Participant
///
/// - GET /api/discussions/:discussionId/participants/user/:userId

/// Deletes all comments from the participant with the given id in the discussion with the given id.
///
/// - Parameters:
///   - discussionId: The id of the discussion.
///   - participantId: The id of the participant.
/// - Returns: Void
///
/// - DELETE /api/discussions/:discussionId/participants/:participantId/comments
struct DiscussionController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    // let api = routes.grouped("api")
    let discussions = routes.grouped("discussions")
    let protected = discussions.grouped(AuthMiddleware())
    discussions.get(use: index)
    discussions.get("is-title-taken", ":title", use: isTitleTaken)

    protected.post("create", ":title", use: create)
    protected.delete(":discussionId", "delete", use: delete)
    protected.delete(":discussionId", "leave", use: leave)
    protected.post(":discussionId", "join", use: join)
    protected.get(":discussionId", "details", use: getDetails)
    protected.webSocket(":discussionId", "ws") { req, ws in
      await wsDiscussion(req, ws: ws, store: store)
    }
    protected.get(":discussionId", "is-participant", use: isParticipant)

    let discussionId = discussions.grouped(":discussionId")

    // comments
    let comments = discussionId.grouped("comments")
    let protectedComments = comments.grouped(AuthMiddleware())
    protectedComments.post("add", use: addComment)
    protectedComments.delete("delete", ":commentId", use: deleteComment)

    // participants
    let participants = discussionId.grouped("participants")
    let protectedParticipants = participants.grouped(AuthMiddleware())
    protectedParticipants.get(":participantId", use: getParticipantById)
    protectedParticipants.get("user", ":userId", use: getParticipantByUserId)
    protectedParticipants.delete(":participantId", "comments", use: deleteCommentsFromParticipant)
    protectedParticipants.delete("delete", use: deleteAllParticipantsFromDiscussion)
  }

  @Sendable
  func index(_ req: Request) async throws -> [Discussion] {
    return try await Discussion.query(on: req.db)
      .sort(\.$createdAt, .descending)
      .all()
  }

  @Sendable
  func create(_ req: Request) async throws -> Response {
    guard let title = req.parameters.get("title") else {
      throw Abort(.badRequest, reason: "Missing title")
    }

    let user = try await req.user()

    let discussion = Discussion(title: title, authorId: user.$id.value!)

    try await discussion.save(on: req.db)

    let participant = try Participant(
      discussionId: discussion.requireID(), userId: user.requireID(), isAuthor: true)
    try await participant.save(on: req.db)

    return req.redirect(to: "/api/discussions")
  }

  @Sendable
  func delete(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")

    guard let discussionUUID = UUID(uuidString: discussionId) else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let author = try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussionUUID)
      .filter(\.$isAuthor == true)
      .with(\.$user)
      .first()

    guard let author = author else {
      throw Abort(.notFound, reason: "Author not found")
    }

    let user = try await req.user()
    guard author.user.id == user.id else {
      throw Abort(.unauthorized, reason: "You are not the author of this discussion")
    }

    try await author.delete(on: req.db)

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    try await discussion.delete(on: req.db)
    // let discussions = try await Discussion.query(on: req.db).all()
    // let discussionsJSON: [[String: String]] = discussions.map { discussion in
    //     discussion.toDictionary()
    // }
    // let jsonData = try JSONEncoder().encode(discussionsJSON)
    // let res = Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: jsonData))

    return req.redirect(to: "/api/discussions")
  }

  @Sendable
  func join(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let user = try await req.user()
    let testParticipant = try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussion.requireID())
      .filter(\.$user.$id == user.requireID())
      .first()

    guard testParticipant == nil else {
      throw Abort(.badRequest, reason: "User already joined discussion")
    }

    let participant = try Participant(
      discussionId: discussion.requireID(), userId: user.requireID(), isAuthor: false)

    try await participant.save(on: req.db)

    try await broadcastUpdate(req, discussionId: discussion.requireID())

    return Response(status: .ok, body: .init(string: "Successfully joined discussion"))
  }

  @Sendable
  func getDetails(_ req: Request) async throws -> Discussion {
    let discussionId = try req.parameters.require("discussionId")

    let discussion = try await Discussion.getDetails(
      request: req, discussionId: UUID(uuidString: discussionId) ?? UUID())

    let isDiscussionIncludesUser =
      try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussion.requireID())
      .filter(\.$user.$id == req.user().requireID())
      .first() != nil

    if !isDiscussionIncludesUser {
      throw Abort(.unauthorized, reason: "User is not a participant of discussion")
    }

    return discussion
  }

  @Sendable
  func leave(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let user = try await req.user()
    let participant = try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussion.requireID())
      .filter(\.$user.$id == user.requireID())
      .first()

    guard let participant = participant else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    guard participant.isAuthor == false else {
      throw Abort(
        .badRequest, reason: "Cannot leave discussion as author. Please delete it instead.")
    }

    try await participant.delete(on: req.db)

    try await broadcastUpdate(req, discussionId: discussion.requireID())

    return Response(status: .ok, body: .init(string: "Successfully left discussion"))
  }

  @Sendable
  func wsDiscussion(_ req: Request, ws: WebSocket, store: WebSocketManagerStore) async {
    do {
      let discussionDetails = try await getDetails(req)

      let discussionManager = try WebSocketManager(
        threadLabel: discussionDetails.requireID().uuidString)
      discussionManager.addConnection(ws, req: req)
      let discussionId = try discussionDetails.requireID()

      // Safely add the WebSocketManager to the store
      await store.addWebSocket(for: discussionId, manager: discussionManager)

    } catch {
      print("ERROR CREATING DISCUSSION WEBSOCKET: \(error)")
    }
  }

  @Sendable
  func addComment(_ req: Request) async throws -> Comment {
    let discussionId = try req.parameters.require("discussionId")
    let content = try req.query.get(String.self, at: "content")

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let user = try await req.user()
    let userId = try user.requireID()

    let participant = try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussion.requireID())
      .filter(\.$user.$id == userId)
      .first()

    guard let participant = participant else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    let comment = try Comment(
      content: content, discussionId: discussion.requireID(), participantId: participant.requireID()
    )

    try await comment.save(on: req.db)

    try await broadcastUpdate(req, discussionId: discussion.requireID())

    return comment
  }

  @Sendable
  func deleteComment(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")
    let commentId = try req.parameters.require("commentId")

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let comment = try await Comment.find(UUID(uuidString: commentId), on: req.db)
    guard let comment = comment else {
      throw Abort(.notFound, reason: "Comment not found")
    }

    try await comment.delete(on: req.db)

    try await broadcastUpdate(req, discussionId: discussion.requireID())

    return req.redirect(to: "/api/discussions/\(discussionId)/comments")
  }

  @Sendable
  func isParticipant(_ req: Request) async throws -> Bool {
    let discussionId = try req.parameters.require("discussionId")

    let discussion = try await Discussion.find(UUID(uuidString: discussionId), on: req.db)
    guard let discussion = discussion else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let user = try await req.user()
    // print(try await req.user())
    let testParticipant = try await Participant.query(on: req.db)
      .filter(\.$discussion.$id == discussion.requireID())
      .filter(\.$user.$id == user.requireID())
      .first()

    return testParticipant != nil
  }

  @Sendable func getParticipantById(_ req: Request) async throws -> Participant {
    let participantId = try req.parameters.require("participantId")
    let participantUUID = UUID(uuidString: participantId)

    guard let participantUUID = participantUUID else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    // let participant = try await Participant
    // .find(UUID(uuidString: participantId), on: req.db)

    let participant = try await Participant.query(on: req.db)
      .with(\.$user)
      .filter(\.$id == participantUUID)
      .first()

    guard let participant = participant else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    return participant
  }

  @Sendable func getParticipantByUserId(_ req: Request) async throws -> Participant {
    let userId = try req.parameters.require("userId")
    let userUUID = UUID(uuidString: userId)

    guard let userUUID = userUUID else {
      throw Abort(.notFound, reason: "User not found")
    }

    let discussionId = try req.parameters.require("discussionId")
    let discussionUUID = UUID(uuidString: discussionId)

    guard let discussionUUID = discussionUUID else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let participant = try await Participant.query(on: req.db)
      .with(\.$discussion)
      .with(\.$user)
      .filter(\.$discussion.$id == discussionUUID)
      .filter(\.$user.$id == userUUID)
      .first()

    guard let participant = participant else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    return participant
  }

  @Sendable func deleteCommentsFromParticipant(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")
    let discussionUUID = UUID(uuidString: discussionId)

    guard let discussionUUID = discussionUUID else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let user = try await req.user()
    let userUUID = try user.requireID()

    let participant = try await Participant.query(on: req.db)
      .with(\.$discussion)
      .filter(\.$discussion.$id == discussionUUID)
      .filter(\.$user.$id == userUUID)
      .first()

    guard let participant = participant else {
      throw Abort(.notFound, reason: "Participant not found")
    }

    try await Comment.query(on: req.db)
      .filter(\.$participant.$id == participant.requireID())
      .delete()

    try await broadcastUpdate(req, discussionId: discussionUUID)

    return Response(status: .ok, body: .init(string: "Successfully deleted comments"))
  }

  @Sendable func isTitleTaken(_ req: Request) async throws -> Bool {
    let title = try req.parameters.require("title")
    return try await Discussion.isTitleTaken(title, on: req.db)
  }

  @Sendable func deleteAllParticipantsFromDiscussion(_ req: Request) async throws -> Response {
    let discussionId = try req.parameters.require("discussionId")
    let discussionUUID = UUID(uuidString: discussionId)

    guard let discussionUUID = discussionUUID else {
      throw Abort(.notFound, reason: "Discussion not found")
    }

    let participants = try await Participant.query(on: req.db)
      .with(\.$discussion)
      .with(\.$comments)
      .filter(\.$discussion.$id == discussionUUID)
      .all()

    /// Deleting all participants and their comments for this discussion
    for participant in participants {
      try await Comment.query(on: req.db)
        .filter(\.$participant.$id == participant.requireID())
        .delete()

      try await participant.delete(on: req.db)
    }

    return Response(status: .ok, body: .init(string: "Successfully deleted all participants"))
  }
}
