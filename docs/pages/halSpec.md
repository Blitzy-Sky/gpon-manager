# GPON HAL Documentation

## Version History

| Date | Comment | Version |
| --- | --- | --- |
| 2026-08-24 | Initial release. Specifies the GPON `JSON` HAL contract carried by `hal_schema/gpon_hal_schema.json` and by its build-selected variant `hal_schema/gpon_wan_unify_hal_schema.json`, recorded as an `Unreleased` entry in `CHANGELOG.md`. | 1.0.0 |

The `Version` column above is the revision of **this document** and of nothing else. Four distinct
version identities apply to this component, and conflating them is the easiest way to misread it.
They are listed separately here, each with the artefact that establishes it.

| Identity | Value | Established by |
| --- | --- | --- |
| Document revision | `1.0.0` | The table above. Applies to this specification only, and is advanced when this document changes. |
| HAL schema version | `0.0.1` | `definitions.schemaVersion.const`, identical in both shipped schemas. This is the value that travels in every message's `version` field, and it is the only version a caller's messages carry. |
| Release tag | `v1.7.0` | The repository's most recent tag, dated 2025-11-06 in `CHANGELOG.md`, which also records `v1.6.0` through `v1.0.0`. This is the release the document describes. |
| Generated-site version string | The `git describe --tags` output at build time | `docs/generate_docs.sh` passes it to the documentation generator as `PROJECT_VERSION`. It is recomputed on every build and is not a version. |

Two consequences follow, and both are places a reader goes wrong. The interface is **not** at
`v1.7.0`: that is the repository release, while the contract this document specifies declares
`0.0.1`. And the generated-site string takes the form `v1.7.0-<n>-g<abbrev-sha>` whenever the
checked-out commit is not exactly a tag — the `-<n>-g<sha>` suffix means *n* commits past the named
tag at that commit, so a string of that shape denotes a position in history rather than a release,
and it never appears as a release heading in `CHANGELOG.md`.

*Derived from `CHANGELOG.md`, the repository's tag list, and `definitions.schemaVersion` in both
files under `hal_schema/`.*

## Acronyms

- `ACS` \- Auto Configuration Server, the remote management server a `TR-069` agent contacts
- `DML` \- Data Model Layer, the `TR-181` parameter surface the manager exposes to the rest of `RDK-B`
- `FEC` \- Forward Error Correction
- `GEM` \- `GPON` Encapsulation Method, the frame format carrying user traffic over the `PON`
- `GPON` \- Gigabit-capable Passive Optical Network
- `GTC` \- `GPON` Transmission Convergence, the framing sub-layer between the `PON` and `GEM`
- `HAL` \- Hardware Abstraction Layer
- `IPC` \- Inter-Process Communication
- `JSON` \- JavaScript Object Notation
- `JSON-RPC` \- The remote procedure call convention carried over `JSON`, used by this HAL's transport
- `MIC` \- Message Integrity Check, the integrity field on an `OMCI` message
- `OMCI` \- `ONT` Management and Control Interface
- `ONT` \- Optical Network Termination, the subscriber-side endpoint this interface models
- `ONU` \- Optical Network Unit, the term the `ITU-T` recommendations use for the same endpoint
- `PLOAM` \- Physical Layer Operations, Administration and Maintenance
- `PON` \- Passive Optical Network
- `RDK-B` \- Reference Design Kit for Broadband Devices
- `TCP` \- Transmission Control Protocol
- `TR-069` \- Broadband Forum Technical Report 069, the CPE WAN management protocol
- `TR-181` \- Broadband Forum Technical Report 181, which defines the `Device:2` root data model
- `VEIP` \- Virtual Ethernet Interface Point, the `OMCI` managed entity bridging `PON` to Ethernet
- `VLAN` \- Virtual Local Area Network
- `ITU-T` \- International Telecommunication Union Telecommunication Standardization Sector

Only terms used in this document are listed. The optical and `PON` terms are those the shipped
schemas use to name the objects they model; the `ITU-T` recommendations that define them are cited
in `Description`.

*Derived from the object and parameter names in `hal_schema/gpon_hal_schema.json`.*

## Description

The diagram below describes a high-level software architecture of the GPON HAL module stack.

```mermaid
flowchart TD;
    RDKBStack[RDK-B Stack] <-->
    GponManager["GponManager (RdkGponManager)"] <-->
    JSONHALSocket["JSON HAL socket (TCP 127.0.0.1:40100)"] <-->
    VendorServer["Vendor JSON HAL Server (json_hal_server_gpon)"]
```

Every diagram in this document is authored as a fenced `mermaid` block. Such blocks render as
diagrams on GitHub, which is the primary surface for a developer reading this repository. The
documentation generator used here does **not** render them; it displays their source text instead.
That limitation is stated rather than worked around, because the only available workaround would
fix the generated site at the cost of the surface most readers actually use.

The GPON HAL is the interface between `RDK-B` middleware and a vendor's `GPON` implementation. It
differs from most HALs in `RDK-B` in one structural respect that governs everything else in this
document: **it is not a C header, and no library is linked across the HAL boundary.** The contract
is a `JSON` Schema, the two participants are separate processes, and they exchange messages over a
`TCP` socket. There is consequently no header from which to generate an inline API reference, and
the per-parameter detail that inline documentation would carry for a C HAL is carried instead by
[`halSpecDetailed.md`](halSpecDetailed.md) in this folder. This is also why the workspace has no
`rdkb-halif-gpon` repository: the contract lives here, beside the manager that speaks it
[`README.md:27`, superproject].

GponManager is the `RDK-B` middleware that owns `GPON` state, and it is the **client** of this
interface; the vendor supplies the **server**. The manager presents `ONT` configuration and status
to the rest of `RDK-B` as a `TR-181` `DML` surface under `Device.X_RDK_ONT`, and translates reads
and writes on that surface into `JSON` HAL requests
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c`]. No separate middleware service sits between
the `RDK-B` stack and this interface — the superproject inventory records `GPON` as having no
service dependency [`README.md:102`, superproject] — because the manager in this repository is
itself the owning service. That is what the second box in the diagram above represents.

**The object tree is a vendor extension, not a Broadband Forum model, and that decides where its
semantics come from.** Every parameter lives under `Device.X_RDK_ONT`, and the `X_` prefix marks an
extension to the `TR-181` [`Device:2` root data model](https://device-data-model.broadband-forum.org/)
rather than a branch the Broadband Forum defines. No `Device:2` release specifies `X_RDK_ONT`, so
this document does not cite a data-model version for it. The meaning of the parameters comes from
the optical standards the schema's own descriptions reference — `ITU-T G.988` for the `OMCI` managed
entities and their counters, cited by clause in seven parameter descriptions, and `ITU-T G.9807`,
cited in three `GTC` error-counter descriptions — together with the manager's `DML` description
[`config/RdkGponManager.xml`]. The five `PhysicalMedia` sub-objects that mirror `TR-181` interface
conventions, `Alias`, `Enable`, `LastChange`, `LowerLayers` and `Upstream`, exist only in the
variant schema and are the subject of `Optional Components`.

What the interface covers, in the terms the segments use: the optical transceiver and its alarms
(`PhysicalMedia`), `GEM` port and Ethernet flow mapping including `VLAN` tag handling (`Gem`), the
`VEIP` interface and its Ethernet flows (`Veip`), the `PLOAM` registration state and its timers
(`Ploam`), `GTC` framing and `FEC` counters (`Gtc`), `OMCI` message and `MIC` error counts (`Omci`),
and the `ACS` address and associated tag handed from the `OMCI` domain to the `TR-069` domain
(`TR69`). `API Surface` names all seven segments with their parameter counts.

**How to read the rest of this document.** It is arranged in two tiers. The overview tier is this
topic plus `Component Runtime Execution Requirements`, which together answer what this interface is
and how to call it — initialization order, threading, memory, timeouts and error handling. The
protocol tier is `Non functional requirements` and `Interface API Documentation`, which answer what
the wire actually looks like, what varies by build, and what happens when a call fails. Within that
second tier `API Surface` is the index: it names every action and every object segment, and marks
the point past which the detail continues into [`halSpecDetailed.md`](halSpecDetailed.md).

**One verification limit applies to this whole document.** `GPON` is not available on the `HUB6` or
`XER10` reference platforms [`README.md:102-103`, superproject], so no statement here has been
confirmed by running the HAL. Everything asserted is derived from the shipped schemas, the client
configuration, the manager source and the pinned transport library, and each claim carries the
locator that establishes it. Where none of those establishes a behaviour, this document says so
instead of filling the gap.

*Derived from `hal_schema/gpon_hal_schema.json`, `source/TR-181/middle_layer_src/gponmgr_dml_hal.c`,
`config/RdkGponManager.xml` and the superproject `README.md`.*

## Optional Components

**Two schema variants ship, and which one a deployment uses is a compile-time decision.** This is
the only optionality in the interface, and it is resolved inside this repository — unlike some HALs
in this bundle, nothing here is left to a runtime lookup or to an undocumented deployment step.

| Build | Configuration file the manager reads | Schema the configuration names | Server port |
| --- | --- | --- | --- |
| Default | `/etc/rdk/conf/gpon_manager_conf.json` | `/etc/rdk/schemas/gpon_hal_schema.json` | `40100` |
| `WAN_MANAGER_UNIFICATION_ENABLED` defined | `/etc/rdk/conf/gpon_manager_wan_unify_conf.json` | `/etc/rdk/schemas/gpon_wan_unify_hal_schema.json` | `40100` |

The two rows differ in exactly one field: the schema path. The port is `40100` in both
[`config/gpon_manager_conf.json`, `config/gpon_manager_wan_unify_conf.json`], so a vendor server
listens on the same port either way and cannot infer the variant from the port it was given.
`Variability Management` sets out the two-step selection that produces this table, and
`Platform or Product Customization` sets out what the variant changes in the contract.

**What the variant adds.** The `wan_unify` schema is a superset: it removes nothing and adds five
`PhysicalMedia` parameter definitions, taking the total from 90 to 95. Three of the five are
writable, which takes the writable surface from 8 parameters to 11, and two of them introduce the
`boolean` datatype, which does not appear anywhere in the default schema. The complete comparison,
per parameter, is in [`halSpecDetailed.md`](halSpecDetailed.md).

**A second effect of the same flag, which is easy to miss because it is not in either schema.** In
the `WAN_MANAGER_UNIFICATION_ENABLED` build the manager itself launches the vendor server before
initializing its client, running `/bin/json_hal_server_gpon` if that path exists and
`/usr/bin/json_hal_server_gpon` otherwise, in both cases passing the `wan_unify` configuration file
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:100-108`]. In the default build the manager
launches nothing and expects the server to be started by the platform. A vendor packaging a server
for a unified-WAN build must therefore install it under one of those two names, and must tolerate
being started with that configuration path as its only argument.

