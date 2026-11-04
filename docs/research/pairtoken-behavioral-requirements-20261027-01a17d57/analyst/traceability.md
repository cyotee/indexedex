# Analyst-only requirement traceability

Run: pairtoken-behavioral-requirements-20261027-01a17d57. This file is outside handoff/ and is not required planner input. It retains source locators for the normative IDs in the coordinator draft and later final.

Coordinator synthesis uses Astra's detailed extraction as the organizational base after reading all four originals. Grok, MiniMax and Kimi independently cover the same behavioral domains. Their mistaken broad claims are not adopted; see candidate-qualification-notes.md. Public interfaces, math and standard numerical coefficients describe behavior; no target implementation listings are copied into the handoff.

PT-CONFORM-01/02 are coordinator scope/planning-use requirements, not source observations. Source identity is analyst/evidence-manifest.md. The remaining IDs retain the traceability table below; full dependence and exposure claims remain analyst statements.

## Final revision annotations

Final requirements preserve the reviewed numeric IDs. Astra C1-C4/N1 and MiniMax MINI-01 through MINI-05 are resolved in coordinator/resolution.md. PT-BAL-05/PT-AC-52/PT-ERROR-03 now specify actual wrapped returndata; PT-AC-11 explicitly requires positive supply; PT-DEP-03 fixes sampled balance/price order; PT-BAL-02 states nominal native receipt; PT-VIEW-01 distinguishes both read slots; PT-DEP-02 and PT-ZAP-02 clarify existing compound/cap consequences; front matter and PT-HANDOFF-01 preserve the entire standalone artifact. No new product behavior is inferred.

The provenance, method and detailed source table following this annotation originate in Astra's preserved independent candidate. They are attributed member examination records, not claims that the coordinator personally performed every listed library read. Coordinator source checks and cross-member scope are separately recorded in the source-coverage register, evidence manifest, resolution and council report.



## 17. Evidence identity and method

This section is analyst material, not an instruction for a later planner to consult raw code.

- Source exposure: continued Astra council-member context from the preceding fidelity audit; this is a new independent requirements original.
- Source identity supplied by the coordinator: chain `4663`, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, match ID `55980642`, exact creation/runtime metadata.
- Re-fetch supplied by the coordinator: `2026-10-27T14:29:44.246Z`, HTTP 200. The brief reports that the full response body and all 28 source contents match the preceding audit. I did not perform an independent re-fetch, chain query or bytecode reconstruction.
- HTTP-body SHA-256: `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98`.
- Admitted archived JSON SHA-256 from the corrected prior manifest: `b092a33582f4a7f6c76564b0a5ea276561b84347ab66494eea81e462442fcea0`. Its added terminal newline explains the difference; removing that newline restores the original body. No unexplained source mutation is inferred.
- Source endpoint: `https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources`.
- Raw evidence resides in `docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/evidence/`. This run did not overwrite or duplicate it.
- The complete PairToken source was reread in this assignment, together with exact tick-price, amount-delta, liquidity and currency-transfer passages. The complete 28-file bundle had been read in the continued prior review context; unchanged dependency observations were carried forward under this run's evidence identity. This does not claim a fresh full mathematical audit of every indirect library.
- Current-run peers were not read. Earlier alternative-vault requirements were not used as the baseline. Previous source-informed findings assisted coverage, but actual source semantics control this candidate.
- No source listings or copied source comments appear in Parts I-III. Mathematical coefficients and public identifiers are included where necessary to define exact observable behavior.
- No project tests, compilation, installations, deployments, Git/config operations, delegation, wallet actions or external messaging occurred. Acceptance scenarios are unexecuted. The only authored path is this run's `members/astra/response.md`.

Source text and declared branches are observations. Algebraic restatements and consequences are static derivations. Equivalence of a future implementation, live dependency behavior and exploitability are not observed or certified here.

## 18. Requirement-to-source traceability

