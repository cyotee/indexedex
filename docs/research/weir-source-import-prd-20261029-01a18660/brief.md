# WeirVaults source-import PRD — common council brief

## Authorization and deliverable

User, 2026-10-29:

> Thank you. Then let's start by writing a PRD to copy the Weir Vault source code int the Indexedex repo in the path /Users/cyotee/Projects/indexedex/contracts/protocols/strategy/weir. This PRD should include requirements for testing the copied code so we can ensure our version works correcrtly. Have the council review the Weir code and write the PRD file.

Produce an implementable, standalone PRD for a faithful baseline source import, including concrete testing and release evidence. Do not implement the import. The final PRD goes at `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`; the invoking coordinator publishes it after the council's originals and one advisory round. The user-specified destination overrides generic preferences for placing raw protocol source under external/. No duplicate production tree is requested.

Do not accidentally implement the previously discussed adaptation: no ERC20/ERC4626 wrapper, Rate Provider, Diamond/SE conversion, registry integration, fee removal, dead-share removal, hook-only already-unlocked path, strict single-token guarantee, new simulator, optimization or economic repair in this baseline. Preserve source limitations and characterize them with tests. Later adaptation requires its own requirements.

## Frozen primary evidence

Run root: `docs/research/weir-source-import-prd-20261029-01a18660/`.

Coordinator retrieved the public Sourcify record with HTTP 200 on 2026-10-29:

`https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources,metadata`

Record reports match for creation and runtime; verifiedAt `2026-09-30T03:34:14Z`. This is registry metadata, not a new independent bytecode reproduction, audit or live transaction.

Read all three domain files completely, not merely comments:

- `source-snapshot/sources/src/WeirVaults.sol.txt` (427 source lines plus terminating newline), SHA-256 `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180`.
- `source-snapshot/sources/src/base/WeirBase.sol.txt`, SHA-256 `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498`.
- `source-snapshot/sources/src/libraries/LiquidityAmounts.sol.txt`, SHA-256 `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d`.
- `source-snapshot/manifest.json` contains the authoritative SHA-256, original metadata keccak256 identifiers, license inventory, compiler settings and source paths for all 39 files. All 39 exact source texts are frozen as `.sol.txt` research references, not production Solidity.

Upstream compilation: solc `0.8.26+commit.8a97fa7a`, optimizer 800, Cancun, viaIR=true, metadata bytecodeHash=none. Current IndexedEx default/fork: solc `0.8.35`, optimizer 1, via_ir=false; do not change these settings or add a profile. Exact deployed bytecode equality is therefore not the default acceptance criterion. Separate faithful source/ABI/arithmetic behavior from reproducible upstream compilation.

No upstream Git repository/revision, source tests or audit was supplied or verified. Do not invent them. Content-addressed verified source is the pin; record this provenance limit.

## Mandatory review details

Review the executable code for every public/inherited user, view, callback, receive and admin surface; enumerate inherited ownership/pause/reentrancy behavior and errors, events, struct layouts and casts. Define numbered requirements plus useful AC rows with preconditions, action and exact expected result. Cite source path/line ranges; source quirks are observations, not permission to repair them.

Account for multiple PoolIds, full-range ticks/salt-zero position ownership, 1,000 unassigned genesis shares, default 500bps/cap 1,000bps fee, liquidity-ratio issuance, idle claims, deposit recipient versus payer/refund, compound ordering, two-unit liquidity cushion, signed deltas and rounding, zap heuristic and partial fills, fees at zero/nonzero liquidity, uint64 timestamp, preview excluding pending fees and lacking zap/maintenance parity, native token handling, pausing only deposit, transferable per-pool non-ERC20 balances, no arbitrary full-consumption guarantee and ordinary nested-unlock failure.

Requirements must distinguish:

1. Correct import fidelity to the baseline, including observable awkward behavior.
2. A documented upstream risk or limitation, including executable characterization if feasible.
3. A newly desired improvement, excluded from this import unless separately approved.

Do not demand that baseline tests prove a safety property the source does not implement, or manufacture a test that fails faithful source and then authorize a fix.

## Licensing and dependencies

Top-level WeirVaults and WeirBase declare MIT. Weir's LiquidityAmounts declares GPL-2.0-or-later. The bundled v4-core Position declares BUSL-1.1 and is used through StateLibrary's position-key helper. The other 37 of 39 files declare MIT. Preserve headers/notices and record the full transitive license map. No license scrubbing, blanket MIT label, clean-room claim, automatic legal clearance, or relicensing is authorized. The PRD can require dependency/license disposition before an eventual copied-source release without blocking document authoring.

