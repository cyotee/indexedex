# Remediation PRD — APEX Stage 2 partial review

- **Status:** DRAFT
- **Date:** 2026-10-07
- **Review target:** Current IndexedEx working tree read in this session. Last supplied identity, not recomputed: IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`, content hash `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`, captured 2026-10-07T20:54:31Z.
- **Inputs:** `docs/plans/APEX_STAGE2_REVIEW_PRD.md`, `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`, `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`, reviewer originals under `docs/reviews/apex-stage2-council-2026-10-07/reviewers/`, and coordinator re-reads cited below.
- **Astra participation:** Substantive first-pass original at `reviewers/astra-vaults-original.md`. Session `ses_ee7c3c41effeYQYXPCEIvWJJVS`. One first-pass call. The return timed out after the file was written. Not treated as censorship. No resubmission. No cross-review.
- **Other reviewers:** Grok `ses_ee7c39bfdffe3UuuuiBqYNZZ7f` and Kimi `ses_ee7c34ec4ffeOABWPSUENRQSF2` returned originals. MiniMax `ses_ee7c378ebffeUmQNGUktYmxqXU` did not. This is not four-member consensus.
- **Plan conflict:** The Stage-2 plan says not to generate a remediation PRD automatically. This file exists because the review-council role requires a DRAFT handoff. It is not permission to change code, tests, configuration, or deployments.

## Required outcome

Current production paths that contradict a locked caller-maximum, local-credit, exact-output fulfillment, initiating-caller, or residual-retention rule are brought into conformance, or the owner records a scoped amendment before those paths are treated as accepted. Stage-1 evidence claims that do not cover the current replacement packages are narrowed or regenerated. No live-instance migration, audit submission, or implementation is authorized by this draft.

## RC-01 — Native SY internal-balance redemption does not authenticate the initiating caller

- **Severity:** High for generic inheritors that burn the post-call `msg.sender`. Medium for the FullSpread self-held manifestation. See dissent.
- **File and line:** `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:34-67`. Generic burn: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:272-291`.
- **Intended behavior:** External SY internal-balance redemption rejects a code-less initiating caller before the vault changes call identity. D9. Custody SY already calls `requirePretransferCaller`.
- **Broken requirement or invariant:** The adapter records a self-call on the internal-balance flag and encodes `pretransferred=false`. It does not check initiating bytecode. After that call, ERC-4626 burns `msg.sender`, which is the vault.
- **Acceptance criteria:**
  - Every family that inherits this adapter either rejects a code-less initiating caller before the self-call, or has an explicit owner exception naming that family.
  - A rejected call leaves vault-held shares unchanged.
  - A same-state contract caller that is allowed by the ruling still redeems only the shares the rule permits.
  - FullSpread and Wings are assessed separately. Closing the generic ERC-4626 path does not close them, and the reverse is also false.
- **Non-goals:** Do not add a sender-attribution ledger. Do not treat D12 resting-credit acceptance as this gate. Do not claim third-party wallet burns that the re-read did not show.

## RC-02 — Camelot zap-out exact-output can burn shares above the caller maximum

- **Severity:** High. Prior wave rated the same branch Medium. That severity dissent is unresolved. The missing check is not disputed by the re-read.
- **File and line:** `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:748-764`.
- **Intended behavior:** A non-pretransferred exact-output share burn charges the quoted shares only when they are within `maxAmountIn`. The adjacent Camelot share-to-pool branch and the Uniswap V2 and Aerodrome siblings already compare before burn, per Grok's original. Coordinator re-read confirmed the zap-out omission, not every sibling.
- **Broken requirement or invariant:** R7.5 / caller-maximum. The zap-out branch computes shares and burns them without comparing to `maxAmountIn` when pretransfer is false.
- **Acceptance criteria:**
  - Both pretransfer flags reject a quoted share input above the caller maximum before any burn, using the same bound the adjacent Camelot branch uses.
  - A funded call at the maximum succeeds. A lower maximum is rejected and share balances are unchanged.
  - A later refund helper or an allowance failure is not treated as this check.