**There is no optional transport, no optional action and no optional notification type.** Both
schemas declare the same eleven actions, the same nine enumerations and the same eighteen
subscribable parameters. The only list the schemas mark as optional is
`getParameterOptionalList`, which holds 24 read paths — the 21 `Gem` Ethernet-flow entries and the
three `TR69` entries — and it is a read-scoping list rather than a build option: a vendor that does
not implement one of those paths answers `Not Supported`, as `Internal Error Handling` describes.
The companion `setParameterOptionalList` is empty in both schemas, which is a defect in the shipped
contract rather than an option; [`halSpecDetailed.md`](halSpecDetailed.md) records it.

*Derived from `config/gpon_manager_conf.json`, `config/gpon_manager_wan_unify_conf.json`,
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:57-61,100-108` and both files under
`hal_schema/`.*

## Component Runtime Execution Requirements

The client side of this interface is a library linked into the calling process; the server side is a
separate process. What follows applies to a caller running the client, which for this repository is
GponManager and for a test harness is whatever process links the same client library.

### Initialization and Startup

**Three steps, in this order, and the third is not optional.** The manager's own bring-up is the
reference sequence [`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:107-151`]:

1. `json_hal_client_init()` with the path of the client configuration file
   [`gponmgr_dml_hal.c:111`]. This is where the deployment contract is read.
2. `json_hal_client_run()`, which starts the client socket thread [`gponmgr_dml_hal.c:117`].
3. Poll `json_hal_is_client_connected()` until it reports a connection, sleeping one second between
   attempts and giving up after ten [`gponmgr_dml_hal.c:130-143`, with
   `HAL_CONNECTION_RETRY_MAX_COUNT` at `:37`]. Initialization fails if the connection is not
   established inside that window, and the manager returns failure rather than proceeding
   [`gponmgr_dml_hal.c:145-149`].

Step 3 exists because step 2 succeeding does not mean a connection exists. `json_hal_client_run()`
starts a thread; the socket connects asynchronously on that thread. A caller that issues a request
immediately after step 2 may be issuing it into an unconnected client.

**What step 1 actually reads, which matters more than it looks.** The configuration file supplies
the server port and the schema path. The client library then opens the **schema file itself** and
takes the module name and the schema version out of it — `definitions.moduleName.const` and
`definitions.schemaVersion.const` — storing both for later use. Every request header the client
subsequently builds carries those two values as its `module` and `version` fields. Three
consequences follow for anyone deploying or testing this HAL:

- The schema file must exist and be readable at the path the configuration names, or initialization
  fails. It is a runtime dependency of the client, not merely a design-time artefact.
- The `module` and `version` a caller sends are **not** hard-coded in the caller. They come from the
  deployed schema file, so deploying the wrong file silently changes the identity of every message.
- Because both GPON schemas declare the same `moduleName` `gponhal` and the same `schemaVersion`
  `0.0.1`, a variant mismatch between manager and vendor is **not** detectable from the envelope. It
  shows up later, as an unrecognised parameter name.

**No initialization message is sent over the wire.** Some `JSON` HALs in `RDK-B` write an
initialization flag as their first request; this contract defines no such parameter, and the manager
sends nothing at bring-up. The first message a vendor server sees is an ordinary request.

**The client entry points this interface is used through**, all declared by the pinned transport
library cited in `Build Requirements`:

- `json_hal_client_init()` — read the configuration and the schema, and prepare the client
- `json_hal_client_run()` — start the client socket thread
- `json_hal_is_client_connected()` — test whether the socket is connected
- `json_hal_client_get_request_header()` — build an envelope for a named action
- `json_hal_add_param()` — append a parameter entry to a request's `params` array
- `json_hal_client_send_and_get_reply()` — send and wait for the correlated reply
- `json_hal_client_send_and_get_reply_with_timeout()` — the same, with a caller-supplied wait
- `json_hal_client_subscribe_event()` — register a callback and subscribe one event
- `json_hal_get_result_status()` — read `Result.Status` out of a reply
- `json_hal_get_total_param_count()` and `json_hal_get_param()` — walk a reply's `params` array
- `json_hal_client_terminate()` — tear the client down

GponManager uses `json_hal_client_get_request_header()`, `json_hal_add_param()`,
`json_hal_client_send_and_get_reply()`, `json_hal_get_result_status()`, `json_hal_get_param()` and
`json_hal_client_subscribe_event()` [`gponmgr_dml_hal.c:218-286`, `:753`, `:1392`]. It does not call
`json_hal_client_terminate()` anywhere, so on this client the socket's lifetime is the process's
lifetime.

**Vendor obligation.** The server must be listening before, or shortly after, the client starts, and
must accept a reconnection without operator intervention: the client's ten-second window is the
whole budget a cold start gets, and a server that is not accepting connections inside it causes
manager initialization to fail outright rather than to degrade.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:37,100-151,218-286,753,1392`,
`config/gpon_manager_conf.json`, and `json_hal_client.h` / `json_hal_common.h` at the pinned
transport revision cited in `Build Requirements`.*

### Threading Model

**Transport threading belongs to the client library, not to this interface.**
`json_hal_client_run()` starts the client socket thread, so after initialization a dedicated thread
owns the socket and performs the receive loop. A caller's own thread never touches the socket.

