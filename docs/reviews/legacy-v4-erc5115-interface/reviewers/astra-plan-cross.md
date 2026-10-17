# Astra — replacement-session cross-review

Date: 2026-10-15.

This is an explicitly authorized replacement session, not continuity. I do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`, did not read its history or original artifact, and do not adopt its findings as my own. MiniMax's supplied original is labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`, without memory of `ses_ec41255ceffeVhrySLQe8hwwMC`. This report reviews the three supplied original plan drafts together, once. I did not read peer cross-review artifacts. Historical cross-review summaries embedded in the controlling PRD are claims checked against source, not authority to change scope.

## Decision

**Agree that a deterministic plan can be written without a remaining product/owner choice; dissent that the three drafts are executable unchanged.** The controlling PRD already fixes the token flag, selector owners, registration sites, unchanged redemption semantics, scope and size stop. The corrections below are implementation requirements, not new product decisions.

**Confirm both proposed sentences, for the current source and fixed facet separation:**

1. **The query target must stop inheriting the Pendle preview and discovery bases.** Its current parent is `NativeStandardYieldPreviewTarget` (aliased in the V4 target at lines 11–25), which inherits `NativeStandardYieldDiscoveryTarget` and `NativeStandardYieldPreviewCallsTarget`. Discovery still requires `assetInfo` at line 16 and provides public validation and reward methods at lines 19–29. Removing `assetInfo` while retaining that aggregate leaves the concrete query target incomplete. Making validation overrides internal also cannot satisfy its public declarations. Implement the six required reads locally, preserving existing preview argument direction and invalid-token zero returns. This conclusion is about the actual aggregate and the PRD's restricted change, not a claim that every imaginable preview-only abstraction requires Pendle.
2. **The money target must not itself inherit `IERC5115_StandardizedYield`.** That interface declares eight methods at lines 21–53; the money target and its concrete IN facet supply only the two money methods, not the six reads. An abstract intermediate does not discharge those obligations for the concrete IN facet. Keep the interface import for qualified events/selectors and registration, without adding full-interface inheritance to either partial implementation. Delete obsolete `override` annotations where their overridden declaration has been removed.

The one sentence the consolidated plan should use to remove routing and inheritance ambiguity is:

> Rewrite both existing V4 yield targets without the Pendle bases or full `IERC5115_StandardizedYield` inheritance, implement their assigned money/read methods locally, forward both deposit flag values through the existing guarded `_exchangeIn` token-to-share branch, and locally preserve the redemption route and vault-held-share checks formerly inherited from `NativeStandardYieldMoneyTarget`, removing only obsolete overrides and replacing the vanished `super._standardRoute` fallback with its existing local semantics.

## Astra findings on the original drafts

### Astra-R1 — Retained query inheritance contradicts removal instructions

- **Severity:** Medium. **Impact class:** Build failure / obsolete ABI retained.
- **File and line:** `reviewers/minimax-plan.md:39–51` (paths here are relative to this review directory).
- **Intended behavior / broken invariant:** PRD lines 19, 25–49, 65–67 require the V4-only interface replacement without shared-base redesign or Pendle discovery surface.
- **Facts:** MiniMax retains the preview aggregate, deletes `assetInfo`, and changes public validation overrides to internal; the source inheritance obligations described above remain. The aggregate also supplies reward methods even if omitted from the proxy cut.
- **Inference:** Following these instructions cannot produce the specified concrete query contract. Selector filtering alone does not fix abstract-method or visibility obligations.
- **Fix direction:** Adopt Grok lines 52–54 and Kimi line 46: remove the aggregate and implement the six reads locally; remove obsolete overrides/imports. Preserve `previewExchangeOutOneToMany` and existing quote semantics.
- **Confidence:** High (source inspection; not compiler execution).

### Astra-R2 — Full-interface inheritance makes the money facet incomplete