- **Non-goals:** Do not change Uniswap V2 or Aerodrome routes that already check. Do not describe a live withdrawal procedure.

## RC-03 — Legacy Uniswap V3 Standard Exchange still authorizes pretransfer from stored total minus live deployed, and a current launch stage still constructs it

- **Severity:** High
- **File and line:** `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol:855-871`. Construction: `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56`.
- **Intended behavior:** Local credit is unbooked face custody. An outside change in deployed inventory must not shrink booked face and create unbooked credit. Current product text says the preserved V3/V4 trees are not deprecated.
- **Broken requirement or invariant:** On `pretransferred == true`, `faceBooked` is stored reserve minus live deployed, then credit is balance minus that booked face. The false-flag path pulls by transfer and is not this defect.
- **Acceptance criteria:**
  - Owner decides whether current launch and DETF deploy paths may keep constructing this package.
  - If they may not, those paths stop constructing it and name the replacement package.
  - If they may, pretransfer credit no longer grows because live deployed inventory diverges from stored reserve, and public pretransfer rejects a code-less caller, unless the owner explicitly accepts the preserved behavior and removes the package from submission scope.
  - FullSpread source is not evidence that this file is unused.
- **Non-goals:** Do not label the file deprecated without an owner ruling. Do not reconstruct old stored-total cases on FullSpread or Wings. Do not require a red run on preserved historical artifacts.

## RC-04 — V3 FullSpread direct exact-output does not prove requested output was filled

- **Severity:** Medium
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:253-279` and `:500-525`. Quote result shape: `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:141-158`.
- **Intended behavior:** A successful exact-output operation delivers the requested output or reverts, and charges no more input than the caller maximum.
- **Broken requirement or invariant:** `_quoteSwapOut` returns only `quote.amountIn`. The quoter can stop at the price limit with `fullyFilled=false` and a partial `amountOut`. `_swapExactOut` checks the input delta against `maxAmountIn` and does not check the output delta in the re-read function.
- **Acceptance criteria:**
  - An incomplete exact-output quote is rejected before it is reported as success.
  - Settlement verifies delivered output against the requested amount.
  - A funded complete exact-output still succeeds and remains bounded by the input maximum.
  - Hookless, Pons-family, and Wings are not changed to fix this V3 path unless their own source has the same omission. Astra reported their inspected exact-fill checks do not.
- **Non-goals:** Do not treat the quoter's partial-fill return as a defect in Crane. Do not claim a measured shortfall. The caller that consumes `_swapExactOut` was not re-read by the coordinator; a follow-up must confirm no later output check already exists before editing.

## RC-05 — Rocket Pool can stake a skipped sub-minimum book together with the next credit

- **Severity:** Medium
- **File and line:** `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:445-459` and `:500-515`.
- **Intended behavior:** D39 / D42 / R14.19. A booked amount below the deposit minimum stays booked. A later stake of caller excess does not include that skipped book.
- **Broken requirement or invariant:** `_stakeWethToRethSoft` returns without depositing when the offer is below the minimum. `_bestEffortStakeOverageTowardTarget` then stakes `liquid - target`. Liquid balance still contains the skipped book plus newly credited WETH.
- **Acceptance criteria:**
  - After a skipped first stake, the second stake is bounded to the caller's own sleeve-eligible credit.
  - Two allocations that are each below the minimum, and whose sum meets it, leave the old allocation unstaked.
  - A single sub-minimum credit remains booked.
  - EtherFi is not "fixed" by this change. No EtherFi arithmetic defect was confirmed.
- **Non-goals:** Do not change the accepted deposit-fee socialization. Do not treat an unexecuted recurrence test as evidence.

## RC-06 — Supported inverse residual retention is not the OD-08 zero-preview signal

- **Severity:** Medium
- **Origin:** possible `STAGE1_OPEN` for REQ-01. Do not assign a new ID that erases REQ-01.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:634-654`, especially `:649-653`. Callers at `:574`, `:599`, and `:693`.
- **Intended behavior:** OD-08. Book-and-wait applies only to a successful Standard Exchange `previewExchangeIn` of `0`. Hook joins stay hard calls. A hook preview of `0` or a hook join revert rolls the parent back. No new catch.
- **Broken requirement or invariant:** When the SE supports exact-output quantity quotes, the function books the pair balance if `amount_` is below the quoted input for one share. That branch does not call `previewExchangeIn`. The unsupported branch does use the zero preview. The `supportsInterface` catch is a separate undecided site and is not this requirement.
- **Acceptance criteria:**
  - Owner either ratifies the exact-output quote as an explicit book-and-wait signal attached to REQ-01, or retention on the supported branch happens only after a successful `previewExchangeIn` of `0` for the same amount.
  - Dependency calls stay hard. No new catch is added.
  - A hook join revert still rolls the parent back and does not book that failed join as a holder reserve.
