# Changelog

All notable changes to `gpon-manager` are documented in this file.

The format follows the Keep a Changelog 1.1.0 convention, and this repository adheres to Semantic
Versioning 2.0.0.

Every release recorded below names a tag that exists in this repository, and its date is the date of
the tag: the tagger date where the tag is annotated, and the tagged commit's date for `v1.1.0` and
`v1.0.0`, which are lightweight tags carrying no tagger date of their own. A `git describe --tags`
string denotes a number of commits past a tag rather than a release, so no such string is recorded
here as a release. Work that is not yet tagged is listed under `Unreleased`. This file was
introduced after every release below was tagged, so each release entry is compiled from the
non-merge commits in the range its tag closes.

The repository additionally carries the release-candidate tags `RC1.7.0a` (2025-08-19), `RC1.6.0a`
(2025-07-03), `RC1.5.0a` (2025-03-18), `RC1.4.0a` (2025-01-28), `RC1.3.0a` (2024-10-18) and
`RC1.2.0a` (2024-08-08). These are pre-release markers rather than releases, so they are named here
for completeness and have no release heading of their own. Each marks the same commit as the release
of the same number, so its changes are the ones recorded under that release.

Two version numbers travel with this repository, and they are not the same kind of thing:

- **Release tag** - the point in this repository's history that a consumer checks out, recorded as
  the release headings in this file. The current tag is **v1.7.0**.
- **HAL schema version** - the version of the JSON HAL contract itself, carried by the
  `schemaVersion` definition in `hal_schema/gpon_hal_schema.json` and
  `hal_schema/gpon_wan_unify_hal_schema.json` as the constant **0.0.1**. The schema states that this
  value must not be modified, because HAL operation depends on the client and the vendor server
  agreeing on it. It is advanced independently of the release tag.

## Unreleased

Changes made since the `v1.7.0` tag and not yet part of a tagged release: three
repository-maintenance commits that change only files under `.github/`, and the HAL documentation
work. The HAL documentation work is documentation only: no interface contract, configuration file
or source file was modified, so the component's behaviour and its `TR-181` surface are unchanged.

### Added