- **Severity:** Medium. **Impact class:** Build failure / pressure to violate selector ownership.
- **File and line:** `reviewers/minimax-plan.md:114–132,149`; related ambiguity in `reviewers/kimi-plan.md:32–36`.
- **Intended behavior / broken invariant:** PRD lines 23 and 49 keep money and six reads on their respective existing facets.
- **Facts:** MiniMax explicitly adds the full interface as a base. `UniswapV4StandardExchangeInFacet.sol:12` is concrete and inherits the money target; `UniswapV4StandardExchangeInTarget.sol:30–85` supplies no ERC-5115 reads. Kimi retains bare `override` on methods whose Pendle parent it removes, without specifying a remaining declaration.
- **Inference:** MiniMax's concrete facet would lack six required implementations. Adding those reads to satisfy the compiler would be the wrong remedy for this scoped plan.
- **Fix direction:** Import, but do not inherit, the named interface in the partial targets; use qualified events and selector references, and remove money-method overrides that no longer override a base.
- **Confidence:** High.

### Astra-R3 — Removing the money parent also removes live routing and balance-check helpers

- **Severity:** Medium. **Impact class:** Build failure / redemption semantic regression.
- **File and line:** `reviewers/grok-plan.md:23–27`; `reviewers/kimi-plan.md:36–37`; `reviewers/minimax-plan.md:154–180`.
- **Intended behavior / broken invariant:** PRD lines 55–59 require removing the money parent while preserving redemption, including its internal-balance gate.
- **Facts:** V4 `_standardRoute` currently calls `super._standardRoute` at `UniswapV4StandardYieldExecutionTarget.sol:63`. The sole implementation is in the removed shared money parent (`NativeStandardYieldTarget.sol:47–58`), which also defines `_requireVaultHeldShares` and `_vaultHeldShares` at lines 60–67. The remaining `StandardExchangeInExecutionBase.sol:7–9` declares only `_exchangeIn`. MiniMax also both preserves a validation helper call (line 154) and deletes that helper (line 175).
- **Inference:** Instructions to keep these overrides “as-is” leave an absent super method and, unless explicitly transplanted, missing share checks. The two inheritance sentences alone do not complete a compilable plan.
- **Fix direction:** Specify local preservation of `_requireVaultHeldShares` and its exact balance/error behavior, retain named-holder redemption and its lock/TWAP behavior, replace the lost fallback with the existing shared route semantics, and remove orphaned override markers. Validation uses `Config._isValidToken` directly. Do not keep or restore the Pendle parent as a shortcut.
- **Confidence:** High.

### Astra-R4 — True-flag deposit instructions must preserve the guarded execution wrapper

- **Severity:** Medium. **Impact class:** Potential reentrancy-guard and accounting-side-effect regression in implementation.
- **File and line:** `reviewers/grok-plan.md:35–36`.
- **Intended behavior / broken invariant:** PRD lines 59–61 change token acquisition mode, not the existing execution safeguards or TWAP maintenance.
- **Facts:** Grok specifies `_exchangeIn` for false but a custody-helper-plus-zap sequence for true. The current wrapper at `UniswapV4StandardExchangeInTarget.sol:43–73` supplies `nonReentrant`, token acquisition, zap execution and the TWAP poke. The custody helper at `internal/UniswapV4StandardExchangeCustody.sol:23–42` supplies no such wrapper.
- **Inference:** Literal direct calls on the true branch could omit the lock and TWAP poke. This is a plan ambiguity, not a claim that an implemented vulnerability has been observed.
- **Fix direction:** Adopt MiniMax/Kimi's boolean forwarding through `_exchangeIn` for both flag values. That branch already passes the flag to the existing helper, with no added token-path caller gate and no second pull. Preserve the original post-route minimum and zero-share checks.
- **Confidence:** High on the missing specification; conditional on implementation for runtime impact.

### Astra-R5 — Character counting is not a runtime-byte-size measurement

