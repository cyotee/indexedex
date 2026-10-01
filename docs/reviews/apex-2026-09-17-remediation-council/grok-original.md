# Grok original review — APEX 2026-09-17 remediation

- Reviewer: Grok (xai/grok-4.7), independent first pass
- Date: 2026-09-25
- Scope: current working-tree production source that implements the APEX 2026-09-17 remediation
- Code was not edited. Forge was not run. Passing-test claims in the plan and follow-up record were not treated as proof.
- Live instances were not read. A source edit is not a remediation of immutable deployed bytecode.

## Documents

| Path | Status |
| --- | --- |
| `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | Read. Requirements R1–R14 and owner clarifications through the twenty-second review. Later plan rulings D49–D69 are additional locked decisions. |
| `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` | Read through D69 and the file-scope tables. Status “complete” and the 34,909-test claim are claims, not evidence reviewed here. |
| `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` | Read, 7 pages. Auditor claims only. |
| `docs/audits/apex-2026-09-17-followup-fixes.md` | Read. Later pricing and hook-custody corrections were checked in code where cited below. |
| `CLAUDE.md` | Read. |
| `docs/agent/SKILL_CATALOG.md` | Read. |
| `.claude/skills/indexedex-adversarial-testing/SKILL.md` | Read. E6 / I1–I3 trust-flag rules used as review criteria. |
| `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` | Read through the trust-flag catalog. |
| Peer review artifacts under `docs/reviews/` and `reviews/` | Not read. |

Where the original audit, the PRD, and later owner rulings conflict, the later recorded owner ruling was treated as the requirement. Current code supersedes narrative. D50’s buffered-leg credit heuristic is superseded by the follow-up record’s raw / identity / non-identity custody split; D15’s credit and refund cap remains.

Context7 was not queried. This pass reviewed this repository’s own accounting, not an external library API. `BetterAddress.isContract` was read locally.

## Method

Searched production credit, refund, burn, caller-guard, `try`/`catch`, and hook face-transfer sites, then read the callers named in the assignment. Historical Uniswap trees under `contracts/protocols/dexes/uniswap/{v3,v4}/` were treated as inventory, not as the fix. Tests were not executed and were not used as proof that a claimed behavior holds.

## Findings

### 1. Single-CP HookTarget exact-out still refunds `maxAmountIn - amountIn`

- Severity: Low
- File and line: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754`
- Intended behavior: D15 / R13. Pretransferred exact-output refunds only `credit - used`, where `credit = min(unbooked, maxAmountIn)`. A caller with no bytecode is rejected. `pretransferred=false` pulls exactly `used` and refunds nothing. Booked inventory is never paid out.
- Broken requirement or invariant: The abstract target’s `exchangeOut` pulls `amountIn` when `pretransferred` is false, which matches the false-flag rule, but when the flag is true it transfers `maxAmountIn - amountIn` to `msg.sender` with no `LocalCreditLib` budget, no `requirePretransferCaller`, and no check that unbooked credit covers the refund.
- Impact class: value accounting, access control, spec nonconformance
- Fix direction: Delete this duplicate `exchangeIn` / `exchangeOut` pair, or route it through the SeTarget helpers (`_securePull` / `_pullExactOutInput`) that already implement D15. Do not leave a second exact-out implementation in the family tree.
- Confidence: high that the function implements the unsafe refund; high that the current production cut does not expose it
- Evidence label: observed fact

Facts. Lines 749–753 transfer `maxAmountIn - amountIn` on the true flag and do not call `LocalCreditLib`. The production package installs `exchangeOut` from `UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet`, which inherits `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget` (`DFPkg.sol:214-217`, SeFacet `facetFuncs` includes `IStandardExchangeOut.exchangeOut`). SeTarget `exchangeOut` at `SeTarget.sol:836-864` calls `_pullExactOutInput`, which budgets credit and refunds `credit - used` (`SeTarget.sol:981-989`). A repository search found no production contract inheriting `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget`; the contract is `abstract` (`HookTarget.sol:49`).

Inference. The unsafe function is not on the current diamond cut. It remains a second implementation in the family source. A later facet cut that exposes this selector would pay `maxAmountIn - used` from whatever face the hook holds, including booked or donated inventory, and would accept an EOA pretransfer.

Speculation. None on reachability of the current cut.

### 2. FullSpread integrator README still documents the superseded pull and refund rules