**Asynchronous event callbacks arrive on that library-owned thread**, not on the thread that
registered them. GponManager registers its callback through `json_hal_client_subscribe_event()`
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:1389-1396`], and the callback signature receives
the raw event message and its length rather than a parsed object, so parsing happens on the
library's thread inside the callee. Any state a callback touches must therefore be synchronized by
the caller; the manager's callback parses the message and hands the result to the surrounding
component rather than mutating shared state in place.

**Concurrent requests are serialised by the library, and the consequence is a queue, not
interleaving.** The synchronous send path takes a mutex for the whole exchange: the transport
library documents `json_hal_client_send_and_get_reply()` and its timed form as blocked "until we get
a proper response from the server or timed out happened", and states that the lock it takes is
"unlocked once we get response from server or when the timeout period expired". So a second caller
does not have its request interleaved with the first — it waits for the first exchange to finish or
to time out. Two things follow that a caller must plan for:

- **Throughput is one outstanding request at a time**, regardless of how many threads call. Batching
  several parameters into one `params` array is the way to reduce round trips, subject to the buffer
  limit in `Memory Model`.
- **A slow or unresponsive server delays every waiting caller**, not only the one that asked. With
  the ten-second floor described in `Blocking calls`, a server that stops answering costs each queued
  caller its own full wait in turn.

**Vendor obligation.** A server must tolerate a single long-lived client connection carrying
sequential requests, and it must stamp every reply with the `reqId` of the request it answers —
that identifier is the only field a client can correlate on, and the client library cross-checks it
before handing a reply back.

*Derived from `json_hal_client.h` and `json_hal_client.c` at the pinned transport revision cited in
`Build Requirements`, and `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:1389-1396`.*

### Process Model

**Two processes across a socket, not a library linked into one.** This is the structural difference
between this HAL and the C HALs elsewhere in `RDK-B`, and it changes what a caller must plan for. A
C HAL is a shared object loaded into the calling process, so a HAL call is a function call and a HAL
fault is the caller's fault. Here the vendor implementation is a **separate process** reached over a
`TCP` socket, so:

- The two sides start, stop and fail independently. The vendor server may be restarted underneath a
  running manager, and the manager may be restarted underneath a running server.
- A HAL call is an `IPC` round trip and can fail for transport reasons that have nothing to do with
  the parameter being read or written. Every call site must handle a transport failure distinctly
  from a `Failed` result status.
- Loss of the connection is a first-class state rather than an exception. It is observable through
  `json_hal_is_client_connected()`, which is why initialization polls it instead of assuming success.

**The exchange is `JSON-RPC` style over a `TCP` socket**, as the transport library's own description
of both participants states [`json-hal-library/README.md:50,132`]: a request names an action, and the
reply that answers it is matched to the request by identifier rather than by position on the
connection.

**The socket is loopback-only, so both processes run on the same device.** The client sets its host
to `127.0.0.1` and takes only the port from the configuration file, so the server address is not
configurable. A vendor server must listen on the loopback interface on port `40100`; nothing in this
interface permits a remote server, and a test harness must run on the device under test rather than
alongside it.

**Roles are fixed and asymmetric.** GponManager is always the **client** and the vendor software
always supplies the **server**. Both sides are given the port by the same configuration file, so
they agree on it without a discovery step. The server's listen backlog is 32 connections, which is
ample for the single client this interface expects and is stated here only so that a vendor
implementing the server side knows it is not one.

**Direction of travel per action.** The client originates `getSchema`, `getParameters`,
`setParameters`, `subscribeEvent`, `getActiveSubscriptions` and — were it usable — `deleteObject`.
The server originates `getSchemaResponse`, `getParametersResponse`,
`getActiveSubscriptionsResponse`, `result` and `publishEvent`. Only `publishEvent` is unsolicited.
`API Surface` gives the complete mapping with the payload each action must carry.

*Derived from `tcp_client.h`, `tcp_client.c`, `tcp_server.c` and `json_hal_client.c` at the pinned
transport revision cited in `Build Requirements`, and `config/gpon_manager_conf.json`.*

### Memory Model

Because the vendor implementation is a separate process, no memory is shared across the HAL boundary
and no buffer lifetime spans it. What crosses the boundary is a serialized `JSON` document. The
memory model that matters to a caller is therefore entirely local: it concerns the `json_object`
handles the client library hands out and takes back, and those are reference-counted rather than
owned outright.

Two handles exist per exchange. The **request** object is created by the caller, conventionally from
`json_hal_client_get_request_header()`, which returns a `json_object` already carrying the `module`,
`version`, `action` and `reqId` fields, and — for every action except `getSchema` — an empty `params`
array ready for the caller to append to. The **reply** object is produced by the library and returned
through an out-parameter. Both are released with `json_object_put()`, which decrements the reference
count rather than freeing unconditionally.

#### Caller Responsibilities

- **Release both handles on every path, including every failure path.** The reply must be released
  even when the exchange reported failure, because the library may have produced a partial or error
  reply before returning. The manager's pattern is a guarded release macro applied to both handles at
  each exit [`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:46-50`], used at every failure branch
  around a send [`gponmgr_dml_hal.c:264-270`].
- **Guard the release.** The reply out-parameter is left untouched when a call fails early, so it
  must be tested before it is released; that is what the manager's macro does.
- **Do not retain a value extracted from a reply beyond the reply's lifetime.** Values read out of a
  reply with `json_hal_get_param()` must be copied into caller-owned storage before the reply handle
  is released. A pointer into a released `JSON` document is not valid afterwards.
- **Bound what one message carries.** The transport's receive buffer is 16384 bytes. Larger messages
  are reassembled across successive reads rather than truncated, but the buffer is not negotiable, so
  a caller batching many parameters into one `params` array should size the batch with that figure in
  mind. The bulk reads the manager issues are scoped by object prefix for exactly this reason; see
  `API Surface`.
- **Do not reuse a request handle for a second send.** Correlation depends on each exchange carrying
  its own `reqId`, and the header helper allocates one per call.
- **Zero-terminate every string placed in a request.** The parameter entry the manager fills is a
  fixed-size character structure copied with a bounded copy [`gponmgr_dml_hal.c:218-231`], and the
  transport serializes it as a C string.

#### Module Responsibilities

- The client library owns the socket buffer and the reassembly of a message that spans several
  reads. A caller never sees a partial document.
- The library populates the reply handle only when it has a complete parsed document, and it
  transfers that handle to the caller, who becomes responsible for releasing it.
- The library owns the request-identifier counter and the tracking record for an outstanding
  request, and releases that record when the exchange completes or expires.
- The vendor server owns everything on its side of the socket. It must not assume that a client
  which disconnected has released anything on its behalf, and it must be able to serve a fresh
  connection from a restarted manager.
- Neither side may assume the other's allocation lifetimes. This is the practical benefit of the
  two-process model: a leak or a corruption in the vendor implementation cannot corrupt the
  manager's heap, which is not true of a C HAL loaded into the calling process.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:46-51,219-231,264-286`, and
`json_hal_client.h`, `json_hal_common.h` and `json_rpc_common.h` at the pinned transport revision
cited in `Build Requirements`.*

### Power Management Requirements

**No power-management behaviour is specified by this interface.** Neither shipped schema defines a
power state, a low-power mode, a sleep or wake action, or a parameter reporting participation in
power management; no action in the vocabulary requests a power transition; and neither the client
configuration nor the manager source establishes any power-management role for this HAL. A caller
must not expect a `GPON` HAL request to affect device power state, and a vendor is not obliged by
this contract to implement one.

**One nearby group of parameters is easy to mistake for power management and is not.** The
`PhysicalMedia` segment carries optical diagnostics — received and transmitted signal levels with
their lower and upper thresholds, supply voltage, laser bias current and transceiver temperature.
These are optical link measurements, and the four writable threshold parameters set alarm thresholds
rather than transmit power. Reading or writing them does not change device power consumption, and
this contract states nothing about the effect of writing them beyond the alarm behaviour the
`ITU-T G.988` clauses cited in their descriptions define.

*Derived from the absence of any power-related definition in both files under `hal_schema/`, and the
`PhysicalMedia` parameter descriptions in `hal_schema/gpon_hal_schema.json`.*

### Asynchronous Notification Model

**One subscription mechanism, two message flows.** A caller subscribes with `subscribeEvent`, which
the server acknowledges with a `result`; thereafter the server sends `publishEvent` messages
unsolicited whenever the subscribed parameter meets the notification condition. A caller can
enumerate what it is subscribed to with `getActiveSubscriptions`, answered by
`getActiveSubscriptionsResponse`.

**Required fields differ between the two, which is the most common mistake in implementing them.**
A `subscribeEvent` parameter entry requires `name` and `notificationType` and carries no value. A
`publishEvent` parameter entry requires `name`, `type` and `value` — the datatype travels with the
event, so a receiver does not have to look the parameter up to interpret its value.

**`notificationType` admits exactly two values: `interval` and `onChange`, with `onChange` as the
default.** This is worth stating sharply because the transport library defines two further types,
`onChangeSync` and `onChangeSyncTimeout`, behind its `JSON_BLOCKING_SUBSCRIBE_EVENT` compile guard.
Those two belong to another `RDK-B` `JSON` HAL's contract, **not to this one**: neither appears in
either GPON schema, so a subscription requesting one is not a valid message on this interface, and a
vendor server implementing this contract need not support them. GponManager subscribes with
`onChange` [`source/TR-181/middle_layer_src/gponmgr_dml_hal.h:43`].

**The subscribable surface is exactly eighteen parameters, identical in both schema variants.** No
other parameter may be subscribed, because `subscribeEvent` and `publishEvent` both bind their
`params` items to `subscribeEventSupportedList` and to nothing else:

| Group | Parameters |
| --- | --- |
| Optical status | `Device.X_RDK_ONT.PhysicalMedia.{i}.Status` |
| Optical alarms (14) | `Device.X_RDK_ONT.PhysicalMedia.{i}.Alarm.` `Rdi`, `Pee`, `Los`, `Lof`, `Dact`, `Dis`, `Mis`, `Mem`, `Suf`, `Sd`, `Sf`, `Lcdg`, `Tf`, `Rogue` |
| Registration | `Device.X_RDK_ONT.Ploam.RegistrationState` |
| `VEIP` state | `Device.X_RDK_ONT.Veip.{i}.AdministrativeState` and `.OperationalState` |

Each alarm carries `alarmEnumList`, so an event value is `Active` or `Inactive`; the optical status
carries `statusEnumList`; the registration state carries its own nine-value enumeration. `Ploam`
is a singleton so its path has no instance number, while `PhysicalMedia` and `Veip` are indexed.
`State Diagram` enumerates every value each of these can take.

**Delivery guarantees are not specified, and a caller must not assume them.** Nothing in either
schema or in the transport states whether an event is delivered at least once, whether events are
coalesced when a value changes twice quickly, whether a subscription survives a reconnection, or
whether an initial value is published on subscription. A caller that needs current state should
read it with `getParameters` rather than wait for an event, and should re-subscribe after any
reconnection rather than assume the subscription persisted.

**Vendor obligation.** A server must acknowledge every `subscribeEvent` with a `result` — silence
costs the caller its full timeout — must publish only parameters that appear in the subscribable
list above, and must send `publishEvent` with all three required fields populated, since a receiver
has no other way to type the value.

*Derived from `definitions.subscribeEvent`, `definitions.publishEvent`,
`definitions.subscribeEventSupportedList` and `definitions.notificationType` in both files under
`hal_schema/`; `source/TR-181/middle_layer_src/gponmgr_dml_hal.h:43` and
`gponmgr_dml_hal.c:1389-1396`; and `json_rpc_common.h:52-56` at the pinned transport revision.*

### Blocking calls

**The request path is synchronous and it blocks.** The C HALs in `RDK-B` require that none of their
calls block; this interface is the opposite, and a caller coming from a C HAL must adjust for it. A
send-and-reply call blocks the calling thread until the server answers or the wait expires, so HAL
requests must not be issued from a thread with latency obligations of its own.

**The wait is counted in ticks and clamped at both ends, and the floor is the part that surprises
callers.** The transport waits in 250-millisecond ticks. The untimed form passes a fixed 40 ticks,
which is exactly **10 seconds**. The timed form converts the caller's request into ticks and then
bounds it: fewer than 40 ticks is raised to 40, and more than 480 is reduced to 480 — a ceiling of
exactly **120 seconds**.

