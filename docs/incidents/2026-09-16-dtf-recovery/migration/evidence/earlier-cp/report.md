# Earlier CP source, custody, units, and harvest evidence

Date: 2026-11-10. Scope: implementation-plan task 1, earlier CP lane only.

**Result: evidence work complete; source-route closure remains UNPROVEN.** The completed pinned Alchemy fork and separately labeled fresh public fork each have **18 PASS, 2 FAIL, 4 UNPROVEN** checks. Real transactions establish custody, reward harvesting, conversion to a rebasing receipt, burned-position rejection, and rollback. Mature withdrawal and receipt redemption are blocked by the deployed underlying vault's disabled state. This report does not authorize dropping those routes, changing contribution pricing, or treating LP shares as modern funded principal.

## 1. Reproduction and execution identity

Run from `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`:

```sh
bun scripts/recovery/dtf-migration/phase01/earlier-cp/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe
```

Binary PASS observable, recorded before execution in each result: authenticated source runtime and selector bindings, successful mined custody/claim transactions with measured state changes, rejected-operation rollback, and teardown read-backs. Exit 0 means all recorded checks PASS; exit 2 means closure is not proven. A failing subprocess or RPC is not a product verdict.

The exact invocation was executed. Its original `probe.json` records HTTP 429 during source reads; `probe-alchemy429.json` preserves an earlier historical Anvil attempt that also encountered Alchemy compute-unit throttling. Those failures remain unchanged. **The subsequent login-shell retry completed the pinned historical custody suite**, so historical access is no longer a blocker. The remaining source/harvest limitations are listed below.

The initial child environment lacked `ALCHEMY_KEY`; `/bin/zsh -lic` loaded the existing key without displaying it. The recorded configured alias remains `robinhood_mainnet_alchemy`; no secret value is retained. An explicit public fallback is separately identified, not represented as an Alchemy success.

The owner-requested retry used `/bin/zsh -lc`, worktree cwd, and an isolated `TMPDIR` plus Bun/node cache exports. Presence-only check: `ALCHEMY_KEY_PRESENT`. Literal probe invocation:

```sh
bun scripts/recovery/dtf-migration/phase01/earlier-cp/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry
```

`probe-alchemy-retry.json`, `.source.json`, and `.summary.json` are the authoritative pinned replay. The suite completed at block `108944663`, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, with `freshFallback=false`. It returned exit 2 for the recorded source/route limitations, not a credential or RPC failure. Runtime: Bun PID `43842`, same Bun/Anvil binaries below; owned Anvil PID `43955`, loopback port `56817`. All custody, claim, sale, negative-case and rollback verdicts reproduced. The transaction hashes cited in section 4 also occur in this pinned replay.

The completed, separately labeled fresh probe was:

```sh
bun scripts/recovery/dtf-migration/phase01/earlier-cp/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_public --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-fresh3
```

The public endpoint could serve the requested header but returned historical-state-unavailable. The executable preserved that failure and pinned a fresh block:

| Identity | Observed value |
| --- | --- |
| Public/local chain ID | `4663`, RPC `0x1237` |
| Requested block | `108944663`, `0x67e5d17` |
| Requested hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Fresh execution block | `110859526`, `0x69b9506` |
| Fresh execution hash | `0x95e705f74dedcea73e2c87c4276435e1ccb498680f1c46e25fba8bb1aa0cac36` |
| Fresh block timestamp | `2026-11-10T11:52:20Z` |
| Source-discovery block/hash | `0x69b94c8` / `0xadd31b8bb9569d43c1aaa065d6c496a96d6f8d339da73e1ba3edc49c2318019d` |
| Bun | `1.4.2`, `/opt/homebrew/Cellar/bun/1.4.2/bin/bun`, Darwin arm64 |
| Anvil | `1.9.0-Homebrew`, commit `6056c5845d34205a83cf7108042adb137325c9df`, build `2026-11-02T18:15:17Z` |
| Successful fresh fork resource | PID `39477`, loopback port `56303` |

Before writes, the fork header hash, chain ID, all three proxy runtimes, every discovered facet runtime, and complete loupe routing were compared with the source-discovery observations. The fresh replay intentionally separates discovery and execution blocks; the pinned Alchemy replay uses the requested block for both. Transactions use disabled automining plus explicit `evm_mine`, followed by a receipt read and `callTracer`; there are no receipt polling loops or timing sleeps.