- Severity: Low
- File and line: `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-48`
- Intended behavior: R13 and the APEX amendment in `uniswap-se-v2-liquidity-leak-fixes.md:14`. Exact-input pretransfer credits exactly `amountIn` when unbooked available covers it and refunds nothing. `pretransferred=false` exact-output pulls quoted `used` and refunds nothing. Pretransferred exact-output refunds only `credit - used`.
- Broken requirement or invariant: The public FullSpread README still says `exchangeIn` requires `actualIn == amountIn`, that V3 token exact-out pulls its quote plus a capped buffer, that V4 pulls max, and that dual exits pull max shares and refund unused shares.
- Impact class: spec nonconformance
- Fix direction: Replace those sentences with the D15 / D17 / D28 rules already written in the liquidity-leak PRD amendment. Do not leave the integrator-facing README describing pull-max or exact-in equality.
- Confidence: high
- Evidence label: observed fact

Facts. README lines 32–48 state the superseded rules. The executable FullSpread V4 token exact-out path quotes first, pulls `estimatedAmountIn` when `pretransferred` is false, and pulls the credit budget only when the flag is true (`UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:55-78`). Dual-exit false-flag pull amount is `quoted.sharesToBurn`, not `maxAmountIn` (`UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol:36-43`). The liquidity-leak PRD amendment at line 14 already records the new rule. The README was not updated to match.

Inference. An integrator who follows the README will pull `maxAmountIn` or require exact-in push equality against a vault that no longer does either. That is a documentation defect, not a runtime refund of booked inventory.

### 3. ERC-4626 exact-out NatSpec still sends residual dust to `feeTo`

- Severity: Low
- File and line: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20`
- Intended behavior: D6 / R10. Protocol residual, dust included, stays as book for existing holders. The fee recipient receives only explicit usage or protocol fees. `_absorbDustToFeeTo` is not used on in-scope refund paths.
- Broken requirement or invariant: The target’s own NatSpec still says unrefundable residual at or below `MAX_DUST_WEI` goes to `feeTo` when `feeTo` is non-zero, and is skipped when `feeTo` is zero.
- Impact class: spec nonconformance, accounting clarity
- Fix direction: Replace that NatSpec with the D6 retention rule. Confirm no executable absorb-to-`feeTo` remains on this route; the body read here refunds through `_pullExactOutInput` and does not transfer residual to `feeTo`.
- Confidence: high on the stale NatSpec; high that the function body read does not implement the stale sentence
- Evidence label: observed fact

Facts. Lines 17–20 describe dust-to-`feeTo`. The wrap exact-out body at lines 72–88 calls `_pullExactOutInput` and `_syncAllExpectedHoldReserves` and does not call an absorb helper. A production-source search found `_absorbDustToFeeTo` only in a non-CP single-hook plan markdown, not in executable Solidity.

### 4. Orbital capped unwrap reports the approval cap as shares spent

- Severity: Low
- File and line: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`
- Intended behavior: D25. The capped unwrap calls SE `exchangeOut` with a share cap. Under D15 the SE pulls exactly the shares it uses and delivers `amountOut`, or the SE revert propagates. The hook must not account the unused approval as burned shares.
- Broken requirement or invariant: After `exchangeOut`, the function assigns `seIn = maxIn`, where `maxIn` is `min(quoted shares, cap)`, not the amount the SE actually pulled.
- Impact class: accounting clarity
- Fix direction: Return the SE’s reported spend, or measure the share-balance delta around the call, and use that as `seIn`. Do not treat the pre-call approval cap as consumption.
- Confidence: high that the return value is the cap; high that current in-repo callers ignore it
- Evidence label: observed fact for the assignment; inference that it is not a live mis-debit today

Facts. Lines 557–565 approve `maxIn`, call `exchangeOut(..., maxIn, ..., amountOut, ..., false, ...)`, then set `seIn = maxIn`. Call sites in this hook (`HooksTarget.sol:298-302`, `SeTarget.sol:125` and `185`, `WithdrawTarget.sol:177`, and the internal swap executors at lines 586 and 604) discard the return value. Settlement of face to the PoolManager in `beforeSwap` uses the quoted `amountOut`, not this return (`HooksTarget.sol:306-313`).

Inference. Today the wrong return does not move tokens. A later caller that debits SE-share inventory by this return would overstate consumption whenever the SE pulls less than the cap.

### 5. Shared hook exact-out helper does not itself enforce `used <= credit`