| Requested wait | Effective wait | Why |
| --- | --- | --- |
| The untimed form | exactly 10 seconds | It passes the floor value, so it is the *shortest*-waiting form rather than an unbounded one. |
| Under 10 seconds | 10 seconds | Raised to the tick floor. A short timeout is not honoured, and asking for 2 seconds still costs 10. |
| 10 to 120 seconds | as requested | Between floor and ceiling, so used as given, rounded to a whole 250-millisecond tick. |
| Over 120 seconds | 120 seconds | Reduced to the ceiling. Asking for 300 seconds gives 120. |

**GponManager uses only the untimed form**, at eight send sites — one for the set path and one for
each of the seven object-prefix reads
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:264`, `:741`, `:806`, `:873`, `:941`, `:1001`,
`:1080`, `:1165`]. Every HAL exchange this manager performs therefore has a 10-second budget, and a
caller wanting longer must use the timed form deliberately.

**Connection establishment blocks for its own bounded window**, up to ten one-second attempts, as
`Initialization and Startup` sets out. The worst case for a cold start is that window followed by
the first request's wait.

**Nothing on this interface is asynchronous except event delivery.** There is no request handle to
poll, no completion callback for a request, and no way to cancel one in flight. A caller needing
concurrency gets it by not calling from a latency-sensitive thread, not by a non-blocking form of
these calls — and, as `Threading Model` notes, additional threads queue behind the library mutex
rather than overlapping.

**Vendor obligation.** A server must answer every request it receives, including one it cannot
satisfy. An unanswered request costs the caller its full wait and yields no information, whereas a
prompt `result` carrying `Failed`, `Invalid Argument` or `Not Supported` costs a round trip and tells
the caller what happened.

*Derived from `tcp_client.h:35`, `json_hal_client.c:35,589-598,614` at the pinned transport revision
cited in `Build Requirements`, and the eight send sites listed above in
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c`.*

### Internal Error Handling

**Errors arrive in the reply, not out of band.** There is no error callback and no error event. A
failure is either a **transport failure**, visible as a failed send-and-reply call, or an
**application failure**, carried in the reply's `Result.Status`. A caller must distinguish the two:
the first means the request may never have been processed, the second means it was processed and
refused.

`Result.Status` takes one of four values, from `definitions.resultStatusEnumList`, with `Success` as
the schema's default. The value is read with `json_hal_get_result_status()` rather than by reaching
into the document. What a caller should do differs per value:

| Status | Meaning | What the caller should do |
| --- | --- | --- |
| `Success` | The request was accepted and applied. | Proceed. For a write, success means the vendor accepted the value, not that any dependent optical or registration state has finished converging — re-read the affected parameter if the settled value matters. |
| `Failed` | The request was understood but could not be applied. | Do not retry blindly; the same request will usually fail again. Log the parameter and the status, and surface the failure upward. |
| `Invalid Argument` | A parameter name, type or value was not acceptable. | Treat as a defect in the request rather than a transient condition. Check the name against the schema's `name` constraint, the `type` against the parameter's declared datatype, and the value against its constraint. |
| `Not Supported` | The vendor does not implement this parameter or action. | Treat as a normal outcome for a path reachable only through `getParameterOptionalList`, and stop requesting it. See `Optional Components`. |

**`Invalid Argument` and `Not Supported` are the two most often mishandled**, because both are
permanent for a given request and neither should be retried. Retrying either produces load without
progress.

**Two spellings a caller will meet, given as upstream writes them.** The reply's payload object is
`Result` with a single `Status` property, and the transport library's macro for that field name is
spelled `JSON_RPC_FILED_RESULT` — `FILED`, not `FIELD`. That is the upstream spelling
[`json_rpc_common.h:57`], reproduced here so a reader grepping the transport source finds it, and it
does not change the wire field name, which is `Result`. Likewise the status value `Invalid Argument`
contains a space, as does `Not Supported`; neither is camel-cased.

**A write is acknowledged by `result`, not by a dedicated response action.** There is no
`setParametersResponse` in this protocol. `API Surface` states this in full, because assuming
otherwise is the single most common misreading of this interface.

**How the manager treats the status, as a worked reference.** The set path reads the status and
treats anything other than success as a failure of the whole operation, logging the parameter name
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:272-286`]; a failure to extract a status at all is
handled distinctly from a status of failure, because the two mean different things.

**Vendor obligation.** A server must choose the status that describes the actual outcome rather than
defaulting to `Failed` for every refusal — the caller's correct response differs per value — and it
must not report `Success` for a write it did not apply.

*Derived from `definitions.resultStatusEnumList` and `definitions.result` in both files under
`hal_schema/`; `json_rpc_common.h:57` and `json_hal_client.h` at the pinned transport revision; and
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:264-290`.*

### Persistence Model

**This interface makes no persistence guarantee.** Neither shipped schema states whether a value
written with `setParameters` survives a reboot, a vendor-process restart or a client reconnection. No
action requests persistence, no parameter reports whether a value is persisted, and no result status
distinguishes a value that was applied from one that was applied and stored. A caller must not infer
durability from a `Success` result, and should re-apply any value it needs to hold after a restart on
either side of the socket.

**What the interface does define is correlation state, and it is per-connection rather than
persistent.** Requests are matched to replies by `reqId`, a client-side counter that starts at 100,
increments once per request header and wraps back to its start value on overflow. The identifier is
formatted as a zero-padded eight-digit decimal string, so the first request of a fresh client carries
`"00000101"`, which satisfies the envelope's `^[0-9]+$` constraint. Two consequences: the counter is
**not** stable across a client restart, so a `reqId` must never be used as a durable key for
anything; and a server must correlate on the identifier it was sent rather than on arrival order,
because that is the only thing the client checks a reply against.

**Nothing on the wire is cached, but the manager caches above it, and a caller reading through the
`DML` sees the result.** GponManager suppresses a re-read of an object it fetched less than
`DML_GTC_FETCH_INTERVAL` seconds ago — 10 seconds
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:72`] — applied to the `TR69`, `Omci`, `Ploam` and
`Gtc` reads [`gponmgr_dml_hal.c:727`, `:793`, `:859`, `:927`]. A value read from the manager's `DML`
may therefore be up to 10 seconds old, while a value read directly over this HAL is as current as the
vendor server makes it. That distinction matters when writing a test: asserting on a counter through
the `DML` immediately after provoking a change can observe the cached value.

**Vendor obligation.** A server must answer with values current as of the reply, not as of an
earlier internal poll, or must document its own sampling interval — this contract states none, so a
caller cannot otherwise know how stale a counter is.

*Derived from `properties.reqId` in both files under `hal_schema/`;
`json_hal_client.c:42,840-859,959-966` and `json_rpc_common.h:89` at the pinned transport revision;
and `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:72,727,793,859,927`.*

## Non functional requirements

The following non-functional requirements apply to a vendor implementation of the GPON `JSON` HAL
server and, where stated, to the client side of the interface.

### Logging and debugging requirements

Vendor software is required to record all errors and critical informative messages, so that the
functional flow across the socket can be identified and debugged. Logging should use the `syslog`
mechanism, which is suited to system-level software; the use of `printf` is discouraged unless
`syslog` is unavailable.

Logs should be categorized by the following levels, as defined by the Linux standard logging system
and listed here in descending order of severity:

- **FATAL:** Critical conditions, typically indicating a crash or a failure that requires immediate
  attention.
- **ERROR:** Non-fatal error conditions that nonetheless significantly impede normal operation.
- **WARNING:** Potentially harmful situations that do not yet represent errors.
- **NOTICE:** Important but not error-level events.
- **INFO:** General informational messages that highlight system operation.
- **DEBUG:** Detailed information useful when diagnosing a problem.
- **TRACE:** Very fine-grained logging that traces internal flow.

Each entry should carry a timestamp, the level and a message describing the event, so that logs from
different vendors and components can be parsed and correlated uniformly.

**No vendor log file is specified for this interface.** Several C HALs in `RDK-B` name one — MoCA
requires `moca_vendor_hal.log` under `/var/tmp/` or `/rdklogs/logs/`, for instance — but neither
shipped schema, the client configuration, nor the manager source names a log file, a directory or a
log-rotation requirement for the `GPON` HAL. This document does not invent one by analogy. A vendor
choosing a name should follow the corpus convention of a single component-scoped file under
`/rdklogs/logs/`, and should state the choice in its own release documentation, but nothing in this
contract obliges a particular name.

**Where the client side's own diagnostics go, which is worth knowing before debugging a failure.**
Two facts about the code paths on the manager's side of the socket:

- GponManager logs through the `RDK-B` trace macros, so its HAL failures reach the component's
  normal log — for example the initialization failures at
  [`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:113,119,147`] and the invalid-parameter guard at
  [`:39-44`].
- Some failures on the send path are written with `fprintf` to standard error rather than through
  the trace macros [`gponmgr_dml_hal.c:266,280,285`], as are the transport library's own error and
  informational messages [`json_rpc_common.h:94-98`]. A reader who finds nothing in the component log
  after a failed exchange should check the process's standard error before concluding that nothing was
  logged.

**Debugging the wire itself.** Because both participants are separate processes on the loopback
interface, an exchange can be observed without instrumenting either: the messages are `JSON`
documents on `TCP` port `40100`. Each is self-describing — the envelope names the module, the schema
version, the action and the correlation identifier — so a captured message can be validated against
the shipped schema directly, which is the check `Quality Control` recommends.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:39-44,113,119,147,266,280,285`;
`json_rpc_common.h:94-98` at the pinned transport revision; the absence of any logging requirement in
both files under `hal_schema/` and in `config/`; and the register of
`rdkb-halif-moca/docs/pages/MoCAHalSpec.md`.*

