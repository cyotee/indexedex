# Readable source extraction — exact next action for L3

Date: 2026-09-27. This is a data-formatting handoff, **not product implementation, deployment or a change to the PRD**. The research council has not executed a parser or shell command.

## Why this is needed

The complete verified-source response has already been retrieved. The council's available file reader truncates a single line at2000 characters, and its grep suppresses long matching lines. Sourcify's response contains JSON-escaped source newlines on one large physical line. Reading the first portion therefore shows the constructor but not the conversion bodies.

Additional documentation lookup confirmed the documented read-only contract endpoint and its full `sources` map. It did not supply a confirmed per-file plain-text endpoint. Do not repeat previously failed legacy URLs or substitute metadata/generic SY examples for the target bodies.

## Input — prefer the existing downloaded public response

Use either surviving local artifact:

```text
/Users/cyotee/.local/share/opencode/tool-output/tool_0ea41f562001ukVf9Ew26AjIlK
/Users/cyotee/.local/share/opencode/tool-output/tool_0ea31fc8d0011nQs5FyfXOfDTh
```

These are tool-created public-source responses, not private code or credentials. Confirm the file contains a complete JSON object with the expected `sources` map. If the session-specific files are unavailable, the portable read-only input is:

https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources

Expected implementation record: chain4663, address `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, matchId47105638, compilation target `PendleStakedNetSY`. Metadata/compilation/proxy-resolution evidence is in [COUNCIL_CONSOLIDATION.md](./COUNCIL_CONSOLIDATION.md). The source response is evidence from the verification service, not a fresh block-pinned execution test.

## Required output

An agent/environment allowed to perform local JSON parsing should create:

`docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`

Do not modify any Solidity, dependency, config or instruction file. No RPC calls, keys, transactions, contract deployments or code builds are needed for this extraction.

### Exact formatting procedure

1. Parse the existing response as JSON, not regex or manual escape replacement.
2. Read each `sources[path].content` string and decode its JSON escapes normally. Preserve the complete decoded source—including imports/comments and actual line breaks—without truncation, summarization or source changes.
3. Put the target source **first**, under a heading containing its exact source key, followed by a fenced Solidity block with real physical newlines.
4. Include every other source in the response under its own exact-path heading and code block. This avoids missing a target helper dependency and turns the bundle into readable line-oriented data without publishing anything new externally.
5. Add a short manifest: input filename/URL, extraction date, implementation address/match record, source-file count, and any parse/hash verification result actually obtained. Do not label an unperformed integrity comparison as verified.
6. Explicitly report if a requested source is absent from the map. Never fill an absent source with a similar current GitHub file.

### Target source key

```text
lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol
```

Supporting files of particular interest are the exact `SYBaseUpgV2.sol`, `TokenHelper.sol`, `TokenWithSupplyCapUpg.sol`, NetNet staking/token interfaces and decimal-wrapper interfaces/implementation contained in the same compilation. Preserve actual keys; do not guess a directory or import version.

Target metadata evidence previously obtained:

- Reported source keccak256: `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`.
- Reported source CID: `QmXxcstnT7GawRbrX7a9TE6xWLfaH7VGYEaF44jeV1WwJ8`.

Do not replace keccak256 with NIST SHA3-256 when comparing the source hash. A metadata hash is not a claim that the moderator independently computed it.

## What the council can do once the output is available

Read the actual token-list, `_deposit`, `_redeem`, preview, exchange-rate and due-epoch/index branches with their exact dependencies. Derive the source-supported SY debit for native NET/sNET output; keep that separate from the already-implemented Weighted quote coordinates. Record rounding, real minOut/receipt semantics, source-specific inverses and current-state verification requirements in plan §6.5.

No owner economic decision is needed. No source code should be changed merely to create this readable evidence. If no parsing-capable environment is available, supplying the full decoded target source and exact imported dependencies as plain text/Markdown serves the same purpose.

## Current status

Executed on 2026-09-28. The readable extract is [VERIFIED_SY_SOURCE_EXTRACTS.md](./VERIFIED_SY_SOURCE_EXTRACTS.md). All 25 decoded source strings were compared back to the input JSON and matched, including the target. Independently computed keccak256 of the decoded target UTF-8 content equals the previously reported `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`. The decimal-wrapper implementation body is absent from this compilation response and was not substituted. L3 formula analysis is not closed by this formatting step.
