# Intent: Update all dependencies to their latest stable versions

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

The generator runs on Ruby 4.0.6, but Ruby 4.0.7 is the latest stable release. The maintainer's machines and CI both run an outdated patch release.

An audit on 2026-10-06 found the state of every dependency:

| Dependency | Pinned | Latest stable |
|---|---|---|
| Ruby (`.ruby-version`) | 4.0.6 | 4.0.7 |
| `actions/checkout` | v7.0.1 | v7.0.1 |
| `spinel-coop/setup-rv` | `@main` | `v1` is the only tag; it is 32 commits behind `main` and has no `current` input |
| minitest, base64, yaml, erb, json | bundled with Ruby; no `Gemfile` | follow the Ruby version |

## Proposed outcome

Every dependency is at its latest stable release. The generator, its tests and CI all run on Ruby 4.0.7.

## Affected users and systems

- The maintainer's machines: rv selects the Ruby version from `.ruby-version`.
- CI: both jobs read `.ruby-version` through `setup-rv`'s `ruby-version: current`.

## Constraints

- No system tooling changes: Ruby 4.0.7 is already installed through rv on the maintainer's machine.
- The CI workflow file stays unchanged, because `.github/workflows/` edits need explicit approval and none is needed here.
- CI runs on `ubuntu-slim` and skips the Terminal.app output, because `plutil` is macOS-only.

## In scope

- Moving the pinned Ruby version from 4.0.6 to 4.0.7.

## Out of scope

- `spinel-coop/setup-rv`: it stays on `@main`. No newer stable release exists, and `v1` cannot read `.ruby-version`.
- Pinning any action to a commit SHA.
- Adding a `Gemfile` to pin the bundled gems.
- Changes to the Dependabot configuration.

## Acceptance criteria

- A shell in the repository runs Ruby 4.0.7.
- Both test files pass on Ruby 4.0.7.
- Regenerating every theme on Ruby 4.0.7 changes no committed file.
- Both CI jobs install Ruby 4.0.7 and pass.
- Every action that the workflow pins to a release is at its latest stable release.

## Open questions

None.
