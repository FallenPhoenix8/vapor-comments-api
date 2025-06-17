[![Local](https://github.com/FallenPhoenix8/vapor-comments/actions/workflows/swift.yml/badge.svg)](https://github.com/FallenPhoenix8/vapor-comments/actions/workflows/swift.yml)

# Description

The `vapor-comments-api`, a backend service built with Swift's Vapor framework, powers a discussion board application. It handles user authentication, discussion management, and comment storage. The API uses PostgreSQL for data persistence and supports server-side rendered client applications via WebSockets for real-time updates.

# Technologies used

- **Vapor**: a web framework for Swift, used for building the API and handling HTTP requests
- **Fluent**: an ORM for working with databases in Vapor, used for defining and interacting with the database schema
- **PostgreSQL**: a powerful open-source object-relational database system, used for storing and retrieving comments and user data
- **JWT**: JSON Web Tokens for authentication, used for generating and verifying tokens sent in the `Authorization` header of requests

# Getting started

## Environemntal variables

- **DB_HOST**: The hostname for your PostgreSQL database.
- **DB_USERNAME**: The username for connecting to your PostgreSQL database.
- **DB_PASSWORD**: The password for connecting to your PostgreSQL database.
- **DB_NAME**: The name of your PostgreSQL database.
- **JWT_SECRET**: The secret key used for signing and verifying JSON Web Tokens.
- **FRONTEND_URL**: The URL of the frontend application, used for CORS configuration.
- **PORT**: The port on which the Vapor server will run (default is 8080).

## Running dev scripts

In order to run the dev scripts, you need to have `watchexec` installed on your system.
If you are using brew package manager, it can be installed with following command:

```zsh
brew install watchexec
```

It's not possible to run both backend and frontend in a live development version. There are 2 dev scripts.
In order to run backend development script, execute the following script:

```zsh
sh ./dev-backend.sh
```

And in order to run frontend development script, execute this script:

```zsh
sh ./dev-frontend.sh
```

## Building for production

You can build the project using `build.sh` script.

```zsh
sh ./build.sh
```

# Routes

The backend API provides the following routes for managing authentication, discussions, and comments, along with example queries and outputs:

## Authentication Routes

- **POST /api/auth/register**: Register a new user.

  - Request Body: `{ "username": "newuser", "password": "password123", "confirmPassword": "password123" }`
  - Response: `201 Created` with user details.
  - Example Response:
    ```json
    {
      "id": "uuid-string",
      "username": "newuser"
    }
    ```

- **POST /api/auth/login**: Login an existing user.

  - Request Body: `{ "username": "existinguser", "password": "password123" }`
  - Response: `200 OK` with JWT token.
  - Example Response:
    ```json
    {
      "token": "jwt-token-string"
    }
    ```

- **POST /api/auth/logout**: Logout the current user.

  - Response: `302 Redirect` to home page.

- **DELETE /api/auth/me**: Delete the current user.

  - Response: `302 Redirect` to home page.

- **GET /api/auth/me**: Get details of the current user.

  - Response: `200 OK` with user details.
  - Example Response:
    ```json
    {
      "id": "uuid-string",
      "username": "existinguser"
    }
    ```

- **GET /api/auth/is-authenticated**: Check if the user is authenticated.

  - Response: `200 OK` or `401 Unauthorized`.
  - Example Response:
    ```json
    "true" // or "false" based on authentication status
    ```

- **GET /api/auth/username-exists**: Check if a username already exists.
  - Query: `?username=checkuser`
  - Response: `200 OK` with boolean result.
  - Example Response:
    ```json
    {
      "exists": true
    }
    ```

## Discussion Routes

- **GET /api/discussions**: Get a list of all discussions.

  - Response: `200 OK` with array of discussions.
  - Example Response:
    ```json
    [
      {
        "id": "uuid-string",
        "author": {
          "id": "uuid-string"
        },
        "updatedAt": "2025-06-16T22:55:40Z",
        "picture": null,
        "title": "A discussion title",
        "createdAt": "2025-06-16T22:55:40Z"
      }
    ]
    ```

- **GET /api/discussions/is-title-taken/:title**: Check if a discussion title is already taken.

  - Response: `200 OK` with boolean result.
  - Example Response:
    ```json
    {
      "isTaken": true
    }
    ```

- **POST /api/discussions/create/:title**: Create a new discussion with the given title.

  - Response: `303 See Other` to discussions list.
  - Example Response:
    ```json
    {
      "id": "uuid-string",
      "title": "New Discussion Title"
    }
    ```

- **DELETE /api/discussions/:discussionId/delete**: Delete a discussion by its ID.

  - Response: `303 See Other` to discussions list.

- **POST /api/discussions/:discussionId/join**: Join a discussion by its ID.

  - Response: `200 OK` with success message.
  - Example Response:
    ```json
    {
      "message": "Successfully joined discussion"
    }
    ```

- **GET /api/discussions/:discussionId/details**: Get details of a discussion by its ID.

  - Response: `200 OK` with discussion details.
  - Example Response:
    `json
{
      "id": "uuid-string",
      "title": "Discussion Title",
      "createdAt": "2023-10-01T12:00:00Z",
      "updatedAt": "2023-10-01T12:30:00Z",
      "author": {
        "id": "uuid-string",
        "username": "authorName"
      },
      "participants": [
        {
          "id": "uuid-string",
          "username": "participantName"
        }
      ],
      "comments": [
        {
          "id": "uuid-string",
          "content": "Comment content",
          "createdAt": "2023-10-01T12:45:00Z",
          "author": {
            "id": "uuid-string",
            "username": "commentAuthor"
          }
        }
      ]
    }
    `

- **GET /api/discussions/:discussionId/is-participant**: Check if the current user is a participant of the discussion.

  - Response: `200 OK` or `403 Forbidden`.
  - Example Response:
    ```json
    {
      "isParticipant": true
    }
    ```

- **WebSocket /api/discussions/:discussionId/ws**: Connect to the WebSocket for real-time updates on a discussion.
  - Establishes a WebSocket connection for updates.

## Comment Routes

- **POST /api/discussions/:discussionId/comments/add?content=_text_**: Add a comment to a discussion.

- **DELETE /api/discussions/:discussionId/comments/delete/:commentId**: Delete a comment by its ID in a discussion.

  - Response: `303 See Other` to the list of comments in the discussion.

## Participant Routes

- **GET /api/discussions/:discussionId/participants/:participantId**: Get a participant by their ID in a discussion.

  - Response: `200 OK` with participant details.

- **GET /api/discussions/:discussionId/participants/user/:userId**: Get a participant by user ID in a discussion.

  - Response: `200 OK` with participant details.

- **DELETE /api/discussions/:discussionId/participants/:participantId/comments**: Delete all comments from a participant in a discussion.
  - Response: `303 See Other` to discussion details.