- [docs/pages/halSpec.md](https://github.com/rdkcentral/gpon-manager/blob/a55601f2183e4a494cccccfbf3777a5663ef298a/docs/pages/halSpec.md) - the `GPON` `JSON` HAL interface specification. It covers the architecture,
  initialization and startup order, the threading, process and memory models, blocking behaviour,
  asynchronous notification, persistence, the non-functional requirements, and the complete action and
  object surface, and it records which actions are unusable under the shipped schemas. This repository
  had no HAL documentation before it.
- [docs/pages/halSpecDetailed.md](https://github.com/rdkcentral/gpon-manager/blob/a55601f2183e4a494cccccfbf3777a5663ef298a/docs/pages/halSpecDetailed.md) - the per-parameter reference, which for a schema carries the depth
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
- Five symlinks under `docs/pages/` - `CHANGELOG`, `CONTRIBUTING`, `COPYING`, `LICENSE` and `NOTICE`,
  each carrying a `.md` suffix - pointing at the corresponding files in the repository root, so the
  release history, the contribution guidance and the legal text render alongside the HAL documentation
  in the generated site.
- This changelog, the release-history record for the repository and the source for the
  `Version History` topic of the HAL specification. The repository had no changelog before this
  entry.
- `.github/workflows/fossid_integration_stateless_diffscan_target_repo.yml` - a FossID stateless
  diff-scan GitHub Actions workflow. It runs when a pull request from a branch of this repository,
  not from a fork, is opened, synchronized or reopened, and calls the shared
  `rdkcentral/build_tools_workflows` FossID workflow at `1.0.0`
  ([`1e55e5d`](https://github.com/rdkcentral/gpon-manager/commit/1e55e5d299dffb068b82adb478b02f93fecf6b28),
  [#22](https://github.com/rdkcentral/gpon-manager/pull/22)).

### Changed

- The repository README - replaced the single-line stub that stood at `v1.7.0` with a manager
  overview: what `RdkGponManager` owns, why this HAL is a `JSON` Schema rather than a C header,
  links to both documentation pages, the module identity and object tree, the two-step build-time
  variant selection, the repository layout, the build options and the contribution route. Every
  factual claim names the file that establishes it.
- `.github/workflows/cla.yml` - the Contributor License Agreement workflow now declares its token
  permissions explicitly and calls the shared `rdkcentral/cmf-actions` CLA workflow at `v1` instead
  of `main`
  ([`11f7d4f`](https://github.com/rdkcentral/gpon-manager/commit/11f7d4fd4eeff3950f5a961665348fbd9b60afea),
  [#21](https://github.com/rdkcentral/gpon-manager/pull/21)).
- `.github/CODEOWNERS` - the default reviewer for every path changed from
  `@rdkcentral/wanmanager-owners` to `@rdkcentral/wanmanager-maintainers`
  ([`aa384fd`](https://github.com/rdkcentral/gpon-manager/commit/aa384fdd6251f3305e3aa28a843b814cdea9e9a8),
  [#20](https://github.com/rdkcentral/gpon-manager/pull/20)).

## 1.7.0 - 2025-11-06

Release tagged [`v1.7.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.7.0).
Its changes since `v1.6.0` are the range
[`v1.6.0...v1.7.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.6.0...v1.7.0).

### Added

- Contributor License Agreement check as the `.github/workflows/cla.yml` GitHub Actions workflow,
  which calls the shared `rdkcentral/cmf-actions` CLA workflow on pull requests and comments
  ([`16ea0a7`](https://github.com/rdkcentral/gpon-manager/commit/16ea0a7c9e52f3cc34e0878ce2445866cafaa140),
  [#17](https://github.com/rdkcentral/gpon-manager/pull/17)).

### Removed

- The D-Bus build dependency (RDKBDEV-3238): `configure.ac` no longer requires the `dbus-1` package,
  and the `GponManager` build no longer passes `DBUS_CFLAGS` or links `DBUS_LIBS`
  ([`d5fa20f`](https://github.com/rdkcentral/gpon-manager/commit/d5fa20f62b2d7c4c642b20885b48add20c95752b),
  [#18](https://github.com/rdkcentral/gpon-manager/pull/18)).

### Fixed

- The JSON request and reply objects leaked when `json_hal_client_send_and_get_reply()` failed
  (RDKBDEV-3239). `GponHal_setParam` and the `GponHal_get_*` readers for physical media, GTC, PLOAM,
  OMCI, GEM, VEIP and TR-69 now free both objects before returning the failure
  ([`4a99a1f`](https://github.com/rdkcentral/gpon-manager/commit/4a99a1fae972af26e3d93a335932a6b76cad3a61),
  [#19](https://github.com/rdkcentral/gpon-manager/pull/19)).

## 1.6.0 - 2025-08-05

Release tagged [`v1.6.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.6.0).
Its changes since `v1.5.0` are the range
[`v1.5.0...v1.6.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.5.0...v1.6.0).

### Removed

- The D-Bus path message handler `CcspComp_path_message_func` and its
  `CCSP_Message_Bus_Register_Path` registration, from
  `source/GponManager/ssp_messagebus_interface.c`. The change was raised as an internal build fix
  (CTB-3889_3075)
  ([`70e7258`](https://github.com/rdkcentral/gpon-manager/commit/70e725844e08c4cf5b23c82b8c2bac3194c200f5),
  [#15](https://github.com/rdkcentral/gpon-manager/pull/15)).

## 1.5.0 - 2025-05-23

Release tagged [`v1.5.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.5.0).
Its changes since `v1.4.0` are the range
[`v1.4.0...v1.5.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.4.0...v1.5.0).

### Added

- `.github/CODEOWNERS`, which makes `@rdkcentral/wanmanager-owners` the default reviewer for every
  path in the repository (CMFSUPPORT-2402)
  ([`28b9c1a`](https://github.com/rdkcentral/gpon-manager/commit/28b9c1a7ea6cf286ac82ae705d5e65eeb0ecde19),
  [#16](https://github.com/rdkcentral/gpon-manager/pull/16)).

## 1.4.0 - 2025-02-12

Release tagged [`v1.4.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.4.0).
Its changes since `v1.3.0` are the range
[`v1.3.0...v1.4.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.3.0...v1.4.0).

### Added

- The build version is logged at startup (RDKB-58019): `configure.ac` captures the output of
  `git describe --tags --always --dirty` as `GIT_VERSION`, the `GponManager` build passes it as a
  compile definition, and `ssp_main.c` logs it once the logger is initialised
  ([`a620cf8`](https://github.com/rdkcentral/gpon-manager/commit/a620cf8124004b64a4c85bd7a0e6d3d0505c98be),
  [#14](https://github.com/rdkcentral/gpon-manager/pull/14)).
- Diagnostic logging across the controller, the link state machine and the TR-181 middle layer
  (RDKBDEV-2943): failed HAL event subscriptions, failures to send the HAL configuration, link
  state-machine transitions, memory-allocation and thread-start failures, and failures to apply
  default values are now logged
  ([`2f32d6e`](https://github.com/rdkcentral/gpon-manager/commit/2f32d6e36ca261f1cc0fb2265f28581eb3cacf3a),
  [#12](https://github.com/rdkcentral/gpon-manager/pull/12)).

### Fixed

- `UINT` and `ULONG` data-model values stopped updating once they passed `2^31 - 1`
  (RDKBDEV-2900). Unsigned values received from the HAL are now parsed with `strtoull` instead of
  `strtoul` in `gponmgr_dml_hal_param.c`
  ([`6bf8c6f`](https://github.com/rdkcentral/gpon-manager/commit/6bf8c6f673c78f5f2aeac6e2888b9216a25afbed),
  [#13](https://github.com/rdkcentral/gpon-manager/pull/13)).

## 1.3.0 - 2024-10-31

Release tagged [`v1.3.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.3.0).
Its changes since `v1.2.0` are the range
[`v1.2.0...v1.3.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.2.0...v1.3.0).

### Changed

- The `WAN_MANAGER_UNIFICATION_ENABLED` variant is realigned with the community-proposed data model
  (RDKBDEV-2732). `config/RdkGponManager.xml` and `hal_schema/gpon_wan_unify_hal_schema.json`
  return to the names the default variant uses: `VoltageLevel` for `CurrentVoltage`,
  `TotalFecCodeWords` and `HecErrorCount` for `GtcTotalFecCodeWords` and `GtcHecErrorCount`, the
  `Ploam.RegistrationTimers` object with `TO1` and `TO2` for `TO1Timer` and `TO2Timer`,
  `RxBaseLineMessageCountValid` and `RxExtendedMessageCountValid` for `BaselineMessageCount` and
  `ExtendedMessageCount`, and `MeId` for `ManagedEntityId`
  ([`46c63a6`](https://github.com/rdkcentral/gpon-manager/commit/46c63a64f723192f88236c2b21740d72ef9e0ebe),
  [#7](https://github.com/rdkcentral/gpon-manager/pull/7)).
- The unification variant no longer pins its HAL queries to instance 1 (RDKBDEV-2856). It queries
  `Device.X_RDK_ONT.PhysicalMedia.`, `Device.X_RDK_ONT.Gem.` and `Device.X_RDK_ONT.Veip.` as the
  default variant does, reading GEM data from `Gem` rather than `GemStats`, and the retry limit on
  the initial data read in `GponHal_get_init_data` is removed
  ([`de93389`](https://github.com/rdkcentral/gpon-manager/commit/de93389928803a31634bbb368da093d42b795f82),
  [#8](https://github.com/rdkcentral/gpon-manager/pull/8)).

### Fixed

- Errors that `GponManager` logged at runtime (RDKBDEV-2857). VEIP `EthernetFlow.Ingress.Tagged`
  is now sent to the HAL as the string `Single`, `Double` or `Untagged` rather than as an integer,
  and `EthernetFlow.Ingress.Q-VLAN.Vid` as an unsigned integer; `ModuleVendor` and `EthernetFlow`
  values received from the HAL are mapped without returning a failure status; the `PonMode` test
  for `GPON` matches `GPON` rather than `XGPON`; and the unification variant no longer sends
  `PhysicalMedia` `Enable`, `Alias` and `LowerLayers` to the HAL with its configuration
  ([`7bcd66d`](https://github.com/rdkcentral/gpon-manager/commit/7bcd66dd3bf4cb3f8ffd9059b7bede5dd58a91c8),
  [#9](https://github.com/rdkcentral/gpon-manager/pull/9)).

## 1.2.0 - 2024-08-30

Release tagged [`v1.2.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.2.0).
Its changes since `v1.1.0` are the range
[`v1.1.0...v1.2.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.1.0...v1.2.0).

### Fixed

- Build errors with `-Werror` and `-Wall` enabled (RDKBDEV-2732): unused variables removed, and
  format specifiers and pointer casts corrected across the manager and its TR-181 middle layer. One
  correction changes behaviour: `eventcb_PloamRegistrationState` now maps PLOAM registration-state
  events with `Map_hal_dml_ploam` instead of `Map_hal_dml_veip`
  ([`df0f667`](https://github.com/rdkcentral/gpon-manager/commit/df0f667e952d6f042438ac08ce8a7ae130ceb870),
  [#5](https://github.com/rdkcentral/gpon-manager/pull/5)).

## 1.1.0 - 2024-06-26

Release tagged [`v1.1.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.1.0).
Its changes since `v1.0.0` are the range
[`v1.0.0...v1.1.0`](https://github.com/rdkcentral/gpon-manager/compare/v1.0.0...v1.1.0).

### Added

- Breakpad crash handling (RDKBDEV-2730): in a build with `INCLUDE_BREAKPAD`, `ssp_main.c` now
  installs `breakpad_ExceptionHandler()`, which was previously commented out
  ([`05cfc8d`](https://github.com/rdkcentral/gpon-manager/commit/05cfc8d7ebe5eccd4937a612b66a00e32bb666fc),
  [#3](https://github.com/rdkcentral/gpon-manager/pull/3)).

### Fixed

- `json_hal_server_gpon` did not start when `WAN_MANAGER_UNIFICATION_ENABLED` was set
  (RDKBDEV-2736). `GponHal_Init` now starts it with `/etc/rdk/conf/gpon_manager_wan_unify_conf.json`
  instead of `/etc/rdk/conf/gpon_manager_conf.json`, from `/bin` where it exists there and otherwise
  from `/usr/bin`
  ([`c4c2a64`](https://github.com/rdkcentral/gpon-manager/commit/c4c2a6442c1e3f5e4b8ab57f25f4f1bf27175847),
  [#4](https://github.com/rdkcentral/gpon-manager/pull/4)).

## 1.0.0 - 2024-05-30

First tagged release, at tag
[`v1.0.0`](https://github.com/rdkcentral/gpon-manager/releases/tag/v1.0.0). It publishes
`RdkGponManager` on GitHub together with the history the component accumulated on the RDK `stable2`
branch from 2021, merged through [#1](https://github.com/rdkcentral/gpon-manager/pull/1). The
open-sourcing commit (CMFSUPPORT-1698) rewrote the licence headers of the source and build files to
the Apache 2.0 form
([`198ce72`](https://github.com/rdkcentral/gpon-manager/commit/198ce72b5d254f0b8e6649823b9d3eedb936b67b)).

### Added

- The `RdkGponManager` component (RDKB-34410): the `GponManager` CCSP process, the TR-181
  `Device.X_RDK_ONT.` data model in `config/RdkGponManager.xml`, the JSON HAL client integration and
  its configuration file `config/gpon_manager_conf.json`, the HAL contract
  `hal_schema/gpon_hal_schema.json` with its example messages, and the Apache 2.0 `LICENSE`,
  `COPYING` and `NOTICE`
  ([`199351c`](https://github.com/rdkcentral/gpon-manager/commit/199351cd3c45a67c185638af7f57a3197378f68a)).
- The WAN Manager unification variant (RDKBDEV-942): built with `WAN_MANAGER_UNIFICATION_ENABLED`,
  the manager forwards the GPON link events it receives from the JSON HAL to WAN Manager, using
  `hal_schema/gpon_wan_unify_hal_schema.json` and `config/gpon_manager_wan_unify_conf.json`
  ([`be2f58b`](https://github.com/rdkcentral/gpon-manager/commit/be2f58b7ccc880c0a4edbd476d6e3550b0afc80c)).

### Changed

- The data-model C file is generated at build time from `config/RdkGponManager.xml`, which was
  converted to Unix line endings (RDKBDEV-2239)
  ([`740e6c3`](https://github.com/rdkcentral/gpon-manager/commit/740e6c36197888bfbf686a691ae71ea75b74953c)).
- Build and code clean-up: the autotools files were tidied, obsolete Windows support was dropped,
  `AnscEqualString()` was replaced with `strcmp()`, unnecessary command buffers and an unused
  logging variable were removed, `syscfg` is included as `syscfg/syscfg.h` without an explicit
  `syscfg_init()` call, and five source files were converted from Windows to Unix line endings
  ([`5a068fc`](https://github.com/rdkcentral/gpon-manager/commit/5a068fc52c29c5d0ad1469325951fcd2db95932e),
  [`cfb7e59`](https://github.com/rdkcentral/gpon-manager/commit/cfb7e59cd8e668fdc2cdb08ab1e4e88cc8c0f156),
  [`f44cce7`](https://github.com/rdkcentral/gpon-manager/commit/f44cce790049bb8bce9281871c114721814861a5),
  [`6b6d4c3`](https://github.com/rdkcentral/gpon-manager/commit/6b6d4c35db600d3d62805e1bf3031fc658f3153e),
  [`1a570ef`](https://github.com/rdkcentral/gpon-manager/commit/1a570eff4d1128a2e64b40b987d8debd04eecbc1),
  [`c805d90`](https://github.com/rdkcentral/gpon-manager/commit/c805d9072871b2282e355c14e9eb896f0bbcc7fd),
  [`587479a`](https://github.com/rdkcentral/gpon-manager/commit/587479aff9f3f0fefc2b52f501e8162db8a13cc1),
  [`00bfd27`](https://github.com/rdkcentral/gpon-manager/commit/00bfd278a683bff0092660a62de74ddc72a8ed9a),
  [`62b9a1b`](https://github.com/rdkcentral/gpon-manager/commit/62b9a1bec40ad59138b550520f48effbaa68fa74)).

### Fixed

- `PhysicalMedia` received-power and transmitted-power signal-level thresholds that were set
  through the data model were not passed to the HAL (RDKBDEV-596)
  ([`97cec65`](https://github.com/rdkcentral/gpon-manager/commit/97cec655f79bcc6597313d561b89acc085514b39)).
- `PhysicalMedia.{i}.RedundancyState` always read `Active`. The value now comes from the HAL, and
  the `Standy` enumerator is spelled `Standby` (RDKBDEV-598)
  ([`71c3017`](https://github.com/rdkcentral/gpon-manager/commit/71c30172c520b2788e1d3ad994f43c3acd600bb0)).
- `Gponmgr_eth_addInterface` took the VEIP interface name from `InterDomainName`, which the HAL
  returned empty; it now uses `InterfaceName`
  ([`dea6eff`](https://github.com/rdkcentral/gpon-manager/commit/dea6effb67d85492e0deb341d4899a6579e4205e)),
  and the temporary buffers that hold that name are sized to its 256-byte definition
  (RDKBDEV-2244)
  ([`d3c1f45`](https://github.com/rdkcentral/gpon-manager/commit/d3c1f45c2440d0b165f70e4d1d3b2c5e982a3353)).
- An inverted `WAN_MANAGER_UNIFICATION_ENABLED` test in `GponPloam_GetParamUlongValue()`
  ([`2215127`](https://github.com/rdkcentral/gpon-manager/commit/221512796ed3b93efa1eeb8b10c00ed70dae0409)).
- A build failure caused by the stale `rpc-cli/rpc_client.h` include (RDKBCMF-266)
  ([`5a491fa`](https://github.com/rdkcentral/gpon-manager/commit/5a491fa27ce3de784647df837955ba52267cc9d4)).