### Memory and performance requirements

**Client module responsibility.** The caller allocates and releases the `json_object` handles
described in `Memory Model`, and copies any value it needs out of a reply before releasing it.

**Vendor implementation responsibility.** A vendor server allocates whatever it needs internally and
is solely responsible for releasing it. Nothing crosses the process boundary, so a vendor's
allocation policy cannot affect the caller's heap.

**The quantitative limits this interface actually imposes**, each with the artefact that sets it:

| Limit | Value | Where it comes from |
| --- | --- | --- |
| Transport receive buffer | 16384 bytes per read, reassembled across reads for a larger message | `MAX_BUFFER_SIZE`, transport library |
| Synchronous reply window | 10 seconds floor, 120 seconds ceiling | Tick clamp, transport library; see `Blocking calls` |
| Connection establishment window | 10 attempts, 1 second apart | `HAL_CONNECTION_RETRY_MAX_COUNT`, manager |
| Server listen backlog | 32 | Transport library server |
| Manager-side re-read suppression | 10 seconds per cached object | `DML_GTC_FETCH_INTERVAL`, manager |
| Outstanding requests per client | one at a time, serialised by the library mutex | Transport library; see `Threading Model` |

**No memory footprint limit and no CPU budget are specified for this interface.** Neither schema, the
client configuration nor the manager source states a resident-memory ceiling, a per-request CPU
budget or a throughput target for a vendor server, and this document does not invent one. A vendor
should size its implementation against the product specification for the platform it ships on. What
*is* specified, and is the practical performance contract, is the reply window above: a server that
cannot answer inside 10 seconds will have its caller time out on the untimed form that GponManager
uses everywhere.

**One performance consequence of the model worth planning for.** Because requests serialise and each
carries a full round trip, the cost of reading the `ONT` is dominated by the number of requests
rather than by their size. The manager reads by object prefix — seven requests for the whole tree
rather than one per parameter [`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:737,802,869,937,997,1076,1161`] —
and a caller should follow the same pattern within the 16 KiB limit.

*Derived from `json_rpc_common.h:87`, `tcp_client.h:35`, `json_hal_client.c:35,589-598`,
`tcp_server.c:155` at the pinned transport revision; and
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:37,72,737-1161`.*

### Quality Control

To ensure quality and reliability, third-party analysis tools such as `Coverity`, `Black Duck` and
`Valgrind` should be used to analyse a vendor implementation, so that memory leaks, memory
corruption and other defects are found before deployment. Both the vendor server and any client
linking the transport library must practise disciplined allocation, release and error handling, for
the reasons `Memory Model` sets out.

**One check is specific to a schema-defined interface and is the most valuable one available here:
validate every message against the shipped schema.** Because the contract is a machine-readable
`draft-07` schema, conformance is testable directly rather than by inspection — a request or reply
can be validated against `hal_schema/gpon_hal_schema.json`, or against
`hal_schema/gpon_wan_unify_hal_schema.json` for a unified-WAN build, before it is trusted. Two
qualifications a tester needs:

- **Validate against the variant the build uses.** A message can be valid under one schema and
  invalid under the other, since the variant's parameter set is a superset.
- **Do not treat the shipped example messages as pre-validated fixtures.** The repository ships eight
  `hal_schema/example_*_msg.json` files, and they are illustrative rather than conformance-tested:
  they are not all valid against the schema they sit beside, and one is valid but names a schema path
  belonging to a different HAL. [`halSpecDetailed.md`](halSpecDetailed.md) records each file's
  disposition and publishes corrected worked exchanges. The examples themselves are left unmodified,
  because they are shipped artefacts that other consumers may depend on.

**Static conformance of the contract itself is also checkable, and is not clean.** Both schemas fail
the `draft-07` meta-schema in exactly two places each, in both cases an empty `anyOf` array that no
instance can satisfy. Neither is repaired here — the schemas are the contract and this documentation
does not edit them — and both are recorded in [`halSpecDetailed.md`](halSpecDetailed.md), together
with the consequence for `deleteObject` that `API Surface` states. A test suite adding a meta-schema
check should expect those two failures per file and fail on any third.

**Keeping this document true, with a named addressee.** Every topic here names the file it was
derived from, which makes staleness detectable from a diff rather than from a review-by date:
**any change to a file this document cites obliges a review of the topics that cite it.** The
files that matter most are the two schemas, the two client configuration files and
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c`, since a change to any of them can invalidate a
statement here without touching this file. The responsible reviewer is the repository's code owner,
**`@rdkcentral/wanmanager-maintainers`** [`.github/CODEOWNERS:5`], and a pull request that changes any
cited file should carry a review of the affected topics.

*Derived from `.github/CODEOWNERS:5`; the meta-schema and instance validation of both files under
`hal_schema/` and of the eight `hal_schema/example_*_msg.json` files; and the register of
`rdkb-halif-moca/docs/pages/MoCAHalSpec.md`.*

### Licensing

The GPON HAL contract and this repository are licensed under the **Apache License, Version 2.0**. A
vendor implementation of the HAL server is expected to be released under the same licence.

The licence text and the attribution notice ship with the repository as `LICENSE`, `COPYING` and
`NOTICE` at its root, and are rendered alongside this specification in the generated documentation
through the `LICENSE.md`, `COPYING.md` and `NOTICE.md` symlinks in this folder, so the terms are
verifiable from inside the documentation set. Every source file in the repository carries the
Apache-2.0 header, and files added by this documentation work preserve it.

*Derived from `LICENSE`, `COPYING` and `NOTICE` at the repository root, and the licence headers in
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:1-18`.*

### Build Requirements

**No HAL library is built from this repository, and none is linked across the HAL boundary.** This
follows from the contract being a schema rather than a header, and it is the first thing an
integrator coming from a C HAL needs to know. There is no `libhal_*` artefact to produce for the HAL
itself, no header to install for the contract, and no symbol a vendor must export. What a vendor
delivers is a **process** that speaks the protocol and validates against the shipped schema; what
this repository delivers on the HAL boundary is the schema file, deployed to the path named in
`Optional Components`.

**What the client side links.** The manager builds with `autotools` and should be capable of
building under the Yocto distribution environment. The middle layer that contains all HAL
interaction links `-lccsp_common -lhal_platform -ljson_hal_client -ljson-c -lpthread -lsyscfg`
[`source/TR-181/middle_layer_src/Makefile.am:39`], and the manager binary additionally links the
`RDK-B` logging and secure-wrapper libraries [`source/GponManager/Makefile.am:31`]. A component other
than this manager that wants to speak this HAL links the same client library, `json_hal_client`.

**The transport library, cited by pinned revision.** The client library is `json-hal-library`, and
this document cites it at the exact revision this workspace records for it rather than by a moving
reference:
[`json-hal-library` at commit `86a0a300b976f8e3295064af8fb3fd1c793c9e64`](https://github.com/rdkcentral/json-hal-library/tree/86a0a300b976f8e3295064af8fb3fd1c793c9e64).
Its
[`json_hal_client.h`](https://github.com/rdkcentral/json-hal-library/blob/86a0a300b976f8e3295064af8fb3fd1c793c9e64/json_hal_client.h)
is the authority for every client entry point named in this specification,
[`json_hal_server.h`](https://github.com/rdkcentral/json-hal-library/blob/86a0a300b976f8e3295064af8fb3fd1c793c9e64/json_hal_server.h)
for the server side a vendor implements, and
[`json_hal_common.h`](https://github.com/rdkcentral/json-hal-library/blob/86a0a300b976f8e3295064af8fb3fd1c793c9e64/json_hal_common.h)
for the configuration and parameter helpers. They are cited rather than restated so that the two
cannot drift, and every buffer, tick and backlog constant quoted in this document comes from that
revision. A vendor implementing the server side uses `json_hal_server_init()`,
`json_hal_server_register_action_callback()`, `json_hal_server_run()`,
`json_hal_server_publish_event()` and `json_hal_server_terminate()` from that header.

**The `json-c` dependency, stated in both of its forms because either alone misleads.** The
transport library declares its dependency as **`json-c (0.11)`**, which is the **declared minimum**
[`json-hal-library/README.md:56`, and again at `:140`]; its upstream native build, however, is
exercised against the **`json-c-0.15-20200726`** revision
[`json-hal-library/cov_docker_script/component_config.json:11`]. An integrator who reads only the
first will under-provision relative to what upstream actually tests; one who reads only the second
will overstate what the library requires. Both are therefore given, each labelled with what it is.

**Build-time selection.** Which schema variant a build speaks is a compile-time decision, not a
runtime one. `Variability Management` and `Platform or Product Customization` set out the control and
what it changes.

*Derived from `source/TR-181/middle_layer_src/Makefile.am:39`, `source/GponManager/Makefile.am:31`,
`json-hal-library/README.md:56,140` and
`json-hal-library/cov_docker_script/component_config.json:11` at the pinned transport revision.*

### Variability Management

**The interface is versioned, and its version is not the caller's to change.** The envelope's
`version` field is bound to `definitions.schemaVersion`, a `const` of **`0.0.1`** in both shipped
files, whose own description states: *"DO NOT modify the value of the version string. HAL operation
cannot be performed without correct supported version."* The schema file as a whole carries the same
instruction at its top level: *"DO NOT modify the contents of this schema file. RDK community team
make necessary changes and release."* Adjusting the interface is an architecture decision released
through this repository; a vendor aligns its implementation with a released version of the contract
rather than editing the deployed file. Each released interface is versioned per
[Semantic Versioning 2.0.0](https://semver.org/).

**Selection of the variant is two steps, and both must be understood to know which contract a build
speaks.** Step one is a compile-time flag that picks the *configuration file*
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:57-61`]:

