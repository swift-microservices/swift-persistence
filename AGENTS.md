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
- File headers use the compact license format documented below.

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
- PRs run documentation, formatting, compact license-header, shellcheck, and yamllint checks.
  Automatic API-breakage checking is disabled by project choice; SemVer labels still describe
  the public API impact. The docs workflow adds the DocC plugin only in its temporary checkout.
- PRs and main pushes run Linux tests on Swift 6.3 and 6.4, next/main snapshots, and release
  builds. PRs also run x86_64 static Linux SDK builds against the released and Swift main SDKs.
  CI has no scheduled runs. Require supported stable checks in branch protection; snapshot
  failures remain visible and advisory unless maintainers explicitly require them.
- Static SDK checks follow Swift Temporal SDK's PR-only setup and cross-compile only.
- CI is Linux-only by project choice. macOS and other Apple-platform builds/tests are
  outside this pipeline; Linux success does not establish Apple-platform compatibility.
- Shared library workflows and the SwiftNIO SemVer action follow `@main` by project choice.
  Soundness uses its release tag, and standard Actions use major-version tags. These moving
  references include upstream changes; do not describe them as immutable.
- Dependabot checks weekly, targets main, and labels workflow-update PRs `semver/none`.
- Use the three-line MIT header matched by `.license_header_template`. Keep the tools-version
  directive first in `Package.swift`, followed by that header. `.licenseignore` excludes the
  manifest (the upstream checker requires a header at line one) and the plain-text `LICENSE`.
- Keep the separate Foundation-linking consumer check on Swift 6.3 and 6.4 Noble; a successful
  static SDK build does not prove that the resolved graph avoids full Foundation.