## 2. Authenticated sources and selectors

`probe-alchemy-retry.source.json` contains pinned Sourcify source text, ABI, compilation/deployment metadata, source-service runtime match, observed runtime bytes and hashes, and actual proxy selector-to-facet bindings; `probe-alchemy-retry.json` contains the pinned RPC observations and receipts. The corresponding `probe-fresh3` files preserve the independent fresh replay. Source-service provenance alone is not the proof: the probe compares the service's on-chain runtime bytes with `eth_getCode` and rechecks the fork's code.

All three proxies have observed runtime hash:

`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.

| Source | Deployed identity and relevant implementation |
| --- | --- |
| Liquid DETF | `0xaf0E1967c8F755c747615c5427108Bc549CA1122`; core facet `0x8333749Cc7b1f66b5be568257d362aA749497Cf0`, hash `0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d` |
| LP-lock NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`; `DETFNFTVaultFacet` at `0x3AB85813785b43B864F9C171F7ac97d6B76c459b`, hash `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |
| Rebasing receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01`; facet `0x25E611FB63Eb904776678286EF5cbe2a931B4f9A`, hash `0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc` |
| Physical reserve LP | NFT `lpToken()` returned `0x923877336b14662cFb5B3A60b14e7d716d54A888` |
| Underlying SE | `standardExchangeVault()` returned `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7`; disabled error identifies this same address |