```c
#if defined(WAN_MANAGER_UNIFICATION_ENABLED)
#define GPON_MANAGER_CONF_FILE "/etc/rdk/conf/gpon_manager_wan_unify_conf.json"
#else
#define GPON_MANAGER_CONF_FILE "/etc/rdk/conf/gpon_manager_conf.json"
#endif
```

Step two is that the chosen configuration names the *schema* and the *port*:

- `config/gpon_manager_conf.json` names `/etc/rdk/schemas/gpon_hal_schema.json` and port `40100`.
- `config/gpon_manager_wan_unify_conf.json` names
  `/etc/rdk/schemas/gpon_wan_unify_hal_schema.json` and port `40100`.

So the flag selects the configuration and the configuration selects the contract. Documenting the
schema variant without the flag would leave a reader unable to tell which contract their build
speaks, and documenting the flag without the configuration would leave them unable to find the
schema. Two further points follow from step two: the port is identical either way, so it carries no
information about the variant; and because the client reads `moduleName` and `schemaVersion` out of
the deployed schema file rather than hard-coding them, as `Initialization and Startup` describes,
replacing that file changes what the client sends.

**Nothing else in this interface varies.** There is no runtime capability negotiation, no feature
flag on the wire and no version handshake beyond the `version` field the schema fixes. A caller
cannot ask a server which variant it implements; the closest available check is `getSchema`, which
returns the path of the schema the server is using, and `API Surface` describes what that does and
does not tell a caller.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:57-61`,
`config/gpon_manager_conf.json`, `config/gpon_manager_wan_unify_conf.json`, and
`definitions.schemaVersion` and the top-level `description` in both files under `hal_schema/`.*

### Platform or Product Customization

**One compile-time flag customizes this interface: `WAN_MANAGER_UNIFICATION_ENABLED`.** It exists so
that a product whose `WAN` interfaces are managed through the unified `WAN` manager can present the
`ONT`'s optical interface with the standard `TR-181` interface controls, which the default build does
not expose. What it changes, measured against both shipped schemas and the manager source:

| Effect | Default build | `WAN_MANAGER_UNIFICATION_ENABLED` |
| --- | --- | --- |
| Configuration file read | `/etc/rdk/conf/gpon_manager_conf.json` | `/etc/rdk/conf/gpon_manager_wan_unify_conf.json` |
| Schema the configuration names | `gpon_hal_schema.json` | `gpon_wan_unify_hal_schema.json` |
| Parameter definitions | 90 | 95 |
| Writable parameters | 8 | 11 |
| Datatypes in use | `string`, `int`, `unsignedInt`, `unsignedLong` | the same, plus `boolean` |
| Vendor server process | started by the platform | started by the manager if `/bin/json_hal_server_gpon` or `/usr/bin/json_hal_server_gpon` exists |

**The five parameters the variant adds**, all on the indexed optical interface
`Device.X_RDK_ONT.PhysicalMedia.{i}.`:

| Parameter | Datatype | Access | What it is |
| --- | --- | --- | --- |
| `Enable` | `boolean` | Read-Write | Whether the interface is enabled |
| `Alias` | `string`, up to 64 characters | Read-Write | Non-volatile unique key for referencing this instance |
| `LowerLayers` | `string`, up to 1024 characters | Read-Write | Comma-separated list of lower-layer interface paths |
| `LastChange` | `unsignedInt` | Read-Only | Seconds accumulated in the current operational state |
| `Upstream` | `boolean` | Read-Only | Whether the interface points towards the network rather than towards end devices |

Three of the five — `Enable`, `Alias` and `LowerLayers` — are writable, and they are what takes the
writable surface from 8 to 11: in the default build the only writable parameters are the four optical
signal-level thresholds and the four `VEIP` Ethernet-flow tag and `VLAN` identifier parameters.
`Enable` and `Upstream` are the interface's only `boolean` parameters, so a client built for the
default schema will never encounter that datatype and a vendor server serving the variant must handle
it.

**The manager's own `DML` glue is behind the same flag**, defining the four additional parameter
paths it reads and writes only when the flag is set
[`source/TR-181/middle_layer_src/gponmgr_dml_hal.h:53-57`]. So the flag is consistent end to end:
configuration, schema, writable surface and manager code all move together, and there is no build in
which the manager addresses a parameter its schema does not declare.

**What the flag does not change.** The action vocabulary, the envelope, the eighteen subscribable
parameters, the nine enumerations, the object segments and their instance-path forms, the port, the
`moduleName` and the `schemaVersion` are identical in both variants. A vendor server can therefore be
written once against the variant schema and serve both builds, provided it answers `Not Supported`
rather than failing when asked for a parameter the deployed schema does not include.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:57-61,100-108`,
`source/TR-181/middle_layer_src/gponmgr_dml_hal.h:53-57`, and a definition-level comparison of
`hal_schema/gpon_hal_schema.json` against `hal_schema/gpon_wan_unify_hal_schema.json`.*

## Interface API Documentation

The interface is defined by the `JSON` Schema files under `hal_schema/`, which are the authority for
every field, action, path and constraint named below. This block is the protocol tier of the
document: it describes how the interface is used, what shapes a caller must build and read, what the
complete callable surface is, and what the interface does and does not say about state.

### Theory of operation and key concepts

A caller does not call functions on this HAL; it exchanges messages with a peer process. Four
concepts carry that difference, and everything else in this block follows from them.

**The envelope is the call.** Every message, in either direction, carries the same four required
fields — `module`, `version`, `action` and `reqId` — and the `action` value decides what else the
message must carry. There is no method name, no argument list and no return value in the C sense;
there is an action and a payload whose shape the schema binds to that action.

**The data model is the parameter surface.** What a C HAL expresses as distinct getter and setter
functions, this interface expresses as one `getParameters` action and one `setParameters` action
applied to `TR-181` paths under `Device.X_RDK_ONT`. Adding a capability to this HAL means adding a
parameter definition to the schema, not adding an action.

**Correlation replaces the call stack.** A reply is matched to its request by `reqId`, not by
ordering on the connection, and the client library performs that match before returning a reply to
the caller. This is what lets an unsolicited `publishEvent` share the connection with request and
reply traffic.

**The schema is enforceable, and both sides should enforce it.** Because the contract is
machine-readable, a message can be checked mechanically rather than by convention. `Quality Control`
recommends doing exactly that, and the two constraints most worth checking are the `name` patterns —
which decide whether a path is addressable at all — and the datatype `const` on each parameter.

#### Object Lifecycles

**The client has a lifecycle; the interface has no session.** The client library is initialized,
started, observed to be connected, used, and optionally terminated — the sequence in
`Initialization and Startup`. Across the socket, however, there is no session to open or close: no
action begins or ends a conversation, no state is established by a first message, and a server must
treat each request as complete in itself.

**Object instances belong to the vendor, and this interface exposes them without creating them.**
Three of the seven segments are instanced — `PhysicalMedia`, `Gem` and `Veip`, addressed as
`Device.X_RDK_ONT.PhysicalMedia.{i}.` and so on — and four are singletons: `Gtc`, `Ploam`, `Omci`
and `TR69`. Nothing in the action vocabulary creates an instance: there is no `addObject`, and
`deleteObject` exists in the enumeration but is unusable, as `API Surface` records. So the instance
set is whatever the vendor's hardware presents, and a caller discovers it by reading rather than by
enumerating a table: a read of a singleton object's path returns its parameters, while an instanced
object's parameters are addressed per instance number.

**Subscriptions are the only client-created state on the server side**, established by
`subscribeEvent` and enumerable with `getActiveSubscriptions`. There is no unsubscribe action in the
vocabulary, and neither schema states whether a subscription outlives a reconnection, so a caller
should re-subscribe after any reconnection as `Asynchronous Notification Model` advises.

#### Method Sequencing

**Before any request:** initialize, run, and confirm connectivity. A request issued before
`json_hal_is_client_connected()` reports success is issued into an unconnected client.

**`getSchema` before relying on a schema path.** A caller that needs to know which schema file the
server is using asks with `getSchema` and reads `SchemaInfo.FilePath` from the
`getSchemaResponse`. It is not a prerequisite for anything else — the client already has its own
schema path from its configuration — and what it returns is the server's view, which is the only way
to detect a mismatch between the two sides. A caller must not assume the returned path matches its
own: one of the shipped example responses returns a path belonging to a different HAL entirely, which
is exactly the mismatch this action exists to reveal.

**`subscribeEvent` before any `publishEvent` can arrive.** Events are not sent for parameters that
were never subscribed, and only the eighteen parameters listed in
`Asynchronous Notification Model` may be subscribed.

**Reads and writes are otherwise unordered**, with two qualifications. A write is not read-back: the
`result` acknowledging a `setParameters` reports acceptance, not the settled value, so a caller that
needs the settled value reads it afterwards. And requests serialise on the client mutex, so
"concurrent" reads from several threads execute one after another, as `Threading Model` describes.

#### State-Dependent Behavior

**Before the client is connected**, `json_hal_client_init()` and `json_hal_client_run()` are the only
calls that are meaningful; `json_hal_is_client_connected()` is the test, and it exists precisely
because a started client is not necessarily a connected one. Sending a request in this state fails as
a transport failure rather than returning an application status.

**After the connection is lost**, the same test is what distinguishes a transport problem from a
vendor refusal. Neither schema nor the transport states whether the client re-establishes a dropped
connection automatically, so a caller must not assume recovery; it should test connectivity before
concluding that a run of failures is the server's fault.

