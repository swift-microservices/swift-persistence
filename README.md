# swift-persistence

A transaction boundary that hands a unit of work exactly the repositories it may touch.

One protocol, no dependencies. A domain target links it to say that its use cases run inside
transactions, without linking a database driver. The driver is a separate package the composition
root links and the domain never sees.

```swift
.package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.1.0"),
```

```swift
.product(name: "Persistence", package: "swift-persistence"),
```

## The boundary

```swift
public protocol Database<Scope>: Sendable {
    associatedtype Scope: Sendable

    func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T
}
```

When the closure returns, the transaction commits. When it throws, the transaction rolls back and
the same error reaches the caller: no wrapper, so a use case catches the domain error its
repository raised.

The transaction closure preserves the caller's actor isolation, including across suspension,
so an actor can capture non-Sendable local state inside the closure. Other work on the actor
may run while the closure is suspended. Database rollback does not undo in-memory mutations.

The package enables `NonisolatedNonsendingByDefault` in Swift 6 mode. Drivers adopting this
signature should enable the feature too: it affects async callback types as well as methods.
The callback is nonescaping and does not require `@Sendable` or `@concurrent`.

## The scope

The `Scope` is what the closure receives: repositories built on the transaction's connection, so
everything inside the closure shares one transaction.

Finish all work using the scope before the closure returns or throws. Do not retain its
transaction-bound repositories or launch tasks that use them beyond that point. `Sendable`
does not extend a transaction's lifetime, and the type system does not enforce this lifetime.

A use case declares the scope it needs as a protocol and takes `any Database` over it. The
application's concrete scope conforms to every use case's protocol; a test supplies a scope of
mocks. The use case is written once and sees neither.

```swift
protocol CreatePostUseCaseScope: Sendable {
    var postRepository: any PostRepository { get }
}

struct CreatePostUseCase<Scope: CreatePostUseCaseScope> {
    let database: any Database<Scope>

    func callAsFunction(input: CreatePostUseCaseInput) async throws {
        try await database.withTransaction { scope in
            try await scope.postRepository.create(title: input.title)
        }
    }
}
```

## Drivers

| Package | Database |
| --- | --- |
| [swift-persistence-postgres](https://github.com/swift-microservices/swift-persistence-postgres) | PostgreSQL over PostgresNIO, with per-transaction session variables for row-level security |

A driver proves the commit and rollback contract in its own tests, against its own database.

## Requirements

Swift 6.3, macOS 15 or Linux.

## Development

```sh
swift test
swift-format lint --strict --recursive Sources Tests    # what the soundness check runs
```

## Contributing

Pull requests are welcome. Keep a change focused, and prove new behaviour with a test.

## License

MIT. See [LICENSE](LICENSE).