`P` below means original `src/pair/PairToken.sol` lines inside the admitted source JSON. For that file only, readable-bundle line equals original line plus three. Other dependencies use original paths and symbols. All rows below were examined in the continued source review; the body of this candidate is independently authored.

| Requirements | Primary analyst locator | Coverage / qualification |
| --- | --- | --- |
| PT-SCOPE-01/03, PT-STATE-01 | P:47-78, 214-250, 256-529 | Share/position/basket distinction; collective accounting observed. No alternative `U` ledger imported. |
| PT-SCOPE-02, PT-INIT-01/02 | P:138-152, 214-218, 610-618; `TickMath.minUsableTick`, `maxUsableTick`; `PoolIdLibrary.toId`; `Position.calculatePositionKey` | Identity, first-caller factory, full range and zero salt. |
| PT-SCOPE-04, PT-CONST-01/02 | P:49, 59-66, 651-668; `Currency`, `FixedPoint96`, `TickMath` constants | Raw units and native representation; no token-decimal normalization. |
| PT-STATE-02, PT-PERM-01 | P:76-78, 120-133, 538-544 | Reservation, entered/skip-add scope; ordinary stored state. |
| PT-API-01 through PT-API-04 | P:138, 156, 162, 167 | Exact named signatures, visibility and returns. |
| PT-API-05 through PT-API-11 | P:201, 205, 209, 214, 221, 233, 243 | All named view signatures. |
| PT-API-12 through PT-API-18 | P:256, 308, 351, 366, 412, 550, 133 | All money entrypoints, callback and receiver. |
| PT-GET-01 through PT-GET-17 | P:47-52, 59-74 | All public storage/constant-generated getters, 17 total. |
| PT-MATH-01 | P:169, 176, 184, 192, 247, 332, 338, 397, 429-430, 494, 506; `FullMath.mulDiv`, `mulDivRoundingUp` | Distinguishes checked products, full-precision math and selected modular updates. |
| PT-MATH-02 | `lib/v4-core/src/libraries/SqrtPriceMath.sol:188-254` | Exact direct amount-delta rounding and endpoint ordering. |
| PT-MATH-03 | `src/vendor/uniswap/LiquidityAmounts.sol:13-56` | Piecewise conversion and both-candidate cast behavior. |
| PT-MATH-04 | `lib/v4-core/src/libraries/TickMath.sol:20-114` | Fixed integer function, coefficient constants, inversion and rounding. No idealized real-power substitution. |
| PT-MATH-05 | `src/base/PriceMath.sol:sqrt`; P:399, 554-564, 585, 590-591, 622-630 | Sqrt, width-dependent conversions, positive clamp versus unsigned reinterpretation. |
| PT-INIT-03, PT-ABSENT-01/02 | P:102-152 and complete public contract | No use of `NotFactory`, constructor lock, initialize-pool call, additional readiness guard, or listed absent functions. Concrete factory omitted from evidence. |
| PT-VIEW-01 | P:214-218; `StateLibrary.getSlot0`, `getLiquidity`, `getPositionLiquidity`, `_getPoolStateSlot`, `_getPositionInfoSlot`; `Position.calculatePositionKey` | Manager external-storage read convention and key packing. |
| PT-VIEW-02 | P:221-230; amount-delta helpers | Unclamped live endpoints and idle addition. Literal basket behavior, not asserted exact execution redemption. |
| PT-QUOTE-01, PT-VIEW-03 | P:233-241, 500-519 | All branch precedence, min/ceil clamps, genesis-size predicate. |
| PT-VIEW-04/05 | P:243-250, 256-291, 351-405 | Zero-preview short circuit, no owner cap, compound and rounding differences. |
| PT-DEP-01/02 | P:256-272, 651-657 | Admission, native reservation and post-compound quote checkpoint. |
| PT-DEP-03/04/05 | P:274-302, 661-675 | Pull measurement, computed add versus measured increase, dead-share mint, net output and sender refund. |
| PT-ZAP-01/02 | P:308-332 | Input/native checks, pre-zap basket, cap from vault rather than active pool. |
| PT-ZAP-03/04 | P:334-345, 521-529, 576-608 | Actual-receipt half-swap, tick checkpoint, used-delta issuance, no refund. |
| PT-EXIT-01/02/03 | P:351-363, 391-405 | Post-compound snapshot, sender burn, retention and independent floors; paired transfers. |
| PT-EXIT-04/05 | P:366-388, 538-544, 576-608 | Output choice, swap-only suppression, nominal payout, zero call, partial-fill boundary and event pair amounts. |
| PT-COMP-01/02 | P:412-431, 550-564 | Collection caller delta, collection skip, runtime getter order and protocol fraction. |
| PT-COMP-03 | P:447-463, 688-690 | Notifications, approval/reset, caught failures and success-not-proof qualification. |
| PT-COMP-04/05/06 | P:434-442, 469-495, 576-608 | Strict dust trigger; double-floor leftover valuation; zero exits; active-pool cap; reported addition and event predicate. |
| PT-ERC20-01/02/03/04 | P:156-198 | Exact approvals, allowance sentinel, self/zero transfers, selected checked/modular mutations and events. |
| PT-CB-01/02 | P:80-100, 120-123, 546-570 | Operation values, structs, sender-only guard and encoding. |
| PT-CB-03/04/05/06 | P:576-642 | Modification, Deploy checkpoints, used amounts, casts, limits and per-currency settlement. |
| PT-CB-07 | P:256-345, 351-442, 533-547 | Separate unlocks and outer token/share checkpoints. |
| PT-BAL-01/02/03/04/06 | P:133, 646-690 | Actual idle, incoming measurement, low-level return behavior and refund semantics. |
| PT-BAL-05 | `lib/v4-core/src/types/Currency.sol:40-95`; `CustomRevert.bubbleUpAndRevertWith` | Outgoing payout acceptance, raw reason and wrapped-error layout. |
| PT-BAL-07 | Complete local call/guard inventory; P:661-690 | No explicit token policy; behavior of unsupplied tokens not inferred. |
| PT-EVENT-01/02/03 | P:54-55, 116-118, 156-198, 286-291, 344-345, 360-362, 387-388, 442 | Every event, indexing and payload checkpoint. Interleaved external logs remain possible. |
| PT-ERROR-01/02/03/04 | P:102-130 and checks/calls listed above; helper revert paths | All declared local errors and meaningful ordering; dependency-specific errors remain external. |
| PT-DEPENDS-01/02 | P:20-28, 330-339, 425-430, 447-463, 489-495 | Factory/fee-manager interfaces and runtime usage. No concrete implementation included. |
| PT-DEPENDS-03/04 | `IPoolManager`; `IHooks`; `BalanceDelta`; P:546-642 | Interface responsibilities and actual returned-delta consumption, not a manager-engine proof. |
| PT-DEPENDS-05, PT-HANDOFF-01/02 | Evidence inventory and supplied run brief | Explicit absence/provenance boundaries, not on-chain observations. |

