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
}

/// A database that hands one scope to every transaction. What commit and rollback mean is the
/// driver's to prove; here only the shape matters.
struct ScopeDatabase<Scope: Sendable>: Database {
    let scope: Scope

    func withTransaction<T: Sendable>(
        _ operation: @Sendable (Scope) async throws -> T
    ) async throws -> T {
        try await operation(scope)
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
