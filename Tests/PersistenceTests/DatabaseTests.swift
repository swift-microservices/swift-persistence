//
//  DatabaseTests.swift
//  swift-persistence
//
//  Created by Zaid Rahhawi on 9/11/26.
//

import Persistence
import Testing

/// The shape the package promises: a use case declares the scope it needs, takes `any Database`
/// over it, and is handed that scope inside a transaction.
@Suite
struct DatabaseTests {
    @Test("A use case is handed its scope through any Database<Scope>")
    func useCaseReceivesItsScope() async throws {
        let postRepository = InMemoryPostRepository()
        let useCase = CreatePostUseCase(database: ScopeDatabase(scope: Scope(postRepository: postRepository)))

        try await useCase(input: CreatePostUseCaseInput(title: "Hello"))

        #expect(await postRepository.titles == ["Hello"])
    }

    @Test("A transaction preserves the caller's actor isolation through any Database")
    func transactionInheritsCallerIsolation() async throws {
        let caller = TransactionCaller()
        let database: any Database<Int> = ScopeDatabase(scope: 42)

        let result = try await caller.run(database: database)

        #expect(result == 42)
        #expect(await caller.calls == 2)
    }

    @Test("A transaction preserves MainActor isolation across suspension")
    @MainActor
    func transactionInheritsMainActorIsolation() async throws {
        let database: any Database<Int> = ScopeDatabase(scope: 42)
        var calls = 0

        let result = try await database.withTransaction { scope in
            MainActor.preconditionIsolated()
            calls += 1
            await Task.yield()
            MainActor.preconditionIsolated()
            calls += 1
            return scope
        }

        #expect(result == 42)
        #expect(calls == 2)
    }
}

/// A database that hands one scope to every transaction. What commit and rollback mean is the
/// driver's to prove; here only the shape matters.
struct ScopeDatabase<Scope: Sendable>: Database {
    let scope: Scope

    func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T {
        try await operation(scope)
    }
}

private actor TransactionCaller {
    private(set) var calls = 0

    func run(database: any Database<Int>) async throws -> Int {
        try await database.withTransaction { scope in
            self.preconditionIsolated()
            calls += 1
            await Task.yield()
            self.preconditionIsolated()
            calls += 1
            return scope
        }
    }
}

protocol PostRepository: Sendable {
    func create(title: String) async throws
}

protocol CreatePostUseCaseScope: Sendable {
    var postRepository: any PostRepository { get }
}

struct Scope: CreatePostUseCaseScope {
    let postRepository: any PostRepository
}

struct CreatePostUseCaseInput {
    let title: String
}

struct CreatePostUseCase<Scope: CreatePostUseCaseScope> {
    let database: any Database<Scope>

    func callAsFunction(input: CreatePostUseCaseInput) async throws {
        try await database.withTransaction { scope in
            try await scope.postRepository.create(title: input.title)
        }
    }
}

actor InMemoryPostRepository: PostRepository {
    private(set) var titles: [String] = []

    func create(title: String) {
        titles.append(title)
    }
}
