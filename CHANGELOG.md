# Changelog

All notable changes to `gpon-manager` are documented in this file.

The format follows the Keep a Changelog 1.1.0 convention, and this repository adheres to Semantic
Versioning 2.0.0.

Every release heading below names a tag that exists in this repository, and its date is the date of
the tag: the tagger date where the tag is annotated, and the tagged commit's date for `v1.1.0` and
`v1.0.0`, which are lightweight tags carrying no tagger date of their own. A `git describe --tags`
string denotes a number of commits past a tag rather than a release, so no such string appears here
as a release heading. Work that is not yet tagged is listed under `Unreleased`.

Two version numbers travel with this repository, and they are not the same kind of thing:

- **Release tag** - the point in this repository's history that a consumer checks out, recorded as
  the release headings in this file. The current tag is **v1.7.0**.
- **HAL schema version** - the version of the JSON HAL contract itself, carried by the
  `schemaVersion` definition in `hal_schema/gpon_hal_schema.json` and
  `hal_schema/gpon_wan_unify_hal_schema.json` as the constant **0.0.1**. The schema states that this
  value must not be modified, because HAL operation depends on the client and the vendor server
  agreeing on it. It is advanced independently of the release tag.

## Unreleased

Changes made since the `v1.7.0` tag and not yet part of a tagged release. All of it is documentation:
no interface contract, configuration file or source file was modified, so the component's behaviour
and its `TR-181` surface are unchanged.

### Added

- `docs/pages/halSpec.md` - the `GPON` `JSON` HAL interface specification. It covers the architecture,
  initialization and startup order, the threading, process and memory models, blocking behaviour,
  asynchronous notification, persistence, the non-functional requirements, and the complete action and
  object surface, and it records which actions are unusable under the shipped schemas. This repository
  had no HAL documentation before it.
- `docs/pages/halSpecDetailed.md` - the per-parameter reference, which for a schema carries the depth
  that inline Doxygen carries for a C header. It documents all 90 parameter definitions of
  `hal_schema/gpon_hal_schema.json` and all 95 of `hal_schema/gpon_wan_unify_hal_schema.json` with
  type, constraint, access and description, marking each variant-only parameter in place, alongside the
  26 object definitions, the transport and protocol contract, the deployment contract, the enumeration
  appendix, worked message examples for five protocol workflows, the error model, the event model, and
  the defects the shipped schemas contain.
- `docs/generate_docs.sh` - the documentation build script, pinning the `rdkcentral/hal-doxygen`
  generator at tag `1.2.0` and passing `PROJECT_NAME="RDK-B GPON HAL"`.
- `docs/.gitignore` - excludes the cloned generator in `docs/build` and the generated site in
  `docs/output` from version control.
- `docs/pages/CHANGELOG.md`, `CONTRIBUTING.md`, `COPYING.md`, `LICENSE.md` and `NOTICE.md` - five
  symlinks to the corresponding files in the repository root, so the release history, the contribution
  guidance and the legal text render alongside the HAL documentation in the generated site.
- This `CHANGELOG.md`, the release-history record for the repository and the source for the
  `Version History` topic of the HAL specification. The repository had no changelog before this
  entry.

### Changed

- `README.md` - replaced the single-line stub that stood at `v1.7.0` with a manager overview: what
  `RdkGponManager` owns, why this HAL is a `JSON` Schema rather than a C header, links to both
  documentation pages, the module identity and object tree, the two-step build-time variant selection,
  the repository layout, the build options and the contribution route. Every factual claim names the
  file that establishes it.

## Releases before this file

This changelog was introduced during the HAL documentation work recorded under `Unreleased`, after
the releases below were already tagged. Their contents are not restated here, because doing so would
mean asserting release notes this repository never wrote; the authoritative record for each is the
commit range the tag closes.

| Tag | Date |
|---|---|
| `v1.7.0` | 2025-11-06 |
| `v1.6.0` | 2025-08-05 |
| `v1.5.0` | 2025-05-23 |
| `v1.4.0` | 2025-02-12 |
| `v1.3.0` | 2024-10-31 |
| `v1.2.0` | 2024-08-30 |
| `v1.1.0` | 2024-06-26 |
| `v1.0.0` | 2024-05-30 |

The repository additionally carries the release-candidate tags `RC1.7.0a` (2025-08-19), `RC1.6.0a`
(2025-07-03), `RC1.5.0a` (2025-03-18), `RC1.4.0a` (2025-01-28), `RC1.3.0a` (2024-10-18) and
`RC1.2.0a` (2024-08-08). These are pre-release markers rather than releases, so they are listed here
for completeness and are not release headings.