**Full source authentication: UNPROVEN.** Sourcify returned HTTP 404 for DETF facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`. Its observed hash is `0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`; routed selectors are `0x6a4d3f12`, `0xf5ee7c5b`, `0x36abf3dc`, `0x7cc34bb4`. A direct name read returned `MultiAssetStandardVaultFacet`, which is not verified source evidence. Searches at the same address on Sourcify chains 46630 and 11155111 also returned 404. Relevant verified NFT/core/receipt facets do match their observed runtimes, but this does not authenticate every transitive dependency or close the missing facet.

Exact observed callable selectors:

| Target | Signature | Selector / return |
| --- | --- | --- |
| NFT | `getPosition(uint256)` | `0xeb02c301`; tuple `(originalShares,effectiveShares,bonusMultiplier,unlockTime,rewardDebt)`, all `uint256` |
| NFT | `originalSharesOf(uint256)` | `0x0f3767df`; `uint256` LP accounting shares |
| NFT | `ownerOf(uint256)` | `0x6352211e`; `address`, zero for absent/burned observations |
| NFT | `unlockTimeOf(uint256)` | `0x75d2d262`; `uint256` |
| NFT | `pendingRewards(uint256)` | `0x7dcb2abf`; `uint256` old DETF units |
| NFT | `claimRewards(uint256,address)` | `0x6c7b69cb`; `uint256` |
| NFT | `transferFrom(address,address,uint256)` | `0x23b872dd`; no return |
| NFT | `safeTransferFrom(address,address,uint256)` | `0x42842e0e`; no return |
| NFT | `lpToken()` / `rewardToken()` | `0x5fcbd285` / `0xf7c618c1`; addresses |
| NFT | `convertToAssets(uint256)` | `0x07a2d13a`; LP assets |
| DETF | `sellPositionToDetfNft(uint256,address)` | `0x6b7d927e`; `uint256` principal shares |
| DETF | `closeBondMature(uint256,uint256[],address,uint256)` | `0x7c212893`; `uint256[]` |
| DETF | `redeemClaim(uint256,address,uint256,address,uint256)` | `0xbfe55606`; `uint256` |
| Receipt | `sharesOf(address)` / `totalShares()` | `0xf5eb42dc` / `0x3a98ef39`; external accounting shares |
| Receipt | `redemptionRate()` | `0x540385a3`; WAD rate |
| Receipt | `convertToShares(uint256)` / `convertToClaim(uint256)` | `0xc6e6f592` / `0x2fbc6fea`; source-specific quantities |
| Receipt | `redeem(uint256,address,bool)` | `0x5236be40`; `uint256` pair-token output |
| Tokens | `decimals()` | `0x313ce567`; `uint8` |

The actual event is `NewLock(uint256 indexed tokenId,address indexed recipient,uint256 shares,uint256 bonusMultiplier,uint256 unlockTime)`, topic:

`0x6c9c08a1f1b7feb37476c6618f41abf6bb2f0ed71f504b88f6503b3a2a8475e5`.

It is not the newer funded-principal event.

Source anchors below refer to line numbers in the **unescaped flattened `.sources[filename].content` strings**, retained in the source JSON:

- `DETFNFTVaultFacet.sol`: NewLock/create, 16194-16269; redemption and retirement, 16331-16407; owner/DETF-only reward claim, 16413 onward; NFT sale, 16500 onward; original-share deletion, 15593-15601; LP asset conversion, 15787 onward; position construction, 16135 onward.
- `UniswapV4SingleStandardExchangeDETFFacet.sol`: sale to receipt, 25419 onward; receipt redemption, 25450 onward; mature close, 25644 onward; holder-only reward claim, 25751 onward; `VaultDisabled(address)`, 4531.
- `RebasingClaimTokenFacet.sol`: share constants, 9609-9610; internal/external conversions, 9859-9878; public conversions, 10015 onward; transfer, 10125 onward; NFT-sale mint, 10166 onward; direct redeem, 10194 onward; redemption execution, 10382 onward; current-rate calculation, 10446 onward.

## 3. Units, remaining reads, and original contributions

**PASS:** old DETF, receipt, reserve LP, DTF, and WETH all returned **18 decimals**. None is a 9-decimal modern DETF credit.

NFT 4's exact observed position:

```text
owner             0x230f95db9644C5b3608bA676D18426d03e435B1D
originalShares    2281854312954086546
effectiveShares   2283136213569959131
bonusMultiplier   1000561780219094285
unlockTime        1788261679
rewardDebt        12649110640673
pendingRewards    309005608995105
convertToAssets   2281854312954086546
```

`originalSharesOf` is the live LP accounting basis; `effectiveShares` includes reward weight. Neither is fixed DETF principal or an original DTF contribution. Successful reward claim leaves original shares unchanged. Successful whole-position sale zeroes all five fields and burns the identity. There is no observed `claimedPrincipal` field or partial fixed-principal withdrawal model to rename.

NFT 3 remained locked at `1803205295` (2027-02-21T10:21:35Z), with `562524912595035608166` original shares. Transfer into custody succeeded without changing its lock or principal; early sale reverted. Still-locked shares remain a distinct eligible source-unit question, not zero merely because withdrawal is currently unavailable.

`purchases[]` archives all 16 original purchase receipts, canonical block-hash comparisons, decoded NewLock events, and log-indexed token transfers. Every ID 3-18 matched the frozen input CSV's original LP shares, direct DTF, direct WETH, and separately routed DTF.

- NFT 3: direct WETH `2000000000000000000`; direct DTF `0`; underlying-SE routed DTF `1778859964387451305574664`.
- NFT 4: direct DTF `7215852540309913726431`; direct WETH `0`; routed DTF `0`. The extra `3703818` DTF from reserve LP is settlement, not another contribution.
- NFT 9: direct WETH `100000000000000`; underlying-SE routed DTF `41454674363068691516`. Additional reserve settlement is stored separately.

The normalizer distinguishes payer-to-DETF inputs, underlying-SE-to-DETF routing, and reserve-LP settlement by actual token/from/to/log identity. The first implementation incorrectly summed every nonpayer DTF inflow; its FAIL is preserved in `probe-fresh1.json`. The corrected classifier independently matches all 16 input rows. Routed DTF is never counted as a second original contribution.

Remaining frozen-snapshot pricing, `C0`, new 90-day bonds, configuration removal, and descendant credit nonduplication are not exercised by these legacy transactions. The approved original-contribution quote and remaining-principal delivery rules are unchanged. A source-specific LP eligibility basis must remain explicit rather than silently calling these fields modern principal.

## 4. Actual custody, claims, and blocked harvest

Recovery fixture: `0x100000000000000000000000000000000000c001`; attacker fixture ends `bad1`. These are locally impersonated accounts, not a deployed Migration proxy.

**PASS, NFT custody and rewards:** NFT 4 transferred to recovery in transaction `0x3e3b2b3d5ad372acb94c7f5b2af467e4aba3a310be6b0fdd06316d909953e398`. The new owner then claimed via the NFT in `0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45`, receiving exactly `309005608995105` raw old DETF, from zero. Original LP shares remained `2281854312954086546`. The former owner could no longer claim.

**PASS, mature NFT to receipt:** recovery called DETF `sellPositionToDetfNft` in `0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042`. NFT owner became zero; all position fields became zero; recovery received `4322` raw receipt and `1967558883021387942` external receipt shares, plus the reward above. Physical LP custody stayed at `107516722668090845797720021675152213` raw LP. A second sale of that identity reverted. This proves a descendant exists, not that it independently earns a second migration award.

**PASS, liquid custody:** transfer of `1000000000000000000` raw old DETF produced exactly that recovery balance delta. **PASS, receipt custody:** transfer of `1000000000000000000` raw receipt produced `999999999999999999` displayed receipt and `455166135639508420573509330905780` external shares.

The receipt's observed rate was `2197`; total external shares were `26345106194913509598392145360059647`. Displayed supply was `57898677945502333609` at the pinned historical block and `57898677945502049312` at the fresh block. These distinct observations are retained, not normalized into one number. Deployed source uses internal precision:

```text
SHARE_SCALE = 10^9
SHARE_UNIT  = 10^27
internalShares(amount) = floor(amount * SHARE_UNIT / rate)
externalShares        = floor(internalShares / SHARE_SCALE)
displayedBalance      = floor(internalShares * rate / SHARE_UNIT)
```

Public `convertToShares(10^18)` returned `455166135639508420573509330905780`; `convertToClaim` returned `999999999999999999`. Use these source conversions and measured deltas, not 1:1 receipt/LP/DETF assumptions. This probe does not resolve the historical receipt-holder sum/supply discrepancy or complete fungible contribution ancestry.

**FAIL, presently executable mature withdrawal:** recovery's `closeBondMature(4,[0,0],recovery,18446744073709551615)` transaction `0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1` reverted with:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

**FAIL, receipt-to-DETF harvest:** DETF `redeemClaim` transaction `0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9` reverted identically. **UNPROVEN, alternate direct receipt-to-pair harvest:** receipt `redeem` transaction `0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d` also reverted identically. Both routes retain the custodied assets; no output or donation is claimed.

The source harvest sequence is therefore: take NFT custody; claim old DETF rewards; after maturity either close to the pair token or sell into protocol-NFT backing and receive the rebasing receipt; redeem receipt through the source-specific route; retain outputs for fixed-destination donation. Only custody, rewards, and sale-to-receipt are demonstrated executable here. No disabled vault was re-enabled or patched.

## 5. Required behavior verdicts and limits

| Required behavior | Verdict | Evidence or blocker |
| --- | --- | --- |
| Chain/header/code/loupe identity | PASS for observed identities | Fresh fork rechecks; full source closure separately UNPROVEN |
| Complete verified source identity | UNPROVEN | One facet HTTP 404; no claim of full dependency authentication |
| Historical local custody execution | PASS for demonstrated source operations | Login-shell Alchemy retry completed at the requested block/hash; prior RPC failures remain archived |
| Original contribution/NewLock evidence | PASS | All 16 receipts matched |
| Native 18-decimal units | PASS | Actual token reads |
| Mature and locked NFT custody | PASS | Mined transfer receipts and post-transfer reads |
| Reward claim after custody | PASS | Positive measured old-DETF delta; unchanged LP basis |
| NFT remaining units/consumed identity | PASS | Live reads, sale clears position, repeat sale reverts |
| Nonexistent/zero-principal positions | PASS for rejection tested | ID 999999 absent; standing ID 1 zero original shares and restricted; no fabricated empty user position |
| Liquid/receipt custody and conversions | PASS | Actual balances/shares and mined transfers |
| Mature withdrawal / receipt-to-DETF | FAIL | `VaultDisabled` blocks required proceeds |
| Direct receipt-to-pair route | UNPROVEN | Same deployed disabled-vault blocker |
| Stale identity | PASS | Same runtime-hash guard rejects substituted expected identity before custody |
| Wrong owner transfer/reward redirection | PASS | Reverted transactions; measured state unchanged |
| Approved token operator reward redirection | PASS | Approval succeeds; claim still reverts; state unchanged |
| Wrong-owner mature-close redirection | UNPROVEN | Disabled-vault rejection masks ownership behavior; not an authorization PASS |
| Failed safe-transfer rollback | PASS | Nonreceiver destination reverts after attempted custody; owner/position/approval/balances unchanged |
| Failed harvest rollback | PASS | Before/after position, balances, receipt shares and supply unchanged |
| Case isolation / cleanup | PASS | Snapshot restore, process exit, closed endpoint, removed caches |
| Atomic Migration custody plus bond/donation | UNPROVEN | No Migration contract deployed in this lane |
| Fungible attribution/nonduplication | UNPROVEN | Ordinary source transfers move token balances/shares, not a proven immutable Migration credit ledger; historical ancestry remains incomplete |

Deployed core `closeBondMature` source does not show a holder check in its public body before the DETF-only child retirement. The wrong-owner probe reaches `VaultDisabled`; consequently safe wrong-owner withdrawal cannot be asserted. This is a source observation and an unresolved authorization concern, not a demonstrated theft.

Fungible LP surrender and every other accepted source category remain required by the parent task. This earlier-CP report does not close them by omission. No owner signature/root, postactivation source admission, original-payer-only substitution, or redefinition of LP shares was introduced.

## 6. Validation, cleanup, and DoneClaim

Final executable syntax build: exit 0, `Bundled 64 modules`, archived in `syntax-check.log`. Final language-server diagnostics: **none**. No Forge build/test or contract compilation was needed or run. The final executable, including its public package import, was exercised by the completed pinned Alchemy retry.

Each fork case restores its snapshot. Final fresh cleanup recorded `snapshotReverted=true`, Anvil exit `[0,null]`, `endpointClosed=true`, and `runRootRemoved=true`. `cleanup.log` independently confirms all owned Anvil PIDs `34966,35928,37909,38420,39477` are gone and ports `55585,55649,56079,56183,56303` are closed. All seven per-invocation roots and the bootstrap root `earlier-cp.oHHpEz` were removed. Only owned runtime resources were removed.

The pinned retry independently recorded the same four successful cleanup fields. `cleanup-alchemy-retry.log` confirms PID `43955` gone, port `56817` closed, runtime root `earlier-cp.KhLfPU` removed, and bootstrap/cache root `earlier-cp-retry.SUenv8` removed. The key and credential-bearing RPC URL were never printed or dumped.

### DoneClaim

- **status:** complete-with-concrete-blockers; not source-route-ready.
- **changed_files:** only `scripts/recovery/dtf-migration/phase01/earlier-cp/probe.mjs` and this owned evidence directory. Its files are `report.md`, `probe.json`, `probe.source.json`, `probe.summary.json`, `probe-attempt01.json`, `probe-attempt01.source.json`, `probe-fresh1.json`, `probe-fresh1.source.json`, `probe-fresh2.json`, `probe-fresh2.source.json`, `probe-fresh3.json`, `probe-fresh3.source.json`, `probe-fresh3.summary.json`, `probe-public429.json`, `probe-public429.summary.json`, `probe-alchemy429.json`, `probe-alchemy429.summary.json`, `probe-alchemy-retry.json`, `probe-alchemy-retry.source.json`, `probe-alchemy-retry.summary.json`, `syntax-check.log`, `cleanup.log`, and `cleanup-alchemy-retry.log`. This follow-up changed only the report and added the four Alchemy retry artifacts.
- **exact_tests_and_outcomes:** original required Alchemy invocation above, exit 2/harness HTTP 429; login-shell pinned Alchemy retry above, completed with exit 2, 18 PASS, 2 FAIL, 4 UNPROVEN; separately labeled fresh invocation above, exit 2 with the same verdict totals; final Bun syntax build exit 0; language-server diagnostics clean. Earlier harness defects and RPC failures remain in the named prior results and are not product proof.
- **evidence_paths:** `probe-alchemy-retry.json` is the authoritative pinned custody/trace/rollback journal; `.source.json` is its source/code/ABI/binding archive; `.summary.json` is its bounded numerical and transaction index. `probe-fresh3.*` preserve the fresh replay; other `probe*.json` preserve earlier attempts.
- **cleanup_receipts:** each result's `cleanup` and `attempts`; independent `cleanup.log` and `cleanup-alchemy-retry.log`; no owned process, listening port, or temporary cache remains.
- **risks:** missing verified facet; disabled withdrawal/redemption; masked mature-close authorization; EOA fixture does not prove Migration atomicity, fixed donation destination, credit attribution, or new-bond creation. Historical RPC access is now demonstrated. Original incident inputs and all product contracts remain unchanged. No public transaction, deployment, commit, push, or delegation occurred.
