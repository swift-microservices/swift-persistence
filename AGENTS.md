# Repository guidelines

This package is the transaction boundary shared by every service in the organization. It is
deliberately small. Read this before changing anything.

## What this package is

- One product, `Persistence`, one protocol, `Database`. It depends on nothing, not even
  Foundation, so a domain target can link it without pulling a driver in behind it.
- Drivers live in their own packages (`swift-persistence-postgres`) and depend on this one by
  tag. Nothing driver-specific belongs here.
- The tests state the contract consumers rely on: a use case takes `any Database<Scope>` and is
  handed its scope; the operation keeps the caller's isolation from a custom actor and from
  `@MainActor` across suspension; a thrown error reaches the caller unchanged with its captured
  state intact; and cancelling the caller reaches the operation. A change to the protocol is a
  change to those tests first.

## What does not belong here

- Query, row, or connection abstractions. The driver's own types are that layer.
- Authorization, executors, or context objects. A use case decides what a caller may do.
- Migrations, pools, or configuration. Those are the composition root's.

## Swift

- Swift 6.3, strict concurrency, `Sendable` everywhere it is meaningful.
- Tests use Swift Testing. Commit and rollback semantics are a driver's to prove, in the
  driver's package, against its real database; they are not tested here.
- Doc comments on every public declaration; the DocC catalog in `Sources/Persistence/Documentation.docc`
  is the long-form explanation and must build without warnings.
- Use the checked-in `.swift-format`, copied exactly from apple/swift-temporal-sdk at
  `508797b5468dbc532f77c317bf9df0cb3231f5c1`: four-space indentation, 150-column lines,
  and ordered imports. Format all tracked Swift files, including `Package.swift`, and run
  `swift-format lint --strict`. Public documentation remains a repository requirement even
  though this formatter does not enforce it.
- File headers use the compact license format documented below.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`. The label check blocks merging without one.
- Releases are GitHub Releases, created by the Auto Release workflow: run it by hand on `main`
  and it computes the next version from the labels of the pull requests merged since the last
  release, tags it, and writes the notes from `.github/release.yml`. A major bump is refused
  there and is cut by hand.
- Consumers pin by tag, never by branch or path.

## CI

The standard library CI from the swift-microservices delivery skill
([library-ci.md](https://github.com/swift-microservices/skills/blob/main/skills/delivering-swift-services/references/library-ci.md)).
No exceptions.
