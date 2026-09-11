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
- Format with `swift-format format --in-place --recursive Sources Tests`; the soundness check on
  every pull request runs the same rules, an API breakage check against the base branch, and
  shellcheck and yamllint.
- File headers follow the existing files: name, package, author, date.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`. The label check blocks merging without one.
- Releases are GitHub Releases, created by the Auto Release workflow: run it by hand on `main`
  and it computes the next version from the labels of the pull requests merged since the last
  release, tags it, and writes the notes from `.github/release.yml`. A major bump is refused
  there and is cut by hand.
- Consumers pin by tag, never by branch or path.
