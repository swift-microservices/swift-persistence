# Repository guidelines

This package is the transaction boundary shared by every service in the organization. It is
deliberately small. Read this before changing anything.

## What this package is

- One product, `Persistence`, one protocol, `Database`. It depends on nothing, not even
  Foundation, so a domain target can link it without pulling a driver in behind it.
- Drivers live in their own packages (`swift-persistence-postgres`) and depend on this one by
  tag. Nothing driver-specific belongs here.
- The one test states the shape consumers rely on: a use case takes `any Database<Scope>` and is
  handed its scope. A change to the protocol is a change to that test first.

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
- File headers follow the existing files: name, package, author, date.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`. The label check blocks merging without one.
- Releases are GitHub Releases, created by the Auto Release workflow: run it by hand on `main`
  and it computes the next version from the labels of the pull requests merged since the last
  release, tags it, and writes the notes from `.github/release.yml`. A major bump is refused
  there and is cut by hand.
- Consumers pin by tag, never by branch or path.

## Library CI profile

- This repository profile overrides general service CI and formatting defaults. Libraries
  never commit `Package.resolved`; CI resolves released dependencies from the manifest.
- PRs run soundness checks, including API compatibility, documentation, formatting, shellcheck,
  and yamllint. The docs workflow adds the DocC plugin only in its temporary checkout.
  License-header checking stays disabled because source files use the author-header convention.
- PRs, main pushes, and the weekly schedule run Linux tests on Swift 6.3 and 6.4, next/main
  snapshots, release builds, and static Linux SDK compatibility. Require supported stable
  checks in branch protection; snapshot failures remain visible and advisory unless
  maintainers explicitly require them.
- CI is Linux-only by project choice. macOS and other Apple-platform builds/tests are
  outside this pipeline; Linux success does not establish Apple-platform compatibility.
- Actions and reusable workflows are SHA-pinned. The reviewed SwiftNIO main commit supplies
  Swift 6.4 inputs absent from release 2.103.0; its nested workflows and downloaded scripts
  still follow upstream main. Caller pins do not make that execution chain immutable.
- Keep the separate Foundation-linking consumer check; a successful static SDK build
  does not prove that the resolved graph avoids full Foundation.
