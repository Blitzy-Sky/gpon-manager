# Changelog

All notable changes to `gpon-manager` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
repository adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Every release heading below names a tag that exists in this repository, and its date is the date of
the tag. A `git describe --tags` string such as `v1.7.0-7-g1e7d2f6` denotes a number of commits past
a tag rather than a release, so it never appears here as a release heading. Work that is not yet
tagged is listed under `Unreleased`.

Two version numbers travel with this repository, and they are not the same kind of thing:

- **Release tag** - the point in this repository's history that a consumer checks out, recorded as
  the release headings in this file. The current tag is **v1.7.0**.
- **HAL schema version** - the version of the JSON HAL contract itself, carried by the
  `schemaVersion` definition in `hal_schema/gpon_hal_schema.json` and
  `hal_schema/gpon_wan_unify_hal_schema.json` as the constant **0.0.1**. The schema states that this
  value must not be modified, because HAL operation depends on the client and the vendor server
  agreeing on it. It is advanced independently of the release tag.

## Unreleased

Changes that are merged but not yet part of a tagged release
([compare with v1.7.0](https://github.com/rdkcentral/gpon-manager/compare/v1.7.0...HEAD)).

### Added

- `docs/pages/CHANGELOG.md` - a symlink to this file, so the repository's release history renders
  alongside the HAL documentation in the generated Doxygen site.
- This `CHANGELOG.md`, the release-history record for the repository and the source for the
  `Version History` topic of the HAL specification. The repository had no changelog before this
  entry.

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