**Parameter values are state-dependent in the ordinary sense.** Optical counters, alarm flags,
registration state and `VEIP` administrative and operational states all reflect the `ONT`'s current
condition, and a read returns what is true at the moment the vendor answers. What this interface does
**not** define is which value may follow which: no successor set, no transition table and no ordering
constraint appears anywhere in either schema. `State Diagram` says exactly what is and is not
established, and why no diagram is drawn from it.

*Derived from `properties` and `allOf` in both files under `hal_schema/`; the object and parameter
`name` constraints in `hal_schema/gpon_hal_schema.json`; and
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:107-151,737-1165`.*

### Data Structures and Defines

For a C HAL this topic lists the enumerations, structures and macros a caller must construct or
interpret. **There is no C header here and therefore no C type**; the equivalents are schema
definitions, and they fall into four groups. The complete per-definition inventory is in
[`halSpecDetailed.md`](halSpecDetailed.md); what follows are the shapes a caller must be able to
build and read.

**The envelope.** Four required fields, three of them bound to a definition rather than declared
inline:

| Field | Bound to | Form |
| --- | --- | --- |
| `module` | `moduleName` | `string`, `const` `gponhal` |
| `version` | `schemaVersion` | `string`, `const` `0.0.1` |
| `action` | `action` | `string`, one of the eleven members listed in `API Surface` |
| `reqId` | declared inline | `string` matching `^[0-9]+$`; the client emits a zero-padded eight-digit decimal |

**The payload objects.** Three payload shapes exist, selected by the action:

| Payload | Carried by | Shape |
| --- | --- | --- |
| `params` | `getParameters`, `setParameters`, `getParametersResponse`, `subscribeEvent`, `publishEvent`, `deleteObject` | An array, at least one item, items unique. Each item is a parameter entry whose required fields vary by action. |
| `Result` | `result` | An object with a single `Status` field, `additionalProperties: false`, `Status` required. |
| `SchemaInfo` | `getSchemaResponse` | An object with a single `FilePath` field, `additionalProperties: false`, `FilePath` required, matching `^(.+)/([^/]+)$`. |

**Required fields per `params` entry, which differ by action and are easy to get wrong:**

| Action | Required in each `params` entry |
| --- | --- |
| `getParameters` | `name` only |
| `setParameters`, `getParametersResponse`, `publishEvent` | `name`, `type` and `value` |
| `subscribeEvent` | `name` and `notificationType` |
| `deleteObject` | `name` — but the action is unusable; see `API Surface` |

**A leaf parameter definition**, which is this interface's analogue of a documented function
parameter, carries a `description` and three properties, and most forbid others through
`additionalProperties: false`: `name` — a `const` exact path for a parameter on a singleton object,
or a regular expression for one on an instanced object; `type` — a `const` giving the `TR-181`
datatype; and `value` — the constraint the value must satisfy. Subscribable parameters carry a fourth
property, `notificationType`. An **object definition** is the same shape reduced to `name` alone;
there are 26 of them, and they are what a prefix-scoped read addresses. Every one of the 90
parameters in the default schema carries a `description`, and every description ends with an
`(Access = Read-Only)` or `(Access = Read-Write)` marker.

**Access is derivable two ways, and for this interface they agree exactly.** The prose marker in each
description and membership of `setParameterSupportedList` — which is what a server enforces — both
identify the same 8 writable parameters in the default schema and the same 11 in the variant, with no
disagreement in either file. That is worth stating because it is not true of every `JSON` HAL in
`RDK-B`, and it means a caller can trust the marker here.

**The nine enumerations.** These are the closest thing this interface has to a C HAL's `enum`
declarations, and a caller must treat each as closed:

| Enumeration | Members | Default |
| --- | --- | --- |
| `action` | The eleven members in `API Surface` | none |
| `resultStatusEnumList` | `Success`, `Failed`, `Invalid Argument`, `Not Supported` | `Success` |
| `notificationType` | `interval`, `onChange` | `onChange` |
| `statusEnumList` | `Up`, `Down`, `Unknown`, `Dormant`, `NotPresent`, `LowerLayerDown`, `Error` | none |
| `alarmEnumList` | `Active`, `Inactive` | none |
| `lockEnumList` | `Lock`, `Unlock` | none |
| `redundancyStateEnumList` | `Active`, `Standby` | none |
| `ponModeEnumList` | `GPON`, `XG-PON`, `NG-PON2`, `XGS-PON` | none |
| `physicalConnectorEnumList` | `LC`, `ST`, `FC`, `SC`, `MT-RJ` | none |

`Device.X_RDK_ONT.Ploam.RegistrationState` constrains its value to a nine-member set declared inline
on the parameter rather than as a named enumeration; `State Diagram` lists it with the rest.

**The datatype vocabulary.** Parameter `type` values in use are `string`, `int`, `unsignedInt` and
`unsignedLong`, plus `boolean` in the variant schema only. The transport library recognises a wider
set, including `long`, `hexBinary` and `base64`, but no GPON parameter declares one, so a message
using them would name a datatype this contract does not.

*Derived from `properties`, `allOf` and `definitions` in both files under `hal_schema/`, and
`json_rpc_common.h:61-68` at the pinned transport revision cited in `Build Requirements`.*

### API Surface

This topic is the boundary between the overview above and the protocol depth below. A reader who came
for an orientation can stop here; a reader with a protocol question starts here and continues into
[`halSpecDetailed.md`](halSpecDetailed.md), which carries every parameter definition, every object
path, the enumeration appendix, worked message exchanges and the record of contract defects.

**Where a C HAL has functions, this interface has eleven action values.** They are the complete
callable surface, declared by `definitions.action` in both schemas in the same order:

| Action | Originated by | Payload it must carry |
| --- | --- | --- |
| `getSchema` | Client | none — bare envelope |
| `getParameters` | Client | `params` |
| `getParametersResponse` | Server | `params` |
| `setParameters` | Client | `params` |
| `subscribeEvent` | Client | `params` |
| `getActiveSubscriptions` | Client | none — bare envelope |
| `getActiveSubscriptionsResponse` | Server | none — bare envelope |
| `getSchemaResponse` | Server | `SchemaInfo` |
| `publishEvent` | Server | `params` |
| `deleteObject` | Client | `params` — **but see below; not usable** |
| `result` | Server | `Result` |

**Eight actions bind a payload; three travel as the bare envelope.** The schema attaches a
conditional payload requirement, through its eight `allOf` branches, to `setParameters`,
`getParameters`, `deleteObject`, `subscribeEvent`, `publishEvent`, `result`, `getSchemaResponse` and
`getParametersResponse`. The three with no binding are **`getSchema`, `getActiveSubscriptions` and
`getActiveSubscriptionsResponse`**: for these the four envelope fields are the entire message.

**There is no `setParametersResponse`.** This is the single most commonly mis-stated fact about this
protocol, so it is stated plainly: a write is acknowledged by the generic **`result`** action carrying
`Result.Status`. A caller waiting for an action name symmetrical with `setParameters` waits for a
message the contract does not define. Two of the eleven actions are answered by `result` rather than
by a dedicated response — `setParameters` and `subscribeEvent` — while `getParameters`, `getSchema`
and `getActiveSubscriptions` each have a matching named response.

**`deleteObject` is not usable under either shipped schema.** Its payload definition carries an empty
`anyOf`, a construct no instance can satisfy, so no schema-valid delete message exists to send. It is
listed above for completeness, because it is a member of the enumeration a server must be able to
parse, but it must be treated as **unsupported**: a caller should not attempt object deletion through
this interface, and a vendor need not implement it. This is a defect in the shipped contract rather
than a design decision, and it is recorded rather than worked around — the schemas are the contract,
and editing them is outside the scope of this documentation.
[`halSpecDetailed.md`](halSpecDetailed.md) records it, together with the identical defect on
`setParameterOptionalList`.

**The object tree.** Every parameter lives under **`Device.X_RDK_ONT`**, across seven named segments:

| Segment | Path | Parameters (default / variant) | What it covers |
| --- | --- | --- | --- |
| `PhysicalMedia` | `Device.X_RDK_ONT.PhysicalMedia.{i}.` | 36 / 41 | Transceiver identity and status, optical signal levels and thresholds, voltage, bias, temperature, and the 14 alarms |
| `Gem` | `Device.X_RDK_ONT.Gem.{i}.` | 18 / 18 | `GEM` port state and its Ethernet flow, including `C-VLAN` and `S-VLAN` tag handling |
| `Veip` | `Device.X_RDK_ONT.Veip.{i}.` | 13 / 13 | `VEIP` administrative and operational state and its `Q-VLAN` Ethernet flows |
| `Ploam` | `Device.X_RDK_ONT.Ploam.` | 10 / 10 | Registration state, registration timers and `PLOAM` counters |
| `Gtc` | `Device.X_RDK_ONT.Gtc.` | 8 / 8 | `GTC` framing counters and `FEC` corrected and uncorrected counts |
| `Omci` | `Device.X_RDK_ONT.Omci.` | 3 / 3 | `OMCI` message counts and `MIC` error count |
| `TR69` | `Device.X_RDK_ONT.TR69.` | 2 / 2 | The `ACS` address and the associated tag passed from the `OMCI` domain to the `TR-069` domain |
| **Total** | | **90 / 95** | |

The three instanced segments use a regular expression for `name` that requires an instance number;
the four singletons use an exact `const`. The manager corroborates the same seven-way split with one
query prefix per segment [`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:64-70`], and the `DML`
description declares the same objects [`config/RdkGponManager.xml`].

**Bulk reads by object prefix, and the one trap in them.** A `getParameters` request can name an
object path rather than a leaf, and the manager reads the whole tree that way — seven requests, one
per segment [`gponmgr_dml_hal.c:737,802,869,937,997,1076,1161`]. But a prefix is only addressable if
it matches an object definition's `name` constraint, and that splits the seven:

- `Device.X_RDK_ONT.Gtc.`, `Device.X_RDK_ONT.Ploam.`, `Device.X_RDK_ONT.Omci.` and
  `Device.X_RDK_ONT.TR69.` are declared as exact `const` values, so a request naming one of them
  satisfies the schema.
- `Device.X_RDK_ONT.PhysicalMedia.`, `Device.X_RDK_ONT.Gem.` and `Device.X_RDK_ONT.Veip.` are
  declared as instance-indexed patterns requiring `.{i}.`, so a request naming the bare prefix does
  **not** satisfy the schema; only `Device.X_RDK_ONT.PhysicalMedia.1.` and its siblings do.

The consequence is concrete and a caller should know it before writing a test: a vendor server that
validates incoming requests strictly against the shipped schema will reject the bare
`PhysicalMedia`, `Gem` and `Veip` prefix reads, while accepting the other four. The shipped
`hal_schema/example_getParameters_msg.json` is an instance of exactly that case — it names
`Device.X_RDK_ONT.PhysicalMedia.` and does not validate — and
[`halSpecDetailed.md`](halSpecDetailed.md) publishes a corrected form. A caller wanting a bulk read of
an instanced segment should address it per instance, and a vendor supporting prefix reads for those
segments should document that it accepts an extension to the shipped contract.

**Where the contract is:** the two schema files
[`gpon_hal_schema.json`](../../hal_schema/gpon_hal_schema.json) and
[`gpon_wan_unify_hal_schema.json`](../../hal_schema/gpon_wan_unify_hal_schema.json), and the two
client configuration files [`gpon_manager_conf.json`](../../config/gpon_manager_conf.json) and
[`gpon_manager_wan_unify_conf.json`](../../config/gpon_manager_wan_unify_conf.json). Per-parameter
detail — every path, datatype, constraint, access and description, the object index, the enumeration
appendix, worked exchanges per workflow and the contract defects — is in
[`halSpecDetailed.md`](halSpecDetailed.md) and is not repeated here.

*Derived from `definitions.action`, the eight `allOf` branches, `definitions.deleteObject`, and the
object and parameter `name` constraints in both files under `hal_schema/`;
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c:64-70,737-1161`; and `config/RdkGponManager.xml`.*