Acceptance scenarios PT-AC-01 through PT-AC-58 trace to the requirement IDs in their final column. Their numerical examples are static arithmetic illustrations of the definitions, not claims about an observed live pool.

## 19. Dependency examination inventory

There are 28 supplied source files. The full contents were read in the preceding continued-context audit; this run reread PairToken completely and the detailed helpers named in section 17. “Examined” below denotes that admitted static evidence base, not independent runtime verification. Unused helper entrypoints are not silently promoted into PairToken's public functionality.

| Source file | Status and use |
| --- | --- |
| `src/pair/PairToken.sol` | Examined; complete main source reread for this assignment. |
| `lib/v4-core/src/interfaces/IPoolManager.sol` | Examined interface; concrete manager implementation absent. |
| `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` | Examined callback interface. |
| `lib/v4-core/src/types/PoolKey.sol` | Examined key fields and types. |
| `lib/v4-core/src/types/PoolId.sol` | Examined pool-ID hash. |
| `lib/v4-core/src/types/Currency.sol` | Examined; payout/balance semantics rechecked. |
| `lib/v4-core/src/types/BalanceDelta.sol` | Examined signed packing/extraction. |
| `lib/v4-core/src/libraries/TickMath.sol` | Examined; exact tick-to-price constants/rounding rechecked. Inverse-tick helper is not directly called by PairToken. |
| `lib/v4-core/src/libraries/StateLibrary.sol` | Examined; relevant external-storage getters traced. Other getters are dependency context. |
| `lib/v4-core/src/libraries/Position.sol` | Examined; position-key function directly relevant. Position update implementation does not establish the absent deployed manager's execution. |
| `lib/v4-core/src/libraries/SqrtPriceMath.sol` | Examined; direct amount-delta functions rechecked. Next-price helpers are not the supplied PairToken's swap engine. |
| `lib/v4-core/src/libraries/FullMath.sol` | Examined full-precision floor/ceil and failure contracts. |
| `src/vendor/uniswap/LiquidityAmounts.sol` | Examined; complete conversion helper rechecked in this assignment. |
| `src/base/PriceMath.sol` | Examined; `sqrt` used by quote. `sqrtPriceFor` is not a PairToken callable feature. |
| `lib/v4-core/src/interfaces/IHooks.sol` | Examined hook interface; actual hook implementation absent. |
| `lib/v4-core/src/interfaces/external/IERC6909Claims.sol` | Examined inherited manager interface; no PairToken claim-mint/burn settlement route. |
| `lib/v4-core/src/interfaces/IProtocolFees.sol` | Examined manager protocol-fee interface; separate from PairToken factory-directed carve. |
| `lib/v4-core/src/interfaces/IExtsload.sol` | Examined external persistent storage-read interface. |
| `lib/v4-core/src/interfaces/IExttload.sol` | Examined inherited transient-read interface; not proof of transient PairToken reservation storage. |
| `lib/v4-core/src/interfaces/external/IERC20Minimal.sol` | Examined token interface, not concrete token behavior. |
| `lib/v4-core/src/libraries/CustomRevert.sol` | Examined custom/wrapped error encoding. |
| `lib/v4-core/src/libraries/SafeCast.sol` | Examined checked helper casts; distinguished from PairToken's explicit unchecked-width conversions. |
| `lib/v4-core/src/libraries/BitMath.sol` | Examined indirect tick-library support. |
| `lib/v4-core/src/libraries/FixedPoint128.sol` | Examined dependency constant; not a PairToken account fee-index scale. |
| `lib/v4-core/src/libraries/LiquidityMath.sol` | Examined dependency arithmetic; not a separately supplied manager implementation. |
| `lib/v4-core/src/libraries/UnsafeMath.sol` | Examined rounding support and its denominator conventions. |
| `lib/v4-core/src/libraries/FixedPoint96.sol` | Examined Q96 constants. |
| `lib/v4-core/src/types/BeforeSwapDelta.sol` | Examined hook-return encoding dependency. |
| Concrete factory, fee manager, manager/Pool engine, actual hooks and tokens, live state/deployment artifacts | Not examined: not supplied. Their missing behavior is explicitly bounded in Part III. |

## 20. Completion and publication boundary

The authored requirement inventory covers all 17 named functions, the receiver, all 17 getters, all five events, all 13 declared local custom errors including unused `NotFactory`, the internal behavior needed to determine their results, 58 observable acceptance scenarios, and the specified dependency/provenance limits. Exact quirks are retained rather than repaired.

This is the complete independent initial requirements response for this run. It is suitable for coordinator comparison and synthesis into a standalone candidate baseline, subject to the single later advisory assignment. It is not a consensus final, executed verification, deployment plan, implementation, security finding, or legal-clearance determination. All preceding audit artifacts remain unchanged.

