// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

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
/// protocol CreatePostUseCaseScope: Sendable {
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
    /// The scope and its transaction-bound repositories must not be used after the operation
    /// returns or throws. `Sendable` permits safe sharing; it does not extend their lifetime.
    associatedtype Scope: Sendable

    /// Runs `operation` in a transaction, committing when it returns and rolling back when it
    /// throws.
    ///
    /// A closure formed in the caller's actor context can capture non-Sendable actor-local
    /// state and access it before and after suspension. Other work on that actor may run while
    /// the operation is suspended. Rolling back the database does not undo in-memory mutations.
    ///
    /// The operation is nonescaping. Complete all work using its scope before returning;
    /// neither the scope nor its transaction-bound repositories may be retained for later use.
    ///
    /// The error `operation` throws is rethrown unchanged, so a caller catches the domain error
    /// its repository raised rather than a wrapper the driver put around it.
    ///
    /// - Parameter operation: The unit of work. Receives the scope for this transaction.
    /// - Returns: Whatever `operation` returned, after the transaction committed.
    func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T
}
