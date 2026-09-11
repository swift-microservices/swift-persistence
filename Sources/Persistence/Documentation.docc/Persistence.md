# ``Persistence``

A transaction boundary that hands a unit of work exactly the repositories it may touch.

## Overview

`Persistence` is one protocol, ``Database``, and depends on nothing. A domain target links it to
declare that its use cases run inside transactions, without linking a database driver. The
driver lives in a separate package, such as swift-persistence-postgres, which the composition
root links and the domain never sees.

The protocol is generic over a `Scope`: the set of repositories a transaction exposes. Each use
case declares the scope it needs as a protocol, the application's concrete scope conforms to all
of them, and the database builds a fresh scope on each transaction's connection.

## Example

A use case declares the scope it needs and takes `any Database` over it:

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

## Topics

### The boundary

- ``Database``

### Design

- <doc:TransactionsAndScopes>