- **Non-goals:** Do not redesign DETF bond, threshold, or vesting economics. Do not invent a `beforeSwap` guard from the withdrawn claim. Do not claim demonstrated loss. NatSpec calling the inverse path intentional is counterevidence for intent, not an owner amendment.

## RC-07 — Selector and size discovery does not cover nested replacement packages

- **Severity:** Medium
- **Origin:** possible `STAGE1_OPEN` for REQ-08 evidence scope. Not a claim that any facet exceeds EIP-170.
- **File and line:** `scripts/r12_selector_size_compare.py:36-63`.
- **Intended behavior:** REQ-08 / OD-08 item 3. Current selector and size evidence covers the current hookless, Pons-family, and wings packages, or the claim is narrowed to the directories actually scanned.
- **Broken requirement or invariant:** Discovery globs `*.sol` only in the parent directory of each live baseline row and does not recurse. A package introduced under a new nested directory is invisible unless a live baseline row already has that directory as its parent.
- **Acceptance criteria:**
  - A regenerated compare, or an owner-accepted narrowing, names every current deployable unit in the hookless, Pons-family, and wings package directories, or states a sourced reason a unit is excluded.
  - `STAGE1_EVIDENCE.md` does not say those packages replace the citation unless the artifact includes them.
  - The script is not rerun in the review session. A later verification session must bind source identity, toolchain, and result.
- **Non-goals:** Do not treat a zero oversize count on the scanned subset as certification of unscanned packages. Do not merge hookless and Pons-family packages.

## Dissent and unverified items

- **RC-01 severity:** Astra Medium, limited to vault-held shares and not third-party wallets. Grok High for generic `msg.sender` burns. Coordinator keeps both scopes. Custody SY is a counterexample, not a fix for the native adapter.
- **RC-02 severity:** Prior accepted wave Medium. This wave High. Check absence is confirmed.
- **RC-04 caller:** Coordinator did not re-read `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`. Acceptance requires confirming no later output check.
- **RC-06:** Kimi prefers `DECISION_NEEDED` over a definite defect because a consistent quote may imply a zero preview. The locked exclusive signal is still contradicted until the owner amends it.
- **Not confirmed by coordinator re-read, so not requirements here:** Astra-AV-03, AV-04, AV-05, AV-06; Grok G-B-03, G-B-04, G-B-05, G-B-08; Kimi K3-D-03 and K3-D-04. A follow-up may promote them after a re-read.
- **Unread this wave:** seven hook families, hook × SE matrix, Balancer integrations, audit PDF, and the 108-ID ledger. No hook finding is invented. Historical audit items remain `CLAIM_UNVERIFIED`.
- **Execution:** no Forge run. Passing historical totals are not current evidence.

## Non-goals for the whole draft

No code, test, config, or deployment changes in the review session. No live-instance upgrade. No Slipstream feature work. No new catch. No exploit procedure, proof-of-concept, payload, or attack parameter. Owner approval of a later implementation task is a separate decision.