- **Severity:** Medium. **Impact class:** Incorrect acceptance evidence / false size-gate failure.
- **File and line:** `reviewers/minimax-plan.md:489–503`.
- **Intended behavior / broken invariant:** PRD lines 72 and 81 require reporting both actual runtime sizes and stopping if either exceeds 24,576 bytes.
- **Facts:** MiniMax pipes textual deployed-bytecode output into `wc -c` and treats it as runtime size. Hexadecimal text contains two characters per byte, plus framing such as its prefix and newline.
- **Inference:** The proposed count is not comparable to the byte threshold. Requiring all tests to pass before recording sizes also risks leaving the required size evidence unavailable after an earlier failure.
- **Fix direction:** Following a successful artifact refresh, measure decoded deployed-bytecode length for both named facets, record both numbers before proceeding with the later test gate, and stop/report an oversize without changing architecture. Do not substitute creation-bytecode length or query-facet size.
- **Confidence:** High; no current size measured.

## Agreements, corrections and remaining dissent

- **Grok:** Agree with local query implementation, exact 3/7 selector manifests, in-place registration, and no new execution class. Correct the true-deposit routing ambiguity and missing inherited-helper migration above.
- **MiniMax replacement:** Agree with the existing `_exchangeIn` route, preserved token/share gate distinction, two registration replacements and unchanged array lengths. Reject retained query inheritance and full money-interface inheritance. Its summary says six production files but lists five (line 556); the plan must name five. No sixth file is implicitly authorized. Do not carry forward reviewer-session availability as an implementation precondition (lines 548–550): the controlling PRD, not an unavailable prior session's memory, governs this work.
- **Kimi replacement:** Agree with removing the query aggregate, keeping query semantics and forwarding the token flag. Correct orphaned overrides and specify local helper migration rather than saying all overrides stay unchanged.
- **Evidence determining this replacement's position:** The actual parent graph, abstract discovery declarations, eight-method named interface, concrete IN facet, missing remaining `_standardRoute` base and guarded `_exchangeIn` implementation—not the quoted prior consensus.
- **Unresolved dissent:** None on a product decision within this PRD. The generic local testing skill's code-less-pretransfer rejection expectation conflicts with this item's explicit token-path ruling; for this review the controlling PRD's no-new-token-gate instruction is followed, not silently reversed. This does not certify the deferred stored-reserve residual as safe.
- The consolidated plan must explicitly require production-proxy checks for all nine absent selectors, eight ERC-5115 methods on their designated owners, both interface-ID answers, and both deposit flag modes. Merely retargeting existing false-flag calls or counting selectors is not evidence for the new true-flag behavior.

## Evidence and limits

All three supplied original drafts, the controlling PRD and named interface were present. The assigned output did not exist before this write. No missing supplied input path was encountered. No prior-session history, other reviewer cross-review artifact, external documentation, shell, tests, deployments or exploit procedures were used. No code, instructions, configuration, controlling PRD or `REMEDIATION_PRD.plan.md` was edited.

Files examined with **no additional defect identified in this bounded plan review** (not a full security clearance):

- `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`.
- `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol`.
- `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol` and `NativeStandardYieldDiscoveryTarget.sol` as shared bases that remain unchanged for other families.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol`.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol` and `UniswapV4StandardExchangeOutMultiQueryFacet.sol`, apart from the PRD's already-required metadata migration.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol:140–171`, apart from its already-required interface-ID replacement; the remainder was not reviewed.

Additional examined source: `UniswapV4StandardYieldExecutionTarget.sol`, `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, shared `NativeStandardYieldTarget.sol`, and `internal/UniswapV4StandardExchangeCustody.sol`. These support the findings and the explicitly deferred custody residual; no claim of broader audit coverage is made. Guidance read directly: root `CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, canonical Crane `crane-architecture/SKILL.md`, and local `indexedex-testing/SKILL.md`; Crane `AGENTS.md` was also supplied with the source read.

These are this replacement Astra's original cross-review conclusions. They do not revise or erase an earlier Astra participant's attributed findings. Compilation, tests, artifact freshness and actual deployed sizes remain unverified.

I did not run Forge.
