//
//  Database.swift
//  swift-persistence
//
//  Created by Zaid Rahhawi on 9/11/26.
//

/// The transaction boundary of an application, and the scope it hands to the work inside it.
///
/// A database is built once, at startup, and runs each unit of work in its own transaction.
/// The work receives a `Scope`: the set of repositories it may touch, constructed on the
/// transaction's connection so that every read and write inside the closure shares it.
///
/// A use case declares the scope it needs as a protocol and takes `any Database<ThatScope>`.
/// The composition root supplies a concrete database whose scope conforms to every use case's
/// protocol. The use case never sees a connection, a driver, or a query.
///
/// ```swift
/// protocol CreatePostUseCaseScope {
///     var postRepository: any PostRepository { get }
/// }
///
/// struct CreatePostUseCase<Scope: CreatePostUseCaseScope> {
///     let database: any Database<Scope>
///
///     func callAsFunction(input: CreatePostUseCaseInput) async throws {
///         try await database.withTransaction { scope in
///             try await scope.postRepository.create(title: input.title)
///         }
///     }
/// }
/// ```
public protocol Database<Scope>: Sendable {
    /// What the work inside a transaction is handed: the repositories it may use, built on the
    /// transaction's connection.
    associatedtype Scope: Sendable

    /// Runs `operation` in a transaction, committing when it returns and rolling back when it
    /// throws.
    ///
    /// The error `operation` throws is rethrown unchanged, so a caller catches the domain error
    /// its repository raised rather than a wrapper the driver put around it.
    ///
    /// - Parameter operation: The unit of work. Receives the scope for this transaction.
    /// - Returns: Whatever `operation` returned, after the transaction committed.
    func withTransaction<T: Sendable>(
        _ operation: @Sendable (Scope) async throws -> T
    ) async throws -> T
}
