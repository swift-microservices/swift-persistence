# Swift Persistence

[![Documentation](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/swift-microservices/swift-persistence/documentation)
[![Release](https://img.shields.io/github/v/release/swift-microservices/swift-persistence)](https://github.com/swift-microservices/swift-persistence/releases)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswift-microservices%2Fswift-persistence%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swift-microservices/swift-persistence)
[![CI](https://github.com/swift-microservices/swift-persistence/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/swift-microservices/swift-persistence/actions/workflows/ci.yml)

Swift Persistence is a transaction boundary that hands a unit of work exactly the repositories it
may touch. Your use cases run inside transactions without ever importing a database driver.

- 📦 One protocol, no dependencies
- 🔌 Drivers ship as separate packages, such as
  [swift-persistence-postgres](https://github.com/swift-microservices/swift-persistence-postgres)
- 🐧 Supports Linux (including the static SDK) and macOS 15+
- 🔧 Built with Swift 6.3+ in Swift 6 language mode

🔗 Jump to:
- 📖 [Overview](#-overview)
- 🏁 [Getting Started](#-getting-started)
- 📘 [Documentation](#-documentation)
- 🧰 [Release Info](#-release-info)
- 🛠️ [Support](#%EF%B8%8F-support)

## 📖 Overview

The package is one protocol, `Database`. Its one method, `withTransaction`, runs a closure in a
transaction. When the closure returns, the transaction commits. When it throws, the transaction
rolls back and the same error reaches the caller, unwrapped, so a use case catches the domain
error its repository raised.

The closure receives a **scope**: the repositories the work may use, built on the transaction's
connection, so everything inside the closure shares one transaction. Each use case declares the
scope it needs as a small protocol. The application's real scope conforms to all of them, and a
test hands in a scope of mocks. The use case is written once and never sees a connection, a
driver, or a query.

```swift
public protocol Database<Scope>: Sendable {
    associatedtype Scope: Sendable

    func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T
}
```

**Key Features:**
- 🧱 **Driver-free domain**: a domain target links only this package. The composition root links
  the driver, and the domain never sees it.
- 🎯 **Least privilege by type**: a use case asks for a scope protocol naming only the
  repositories it uses, and sees only those.
- ↩️ **Errors pass through**: a rolled-back transaction rethrows the closure's own error, not a
  driver wrapper.
- ⚡ **Swift Concurrency**: the closure runs on the caller's actor, so an actor can use its own
  state inside a transaction.
- 🧪 **Easy to test**: a test conforms a few lines to `Database` and hands in mocks, with no
  database running.

### Rules to know

- **Use the scope only inside the closure.** The scope and its repositories are tied to the
  transaction. Finish all work with them before the closure returns or throws. Don't store them
  for later, and don't start tasks that keep using them after the closure ends. Being `Sendable`
  doesn't make them live longer, and the compiler won't catch a mistake here.
- **The closure stays on your actor.** It runs with the caller's actor isolation, including after
  an `await`, so it can capture and change the actor's non-`Sendable` state. While the closure is
  suspended, other work on that actor may run. A database rollback doesn't undo changes you made
  to in-memory state.
- **Drivers should enable `NonisolatedNonsendingByDefault`.** This package enables it in Swift 6
  mode. It changes async callback types as well as methods, so a driver needs it on its own target
  to match. The callback is nonescaping and doesn't require `@Sendable` or `@concurrent`; a driver
  must accept it as a plain async closure.

## 🏁 Getting Started

### Prerequisites

- Swift version: Swift 6.3+
- Platforms: macOS 15+ or Linux

To install or upgrade Swift, see https://www.swift.org/install/

### Adding as a dependency

Add the package to your `Package.swift`, and the `Persistence` product to the target that holds
your use cases:

```swift
dependencies: [
    .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "1.0.0")
],
targets: [
    .target(
        name: "PostsDomain",
        dependencies: [
            .product(name: "Persistence", package: "swift-persistence")
        ]
    )
]
```

### Usage

#### A use case that runs in a transaction

A use case says which repositories it needs by declaring a scope protocol, then takes any
`Database` over that scope. `PostRepository` is your own repository protocol.

```swift
import Persistence

// Your repository protocol.
protocol PostRepository: Sendable {
    func create(title: String) async throws
}

// The repositories this use case may touch, and nothing else.
protocol CreatePostUseCaseScope: Sendable {
    var postRepository: any PostRepository { get }
}

struct CreatePostUseCaseInput {
    let title: String
}

struct CreatePostUseCase<Scope: CreatePostUseCaseScope> {
    let database: any Database<Scope>

    func callAsFunction(input: CreatePostUseCaseInput) async throws {
        // Commits when the closure returns; rolls back and rethrows when it throws.
        try await database.withTransaction { scope in
            try await scope.postRepository.create(title: input.title)
        }
    }
}
```

#### Testing with an in-memory database

A test doesn't need a real database. A `Database` that hands the same scope to every transaction
and a mock repository are enough to run the use case with Swift Testing:

```swift
import Persistence
import Testing

// Hands one scope to every transaction. Commit and rollback are the real driver's job.
struct InMemoryDatabase<Scope: Sendable>: Database {
    let scope: Scope

    func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T {
        try await operation(scope)
    }
}

actor MockPostRepository: PostRepository {
    private(set) var titles: [String] = []

    func create(title: String) {
        titles.append(title)
    }
}

struct TestScope: CreatePostUseCaseScope {
    let postRepository: any PostRepository
}

@Test func createsAPost() async throws {
    let postRepository = MockPostRepository()
    let database = InMemoryDatabase(scope: TestScope(postRepository: postRepository))
    let createPost = CreatePostUseCase(database: database)

    try await createPost(input: CreatePostUseCaseInput(title: "Hello"))

    #expect(await postRepository.titles == ["Hello"])
}
```

#### Using a real database

In production, the composition root picks a driver. With
[swift-persistence-postgres](https://github.com/swift-microservices/swift-persistence-postgres),
the application's scope builds its repositories on each transaction's connection, and
`PostgresDatabase` runs every transaction on a `PostgresClient` from PostgresNIO.
`PostgresPostRepository` is your own Postgres implementation of `PostRepository`.

```swift
import Logging
import PersistencePostgres
import PostgresNIO

struct AppScope: PostgresScope, CreatePostUseCaseScope {
    let postRepository: any PostRepository

    init(connection: PostgresConnection, logger: Logger) {
        self.postRepository = PostgresPostRepository(connection: connection, logger: logger)
    }
}

let database = PostgresDatabase<AppScope>(client: client, logger: logger)
let createPost = CreatePostUseCase(database: database)
```

The use case is unchanged: only the database handed to it differs.

## 📘 Documentation

- [API Documentation](https://swiftpackageindex.com/swift-microservices/swift-persistence/documentation)
  - the full reference on Swift Package Index
- [Transactions and scopes](https://swiftpackageindex.com/swift-microservices/swift-persistence/documentation/persistence/transactionsandscopes)
  - what a transaction hands to the work inside it, the scope-lifetime and isolation rules, and
  what a driver must do

Drivers:

| Package | Database |
| --- | --- |
| [swift-persistence-postgres](https://github.com/swift-microservices/swift-persistence-postgres) | PostgreSQL over PostgresNIO, with per-transaction session variables for row-level security |

Each driver proves the commit and rollback contract in its own tests, against its own database.

## 🧰 Release Info

- Versioning: [Semantic Versioning](https://semver.org). The public API is stable from 1.0.0, and
  only a new major version breaks it. CI checks every pull request for API breakage.
- Release notes: [GitHub Releases](https://github.com/swift-microservices/swift-persistence/releases)
- Version compatibility: CI tests Swift 6.3 and 6.4 (plus nightly toolchains) on Linux x86_64 and
  aarch64, and builds with the static Linux SDK.

## 🛠️ Support

If you have a question or found a problem, please
[open an issue](https://github.com/swift-microservices/swift-persistence/issues).

Pull requests are welcome. Keep a change focused, prove new behaviour with a test, and label the
pull request with its semantic version impact.

### Development

```sh
swift test
swift-format lint --strict --recursive Package.swift Sources Tests    # what the soundness check runs
```

## License

MIT. See [LICENSE](LICENSE).