- Severity: Informational
- File and line: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2061-2069`; same shape at `weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:498-506`, `dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:179-187`, `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:981-989`, and the quad target copies (`curve/...HookTarget.sol:475`, `balancer/...HookTarget.sol:290`)
- Intended behavior: D23. Short funding on pretransferred exact-output reverts `TransferDeltaInsufficient(used, credit)` where `credit = budget(available, maxAmountIn)`.
- Broken requirement or invariant: The helper first calls `_securePull(token, used, pretransferred)`, which for a true flag checks `used` against the whole unbooked balance, not against `budget(unbooked, maxAmountIn)`. It refunds `credit - used` only when `credit > used`. It does not revert when `used > credit`.
- Impact class: error handling, spec nonconformance
- Fix direction: Compute `credit` first. Revert `TransferDeltaInsufficient(used, credit)` when `used > credit`, then pull or credit `used`, then refund `credit - used`. Do not rely on every caller to have already compared `used` with `maxAmountIn`.
- Confidence: high on the helper; medium that every current caller is safe
- Evidence label: observed fact for the helper; inference for current caller coverage

Facts. Orbital `SeTarget._swapExchangeOut` compares `amountIn` with `maxAmountIn` before calling the helper (`SeTarget.sol:177-180`). The same pre-check was seen on the weighted, dual, single-CP, and quad SE targets that were opened. `_securePull` still rejects `used` above unbooked available.

Inference. If every caller keeps the `used <= maxAmountIn` check, `used > credit` collapses to `used > available`, which `_securePull` already rejects. The helper is not a safe primitive by itself.

## Audit disposition

Live bytecode was not read. “Refuted in current source” means the reported arithmetic is not what the replacement or corrected production file does now. It does not mean an immutable instance was upgraded.

| Finding | Disposition | Evidence read |
| --- | --- | --- |
| APEX-2026-001-M | Still present in preserved historical source. Refuted in the FullSpread replacement source. Live instances unverified. | Preserved V4 still sets `faceBooked = R > deployed ? R - deployed : 0` and credits from that difference (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1270-1288`). Preserved V3 is the same pattern at the auditor’s cited sibling. FullSpread V4 `_secureTokenTransfer` credits `LocalCreditLib.available(balance, reserveOfToken)` and does not read `_deployedFaceOf` (`UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1218-1229`). `_deployedAmounts` remains a live pricing/rebalance read (`Common.sol:347`, `1242-1246`), not a delivery authenticator. |
| APEX-2026-001-M2 | Unverified as an instance inventory. Not a separate arithmetic defect. The preserved implementation that the report attributes to those seven vaults is still the vulnerable source above. | Report addresses were not queried. No chain read was performed. Replacement source does not carry the `R - deployed` credit term. Source edits do not change the seven reported instances. |
| APEX-2026-003 | Refuted in current custody source for the reported whole-balance refund. Non-atomic contract consumption of unbooked self-shares is an accepted residual per D12 / R5, not a closure of the live vault. | `takeShares` burns exactly `amount` from `address(this)` and does not transfer `prepaid - amount` (`RebasingAwareERC4626Common.sol:309-325`). Exact-out share pretransfer rejects a code-less caller, credits `budget(available(selfBal, 0), maxAmountIn)`, burns the withdraw’s share count, and transfers only `credit - burned` (`RebasingAwareStandardExchangeTarget.sol:117-138`). External SY `redeem` with `burnFromInternalBalance` rejects a code-less external caller and burns exactly the requested amount (`RebasingAwareStandardYieldTarget.sol:45-66`). Live custody vault `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` was not read. |
| APEX-2026-008 | Refuted in current orbital source for the reported whole-face payout. Resting non-identity face remains unrecorded pretransfer credit, which is the accepted D12 / D18 residual, not a refund of that balance to an unrelated pull-funded caller. | `_refundConservation` pays only `balance - opening` on non-identity legs (`OrbitalBufferHookCommon.sol:2013-2024`). Identity and raw legs return without a transfer. `_addLiquidity` snaps before the pull (`1161-1173`). `_freeTokenBalance` still returns the whole buffered face balance (`2028-2033`) but the withdraw caller uses it as a delta around the operation (`WithdrawTarget.sol:159-169`), not as a transfer of that balance. `_refundBufferedDust` was not found as a caller-paying function in this file. |
| APEX-2026-009 | Refuted in current ERC-4626 and Morpho source for the reported whole-self-share sweep. | ERC-4626 `_burnSeShares` burns `burnAmount` from `address(this)` after an available-self check and does not transfer the remainder (`ERC4626StandardExchangeCommon.sol:283-293`). Exact-out burns through `_burnExactOutShares`, which refunds `credit - used` (`267-274`). Morpho `_burnSeShares` is the same burn-only shape (`MorphoBlueStandardExchangeCommon.sol:206-216`). Exact-out share credit is `budget(available(selfBal, 0), maxAmountIn)` (`352-358`). |
| APEX-2026-004B | Refuted in current ERC-4626 source for the reported idle-underlying sweep. | No `_refundOrAbsorbAbove` remains in production Solidity. Exact-in underlying wrap pulls `amountIn`, invests `min(actualIn, capacity after sweep)`, and syncs reserves; it does not refund underlying (`ERC4626StandardExchangeInTarget.sol:100-113`, `ERC4626StandardExchangeCommon.sol:105-122`). Exact-out uses `_pullExactOutInput` (`OutTarget.sol:72-76`, `Common.sol:257-264`). |
| APEX-2026-005 | Refuted as “no canonical helper.” Completeness of every historical payout site was not re-derived. | `LocalCreditLib.available`, `budget`, and `requirePretransferCaller` exist (`contracts/utils/LocalCreditLib.sol:14-28`). `EOAPretransferNotAllowed` is on `ISecurePullErrors` (`ISecurePullErrors.sol:15-16`). D16 consumers opened in this pass call the library or a wrapper around it. D32 surfaces do not. |
| `beforeSwap` guard claim | Refuted in current source. Withdrawn false positive. No new guard was required. | Balancer-quad `beforeSwap` still starts with `BeforeInitializeLib.beforeInitialize(key)` (`...BalancerQuad...HookHooksTarget.sol:112`). That library reverts `NotPoolManager()` when `msg.sender` is not the stored PoolManager (`...BeforeInitializeLib.sol:22-24`). Orbital and weighted `beforeSwap` call `_onlyPoolManager()` directly (`Orbital ...HooksTarget.sol:277`, `Weighted ...HooksTarget.sol:138`). |
| Weighted dust claim | Refuted as a High. Downgraded informational residual stands: unconvertible face stays on the hook and is not paid to the caller or to `feeTo`. | Weighted `_refundBufferedDust` buffers a positive preview and leaves the remainder with an explicit D36 comment; it does not `safeTransfer` that remainder to `msg.sender` (`Weighted ...HookTarget.sol:611-622`). Curve-quad and dual-CP copies match that shape (`CurveQuad ...HookTarget.sol:749` region; `Dual ...HookCommon.sol:435-445`). |

