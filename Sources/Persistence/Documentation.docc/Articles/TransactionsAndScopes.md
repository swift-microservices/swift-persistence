# Transactions and scopes

What a transaction hands to the work inside it, and how a use case asks for it.

## One boundary, one shape

An application's persistence has one entry point: ``Database/withTransaction(_:)``. The closure
it takes is the unit of work. When the closure returns, the transaction commits; when it throws,
the transaction rolls back and the same error reaches the caller.

The package enables `NonisolatedNonsendingByDefault` in Swift 6 mode. A closure formed in an
actor context can capture non-Sendable state and read and update it before and after suspension.
An `await` may let other work on that actor run. The transaction does not make a sequence of
in-memory mutations atomic, and a database rollback does not undo those mutations.

The callback is nonescaping. It does not require `@Sendable`, which would restrict its captures,
or `@concurrent`, which would change its execution contract. The database handle, scope, and
result remain `Sendable` as part of this API's contract.

## A scope is what the work may touch

The `Scope` is the value handed to the closure. It holds repositories, each built on the
transaction's connection, so every operation inside the closure shares one transaction.

The scope and its transaction-bound repositories are valid only while the operation is running.
Finish all work using them before returning or throwing. Do not retain them for later use or
launch tasks that outlive the operation and continue using them. A nonescaping closure does not
prevent its arguments from escaping, and `Sendable` does not extend their lifetime; callers must
respect this rule.

A use case does not take the application's whole scope. It declares a protocol naming only the
repositories it uses, and takes `any Database<Scope>` constrained to that protocol:

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

The application's concrete scope conforms to every use case's scope protocol, and the
composition root supplies one database for all of them. A test supplies a scope of mocks. The
use case is written once against the protocol and sees neither.

## What a database knows

A conforming database knows how to begin, commit, and roll back, how to build a scope on a
connection, and, if the application needs it, how to configure the session for the caller. It
knows nothing about what a caller is or what a repository does. Those belong to the application.

Drivers adopting the protocol should enable `NonisolatedNonsendingByDefault` on their own target.
The feature applies to async function types, including the operation parameter; annotating only
the method does not change a callback type compiled with the older defaults. Implementations
must accept the protocol's plain async callback without adding `@Sendable` or `@concurrent`.

An actor-backed driver can use a nonisolated entry point with these caller-isolated semantics
and explicitly await its internal actor's operations. Moving the entire transaction method onto
the driver's actor would require transferring the non-Sendable callback across that boundary.
