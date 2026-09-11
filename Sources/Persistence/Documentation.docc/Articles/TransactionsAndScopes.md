# Transactions and scopes

What a transaction hands to the work inside it, and how a use case asks for it.

## One boundary, one shape

An application's persistence has one entry point: ``Database/withTransaction(_:)``. The closure
it takes is the unit of work. When the closure returns, the transaction commits; when it throws,
the transaction rolls back and the same error reaches the caller.

## A scope is what the work may touch

The `Scope` is the value handed to the closure. It holds repositories, each built on the
transaction's connection, so every operation inside the closure shares one transaction.

A use case does not take the application's whole scope. It declares a protocol naming only the
repositories it uses, and takes `any Database<Scope>` constrained to that protocol:

```swift
protocol CreatePostUseCaseScope {
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

The application's concrete scope conforms to every use case's scope protocol, and the
composition root supplies one database for all of them. A test supplies a scope of mocks. The
use case is written once against the protocol and sees neither.

## What a database knows

A conforming database knows how to begin, commit, and roll back, how to build a scope on a
connection, and, if the application needs it, how to configure the session for the caller. It
knows nothing about what a caller is or what a repository does. Those belong to the application.