## Checked sites with no confirmed defect

These are sites that were read against the named unsafe patterns. “No defect found” means the pattern was not confirmed in the lines read. It is not a claim that the family is fully audited or that tests pass.

| Site | What was checked | Result |
| --- | --- | --- |
| `contracts/utils/LocalCreditLib.sol:14-28` | `available` floors at 0; `budget` is `min`; caller check is `BetterAddress.isContract` (`codeSizeOf() > 0`, `lib/crane/contracts/utils/BetterAddress.sol:106-108`) | Matches D11. EIP-7702 and contract wallets pass the bytecode check. That is the accepted D12 / D44 residual, not a defect. |
| `contracts/vaults/basic/BasicVaultCommon.sol:77-154` | Base pull credits claimed only when `claimed <= U`; `_refundExcess` pays `min(max - used, unbooked)` only on the true flag; `_secureSelfBurn` burns `burnAmount`, not the whole self-balance | Matches D15 for callers that pass credit as `max`. The base pull does not itself call `requirePretransferCaller`; every inheritor opened below overrides the pull and adds the guard. `_unbookedSurplus` reverts if `balance < reserve` rather than returning the whole balance. Fail-closed, not the forbidden fallback. |
| FullSpread V3/V4 token exact-out and exact-out mint | False-flag pull is quoted `used`. True-flag pull is the credit budget. Refund is `min(provided - used, post-swap surplus above the pre-credit baseline)` (`V4 OutExecuteTarget.sol:55-191`; V3 `OutExecuteTarget.sol:76-132`; V3 delegate mint at `OutExecutionDelegate.sol:102-104`) | Does not pull `maxAmountIn` on the false flag. Callback surplus cannot enlarge the refund above `provided - used`. |
| FullSpread dual exit | False-flag pull is `sharesToBurn`. True-flag pull is credit, with `sharesToBurn > credit` reverting (`V4 OutMultiTarget.sol:36-46`). `_refundUnusedShares` pays `delivered - used` only (`V4 Common.sol:1283-1286`) | Matches D17. |
| FullSpread exact-in zap mint | Post-pull totals back out `amountIn` before share math (`V4 InBase.sol:283-288`) | Incoming credited amount is not priced as pre-existing backing. Excess unbooked above `amountIn` remains in the total and is later booked. That matches D28, not a free mint. |
| FullSpread exact-out mint pricing | `_amountInForZapMint` subtracts `prepaidCredit` from the input-side total reserve (`V4 OutBase.sol:53-61`) | Matches the follow-up rule that the bounded credit, including the amount to refund, is not pre-deposit backing. `prepaidCredit <= unbooked <= free balance <= total reserve` for that token, so the subtraction is not an independent live-deployed authenticator. |
| ERC-4626 SE in/out and receipt adapter | Backing is held receipts plus booked underlying via `convertToShares`, not live unbooked underlying (`Common.sol:63-68`, `ReceiptBackedERC4626AccountingLib.sol:14-20`). Adapter deposit snapshots backing before `_pullReceipts` (`ReceiptBackedERC4626Target.sol:105-115`). Adapter pull requires the measured delta to equal the request (`200-205`). | Incoming adapter deposit is not authenticated by idle receipts. Exact-in SE receipt mint subtracts `actualIn` from backing (`InTarget.sol:118-123`). Exact-out receipt mint subtracts prepaid credit (`OutTarget.sol:128-139`). No `keepBalance == 0` refund helper remains. |
| Morpho wrap exact-in / exact-out | NAV snapshot excludes credited `actualIn` on exact-in pretransfer and excludes the whole bounded credit on exact-out (`MorphoBlueStandardExchangeCommon.sol:263-317`). `_supplyInBound` is a direct `Morpho.supply` (`219-222`). | Matches the follow-up pricing correction. No `try`/`catch` on the supply. |
| Rebasing-aware custody | Asset pretransfer still reverts `AssetPretransferNotSupported` (`RebasingAwareStandardExchangeTarget.sol:77-78`, `111-112`). Share paths use the EOA guard and exact burn. | 003’s reported refund is gone. D12 contract consumption of unbooked self-shares remains, by ruling. |
| Uni V2 / Camelot / Aerodrome token exact-out | Credit is snapshotted before spend; refund helper is `_refundExactOutCredit(token, credit, used, pretransferred)` (`UniswapV2StandardExchangeOutTarget.sol:455-461`, `CamelotV2StandardExchangeCommon.sol:202-214`, Aerodrome `OutExecuteTarget.sol:168` and siblings). Overrides add `requirePretransferCaller`. | D35’s `used + _unbookedSurplus` refund argument was not found on these routes. Uni V2 comments at `OutTarget.sol:538-540` still say `_secureTokenTransfer` returns `balanceOf(this)`. The function returns `amountIn` (`UniswapV2StandardExchangeCommon.sol:420-447`). Stale comment only; not raised separately because the executable refund does not use that comment. |
| Slipstream | Token exact-out uses credit and `_refundExactOutCredit`. Zap-out share credit is `budget(selfBal, maxSharesToBurn)` with booked self-shares 0, then burns `sharesBurned` and transfers `credit - sharesBurned` (`SlipstreamStandardExchangeOutTarget.sol:178-188`). | Matches R7’s booked-self-shares = 0 row. D57 deprecates the package; the 1% share pad remains at `OutTarget.sol:122-129`. That is unfinished product behavior on a deprecated tree, not the 001-M delivery bug. No launch wiring was re-verified. |
| Lido `exchangeInEth` SE-share branch | Stake capacity is read before `submit`; unstaked remainder is wrapped to WETH; shares are minted on `ethValue` against `totalReserveEth()` captured before the stake (`LidoWstETHStandardExchangeInTarget.sol:117-142`, `Common.sol:251-253`). | Matches D47. Direct stETH/wstETH branches still submit the full `msg.value` with no capacity precheck (`147-166`), which D47 requires. |
| Aave Cross-Version Loop | `exchangeIn` / `exchangeOut` / `_mintExactShares` / `_burnWithdrawalShares` revert `TransferDeltaInsufficient(..., 0)` on the true flag (`AaveCrossVersionLoopExchangeInTarget.sol:47`, `OutTarget.sol:72`, `ExchangeBase.sol:195`). False-flag wrap pulls the quoted amount and prices shares against `navUsd` taken before the pull (`OutTarget.sol:76-95`). `navUsd` includes local tokenA (`CrossVersionLoopExecutor.sol:363-385`). | D32 was not opened. Idle tokenA is treated as vault-owned because public pretransfer is rejected. That is the D32 ruling, not a new public-pretransfer credit path. |
| `BalancerV3PoolStandardExchangeTarget` | True flag still reverts `UnsupportedPoolPretransfer()` (`BalancerV3PoolStandardExchangeTarget.sol:123`). | D32 reject preserved on the line read. Delegating packages were not each opened. |
| `BalancerV3SinglePoolStandardExchange` | `requirePretransferCaller` is present at lines 156 and 231. | Guard is present. Full pull/refund arithmetic of this adapter was not re-derived in this pass. |
| Orbital / weighted / dual / single-CP / quad hook credit | Non-identity buffered face uses booked 0 or a face book separate from the rated SE claim. Identity and raw legs subtract a native custody book (`Orbital Common.sol:2072-2078`, `Dual Common.sol:172-176`, `Single-CP SeTarget.sol:969-978`, `Weighted HookTarget.sol:488-495`). | Matches the follow-up custody split. Not the D50 “rated claim exceeds face, so all face is credit” heuristic on identity/raw legs. Buffered-leg face remains unbooked by design (D12 / D18). |
| Weighted / curve / dual dust | Post-buffer remainder is not transferred to `msg.sender`. | D36 holds on the functions read. Not sent to `feeTo`. |
| D16 `try`/`catch` | Production search under `contracts/vaults`, `contracts/hooks`, and `contracts/protocols` found no `try {`. Remaining `catch (` hits are test bases, plan markdown, and the preserved historical V4 `symbol()` fallback (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1340-1343`). | D34 / D37 removal holds for the production trees searched. Preserved historical catch was not treated as a failed fix. D41 / D48 / D49 staticcall sites that were opened (`UniswapV4SeBufferHookLegLib.sol:130-139`, weighted and quad rate `staticcall`s, buffer-hook `prepaySessionActive` probes were not each re-read) are interface probes, not operative token movement, on the lines read. |
| Staked DETF and funded-bond prepaid flag | `StakedDETFTarget.sol:202` and `DETFFundedBondTarget.sol:400` call `requirePretransferCaller`. | Guard present at those lines. Vesting and claim math were not reviewed. |
| Composed / MixedBuffer / MultiVault exact-out | Credit is `budget(available(balance, reserve), maximum)` and the refund is `credit - used` (`ComposedStableCommonDetfExchangeOutQueryFacet.sol:49-105`, `MixedBuffer...ExchangeQueryTarget.sol:59-74`, `MultiVaultWeighted...ExchangeQueryTarget.sol:62-76`). | Refund amount matches D15. Inner `_exchangeIn` syncs reserves before the outer refund (`MixedBuffer...ExchangeInTarget.sol:71`), then the outer call syncs again. The refund amount is still the pre-sync credit minus used, and the pull is `amount_`, not the whole balance. No booked-inventory payout was confirmed. Temporary book-above-balance inside the same locked call is accounting clarity, not a confirmed leak. |

## Limitations

- Forge was not run. The follow-up record’s 34,909-test, 33-campaign, and matrix counts are unverified claims.
- Chain state for the seven reported vaults, the custody vault, and the registry was not read. Historical reproduction at block 64025200 was not repeated.
- Not every D16 file was read line by line. Unread or only partially read areas include most DETF bond/vesting math, most Balancer buffer-pool hook operative paths, EtherFi and Rocket Pool stake prechecks, Aave Stata route bodies beyond the pull override, and the D48 rate-provider staticcall rewrite. Absence of a finding there is absence of review, not a pass.
- No exploit procedure, payload, or reproduction is included. Defects above name the class, the location, and the fix direction only.

## Separation of evidence

- Observed fact: line citations in the findings and disposition table.
- Inference: dead-code reachability of finding 1, and the claim that current hook callers happen to pre-check `maxAmountIn` so finding 5 is not a live short-funding bypass.
- Speculation: none used as a finding. Live-instance exposure is unverified, not speculated as open or closed.