Prefer existing canonical shared dependencies after proving ABI, type, storage-layout, arithmetic, revert and semantic compatibility; no private OZ/v4 clone, new submodule, or global alias/config edit. Do not casually substitute another LiquidityAmounts implementation because the name matches: original rounding, overflow and revert behavior is part of fidelity. A dependency substitution that changes behavior is a deviation requiring an explicit separate decision, not a silent import-only rewrite.

Admitted repository rules: `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md`, `.github/ASSISTANT_DEPLOYMENT.md`; canonical `lib/crane/.claude/skills/crane-porting/SKILL.md`, `crane-porting-verification/SKILL.md`, `crane-testing/SKILL.md`. Native council workflow applies; older OpenCode-only synchronous routing instructions do not replace the current runtime.

Relevant dependency candidates (read before claiming compatibility):

- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`
- Same tree's `interfaces`, `types`, `libraries` (including StateLibrary, Position, LiquidityAmounts).
- `lib/crane/contracts/external/openzeppelin-contracts/` equivalents; match actual versions/semantics, not merely symbols.
- `lib/crane/contracts/test/CraneTest.sol`.
- `lib/crane/test/foundry/fork/ethereum_main/uniswapV4/TestBase_UniswapV4Fork.sol`.

No generic V4 TestBase was located in the first filename search; do not infer none exists anywhere. Prefer existing real-manager deployment infrastructure where appropriate; a dedicated `TestBase_WeirVaults` can extend CraneTest if existing fixture introduces unrelated product wiring. Tests mirror `test/foundry/spec/protocols/strategy/weir/`; test infrastructure lives with the protocol. No invented registry or proxy tests for a standalone upstream contract.

## Test and acceptance expectations

Production-first hermetic Foundry tests must use the actual copied Weir and real v4 manager, backed by reusable TestBase/Behavior/Handler as applicable. No SUT mocking, etching, subclass replacement, direct storage injection or fabricated manager deltas. Hostile peripheral tokens/receivers/hooks are allowed when needed to exercise actual integration and source limitations; no implementation claim that FoT/rebasing tokens are supported.

Require exact balances, ledger and position changes, manager address/currency delta closure, integer expected outputs, events, exact revert selectors/panic/string as applicable, callback provenance, pause/owner/recipient/deadline matrices, and complete rollback including transfers/refunds/fee cuts. Test independent expected calculations rather than call the same SUT/helper to manufacture expected values. Include deterministic fuzz/invariant campaigns across users/pools/operations and characterize reentrancy surfaces without assuming unguarded functions are guarded.

Cover donations/pre-existing inventory, tiny amounts/rounding/casts, realistic single-sided and paired entries, each withdraw zap choice, compound fees/idle/treasury, native/ERC20 paths, separate payer/recipient, shared currencies across pools, unknown pools, and ordinary already-unlocked failure.

Fork parity is a separate local-only gate under `test/foundry/fork/`, `FOUNDRY_PROFILE=fork`, at a pinned chain/block/state with explicit provenance. Source verification is not transaction parity. If unavailable, document missing RPC/state rather than fake results; do not make hermetic CI depend on RPC or secrets. Local deployed reference comparison requires matching inputs and equivalent starting position/inventory/fees/roles; raw comparisons between unrelated live states are invalid.

Future implementation validation must build before test, use current artifact workflow and default/fork profile law, never delete warm out/cache or enable viaIR, never kill slow compilation from impatience. Propose concrete runnable commands; do not run any now. Match test surface to actual baseline: no ERC20 compliance, NAV safety, guaranteed one-token exit, or preview==maintained/zapped execution assertions where the source does not promise it.

## Council authoring procedure and boundaries

Full roster: Astra `chatgpt-subscription/gpt-6-astra:high`, Grok `xai/grok-4.7:xhigh`, MiniMax `minimax/MiniMax-M3` (adaptive setting only if exposed), Kimi `kimi-coding/k3.1-pro:high`.

Fresh independent initial tasks. Each reads this brief and all primary domain files, then authors a substantive PRD contribution: normative requirements, acceptance rows, source preservation risks, concrete test matrix, dependency/license decisions and evidence limits. No peer original reading in this pass. Aim for a complete useful contribution without reproducing source listings.

Only write your assigned `members/<member>/response.md` via apply_patch if active. If inactive, return the COMPLETE contribution inline; do not discover alternate mutation tools. Do not delegate, run shell/Git/build/tests/install/deploy/wallet operations, modify code/config/PRDs, send external messages, or write a common final. Reading admitted context and narrow public primary-source checks is permitted. Report what was actually read.

After every original settles, invoking coordinator synthesizes one frozen complete PRD draft, then resumes these same four tasks once. Advisory reads the full draft plus the other three originals, not peer feedback; write only own feedback path. Final concern disposition and final PRD publication are coordinator-owned. No further advisory round or implementation authorization.