### Sequence Diagram

The exchange below shows a cold start, one write and one read, using the actual client entry points
and the actual action names. Every function named in it is declared by `json_hal_client.h` or
`json_hal_common.h` at the pinned transport revision cited in `Build Requirements`; every action name
is a member of `definitions.action` in the shipped schemas; every parameter path exists in those
schemas; and the ordering follows
`source/TR-181/middle_layer_src/gponmgr_dml_hal.c`. Nothing in it is illustrative.

```mermaid
sequenceDiagram
    participant Mgr as GponManager
    participant Cli as json_hal_client
    participant Srv as Vendor JSON HAL Server
    Mgr->>Cli: json_hal_client_init("/etc/rdk/conf/gpon_manager_conf.json")
    note over Cli: reads server_port and hal_schema_path,<br/>then moduleName and schemaVersion from the schema file
    Mgr->>Cli: json_hal_client_run()
    Cli->>Srv: TCP connect to 127.0.0.1:40100
    Mgr->>Cli: json_hal_is_client_connected()
    note over Mgr,Cli: polled up to 10 times, 1s apart, before initialization fails
    Mgr->>Cli: json_hal_client_get_request_header("setParameters")
    Mgr->>Cli: json_hal_add_param(request, SET_REQUEST_MESSAGE, &param)
    Mgr->>Cli: json_hal_client_send_and_get_reply(request, &reply)
    Cli->>Srv: module/version/action/reqId + params<br/>(PhysicalMedia.1.RxPower.SignalLevelLowerThreshold)
    Srv->>Cli: result with matching reqId
    Cli->>Mgr: reply
    Mgr->>Cli: json_hal_get_result_status(reply, &status)
    Mgr->>Cli: json_hal_client_get_request_header("getParameters")
    Mgr->>Cli: json_hal_client_send_and_get_reply(request, &reply)
    Cli->>Srv: module/version/action/reqId + params<br/>(Device.X_RDK_ONT.Gtc.)
    Srv->>Cli: getParametersResponse with matching reqId
    Cli->>Mgr: reply
    Mgr->>Cli: json_hal_get_total_param_count(reply)
    Mgr->>Cli: json_hal_get_param(reply, i, GET_RESPONSE_MESSAGE, &param)
```

Four details in that exchange are worth drawing out, because each is a place implementations diverge.
The write is answered by **`result`**, not by a response action named after the request. The read is
answered by `getParametersResponse`, which is one of the actions that *does* have a dedicated name —
the asymmetry is in the contract, not in the diagram. The read is scoped to a singleton object prefix,
`Device.X_RDK_ONT.Gtc.`, which is addressable for the reason `API Surface` gives. And every reply is
matched to its request by `reqId` rather than by arrival order, which is what allows an unsolicited
`publishEvent` to arrive between any two of these steps.

Event delivery runs on its own path rather than as part of this exchange: the client calls
`json_hal_client_subscribe_event()` once, and the server thereafter sends `publishEvent` messages
unsolicited, delivered on the library's socket thread. See `Asynchronous Notification Model`.

*Derived from `source/TR-181/middle_layer_src/gponmgr_dml_hal.c:107-151,218-290,741-760,1389-1396`;
`json_hal_client.h` and `json_hal_common.h` at the pinned transport revision; and
`definitions.action` in both files under `hal_schema/`.*

### State Diagram

**No state diagram is drawn for this interface, and the reason is the point of this topic.** The
schemas constrain the **set of values** several parameters may hold, and they constrain nothing about
the **order** those values occur in. There is no successor set, no transition table, no ordering
constraint and no legality rule anywhere in either file. A diagram drawn from a value set alone would
invent its own edges, and a reader — or a test author writing assertions from this document — would
have no way to tell an invented edge from a specified one. So the values are enumerated instead, and
the absence of a transition model is stated rather than papered over.

**The status-bearing enumerations this interface exposes**, with the parameters that use them:

| Values | Where | Meaning |
| --- | --- | --- |
| `Up`, `Down`, `Unknown`, `Dormant`, `NotPresent`, `LowerLayerDown`, `Error` | `statusEnumList`, used by `Device.X_RDK_ONT.PhysicalMedia.{i}.Status` | Operational status of the optical interface at physical level |
| `O1`, `O2`, `O3`, `O4`, `O5`, `O6`, `O7`, `O8`, `O9` | declared inline on `Device.X_RDK_ONT.Ploam.RegistrationState` | The registration state of the `ONT` |
| `Active`, `Inactive` | `alarmEnumList`, used by the 14 `Device.X_RDK_ONT.PhysicalMedia.{i}.Alarm.` parameters | Whether an optical alarm is currently raised |
| `Lock`, `Unlock` | `lockEnumList`, used by the `VEIP` administrative state | Whether the `VEIP` interface is administratively locked |
| `Active`, `Standby` | `redundancyStateEnumList`, used by `Device.X_RDK_ONT.PhysicalMedia.{i}.RedundancyState` | Which of a redundant pair of optical interfaces is in service |

`Device.X_RDK_ONT.Veip.{i}.OperationalState` is likewise enumerated, and every value above is
readable with `getParameters`; the first three rows are also subscribable, as
`Asynchronous Notification Model` lists.

**Transitions between the values above are not specified by this interface.** A caller must not
infer an ordering, a precedence or a legal successor from the value sets: the schemas say which
values a parameter may hold and nothing at all about the sequence in which it holds them.

**The `O`-series names are the trap, so they are addressed directly.** `O1` through `O9` are the
`ONU` activation state names of `ITU-T G.984.3`, and a reader who knows that recommendation knows the
activation sequence it describes. **This interface does not specify that sequence.** The schema
declares the nine values a caller may read and says nothing about which may follow which, so
reproducing the standard's state machine here would mean importing transitions from an external
document and presenting them as this contract's. The recommendation is named as a factual pointer for
a reader who needs the underlying semantics — and a vendor implementation will follow it — but a
caller must not treat an ordering as guaranteed by this HAL, and a test must not assert one against
it.

**What a caller should do instead.** Read the current value rather than track transitions locally:
`Device.X_RDK_ONT.Ploam.RegistrationState` for registration, `PhysicalMedia.{i}.Status` for the
optical interface, and the alarm parameters for fault conditions. Subscribe to the ones that matter,
so a change is delivered rather than polled. And treat any value as possible at any time, since
nothing in the contract excludes a value on the grounds of what preceded it.

**Two further absences, stated so they are not mistaken for omissions.** This interface defines no
overall `ONT` or service state — there is no single parameter reporting whether the `ONT` is
operational, and a caller assembles that judgement from the registration state, the optical status and
the alarms. And transport state is orthogonal to all of the above: the socket may be disconnected
while any of these values holds, and a caller must handle that separately, as `Process Model`
describes.

*Derived from `definitions.statusEnumList`, `definitions.alarmEnumList`, `definitions.lockEnumList`,
`definitions.redundancyStateEnumList` and `definitions.ontPloamRegistrationState` in both files under
`hal_schema/`, and from the absence of any transition or successor construct in either file.*
