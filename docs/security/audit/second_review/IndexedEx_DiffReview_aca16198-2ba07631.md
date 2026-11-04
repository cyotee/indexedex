# IndexedEx — Security Diff Review `aca16198` → `2ba07631`

**Prepared by:** zauth research (APEX) · **Client:** IndexedEx / downto.finance · **Engagement:** ZA-2026-1020-9B9S · **Date:** 2026-10-21
**Scope:** `cyotee/indexedex` `aca16198` → `2ba07631` (89 commits; 26,251 product sLOC across 616 files, including unchanged callers/callees of changed code) and Crane `d87c74b7` → `90203dbc`.
**Confidential:** private disclosure to the code owner. Please do not publish until fixes are deployed.
**Attachments:** `indexedex-2ba07631-pocs.tgz` (Foundry PoCs; see §5 to run them).

## Summary

**45 findings: 7 High, 13 Medium, 21 Low, 4 Informational.** Each finding is one root cause, with an executed Foundry PoC.

- **Live on Robinhood mainnet (4663):** APEX-2026-010 (Medium) and APEX-2026-054 (Low), plus four smaller deployed-code items (036, 037, 038, 039). See §1. APEX-2026-010 has a one-transaction operational fix.
- **Everything else is latent.** None of the families that are new in this range (FullSpread, Wings, new SE buffer hooks, Balancer SE pools/routers, staking SEs) is deployed on 4663. All 7 Highs are in that code.
- **Prior findings:** APEX-2026-001, 008 and 009 are fixed. 003 and the Balancer router issues are not. 005 and 007 are fixed in source but not in the deployed bytecode. Details in §3.
- **Most dangerous combination:** APEX-2026-013 (zero-capital mint of a staking SE's whole reserve) chains into every hook or pool that uses that SE as a leg, through its rate provider. This would be Critical if a staking package ships wired as it is now. Chains are listed in §4.

**How we worked:**
- Every changed function (3,092) was reviewed and classified.
- Hypotheses went through three independent refutation passes (reachability, economics, design intent).
- Each finding has an executed Foundry PoC, re-run by a separate reviewer under anti-cheat rules: unprivileged attacker, capital counted, flash principal repaid, no state cheatcodes mid-attack, profit measured at a fair price, with a control run.
- We ran stateful invariant fuzzing per family (deep campaigns of 1,024 runs × depth 100).
- We ran fork tests against deployed bytecode on 4663. All on-chain access was read-only; nothing was broadcast.
- Finally, every High and Medium finding was re-judged against your PRDs, decision records and production deploy parameters. Severities reflect that pass: 4 findings turned out to be documented trade-offs and are kept as notes. Each write-up has a **Design/config note** when this pass changed its severity or interpretation.

---

## 1. Live on mainnet

### APEX-2026-010 (Medium): retired V4 SE vaults are still enabled, and RICH flows feed them

Six of the seven old V4 SE diamonds (APEX-001 stale-reserve credit) are still enabled. `disabledVaults()` returns only `0x999DaE02`, and `disabledPackages()` is empty.

The funded RICH CP hooks (`0x1ca1771d`, `0x25Ef9b30`, `0x46D94960`) hold their WETH leg as shares of `0x201d31a5`. Three permissionless flows put user WETH into that vault's free sleeve: CP-DETF bond, CP-DETF mint, and hook-pool buys. Anyone can then push the pool price, claim the WETH as stale-reserve credit (the unused credit is refunded to the caller), and restore the price.

On a fork of live 4663, an honest 0.5 WETH bond or mint was sniped for **+0.2996 ETH** (1 ETH push) and **+0.3960 ETH** (0.52 ETH push), with `sqrtP == sqrtP0` asserted. About 0.0005 ETH is exposed today. Every new bond, mint or buy is exposed in the same way.

**Fix: owner actions only. Simulated on a fork, nothing broadcast.**
1. From the registry owner (`0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`), call `setPackageDisabled(0x72b0243E3806eab5E30412cc93682f98f0d20eaE, true)`. This covers `0x201d31a5`, `0xb7D4Bb37`, `0x3E33871A`, `0xabC9C5B5` and `0x17B5f104`.
2. Call `setVaultAddressDisabled(0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531, true)`. It belongs to a different package (`0x0172902b`).
3. Keep `0x999DaE02` disabled. Re-enabling it opens about 0.11 WETH immediately (APEX-2026-037).

Effects verified on the fork:
- The snipe is closed. A bond that lands before the disable transaction is frozen, not stolen.
- Every RICH mint, bond, and hook-pool buy and sell reverts with `VaultDisabled`. The small WETH backing stays frozen until you re-enable.
- `claimRewards`, `sellPositionToDetfNft`, transfers and views keep working.
- Disabling only the DETFs is **not** enough, because the hooks do not check the kill switch.
- There is no owner setter to re-point a hook's `standardExchange`.
- Do not re-enable while a free sleeve exists, because that re-arms the snipe.

### APEX-2026-054 (Low): RICH exits revert today

DETF burn to WETH, `closeBondMature`, `redeemClaim` and hook `withdraw` revert with `TransferFromFailed()`. The deployed hooks call `SE.exchangeIn(seShares, …, pretransferred=false)` but never approved the SE: on chain, `allowance(0x25Ef9b30…, 0x201d…) = 0`. Matured bond id 3 on `0xc2FBe67c` cannot be closed. HEAD source already fixes this (`forceApprove` before unwrap). The deployed stack needs a migration.

### Other deployed-code items (Low/Info)

| ID | Sev | Note |
|---|---|---|
| 036 | Info | All 12 deployed CP hooks still run the APEX-005 inverted credit. Any stray pair token on a hook is claimable. Fixed in source. |
| 037 | Low | Re-enabling `0x999DaE02` opens about 0.11 WETH because the frozen WETH leg has drifted. |
| 038 | Low | A flash stake on sDETF permanently ratchets fee-to/creator reward weights. Griefing only. |
| 039 | Low | Custody SE `0x2E9C1F70` runs the baseline APEX-003 refund-to-caller code. Exposure today is 0. |

**Deployed bytecode lags source.** No contract on 4663 has a facet built from `2ba07631`. Deployed instances still carry APEX-001, 003, 005 and the 007/008 dust-refund class. We recommend an inventory of every enabled vault or package whose source no longer exists at HEAD, with each one disabled or migrated.

---

## 2. Findings

Final severities. "Live" means deployed on 4663. Full write-ups follow in the order of this table.

| ID | Title | Severity | Live |
|---|---|---|---|
| [APEX-2026-011](#apex-2026-011) | Any caller can force V4 FullSpread vaults into blocked mode, which prices single-sided entry and zap exit inconsistently, so a loop with no price move over-mints shares | High | No |
| [APEX-2026-012](#apex-2026-012) | UpperLowerWings prices deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves | High | No |
| [APEX-2026-013](#apex-2026-013) | Staking SEs bundle the generic Crane ERC4626Facet, so `deposit(balance)` mints shares for free and drains the reserve | High | No |
| [APEX-2026-017](#apex-2026-017) | Buffer pool hook calls the caller-supplied router mid-pre-seat; nested `Vault.swap` sells are overpaid | High | No |
| [APEX-2026-018](#apex-2026-018) | Buffer pool `computeBalance` returns a math-domain balance; every dust single-token exit pays out about `h` shares | High | No |
| [APEX-2026-019](#apex-2026-019) | SE router exact-out `WithPermit` pulls `limit` and never refunds; the pass-through branch lets anyone spend the stranded residue | High | No |
| [APEX-2026-031](#apex-2026-031) | Balancer V3 buffer pool prices shares-only/unbalanced joins against its virtual-TTA book, so joiners lose about half their deposit | High | No |
| [APEX-2026-010](#apex-2026-010) | Retired V4 SE vaults still enabled on mainnet; RICH CP-DETF bonds and mints feed honest WETH into an exposed free sleeve | Medium | **Yes** |
| [APEX-2026-014](#apex-2026-014) | A raw leg with a rate provider (allowed since D60) pays swap output without dividing by the rate, so round trips drain LPs | Medium | No |
| [APEX-2026-015](#apex-2026-015) | Curve quad buffer hook prices single-sided LP join/exit on unrated SE share counts while swaps use rated balances, so accrued SE yield can be siphoned | Medium | No |
| [APEX-2026-016](#apex-2026-016) | Weighted partial-book dust seed drains the funded legs (two code paths) | Medium | No |
| [APEX-2026-020](#apex-2026-020) | V4 DETF mint and bond are priced from the manipulable live reserve-hook book | Medium | Partly |
| [APEX-2026-021](#apex-2026-021) | Balancer V3 DETF bond/mint priced off live reserve-pool spot with no `IVault.isUnlocked()` gate | Medium | No |
| [APEX-2026-022](#apex-2026-022) | V3 FullSpread blocked mode can be entered from the pool's own swap callback, so zap-in plus zap-out becomes a fee-free x*y swap over a spot-repriced book | Medium | No |
| [APEX-2026-025](#apex-2026-025) | Wings permissionless rebalance measures its loss cap at the manipulated or self-moved spot | Medium | No |
| [APEX-2026-026](#apex-2026-026) | Wings liquidation quote hard-codes stepLimit=512, so dust ticks (or one trade at spacing 1) freeze deposit, redeem, getRate and liquidationValue | Medium | No |
| [APEX-2026-027](#apex-2026-027) | Lido/EtherFi staking SE `rebalance()` re-queues the full deficit on every call, ignoring pending withdrawal face | Medium | No |
| [APEX-2026-033](#apex-2026-033) | DETF primary redemption charges for a pro-rata slice of all protocol LP but pays only the tokenOut leg | Medium | No |
| [APEX-2026-034](#apex-2026-034) | First-deposit share inflation on the ReceiptBacked ERC-4626 SE (plus Morpho Blue SE variant) | Medium | No |
| [APEX-2026-035](#apex-2026-035) | Aave cross-version loop floors the tokenB net at 0 and has no tokenA<->tokenB route, so a liquidation overpays the first exiter or locks most of NAV | Medium | No |
| [APEX-2026-023](#apex-2026-023) | FullSpread maintenance mints idle excess at a displaced spot (JIT impermanent loss) | Low | No |
| [APEX-2026-024](#apex-2026-024) | Wings redeem dumps the entire opposing balance at a MIN/MAX price limit when a large exit closes the core | Low | No |
| [APEX-2026-028](#apex-2026-028) | DUAL CP buffer hook pays 0 on a single-asset exit to an identity leg but still burns the caller's LP | Low | No |
| [APEX-2026-029](#apex-2026-029) | SE rate provider's full-book valuation of a BPT-as-SE subject moves with pool composition; the Curve quad credits buffered inflow at the pumped rate | Low | No |
| [APEX-2026-030](#apex-2026-030) | Balancer quad protocol fee compares a rated "now" invariant with an unrated checkpoint, so every join or exit mints phantom fee LP | Low | No |
| [APEX-2026-032](#apex-2026-032) | Crane `PostDeployAccountHookFacet` delegatecalls any caller, letting an unprivileged deployer backdoor a registry-registered Balancer ConstProd pool | Low | No |
| [APEX-2026-037](#apex-2026-037) | Frozen WETH leg of the DTF-DETF weighted hook has drifted about 2.8x off market; re-enabling SE 0x999DaE02 without a rebalance opens a cross-leg drain | Low | **Yes** |
| [APEX-2026-038](#apex-2026-038) | Same-transaction sDETF stake/unstake permanently ratchets fee-to/creator standing weights | Low | **Yes** |
| [APEX-2026-039](#apex-2026-039) | Pretransfer credit is not tied to the depositor; exact-out refunds unattributed self-shares to the caller | Low | Partly |
| [APEX-2026-040](#apex-2026-040) | Wings bootstrap has no dead-share sink, and donated fee growth rounds later deposits down to 1 share | Low | No |
| [APEX-2026-041](#apex-2026-041) | FullSpread 64-step quote cap and single-step exact-out let dust ticks next to spot cap zap, redeem and swap sizes | Low | No |
| [APEX-2026-042](#apex-2026-042) | FullSpread DFPkg `initAccount` makes a raw bool-returning `approve` to Permit2, so no vault can be deployed for a no-return (USDT-style) token | Low | No |
| [APEX-2026-043](#apex-2026-043) | Orbital buffer hook radius R is fixed at 10x the first mint, so fill-to-R griefing blocks swaps and joins, and a dust first mint caps the instance permanently | Low | No |
| [APEX-2026-044](#apex-2026-044) | Dilutive usage fee is minted on top of depositor shares, so existing LPs pay it; round trips grief LPs ~95x the griefer's cost; operator can set a 100% fee instantly | Low | No |
| [APEX-2026-045](#apex-2026-045) | Lido/EtherFi/RocketPool staking SEs never check the registry kill switch, so inbound routes stay open on a disabled vault or package | Low | No |
| [APEX-2026-046](#apex-2026-046) | Balancer V3 SE router composite routes revert on settle misaccounting | Low | No |
| [APEX-2026-047](#apex-2026-047) | Aave V3 Stata SE: 1-wei underlying donation blocks every underlying entry; booked aToken counted as backing but never paid out | Low | No |
| [APEX-2026-048](#apex-2026-048) | Aerodrome SE fee compounding zaps sub-quantum dust with minOut 0, freezing every LP-moving route | Low | No |
| [APEX-2026-049](#apex-2026-049) | Camelot V2 SE exact-out LP-to-share deposit reverts on a strict `!=` share check | Low | No |
| [APEX-2026-050](#apex-2026-050) | V4 truncated TWAP credits the whole idle gap with the poked tick; permissionless update resets writeAge | Low | No |
| [APEX-2026-054](#apex-2026-054) | Deployed CP buffer hooks never approve their SE, so DETF burn, `closeBondMature`, `redeemClaim` and hook `withdraw` revert | Low | **Yes** |
| [APEX-2026-036](#apex-2026-036) | Deployed CP buffer hooks still run the APEX-005 inverted pretransfer credit with no caller gate | Info | **Yes** |
| [APEX-2026-051](#apex-2026-051) | AnalyticComposition._certify 50 bps impact check is a no-op (memory aliasing) | Info | No |
| [APEX-2026-052](#apex-2026-052) | AaveCrossVersionLoop never initializes EIP712Repo, so permit fails with standard signers | Info | No |
| [APEX-2026-053](#apex-2026-053) | MultiStepOwnable `acceptOwnershipTransfer` skips the confirm step and buffer period | Info | No |

---

## 3. Prior-finding remediation

| Prior finding | Status at `2ba07631` | Evidence |
|---|---|---|
| APEX-2026-001 (V4 SE stale-R credit) | Fixed in source (code removed in `b8dbdf41`) | The replacement families use `LocalCreditLib.available(balance, booked)`. |
| APEX-2026-001-M (V3 SE variant) | Fixed in source (removed in `1ed6280b`) | V3 FS `_deployedFaceOf` is dead code and could bring the bug back. |
| APEX-2026-001-M2 (deployed instances) | **Not fixed**: 1 of 7 kill-switched | Executed on the live fork. See APEX-2026-010. |
| APEX-2026-003 (refund of resting shares to caller) | **Not fixed** (partly mitigated: exact-in refund removed, EOA gate added) | A contract attacker takes 100% of resting value at HEAD. See APEX-2026-039. |
| APEX-2026-004 / 004B | Partially fixed | 004B no longer works as an exploit (executed). The exact-out residual is the 039 class. |
| APEX-2026-005 (inverted U) | Fixed in source; **not in deployed CP hooks** | See APEX-2026-036. |
| APEX-2026-006 | Stays withdrawn | The guard holds (executed). |
| APEX-2026-007 | Fixed in source; deployed weighted hook still has the old code (balances 0) | Safety tests pass. |
| APEX-2026-008 | Fixed | No longer works as an exploit at HEAD (executed). |
| APEX-2026-009 | Fixed (sweep removed) | The EOA attacker reverts `EOAPretransferNotAllowed`. The contract residual is the 039 class. |
| DEAD-PRETRANSFER | Partially fixed | RebasingDETFToken routes still revert. `DETFSafeTransferLib` is unchanged. |
| Balancer SE router R1 (exact-out permit over-pull) | **Not fixed** | Executed. See APEX-2026-019. |
| Balancer SE router R2 (batch permit double pull) | **Not fixed** (static) | `BatchRouterExactInTarget.sol:127-128` / `:219-220`. |

Note: R1 and R2 were found in the previous review but were not in the September disclosure document.

---

## 4. Chains and systemic themes

**Executed chains:**
- **013 → 029-class rate collapse → every hook using the SE.** A free mint inflates SE supply, so the rate provider (`reserve/supply`) drops to about 0. A hook then values that leg at about 0, and a 1 WETH swap takes about 100% of the hook's other reserve. The attacker then redeems the free shares for the SE reserve. Result: **about 178 WETH vs 80 WETH for the single bug.** Losses scale with the number of integrations.
- **029 × 018.** One push per pool moves the BPT-as-SE rate and arms the `computeBalance` overpay. One Curve-quad swap triggers both, across 4 pools in one flash-loaned transaction: **+4,981 TTA**, with outside LPs losing about 5,930. Fixing either bug breaks the chain.
- **020/021 + bond valuation.** DETF system composite: +3,089. About 1,256 is realised atomically; the rest after the bond lock.
- **010.** This is itself a chain: permissionless deposit → APEX-001 credit → refund to caller. 054 compounds it, because depositors' normal exits are broken.
- **Did not compose:** reentrancy + `computeBalance` + router residue, because they drain the same state and each breaks the other's precondition.

**Themes and what to change:**
1. **Pricing from in-session or blocked-mode state** (011, 012, 021, 022, 023, 024, 025, 050). Loss and impact caps are measured against quotes taken in the same manipulated state. For 011, keep blocked mode but align blocked zap-out and dual exit to your F2 spec (`_singleExit` over the same book F1 uses).
2. **Rated vs face units** (014, 015, 018, 029, 030, 031). Use one unit domain per pool and convert at one boundary. Add regression tests at `rate != 1`.
3. **Pretransfer credit not tied to the depositor** (010, 013, 036, 039, 019). Credit only the balance change within the call, revert on excess instead of refunding, reject `receiver/owner == this`, and make routers pull exactly what they spend.
4. **Spot-priced DETF entry** (020, 021, 033, 038). Cap issuance at a reference price, evaluate the mint gate over the full book, add `minPrincipalOut` to `bond()`, and revert entry while the reserve venue is unlocked.
5. **Bootstrap states** (016, 031, 034, 040, 043, and the 020 first-bond variant). Seed in the deploy transaction or keep owner-only liquidity until a minimum seed lands, and add dead shares or virtual offsets.
6. **Deployed bytecode lags source** (010, 036–039, 045). Treat retiring source as a deployment action, compare deployed bytecode hashes with the HEAD build, and make every vault family check the kill switch.

---

## 5. Coverage and limits

- **Reviewed:**
  - all 616 files and 89 commits;
  - all 3,092 changed functions, each classified;
  - prior findings re-checked, by execution where possible;
  - a 60-contract census of 4663 at block 94,077,713.
- **Fuzzing:**
  - Medium campaigns pass for every family once confirmed findings are quarantined.
  - Deep campaigns found no new issues. Every break was either a known finding or replayed and shown to be a harness artifact.
- **Limits:**
  - Latent findings were tested on the project's fixtures and, where it mattered, production parameters. Real figures will vary with fee, depth and sleeve.
  - Deployed code was matched to source by package history and loupe selectors, not by bytecode hashes.
  - Not executed: the DTF/PONS CP-hook stacks, Balancer router R2, and the DEAD-PRETRANSFER remnants.
  - No symbolic execution was used.
- **Out of scope:** off-chain components, the correctness of external protocols, and owner trust beyond noting centralization risks.

**Reproducing PoCs.** All PoCs referenced as `test/apex_audit/...` are in the accompanying bundle `indexedex-2ba07631-pocs.tgz` (sha256 `d1afe41dbb30960bad81fe8e3cef29dab2d567108c40369a259d3cc62378ffd4`). Extract it at the root of a `2ba07631` checkout. Every other path in this report (`contracts/`, `lib/crane/`, `scripts/`, `docs/`) refers to your repository at `2ba07631`, except where a line explicitly says `aca16198`.
1. Add this profile to `foundry.toml` (the full test suite does not fit in one solc run):
```toml
[profile.audit]
sparse_mode = true
src = "contracts"
out = "out"            # ArtifactCreationCode reads <root>/out/
libs = ["node_modules", "lib"]
test = "test/apex_audit"
script = "script_none"
ffi = true
fs_permissions = [{ access = "read-write", path = "./"}]
solc = "0.8.35"
optimizer = true
optimizer_runs = 1
via_ir = false
gas_limit = 30000000000
```
2. Run: `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/<group>/<File>.t.sol -vvv`

Live-fork tests fork `https://rpc.mainnet.chain.robinhood.com`.

---

## 6. Finding write-ups

<a id="apex-2026-011"></a>

### APEX-2026-011: Any caller can force V4 FullSpread vaults into blocked mode, which prices single-sided entry and zap exit inconsistently, so a loop with no price move over-mints shares

**Severity:** High · **Status:** Latent: not deployed · **Family:** V4 FullSpread (hookless, PonsFamilyV2Hook)

**Summary.** A FullSpread V4 vault switches to "blocked" mode whenever `PoolManager.isUnlocked()` is true. Any contract can therefore force every FullSpread vault on a manager into blocked mode by calling it from inside its own `unlock`. In blocked mode, the single-sided deposit and the exact-out mint price shares by constant-product growth over a book whose deployed liquidity is valued at live slot0. The single-sided zap-out pays at live slot0 from the free sleeve, without removing liquidity. Because the two legs are priced inconsistently, a deposit/zap-out loop over-mints shares even when slot0 never moves. At production Pons depth this took +163.67 (6.8% of NAV 2400) over 50 rounds.

**Affected code.** Hookless paths are under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`. The Pons paths under `.../fullSpread/ponsFamilyV2Hook/` are byte-identical at the same lines.
- `...HooklessStandardExchangeVaultCommon.sol:304-306` (`canOpenPoolManagerUnlock()`), `:985-1009` (snapshot at live `_slot0()`)
- `...VaultInBase.sol:304-312` (blocked single-sided deposit), preview `:278-281`
- `StandardExchangeConstantProduct.sol:58-64`, `:78-96` (share math and its inverse)
- `...VaultOutBase.sol:59-71` (blocked exact-out mint)
- `...VaultInBase.sol:169-183` (blocked zap-out), `:141-156` (`_quoteZapOutAmount`) → `...VaultCommon.sol:813-823`
- `...VaultOutMultiTarget.sol:52-59, 76-92` (blocked dual exit)

**Root cause.** `canOpenPoolManagerUnlock()` returns `!TransientStateLibrary.isUnlocked(_poolManager())`, and `PoolManager.unlock` is permissionless. For a token0 deposit `a` over the book `B = free + deployed(slot0) + earned`, the blocked deposit mints:
```
shares = S * ( sqrt((B0 + a) * B1) / sqrt(B0 * B1) - 1 )
```
This prices token0 at the book composition `B1/B0`. The blocked zap-out instead pays linearly at pool spot:
```solidity
amountOut = _quoteZapOutAmount(tokenOut, sharesBurned, totalShares);   // live-slot0 simulation
uint256 freeOut = _localBalance(tokenOut);
if (amountOut == 0 || freeOut < amountOut) revert ...InsufficientLocalReserve(...);
ERC20Repo._burn(address(this), sharesBurned);
_transferCurrency(tokenOut, recipient, amountOut);
```
A zap-out of `x` token0 depletes only `B0`. Re-depositing `x` is then priced by CP growth over the depleted `B0`. Each round gains about `+S*(x/B)^2/8` shares: the book returns to the same balances and only supply grows. Moving slot0 skews `B1/B0` further (the spot-move variants).

**Attack.**
1. Buy about 16.7% of supply fairly through an idle dual deposit (counted as cost).
2. In a later block, open one `PM.unlock` and make no swaps (slot0 unchanged). The vault is now in blocked mode.
3. Loop: a blocked `exchangeIn(vault -> token0)` sized at 0.8 x free token0, then a blocked `exchangeIn(token0 -> vault)` with the token0 just received.
4. Split the loop across block-sized transactions (10 rounds each).
5. In a later block, exit all shares with an idle pro-rata dual exit.

Spot-move variants: inside the unlock, swap to move sqrtP, then make a blocked single-sided deposit, exact-out mint or zap-out. Swap back to the exact original sqrtP and settle.

**Proof of concept.** `test/apex_audit/adj-fullspread-blocked/PonsBseAtP0ProdDepth.t.sol` (production family and depth). Fixture-depth and spot-move variants: `test/apex_audit/fz-fs-bse-at-p0/FSBseAtP0.t.sol`, `test/apex_audit/fs-blocked-entry-spot-mint/FSBlockedEntrySpotMint.t.sol`, `test/apex_audit/fs-blocked-exit-sleeve/FsBlockedExitSleeve.t.sol`.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/adj-fullspread-blocked/PonsBseAtP0ProdDepth.t.sol -vvv`
```
[PASS] test_P_multiTx_5x10()            (PonsBseProdDepthTest, pool L 37000e18, vault ~2.16%)
  tx gas (10 rounds) 4121583   (x5)
  PONS 5x10 ATTACKER NET PROFIT @P0
  163671064069436834120
  PONS 5x10 HONEST LP DELTA @P0
  -163670900398372764684
[PASS] test_A_selfLoop_control_0rounds()  ATTACKER NET PROFIT @P0 -2
```

**Impact.** Run on the production Pons family at production depth (vault about 2.16% of in-range L, 20% sleeve), with no price move and 4.12M-gas transactions. The attacker gains +163.67 (6.8% of NAV 2400) over 50 rounds. Honest holders lose the same amount; in production the honest holder is the weighted hook, which is the DETF reserve. No flash loan is needed, and the seed is returned on exit. At fixture deep-pool depth, 100 rounds gave +432.89 (1803 bps). The spot-move variants profit only when the vault holds more than roughly 2-4% of in-range L (+174.80, 873 bps, at about 45%). Below that they are griefing that costs the attacker money.

**Design/config note.** Blocked mode is intended and is used in production. See PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` §3; `scripts/foundry/anvil_robinhood_main/Phase_07_Stage_01_FeeAccrualLiquiditySe.sol:20-27` binds a Pons FullSpread SE that the weighted buffer hook holds. The fix must therefore change pricing, not remove the mode. The code deviates from the developer's spec: `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` §2.3 (l.81-90) specifies blocked redemption F2 = CP `_singleExit` over the book, but the implementation uses the idle F6 pool-simulated quote. The High rating rests on the no-price-move variant. At production depth the spot-move variants alone are Low.

**Fix.** Make blocked zap-out follow spec F2: use `_singleExit` over the same `Inventory._totals(book)` that the blocked deposit uses, not `_quoteZapOutAmount`. Do the same for blocked dual-exit pricing. This closes the no-price-move loop at any depth. Add a regression test asserting that a zero-swap blocked loop cannot increase any holder's realized value. Optional, with owner sign-off (PRD l.351 rejects an independent-reference oracle by default): on blocked routes, value `deployed` at a reference price or bound the slot0 deviation.

**Related.** APEX-2026-022, APEX-2026-023

---

<a id="apex-2026-012"></a>

### APEX-2026-012: UpperLowerWings prices deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves

**Severity:** High · **Status:** Latent: not deployed · **Family:** V4 UpperLowerWings

**Summary.** `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That quote reads live `slot0`, `getLiquidity` and the tick bitmap, then simulates selling the vault's opposing inventory into that depth. Depth that exists for only one transaction, or that is left unsettled inside another caller's `unlock`, inflates the quote, and the vault still accepts deposits and redeems in that state. An unprivileged contract deposits at the honest value, adds a large full-range position, redeems at the inflated value and removes the position. In the PoC this nets 70,634,405,953 raw token0 (7.1% of a 1e12 vault) per transaction with zero capital. At the production-scripted sleeve it takes 7.5% of TVL using flash-loanable depth.

**Affected code.** Base path `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`:
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:41-48` (`begin`: no `isUnlocked()` check)
- `...Money.sol:94-105` (l.96, 102: `_harvest`/`_place` return when unlocked)
- `...Money.sol:120-140` (l.132-133, `_deposit`), `:147-181` (l.160-161, `_redeem`), `:167-170` (while unlocked, only `_localTarget() >= required` is checked), `:174-177` (`HolderValueLoss` re-quotes the same state)
- `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:119-135`, `146`, `151`, `253-284` (l.271, 280), `298-334`, `357-389`
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:18-27` (`issue = S*credit/V`, `entitlement = shares*V/S`)
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27-31`, `...QueryTarget.sol:28-30` (same quote exposed to integrators)

**Root cause.**
```solidity
(result_.sqrtPriceX96, result_.tick, ...) = request_.manager.getSlot0(context.id);   // :146
result_.liquidity = request_.manager.getLiquidity(context.id);                       // :151
_removeOwned(request_, context, result_);   // subtracts only this vault's own L (:280) // :152
result_.value = request_.target0 ? total0_ : total1_;                                 // :128
_sell(context, result_, request_.stepLimit);   // walks live bitmap / tick liquidity  // :132
result_.value += result_.proceeds;                                                   // :133
```
V4 liquidity views update as soon as `modifyLiquidity` runs, before the deltas settle. Let S be supply and V0 the honest value. A deposit D mints `m = S*D/V0`. After depth is added the vault is valued at V1, and redeeming pays `D*V1/(V0+D)`, so `profit = D*(V1 - V0 - D)/(V0 + D)`. The uplift is roughly bounded by the vault's liquidation haircut. `HolderValueLoss` compares two quotes taken in the same inflated state, so it cannot detect the inflation.

**Attack.** (in-unlock JIT variant)
1. The attacker contract calls `PoolManager.unlock("")`.
2. `take(currency0, D)` as flash principal.
3. `exchangeIn(token0, D, wings0, ...)` deposits at the honest V0. `_harvest`/`_place` are skipped.
4. `modifyLiquidity(key, -887220, 887220, +1e22, salt)`, left unsettled.
5. `exchangeIn(wings0, m, token0, ...)` redeems at V1 ≈ mark, paid from the local sleeve.
6. `modifyLiquidity(..., -1e22, salt)`.
7. Settle (repay D) and keep `paid - D`.

Settled variant (works at a 0% sleeve): deposit normally and add settled liquidity in the attacker's own unlock. Redeem while the manager is locked, which pays via `_fund` with no sleeve cap. Then remove the liquidity.

**Proof of concept.** `test/apex_audit/wings-spot-nav/WingsSpotNav.t.sol`. Production-sleeve and settled variants: `test/apex_audit/wings-spot-nav-prod0/WingsSpotNav.t.sol`.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/wings-spot-nav/WingsSpotNav.t.sol -vvv`
```
[PASS] test_jit_control_noJit()  attacker net token0 profit -1
[PASS] test_jit_equalExternal()  V at deposit 998045067650 V at redeem 2139175794077; minted 1001958761596 paid 1070634405955; attacker net token0 profit 70634405953; honest entitlement before 998045067650 after 927410661695; vault mark value before 1140731336828 after 1070096930873
SETTLED-JIT deposit D 1000000000000 jit L 10000000000000
  JIT capital locked token0/token1 14137733004082 7073269807199
  minted 1002128459610 paid 1074704386259
  attacker net profit valued @p0 (token0 raw)
74704386253
  honest entitlement before 997876061108 after 923171674847
```

**Impact.** In-unlock JIT variant (zero capital, zero fees): 70,634,405,953 raw token0 (7.1% of 1e12 TVL) at external L 1e12, and 9,777,515,150 (1.0%) at about 25x the vault's L. Per-transaction profit is capped by the pre-attack local target sleeve (`Money.sol:167-168`). In-unlock spot variant (swap, deposit, swap back to the exact original price, redeem; 0.3% swap fees paid): 53,661,742,003 at external L 1e12 and 33,284,087,429 at 1e11. Settled variant: 74,704,386,253 (7.5% of TVL) per transaction and 84,069,116,280 at 100x depth. It uses about 1.4e13 token0 + 7.1e12 token1 (roughly 27x TVL) of transient capital, which a flash loan can supply. The control returns -1. Incumbent holders lose what the attacker gains, and the attack repeats once the sleeve refills.

**Design/config note.** The owner's O1 ruling accepts that round trips can move value between holders, and the attack satisfies the tested SEC-08 bound. However, SEC-08 in PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:334` names temporary liquidity and JIT, and `ACCOUNTING_AND_RECOVERY.md:17` states that O1 "does not waive SEC-08". As scripted, a Wings vault resolves to a 0% sleeve. That blocks the in-unlock variant (`InsufficientLocalTarget`) but not the settled variant.

**Fix.** Revert in `Money.begin()` when `state.manager.isUnlocked()`, and guard `getRate()`, `liquidationValue()` and `preview`/`requiredInput` the same way. This only partly fixes the issue, because settled depth and flash-loaned spot moves still work. Also:
1. Price shares against a manipulation-resistant reference `V_ref` (a TWAP-bounded mark with a fixed haircut). For example, mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`.
2. Cap the depth used in `_sell`.
3. Make `HolderValueLoss` compare against `V_ref`.
4. Optionally, charge an exit fee of at least the current haircut.
5. Add a SEC-08 round-trip test for depth addition.

---

<a id="apex-2026-013"></a>

### APEX-2026-013: Staking SEs bundle the generic Crane ERC4626Facet, so `deposit(balance)` mints shares for free and drains the reserve

**Severity:** High · **Status:** Latent: not deployed · **Family:** Staking SE / Crane ERC4626

**Summary.** The EtherFi, Lido and RocketPool Standard Exchange packages cut the generic Crane `ERC4626Facet` into the diamond, so anyone can call `deposit`/`mint`/`withdraw`/`redeem`. `initAccount` sets `lastTotalAssets = 0`, and no SE path ever updates it. Crane credits `balanceOf(this) - lastTotalAssets` as the deposit and skips `transferFrom` when that amount equals `assets`. `deposit(W)` with `W = asset.balanceOf(vault)` therefore mints `W * (S + 10^3)` shares for nothing. In the PoCs a zero-capital EOA took 100 of 100 weETH / wstETH / rETH. When the SE is bound into a buffer hook, the same mint also drains the hook (about 178.1 WETH net).

**Affected code.**
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeDFPkg.sol:162-166` (`cuts[3]` adds the generic facet, all 16 IERC4626 selectors), `:219-220` (`_setLastTotalAssets(0)`)
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol:145-149, 202-203` (same)
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeDFPkg.sol:144-148, 200-201` (same)
- `lib/crane/contracts/tokens/ERC4626/ERC4626Service.sol:14-38` (`_secureReserveDeposit`)
- `lib/crane/contracts/tokens/ERC4626/ERC4626Target.sol:20-32` (`deposit`), `34-45` (`mint`), `72-98` (`redeem`)
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:458-465, 576-582` (V2-family variant, low)

**Root cause.**
```solidity
uint256 currentBalance = tokenIn.balanceOf(address(this));
actualIn = currentBalance - lastTotalAssets;          // lastTotalAssets == 0 on staking SEs
if (actualIn != amountTokenToDeposit) {                // skipped when assets == balance
    ... transferFrom(msg.sender, this, amountTokenToDeposit) ...
    actualIn = tokenIn.balanceOf(address(this)) - lastTotalAssets;
}
if (actualIn != amountTokenToDeposit) revert ERC4626TransferNotReceived(...);
ERC4626Repo._setLastTotalAssets(layoutStruct, currentBalance);
```
`shares = W * (S + 1000) / (lastTotalAssets + 1) = W * (S + 1000) / 1`. Every SE-path deposit raises `balanceOf(this)` while `lastTotalAssets` stays at 0, so the whole reserve looks like an unclaimed pre-transfer. The `decimalOffset = 3` defence does not help, because the denominator is 1.

**Attack.**
1. Read `W = asset.balanceOf(vault)`. An attack contract does this atomically.
2. Call `IERC4626(vault).deposit(W, attacker)`. No transfer happens, and the call mints `W * (S + 1000)` shares.
3. Exit via SE `exchangeIn(IERC20(vault), minted, asset, 0, attacker, false, deadline)` or `IERC4626(vault).redeem(minted, attacker, attacker)` and receive about `W`.
4. Composite: if the SE is the rated leg of a CP buffer hook, the free mint collapses `StandardExchangeRateProviderFacet._getRate`. Swap 1 WETH through the hook to take its raw reserve, then redeem the SE reserve.

**Proof of concept.** `test/apex_audit/crane-erc4626facet-mint/EtherFiCraneFreeMint.t.sol` (also `LidoCraneFreeMint.t.sol`, `RocketPoolCraneFreeMint.t.sol`; composite `test/apex_audit/chain-free-mint-amplify/ChainFreeMintAmplify.t.sol`). The fixtures deploy the production DFPkgs through `indexedexManager`.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/crane-erc4626facet-mint/EtherFiCraneFreeMint.t.sol -vvv`
```
[PASS] test_freeMint_drain_weETH() (gas: 971689)
  victim redeem value before (weETH) 99900099900099900099
  ERC4626 totalAssets (lastTotalAssets) 0
  vault weETH balance W 100000000000000000000
  attacker shares minted for 0 transfer 10010000000000000000100000000000000000000000
  attacker weETH out (profit, cost=0) 100000000000000000000
  victim redeem value after (weETH) 0
[PASS] test_freeMint_viaCraneRedeem()  crane redeem path: attacker weETH 100000000000000000000
```

**Impact.** With zero capital (gas only, under 1M gas), the attacker took 100e18 of 100e18 weETH / wstETH / rETH. The honest depositor's redeem value went from 99,900,099,900,099,900,099 to 0. In the composite with one CP buffer hook, the attacker netted 178.107 WETH at fair price, against 80 WETH for the free mint alone, and the hook's raw reserve went from 100e18 to 126 wei. The only precondition is a nonzero asset balance, and the window stays open permanently from the first SE-path deposit. Every SE shareholder loses, including any hook or DETF holding SE shares. At the production liquid defaults, about 80% (EtherFi/RocketPool) or 95% (Lido) of TVL can be drained.

**Design/config note.** The PRD says the SE is "**not** a generic ERC-4626 SE" (`contracts/protocols/staking/etherfi/ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md:31`). The owner already replaced the Crane facet with `ReceiptBackedERC4626Facet`, but only for the generic and Stata families (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` D45), so this is an incomplete remediation. No repo script deploys these packages. However, the project's mainnet fork ship gate (`test/foundry/fork/eth_main/vaults/staking/etherfi/EtherFiWeETHStandardExchange_Fork.t.sol:40,88`) wires in the generic facet. The issue becomes Critical if the packages are deployed as currently wired.

**Fix.** Remove the ERC-4626 mutators from the staking SE diamonds: drop `cuts[3]` in the three DFPkgs or cut a views-only facet, and do not pass the generic Crane facet as `pkgInit.erc4626Facet` for these packages. If IERC4626 compatibility is required, write a staking-aware facet that values shares from the SE book and always pulls `assets` via `transferFrom`. Defense in depth:
- In Crane `_secureReserveDeposit`, always pull and measure the delta instead of crediting a pre-existing balance.
- Checkpoint reserves around ERC-4626 entry/exit on the UniV2/Camelot SE.
- Make `_getRate` resistant to supply inflation.
- Add an invariant test that runs every SE family with the production facet set.

**Related.** APEX-2026-045

---

<a id="apex-2026-017"></a>

### APEX-2026-017: Buffer pool hook calls the caller-supplied router mid-pre-seat; nested `Vault.swap` sells are overpaid
**Severity:** High · **Status:** Latent: not deployed · **Family:** Balancer V3 buffer pool / hooks

**Summary.** During a shares→TTA swap, `StandardExchangeBufferHookTarget._preSeatShares` drains `drainAmount` shares from the pool, then calls `params.router.passPrepayAuth()`, and only afterwards applies the matching `hookSharesDelta -= hdSub`. `params.router` is whoever called `Vault.swap`, authenticated only by a 32-byte `prepaySessionActive()` probe. Balancer V3 swap hooks are reentrant and the hook has no lock, so an attacker contract re-enters `Vault.swap` on the same pool while `derivedY` is understated, and each nested sell is overpaid in TTA. A zero-capital attacker nets +391.66 DAI in one transaction.

**Affected code.**
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol:486-491` (`sendTo` + CUSTOM `removeLiquidity`), `496-497` (`_passPrepay` to `params.router`), `546-547` (`hookSharesDelta -= hdSub`, after the callback), `593-604` (`_isPrepayRouter` / `_passPrepay`), `354-397` (`_reconcileTTAToShares`, same ordering at 370)
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol:135-146` (`_derivedY`)
- `lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol:207-209`, `223-225` ("the swap hooks are reentrant")
- Same pattern, not executed: `CommonBufferMultiVaultStablePoolHookTarget.sol:373, 464`; `CommonBufferMultiVaultWeightedPoolHookTarget.sol:403, 508`; `MixedLegWeightedBufferPoolHookTarget.sol:403, 468`; `MultiPairStandardExchangeBufferHookTarget.sol:371, 436`; `MixedBufferMultiVaultStablePoolHookTarget.sol:397, 490`

**Root cause.** The router callback sits between the Vault mutation and the book update:

```solidity
vault.sendTo(shareTok, address(this), drainAmount);                 // 486
vault.removeLiquidity(... remAmts[sharesIdx] = drainAmount, CUSTOM); // 490  pool shares balance -= drainAmount
...
_passPrepay(seRouter, address(seVault));                             // 497  <-- attacker runs here
seVault.exchangeOut(...);                                            // 499
...
Repo._setHookSharesDelta(Repo._hookSharesDelta() - int256(hdSub));   // 547  compensating update
```

During the callback `derivedY = y0 − lift(drainAmount)` while `x = virtualTTA` is unchanged, so a nested shares→TTA sell priced by `WeightedMath.computeOutGivenExactIn(y', wShares, x, wTta, in·(1−fee))` with `y' < y0` returns too much TTA. `_isPrepayRouter` only checks `code.length > 0 && staticcall(prepaySessionActive()) ok && ret.length == 32`.

**Attack.**
1. Attacker contract (implements `prepaySessionActive()`, `passPrepayAuth(address)`, `restorePrepayAuth()`; 0 DAI, 0 shares) calls `Vault.unlock`, then `Vault.swap` shares→TTA (25% of `derivedY`) on deferred credit.
2. `_preSeatShares` drains shares and calls `attacker.passPrepayAuth()`.
3. In the callback the attacker re-enters with sells of 20%, then 15%, then 10%; each is priced on an understated `y`.
4. Before each callback returns, it borrows DAI via `vault.sendTo` and swaps DAI→USDC on Aerodrome so the enclosing `exchangeOut` does not revert `MaxAmountExceeded`.
5. It buys back exactly the 70% of shares sold (EXACT_OUT, 5 chunks).
6. It unwinds Aerodrome, repays the borrowed DAI, settles, and takes the remaining TTA delta with `sendTo`.

**Proof of concept.** `test/apex_audit/hook-midstate-reentrancy/HookMidstateReentrancy.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/hook-midstate-reentrancy/HookMidstateReentrancy.t.sol -vvv`
```
[PASS] test_exploit_nestedPreSeat_4levels() (gas: 18430075)
    hookSharesDelta  -203632107707590856818
    alice LP exit value before (DAI)  5662497915624477361922
    alice LP exit value after  (DAI)  5262350268864248746952
    attacker profit (DAI) 391659900281720464970
    LP loss @pre-attack rate (DAI) 372901085016635347696
[PASS] test_control_sequential_4() (gas: 17971816)
[PASS] test_info_nestedPreSeat_2levels() (gas: 13534692)
```

**Impact.** Fixture: 2000 SE shares, `virtualTTA` 3662.50 DAI, one LP, Aerodrome DAI/USDC 12,000/12,000, 5% static fee. Attacker net +391.66 DAI from zero capital, after the 55.06 DAI Aerodrome round trip; borrowed DAI is repaid inside the same unlock, no external flash loan. The BPT LP loses 372.90 DAI at the pre-attack share rate (about 6.6% of the pool), 400.15 at the post-attack rate. At 5% fee, 2 nesting levels net −12.54 DAI and the non-nested control −194.44, so the edge comes from the re-entry. Repeatable (not executed). BPT LPs lose pro rata.

**Design/config note.** The package registers `5e16` (5%), but its comment says the intended default is 0.05% (`StandardExchangeBufferPoolStandardVaultPkg.sol:395`). Re-run at 0.05%: 4 levels +617.01 DAI (LP loss 584.04), and even 2 levels are profitable (+125.27); the sequential control stays negative at every fee.

**Fix.** Only call `passPrepayAuth`/`restorePrepayAuth` when `params.router` equals an allow-listed IndexedEx router (immutable or registry check), not the 32-byte probe. Independently, commit the book update before any external call: apply `hookSharesDelta -= drainAmount` right after the CUSTOM `removeLiquidity` (line 491) and correct for the surplus donation afterwards; credit `virtualTTA` before `_passPrepay` in `_reconcileTTAToShares`. Defense in depth: a pool-scoped transient lock set in `onBeforeSwap` and checked in swap and liquidity hooks (also protects the shared `pendingPreSeat*` slots); apply to the five sibling hook targets; add a regression test where a router re-entering `Vault.swap` from `passPrepayAuth` reverts or gets no callback.

**Related.** APEX-2026-018 (shares the same `virtualTTA`/`hookSharesDelta` state; composite refuted)

---

<a id="apex-2026-018"></a>

### APEX-2026-018: Buffer pool `computeBalance` returns a math-domain balance; every dust single-token exit pays out about `h` shares
**Severity:** High · **Status:** Latent: not deployed · **Family:** Balancer V3 buffer pool

**Summary.** `StandardExchangeBufferPoolTarget.computeBalance` computes the shares-side balance over `_derivedY = live − lift(h)`, where `h` is `hookSharesDelta`. Balancer V3's `BasePoolMath.computeRemoveLiquiditySingleTokenExactIn` treats the result as a live balance and pays `amountOut = live − newBalance`, so with `h > 0` a dust `SINGLE_TOKEN_EXACT_IN` exit pays about `lift(h)` extra. `onAfterRemoveLiquidity` reduces `h` only by `bptIn / T`, so the next dust exit pays about `h` again. Any TTA→shares swap raises `h`, and the hook does not filter remove kinds, so any BPT holder can drain the LPs' shares side. The defect predates the diff.

**Affected code.**
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol:56-67` (`computeBalance`)
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol:135-157` (`_derivedY`, lift)
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol:58-71` (`shouldCallBeforeRemoveLiquidity: false`), `293-300` (`hSub = bptAmountIn * hPre / tPre`), `396` (`hookSharesDelta += donationRaw`)
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol:381` (`disableUnbalancedLiquidity: false`)
- `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:359-398`
- Same shape, not executed: `CommonBufferMultiVaultStablePoolTarget.sol:59-73`; `CommonBufferMultiVaultWeightedPoolTarget.sol:31-41`

**Root cause.**

```solidity
// StandardExchangeBufferPoolTarget.sol:56-67
uint256 currentBalance = isTta
    ? StandardExchangeBufferPoolRepo._virtualTTA()
    : _derivedY(balancesLiveScaled18);          // live - lift(h)
// BasePoolMath.sol:377-380
uint256 newBalance = pool.computeBalance(currentBalances, tokenOutIndex, invariantRatio);
uint256 amountOut = currentBalances[tokenOutIndex] - newBalance;          // live - math-domain
```

With `L = live`, `H = lift(h)`, `D = L − H`, `r = newSupply / T`: `amountOut = L − D·r^(1/w) = H + D·(1 − r^(1/w))`. The second term is the correct exit; the first, about `H`, is paid on every call. Live `L` falls by about `H` per exit while `h` is essentially unchanged.

**Attack.**
1. Attacker mints about 1 SE share and holds 100 TTA (both counted as cost).
2. `addLiquidityUnbalanced(0 TTA, ~1 share)` gives 0.8926 BPT.
3. Swap 100 TTA → shares; `hookSharesDelta` goes from 0 to 49.82e18 (skip if organic flow already set `h > 0`).
4. Call `removeLiquiditySingleTokenExactIn(pool, bpt/20, shares, 1, false, "")` 20 times; each pays about 47.37e18 shares versus about 0.0475 for a proportional exit.
5. Exit remaining BPT proportionally.

**Proof of concept.** `test/apex_audit/balancer-computebalance-domain/BufferComputeBalanceDomain.t.sol` (composite: `test/apex_audit/chain-rate-oracle/ChainRateOracle.t.sol`)
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/balancer-computebalance-domain/BufferComputeBalanceDomain.t.sol -vvv`
```
[PASS] test_control_noSwap() (gas: 1699974)
  control exit out (shares) for bpt/20 47537155058841124 of shares in 1000000000000000000
[PASS] test_dustSingleTokenExit_drainsLiftH() (gas: 16409268)
    hookSharesDelta 49821317108633576780
  exit 0 47376565524797617967
  exit 19 47344261788727294562
    hookSharesDelta 49809177874655453140
  attacker PROFIT at pre-attack rate (TTA units) 1725321915566261421532
  alice LOSS (TTA units) 1729696738350634038323
```

**Impact.** Capital about 101.8 TTA (100 TTA + about 1 share), no flash loan. Attacker +1,725.32e18 TTA at the pre-attack rate after 20 exits; honest LP 5,662.36e18 → 3,932.66e18 (−1,729.70e18, −30.5%). Extraction saturates at about 3,654e18 (n=80: +3,653.73e18, LP −3,662.50e18), about 65% of LP value from one 100 TTA swap. Profitable from the first exit; if `h > 0` already exists, only BPT is needed. Composite through the curve-quad hook over 4 BPT-as-SE legs (with APEX-2026-029): +6,072.41e18 TTA net in one flash tx; outside LPs lose 6,075.30e18. Pool LPs lose pro rata.

**Design/config note.** The original spec made the pool proportional-only and noted `computeBalance` is used only for single-token ops "which we disable"; `docs/superpowers/plans/2026-06-02-buffer-pool-refactor.md:11-31` flipped `disableUnbalancedLiquidity` to false without considering single-token removes, so this is unintended. The PoC ran at the `5e16` (5%) package literal; at the intended 0.05% (`StandardExchangeBufferPoolStandardVaultPkg.sol:395`) profit is +1,820.37 (LP loss about 32%).

**Fix.** Set `shouldCallBeforeRemoveLiquidity: true` and have `onBeforeRemoveLiquidity` reject every kind except PROPORTIONAL and CUSTOM (restrict CUSTOM to the hook itself); reject `SINGLE_TOKEN_EXACT_OUT` in `onBeforeAddLiquidity`. Hook flags are fixed at registration, so this needs new pools. If single-token kinds must be supported, return a live-domain balance (`computeBalanceOutGivenInvariant(D, …) + lift(h)`) and reduce `h` by the shares actually paid, testing for `taxableAmount` underflow. Defense in depth: fuzz that any exit's value is ≤ `bptIn / T` of pool value for `h` positive, negative and zero; review the CommonBufferMultiVault pools; fix APEX-2026-029 independently.

**Related.** APEX-2026-029, APEX-2026-017, APEX-2026-031

---

<a id="apex-2026-019"></a>

### APEX-2026-019: SE router exact-out `WithPermit` pulls `limit` and never refunds; the pass-through branch lets anyone spend the stranded residue
**Severity:** High · **Status:** Latent: not deployed · **Family:** Balancer V3 SE router

**Summary.** `swapSingleTokenExactOutWithPermit` pulls the user's full `limit` into the router through Permit2 but forwards only the computed `amountIn`; nothing refunds `limit - amountIn` and the router has no sweep or rescue function. Every exact-out permit user loses their slippage allowance even with no attacker. Separately, the vault pass-through exact-out branch has its limit check commented out, accepts an unvalidated caller-supplied `tokenInVault`, and in permit mode pays from the router's own balance, so anyone with a 1-wei permit can take the accumulated residue. This is prior finding R1 from baseline `aca16198`; the router code is unchanged at `2ba07631`.

**Affected code.**
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol:148-158` (entry, no refund), `167-170` (`requestedAmount: swapParams.limit` at 169), `201-215` (`_transferTokenIn` pays from router balance), `317-370` (pass-through branch; limit check commented out at 329-331)
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol:124-133` (`_takeTokenIn` sends only `amountIn`), `173` (`_returnEth`, ETH only)
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapFacet.sol:49` (selector registered)
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol:51-60` (no rescue or sweep facet)

**Root cause.** (a) Over-pull with no refund; `stranded = limit - amountIn`:

```solidity
// ExactOutSwapTarget.sol:148-158
_permitTransferIn(swapParams, permit, signature);   // pulls swapParams.limit into address(this)
_setHasPermitPulledTokenIn(true);
amountIn = _callExactOutHook(swapParams);           // forwards only amountIn
_setHasPermitPulledTokenIn(false);
return amountIn;                                    // limit - amountIn stays in the router
```

(b) Unbounded spend of the router's balance:

```solidity
// ExactOutSwapTarget.sol:325-336
uint256 estimatedAmountIn = params.tokenInVault.previewExchangeOut(tokenIn, tokenOut, params.amountGiven);
// if (estimatedAmountIn > params.limit) {
//     revert LimitExceeded(params.limit, estimatedAmountIn);
// }
...
_transferTokenIn(params.sender, address(params.tokenInVault), params.tokenIn, estimatedAmountIn);
```

In permit mode `_transferTokenIn` is `tokenIn.safeTransfer(recipient, amount)` from `address(this)`, and `tokenInVault`/`pool` are never checked against the registry.

**Attack.**
1. Honest users call `swapSingleTokenExactOutWithPermit` on the pure-Balancer route with `limit > amountIn`; each call strands `limit - amountIn`.
2. Attacker deploys contract `F` with `previewExchangeOut` returning `tokenIn.balanceOf(router)`, a no-op `exchangeOut`, and an owner-only `sweep`.
3. Attacker signs a Permit2 permit for `amount = 1` with `pool = tokenInVault = tokenOutVault = F`, `amountGiven = 1`, `limit = 1`.
4. The router pulls 1 wei, takes the pass-through branch, and sends its whole DAI balance to `F`.
5. Attacker calls `F.sweep(DAI)`. Variant: use the real SE `daiUsdcVault` instead of `F` and receive USDC.

**Proof of concept.** `test/apex_audit/balancer-router-permit/BalancerRouterPermitOverpull.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/balancer-router-permit/BalancerRouterPermitOverpull.t.sol -vvv`
```
[PASS] test_R1_attacker_uses_real_vault_passthrough() (gas: 5474933)
  attacker USDC received       14359419366366358697
  attacker DAI spent           1
[PASS] test_R1_overpull_strands_and_attacker_steals_residue() (gas: 2318022)
  victim1 stranded loss         11144544745347152657
  victim2 stranded loss         3278793579129953179
  router DAI residue           14423338324477105836
  attacker net profit (DAI wei) 14423338324477105836
  router DAI after attack      0
```

**Impact.** victim1 (1000 USDC exact-out, 1% slippage) strands 11.1445 DAI; victim2 (500 USDC, 0.5%) strands 3.2788 DAI. This loss happens on every permit exact-out call regardless of any attacker. The attacker then takes all 14.4233 DAI of residue for 1 wei + gas (fake vault), or receives 14.3594 USDC for 1 wei DAI via the real SE vault. Theft is capped by accumulated residue and repeatable as it accrues. No flash loan, role or price manipulation. Victims cannot recover funds: the router has no rescue path.

**Design/config note.** Robinhood 4663 excludes Balancer routers by locked decision (`docs/ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md:61`), but `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol:253-304` deploys this router to Base mainnet against the official Balancer V3 Vault, where the permit exact-out route works on every existing Balancer V3 pool. Refund is the intended semantics: the batch exact-out permit path refunds (`batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol:145,193-205`).

**Fix.** In `swapSingleTokenExactOutWithPermit`, snapshot `tokenIn.balanceOf(address(this))` before the pull; after the hook, revert if the balance is below the snapshot and refund any excess to `swapParams.sender`. Restore the pass-through limit check (uncomment `329-331`). Defense in depth: track the pulled amount in a transient slot and decrement on spend; require `permit.permitted.token == address(swapParams.tokenIn)`; validate `pool`/`tokenInVault`/`tokenOutVault` against the vault registry; restore the other commented-out `LimitExceeded` checks (702-704, 743-745, 786-788, 877-879); make `_takeTokenIn` honour batch permit mode; add an owner-gated ERC20 rescue for pre-fix residue.

---

<a id="apex-2026-031"></a>

### APEX-2026-031: Balancer V3 buffer pool prices shares-only/unbalanced joins against its virtual-TTA book, so joiners lose about half their deposit
**Severity:** High · **Status:** Latent: not deployed · **Family:** Balancer V3 buffer pool

**Summary.** `StandardExchangeBufferHookTarget.onBeforeInitialize` sets `virtualTTA` to the rated value of the seeded shares and ignores the TTA actually deposited. `computeInvariant`, `computeBalance` and `onSwap` read the TTA side only from `virtualTTA`. The virtual TTA side is intended by design. The defect is that unbalanced and single-sided joins are enabled and are priced against that unbacked virtual book, while proportional exits pay out of live balances. Two paths do this: the pool's native `exchangeIn(shares -> BPT)` and Balancer `addLiquidityUnbalanced`. With the design's own init (shares plus dust TTA), every honest shares-only deposit loses about 50% to incumbent LPs. The preview equals execution, so slippage bounds do not help.

**Affected code.** Paths are under `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`:
- `StandardExchangeBufferHookTarget.sol:129-146` `onBeforeInitialize` (line 138 `virtualInit = exactAmountsIn[sharesIdx]`, line 140)
- `StandardExchangeBufferPoolTarget.sol:34-50` `computeInvariant` (line 45 `balances[ttaIdx] = _virtualTTA()`); `:56-67` `computeBalance`; `:73-96` `onSwap`
- `StandardExchangeBufferHookTarget.sol:169-182` `onBeforeAddLiquidity` accepts every kind
- `StandardExchangeBufferHookTarget.sol:208-256` `onAfterAddLiquidity`: the UNBALANCED branch (230-246) adds only the TTA contributed
- `StandardExchangeBufferHookTarget.sol:99`, `StandardExchangeBufferPoolStandardVaultPkg.sol:381` (`disableUnbalancedLiquidity: false`)
- `StandardExchangeBufferPoolStandardVaultPkg.sol:438-443` `deployPool` (no caller restriction)
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:97-108, 177-186`: native `exchangeIn(shares -> BPT)` uses `UNBALANCED`

**Root cause.**
```solidity
// StandardExchangeBufferPoolTarget.sol:45-46
balances[ttaIdx]    = StandardExchangeBufferPoolRepo._virtualTTA();
balances[sharesIdx] = _derivedY(balancesLiveScaled18);
```
With `V = rawShares * rate` and `T` = TTA deposited, the virtual book is `2V`, but real backing is `V + T`. `computeAddLiquidityUnbalanced` mints BPT as if each BPT were backed by `2V/S`. Each BPT redeems for only `(V+T)/S`. The joiner's loss is about `(V − T)/(2V)`, which tends to 50% as `T -> 0`. Proportional joins and exits are fair (3 wei round trip), and later unbalanced adds never close the gap.

**Attack.** No attacker is needed, but anyone who initializes the pool or holds BPT profits.
1. A pool is initialized as the design prescribes, with shares plus dust TTA. Alternatively, an EOA calls the permissionless `deployPool` and `initialize` with `[shares = 1000e18, tta = 1e18]`.
2. `virtualTTA = 1000 * rate`, while live TTA is `1e18`.
3. Honest users deposit shares through the native `exchangeIn(shares, S, pool, minOut = previewExchangeIn(...))`.
4. They receive BPT priced on the doubled virtual book.
5. The incumbent exits with `removeLiquidityProportional` and takes the joiners' overpayment.

**Proof of concept.** Two test files:
- `test/apex_audit/fz-balancer-sharesonly-join/BufferSharesOnlyJoinProdParams.t.sol`: honest design init, 10-share join
- `test/apex_audit/fz-balancer-sharesonly-join/BufferSharesOnlyJoin.t.sol`: fixture init and attacker init
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-balancer-sharesonly-join/BufferSharesOnlyJoinProdParams.t.sol -vvv
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-balancer-sharesonly-join/BufferSharesOnlyJoin.t.sol -vvv
```
```
SharesOnlyJoin_DesignInit_Fee005 (static swap fee 500000000000000)
  native join shares in / bpt 10000000000000000000 9502868164095756837
  native join value in / out (fsv) 20000000000000000000 10027343565287009033
  native join loss bps 4986
  init LP exit value before/after 2000999999999998950039 2010972656434711935772
  proportional join value in / out (fsv) 19809900000000000000 19809899999999999997
SharesOnlyJoin_DesignInit_Fee5pct (static swap fee 50000000000000000)
  native join loss bps 5109

FzSharesOnlyJoin_AttackerInit::test_attackerInit_harvestsSharesOnlyJoiners
  attacker PROFIT (fsv) 1354761735059532890848
  victims total LOSS bps 3870
```

**Impact.**
- **Design init, honest parties:** a 10-share join (about 1% of the pool) puts in 20.000 fsv and gets back 10.027 fsv, a 49.86% loss at a 0.05% fee and 51.09% at 5%. The incumbent LP captures the difference. A proportional join of the same shares loses nothing.
- **Attacker-initialized pool:** the attacker puts in 2001 DAI with no flash loan and profits +1354.76 DAI at fsv. Three victims lose 1354.76 of 3500 DAI deposited (38.71%). A balanced-init control running the same flow still moves 660.04 DAI. That part comes from ordinary price impact and the gap between the rate-provider NAV and fsv, so the design-init figure above is the cleaner measure of this bug.
- **Who loses:** anyone who deposits shares through a non-proportional path, including the pool's own SE deposit.
- **Who gains:** existing BPT holders.

**Design/config note.** The design spec prescribes the dust-TTA init with `virtualTTA := s_init * r` (`docs/superpowers/specs/2026-05-31-standard-exchange-buffer-pool-design.md` §6.1, lines 230-234), and its decision table (line 25) pairs that with "Proportional only (`disableUnbalancedLiquidity = true`)". The 2026-06-02 refactor (`docs/superpowers/plans/2026-06-02-buffer-pool-refactor.md:11-31,61`) enabled `UNBALANCED` adds without addressing this. The finding is therefore upgraded from Medium to High (latent; Robinhood is locked "No Balancer", D18/D29).

**Fix.** Keep the design init. Then either:
- (a) reject `UNBALANCED` / `SINGLE_TOKEN_EXACT_OUT` from external routers in `onBeforeAddLiquidity`, and implement the native `exchangeIn(shares → BPT)` as a proportional add (live TTA ≈ 0, so it is shares-only and fair); or
- (b) price non-proportional adds against real backing (live shares at rate, plus live TTA, plus hook-held value) rather than `computeInvariant` over `virtualTTA`.

Defense in depth:
- have `deployPool` initialize atomically, or restrict the first `initialize` to the package or registry;
- add a regression test asserting that a shares-only join keeps its value.

**Related.** APEX-2026-018

---

<a id="apex-2026-010"></a>

### APEX-2026-010: Retired V4 SE vaults still enabled on mainnet; RICH CP-DETF bonds and mints feed honest WETH into an exposed free sleeve

**Severity:** Medium · **Status:** Live on Robinhood 4663 (enabled vaults `0x201d31a56c58a3489beC218c7A899d59A07A35f0`, `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7`, `0x3E33871A8740b294A48347BFFD8A5004E1578c0D`, `0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C`, `0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10`, `0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531`; only `0x999DaE02D22E5FEe1c4508430D5196d31d631009` is disabled) · **Family:** Retired V4 Standard Exchange + CP buffer hooks / CP-DETF (deployed, pre-HEAD bytecode)

**Summary.** The diff deletes the V4 Standard Exchange source that carries the APEX-001 stale-reserve credit. Deleting the source does not change the deployed bytecode, and the registry kill switch was applied to only 1 of the 7 deployed diamonds. The RICH, DTF and PONS reserves now sit on CP buffer hooks that still buffer their pair leg into three of the unremediated vaults. The permissionless CP-DETF `bond()` and mint (`exchangeIn`) paths deposit user WETH into the free sleeve of `0x201d31a5`. On a fork of live mainnet, an unprivileged attacker using only its own capital took +0.2996 ETH net from an honest 0.5 WETH RICH bond (+0.3960 ETH with a 0.52 ETH push), and the pool price was restored exactly.

**Affected code.** The vulnerable source was deleted by `b8dbdf41` and does not exist at `2ba07631`. In the credit path, the deployed bytecode (packages `0x72b0243E`, `0x0172902b`) matches `aca16198`. Lines at `aca16198`:
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1270-1289` (`_secureTokenTransfer`, l.1282-1284)
- `UniswapV4StandardExchangeCommon.sol:1292-1297`, `:461-478` (`_deployedFaceOf` → `_positionAmounts`, reads live `_slot0()`)
- `UniswapV4StandardExchangeCommon.sol:605-613` (`_syncVaultReserves` stores R at sync-time price)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol:54, 60, 125-129` (credit, then `_refundExcess` to `msg.sender`)
- `UniswapV4StandardExchangeInTarget.sol:56,64` (same gate on `exchangeIn`)
- Mitigation lever at `2ba07631`: `contracts/registries/vault/VaultRegistryDisableManagerTarget.sol:18` (`setVaultAddressDisabled`), `:26` (`setPackageDisabled`)

**Root cause.**
```solidity
uint256 R  = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn)); // stored at last sync
uint256 B0 = tokenIn.balanceOf(address(this));                          // live free balance
...
uint256 deployed   = _deployedFaceOf(address(tokenIn));                  // LIVE, from current slot0
uint256 faceBooked = R > deployed ? R - deployed : 0;
uint256 U          = B0 > faceBooked ? B0 - faceBooked : 0;
if (amountIn > U) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
return amountIn;                                                         // credited, nothing received
```
`U_i = B0_i - free_i(sync) - fees_i(sync) + [deployed_i(P_now) - deployed_i(P_sync)]`. Selling token *i* into the pool raises `deployed_i(P_now)` above the stale value, so U grows until it equals the whole free sleeve `B0_i`. `exchangeOut` takes the full credit as `providedAmountIn` but spends only the cost of a tiny exact-out. `_refundExcess` then sends `credit - used` to `msg.sender`.

**Attack.**
1. An honest user calls `bond(WETH, 0.5e18, 30 days, user, false, dl)` on RICH CP-DETF `0xc2FBe67c`. The hook buffers the WETH into `0x201d` as free sleeve. U(WETH) is 0 right after.
2. The attacker sells 1 ETH into the ETH/PONS pool through `PoolManager.unlock`. `deployed0` rises while R stays stale, so U(WETH) becomes the whole free sleeve.
3. The attacker calls `0x201d.exchangeOut(WETH, U, PONS, 1e9, attacker, pretransferred=true, dl)` and receives the unused credit as a WETH refund.
4. The attacker sells its PONS back until `sqrtP == sqrtP0`.

Steps 2-4 can run in one transaction. The bonded WETH stays idle, so the attacker does not need to back-run in the same block. The mint path is identical, with `RICH_A.exchangeIn(WETH, 0.5e18, ...)` as step 1.

**Proof of concept.** `test/apex_audit/live-cp-hooks/LiveCpHooks.t.sol` (direct-deposit variant: `test/apex_audit/live-old-v4se/LiveOldV4SE.t.sol`). Both fork live 4663 read-only.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/live-cp-hooks/LiveCpHooks.t.sol -vvv`
```
  U(WETH) right after honest bond 0
  U(WETH) after push 500420582007809891
  WETH refunded to attacker (never sent) 500352762670403629
  attacker net profit (wei ETH) 299614081746770311   (+0.2996 ETH)
  RICH LP/bonder backing delta (wei ETH) -300611745865462888   (-0.3006 ETH)
tightPush (0.52 ETH): profit 396008017111554130, victim delta -396524854212904092.
control_noClaim: profit -10990452332727797, victim delta +9990330185848377.
```

**Impact.** Executed on a live fork: +0.2996 ETH from a 0.5 WETH bond with a 1 ETH push, and +0.3960 ETH with a 0.52 ETH push. Mint gives the same result. A direct 2-ETH-equivalent LP deposit into `0x201d` loses 896 bps (+179,317,414,965,570,397 wei to the attacker). RICH CP-DETF bonders, minters and direct LPs lose. Preconditions: the vault is enabled and has a non-trivial free sleeve. The cost is the push-and-restore round trip through the 1% pool (control: -0.0110 ETH at a 1 ETH push), so any sleeve above roughly 0.01 ETH on `0x201d` is profitable. No privileged role or flash loan is used. About 0.0005 ETH is at risk today. The exposure is every future bond, mint or hook buy.

**Design/config note.** Downgraded from High. The owner's own records list these vaults as the live APEX-001-M2 concern (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:40,113-125`). However, the RICH CP-DETFs and hooks have emitted no events since about L2 block 46M (2026-08-25), and only 505,628,403,878,820 wei is at risk, so likelihood is low.

**Fix.** The registry owner disables the vaults: `setPackageDisabled(0x72b0243E…, true)` plus `setVaultAddressDisabled(0x64e0f5A5…, true)` (package `0x0172902b`). `_requireNotDisabled()` is the first statement of the deployed `exchangeIn`/`exchangeOut`. Disabling only the DETFs is not enough, because `HOOK.exchangeIn(WETH→RICH)` also feeds the sleeve. Side effects: RICH mint, bond and hook buy/sell revert, and backing in `0x201d` is frozen until re-enabled. Re-enabling with a non-zero sleeve re-arms the snipe. The hooks' `standardExchange` cannot be re-pointed (there is no setter). Defense in depth: migrate the CP-hook and CP-DETF stacks off pre-HEAD bytecode, and add a CI check that requires every registry-enabled vault whose package is absent from HEAD source to be disabled.

**Related.** APEX-2026-036, APEX-2026-037, APEX-2026-054

---

<a id="apex-2026-014"></a>

### APEX-2026-014: A raw leg with a rate provider (allowed since D60) pays swap output without dividing by the rate, so round trips drain LPs

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V4 SE buffer hooks (weighted, curve quad; balancer quad/orbital same code shape)

**Summary.** D60 removed the `RateProviderWithoutSE` package check, so every SE-buffer hook now accepts a rate provider on a raw leg. On such a leg the reserve and the exact-in inflow are rated (`raw * rate`). When the raw leg is the output of an exact-in swap, however, the payout is `Math.descale(budget, ratedScales[j])`, which is only a decimal rescale and never divides by the rate. Buying the raw leg pays `r` times the fair amount, and selling it back is credited at the rated value. In the PoCs, 50,000 token2 of the attacker's own capital made +71,012 (weighted) and +73,182 (Curve quad) in 5 round trips at `r = 1.2`.

**Affected code.**
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:398-401`; `.../stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:372-375`; `.../stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol:367-370` (a raw leg may carry a provider)
- `.../weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:61-67` (l.66, rated inflow), `:84-86` (rated reserve), `:146-163` (l.159, unrated raw output), `:271-274` (exact-out debit, not executed)
- `.../curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:114-120`, `:126-134`, `:212-227` (l.223)
- Same shape, not executed: Balancer quad ClaimLib `:92-107` (l.103), `:148-150`; `.../orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:206-213, 254-261, 459`

**Root cause.**
```solidity
// Weighted ClaimLib._outputBudget, raw-leg branch (l.158-160)
} else {
    amountOut = Math.descale(budget, l.ratedScales[j]);   // missing: * RATE_PRECISION / rate_j
    if (amountOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
}
```
The invariant returns `budget` in rated units, so the correct face payout is `budget / r`. Take a round trip `k -> j -> k` with fee `f`. Leg A pays `a(1-f)` face of `j`, where the fair amount is `a(1-f)/r`. Leg B credits that amount as `a(1-f)*r` and returns about `a * r * (1-f)^2`. The net gain is about `(r-1) - 2f` per loop, it compounds, and all of it comes from LPs. Before D60, `r` was always effectively 1 on raw legs.

**Attack.**
1. Hold `a` of an unrated raw leg `k` (own capital or a flash loan).
2. `exchangeIn(token_k, a, token_j, 0, attacker, false, deadline)` returns about `r` times the fair amount of `token_j`.
3. `exchangeIn(token_j, got_j, token_k, 0, attacker, false, deadline)` rates the inflow at `got_j * r`.
4. Repeat with the whole balance until `MaxInRatio`/`WouldZeroReserve` caps the trade or the leg is drained.

**Proof of concept.** `test/apex_audit/rawleg-rp-swap/RawLegRpSwap.t.sol` (Curve quad: `test/apex_audit/rawleg-rp-swap/RawLegRpSwapCurveQuad.t.sol`; production fees: `AdjProdWeighted.t.sol` and `AdjProdCurveQuad.t.sol` in the same directory). Each has an `r = 1.0` control.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/rawleg-rp-swap/RawLegRpSwap.t.sol -vvv`
```
[PASS] test_exploit_rate_1_2() (gas: 21824679)
    token1 out       47482973758146399999999
    fair token1 out  41666666666666666666666
    token2 back      59659259371018486200000
  attacker profit (t2, signed)
  71012097797951869600000
  LP delta (signed)
  -71012097797951869599925
```

**Impact.** At `r = 1.2`, 5 loops on 50,000 token2:
- Weighted (0.3% fee): +71,012.10 (+142%); the honest LP loses 71,012.10 of 2,999,001.
- Curve quad (0.1% fee): +73,182.45 (+146%); the LP loses 73,182.45 of 3,999,001.

Profit matches the LP loss within 76 wei, and the `r = 1.0` controls lose (-1,411.43 / -497.52). At production fees (0.03% dex fee), a 1% rate premium gives +2.85% and a 5% premium gives +15.6% on 50k in 3 loops, with no flash source. Break-even is roughly `r - 1 > 2f`. The losers are third-party LPs who join a hook configured this way. The PoC stopped at 5 loops; a full drain is extrapolated, not executed.

**Design/config note.** Downgraded from High. The only production deploy path (`scripts/foundry/anvil_robinhood_main/Phase_08_Stage_03_FeeAccrualDetf.sol:75-86`) sets `rateProviders[i] = 0` on the raw leg, so exposure requires a deployer to opt in. It is still a bug: the D60 PRD (`docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:9-13`) says the swap invariant uses rated reserves on any leg with a provider, and the output path contradicts that.

**Fix.** Smallest change: until the raw-leg rate path is complete, restore the package guard in each DFPkg, keeping D60's `RateProviderRequired` for buffered legs:
```solidity
if (a.standardExchanges[i] == address(0) && a.rateProviders[i] != address(0)) revert RateProviderWithoutSE();
```
If rated raw legs are intended:
- Divide exact-in output by the rate (weighted l.159, Curve l.223, Balancer l.103).
- Multiply exact-out debits by the rate (weighted l.273, Balancer l.150) and compare against the face reserve.
- Rate the quad pretransfer override.
- Convert Orbital input and output.
- Round in the pool's favour.

Add per-family round-trip tests at `r = 1.2` and `0.8`.

**Related.** APEX-2026-015

---

<a id="apex-2026-015"></a>

### APEX-2026-015: Curve quad buffer hook prices single-sided LP join/exit on unrated SE share counts while swaps use rated balances, so accrued SE yield can be siphoned

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V4 SE buffer hooks (curve quad)

**Summary.** The Curve quad hook values an SE leg as `seShares x rate` for swaps, but as its raw share count for single-sided LP joins and exits. Once the SE leg's rate exceeds 1, the attacker can loop three steps:
- a single-sided join with a raw stable mints LP as if each SE share were worth 1;
- a single-sided exit into the SE leg pays about one share per invariant unit, and each share redeems for `r`;
- a rated swap back closes the loop with about `(r - 1)` profit per unit cycled.

In the PoC (rate 1.04895, 100k flash principal, 3 cycles), the attacker kept 13,623 token1 net and the honest LP lost 14,041.

**Affected code.** Under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` (file prefix `UniswapV4StandardExchangeCurveQuadStableBufferHook`):
- `...Target.sol:564-569` (`_invWadAll`, unrated) vs `:571-576` (`_ratedWadAll`, rated); `:467-473` (`_nativeAt` = share count)
- `...ClaimLib.sol:126-139` (`ratedPairUnits`: SE leg = `seBal x rate`)
- `...JoinCore.sol:487-526` (single join on `_invWadAll()`)
- `...ExitQuoteBase.sol:10-17` (single exit in SE shares), `...ExitExecutionBase.sol:13-42`; `...Target.sol:52-94` (flexible exit)
- `...Target.sol:658-666` (`_snapshotKLastIfFeeOn`: no value-conservation check, unlike the Balancer quad's `LiquidityValueLoss`)
- `...Target.sol:140-151` (`ownerOnlyLiquidity` gates)

**Root cause.**
```solidity
// Target.sol:564-569 — used by single join, single exit, kLast
scaled[i] = Math.scaleTo(_nativeAt(i), l.invScales[i]);          // SE leg: share COUNT
// Target.sol:571-576 — used by swaps
scaled[i] = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);  // SE leg: shares * rate
```
A join of `x` raw stable mints about `x` invariant units. Exiting to the SE leg pays about `x` SE shares, which `_unwrapSeShares` redeems for about `r*x`. The rated swap then returns about `r*x` stable. Net per cycle ≈ `(r - 1) * x - (join fee + exit fee + swap fee + curve slippage)`, taken from the SE yield owed to existing LPs. Proportional join/exit is not affected.

**Attack.**
1. Borrow `x` of a raw stable leg (token1).
2. `depositSingle(token1, x, attacker, 0, deadline)`.
3. `withdrawSingle(token0, lp, attacker, 0, deadline)`. The SE shares are counted 1:1 and unwrapped at rate `r`.
4. `exchangeIn(token0 -> token1, out0, ..., pretransferred=false)` on the hook.
5. Repeat steps 2-4.
6. Repay the principal plus fee.

**Proof of concept.** `test/apex_audit/rawleg-rp-lp-and-fee/CurveQuadLpDomainArb.t.sol` (production fees: `test/apex_audit/rawleg-rp-lp-and-fee/AdjProdCurveQuadLp.t.sol`).
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/rawleg-rp-lp-and-fee/CurveQuadLpDomainArb.t.sol -vvv`
```
  control end token1  99652992666738254983752
  rate leg0 (rp)     1048951048951048952
    lp minted        24972466676647728562515
    token0 out       104634541239557141160667
  attacker net profit 13623352741431738618904
  victim loss         14041249531626211587796
yield 0.5%  (r=1.0040) attacker profit   931592627337965442328   victim delta -2663332220832116500137
yield 5%    (r=1.0490) attacker profit 14260191307994005457471   victim delta -15280176888526739737581
```

**Impact.** The attacker netted 13,623.35 token1 (about 13.6% on 100k capital, after a 9 bps flash fee) in one transaction over 3 cycles. The honest LP's fair value fell from 4,048,951.05 to 4,034,909.80 (-14,041.25, out of roughly 48,951 accrued yield). The control at r = 1 loses 0.347%. At production fees with own capital, about 0.4% SE yield is already profitable, and 5% yield returns +14.3% in 3 cycles. In those production-fee runs the victim loses more than the attacker gains, because the 5% usage fee mints protocol LP to `feeTo`. Preconditions: `ownerOnlyLiquidity == false`, and an SE leg whose rate has drifted past break-even, which happens naturally as yield accrues. Existing LPs lose.

**Design/config note.** Downgraded from High: there is no Curve quad instance on 4663. The only production configuration (`fee_accrual_launch.robinhood.json:41`) deploys a weighted hook, not a Curve quad, and sets `ownerOnlyLiquidity: true`. Using the raw domain for liquidity operations was a deliberate decision (D59; `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:12`), but that decision reasons only about proportional operations. Rule 3 of the same PRD says a buffered leg valued by raw share count "would price the pair wrong". Public instances are a supported configuration (`DETF_ALIGNMENT_PRD.md` D61). A public Curve quad over a yield-bearing SE would make this High.

**Fix.** Price single-sided LP in the rated domain:
- In `_quoteSingleJoinExactIn(Preview)` (JoinCore:487-526), `_singleExitInvOut` (ExitQuoteBase:10-17) and `_singleExitInventory` (Target:87-94), use `_ratedWadAll()` instead of `_invWadAll()`.
- Value SE-leg join input as `shares x rate`.
- Convert SE-leg exit output back to shares with `descale(outS, ratedScales[idx]) * RATE_PRECISION / rate`, rounding down.
- Compute supply in the same domain.

Defense in depth:
- Port the Balancer quad's `LiquidityValueLoss` check, reading supply before any protocol-fee mint.
- Add a fuzz test over `r` in [0.9, 1.1].
- Keep `ownerOnlyLiquidity = true` where LP flow should be restricted (this mitigates but does not fix).

**Related.** APEX-2026-014

---

<a id="apex-2026-016"></a>

### APEX-2026-016: Weighted partial-book dust seed drains the funded legs (two code paths)
**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V4 weighted hooks (plain UniswapV4WeightedSwapHook + UniswapV4StandardExchangeWeightedBufferHook)

**Summary.** The weighted hooks allow a documented "partial book" for n >= 3: the first mint funds only some legs, and the rest are "seeded over time". Any caller can seed a zero-reserve leg through `joinProportional` at any size, with no minimum and no ratio, NAV, rate or oracle check. The plain hook has no owner gate at all, and the SE hook is gated only when `ownerOnlyLiquidity == true`. A 1e9-wei seed completes the book at an absurd price, and the attacker then sells the dust leg into the newly live doors until the funded legs are empty.

**Affected code.**
- `contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookLiquidityTarget.sol:780-787` (`joinProportional`, only `nonReentrant`), `164-229` (`_partialJoin`, seed loop `182-189`)
- `contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol:419-436` (`_seedNavShares`)
- `contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookHooksTarget.sol:194-226`, `230-264` (only gate is `SwapNotLive`; no minimum depth)
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:191-196`, `287-307`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol:53-70` (`_scanProportional`)
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol:80-92`, `172-192` (unwired copy; `joinProportional` has no `onlyLiquidityOwner`)
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol:281`, `423`

**Root cause.** The seed for a zero leg is accepted at face value (SE `_scanProportional:60-63` is identical):

```solidity
// UniswapV4WeightedSwapHookLiquidityTarget.sol:182-189
for (uint256 i; i < n; ++i) {
    if (l.reserves[i] == 0 && amounts[i] > 0) {
        used[i] = amounts[i];                       // any size, no reference price
        working[i] = Math.scaleTo(amounts[i], rates[i]);
        anySeed = true;
    }
}
```

With `b_A = 4000e18`, `b_B = 3000e18`, `b_C = 1e9` (weights 0.4/0.3/0.3): `P(C→A) = (b_A / w_A) / (b_C / w_C) = (4000e18 / 0.4) / (1e9 / 0.3) = 3e12` A per C (fair value is 1). `MAX_IN_RATIO = 30e16` only caps each swap; at 29% steps `b_C ≈ 1e9 * 1.29^k`, so about 80 swaps empty the book. Both HooksTargets open every door once both reserves are non-zero.

**Attack.**
1. Honest LP partial-mints 4000e18 A + 3000e18 B, C = 0.
2. Attacker calls `joinProportional([0, 0, 1e9], attacker, 0, deadline, "")`; `isFullBook()` becomes `true`.
3. Attacker repeatedly swaps C→A / C→B with `amountIn = 29% of reserveOf(C)` while `previewSwapExactIn(out) > in` (80 swaps plain, 76-96 SE).
4. Attacker exits its dust shares.
5. Honest LP's `exitProportional` returns about 0.03% of its deposit.

Front-run form: an honest fair seed broadcast afterwards reverts on `sharesMin` (DoS) or joins the drained book.

**Proof of concept.** `test/apex_audit/dry-dry-econ-weighted-partial-dust-seed/WeightedPartialDustSeedV2.t.sol` (plain) and `test/apex_audit/sib-empty-leg-dust-seed/SeWeightedPartialDustSeed.t.sol` (SE)
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/dry-dry-econ-weighted-partial-dust-seed/WeightedPartialDustSeedV2.t.sol -vvv`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/sib-empty-leg-dust-seed/SeWeightedPartialDustSeed.t.sol -vvv`
```
[PASS] test_dustSeedThenDrain() (gas: 31888809)
  swaps 80
  victim in  7000000000000000000000
  victim out 2059825023745273245
  attacker net profit 6997938522147794028560
[PASS] test_frontrunHonestSeed() (gas: 32152276)
  honest seed tx reverted (slippage) - honest op DoS
[PASS] test_seDustSeed_largeBook() (gas: 71826332)
  ATTACKER NET PROFIT (price 1) 1998911635000068535227035
```

**Impact.** Plain hook: honest LP 7000e18 in, 2.0598e18 out (-99.97%); attacker +6997.94e18 with about 0.70e18 C left in the pool. SE hook (`ownerOnlyLiquidity=false`): +1998.33e18 on a 2000e18 book; +1,998,911.6e18 on a 1M-per-leg book using about 41.4e18 C. A 0.3% dex fee does not reduce extraction (+1998.50e18). No flash loan; fixed cost is gas for one seed, 76-96 swaps and one exit. Preconditions: n >= 3, pool in the partial state holding LP capital. Every LP in the partial book loses.

**Design/config note.** Downgraded from High: every production DETF deploy path sets `ownerOnlyLiquidity = true` (e.g. `scripts/foundry/anvil_robinhood_main/fee_accrual_launch.robinhood.json:41`), under which the attacker's seed reverts, and no script deploys the plain hook. Residual exposure: the HEAD SE weighted package `0x42F40974…` is live on 4663 and `UniswapV4StandardExchangeWeightedBufferHookDFPkg.deployVault` (`:116`) is public, so anyone can deploy a public n>=3 instance (0 existed at the census block).

**Fix.** In the partial branch, revert if any `reserves[i] == 0 && amounts[i] > 0` and the caller is not the hook owner/factory, regardless of `ownerOnlyLiquidity`. Apply at all three sites (plain `_partialJoin`, SE `LiquidityLib`, and the `…LiquidityTarget` copy, which can be deleted). If permissionless seeding must stay, require the seed's value to match the funded book within a tolerance using a rate provider or oracle, never pool spot. Defense in depth: treat a leg as not swap-live until its reserve reaches a minimum fraction of the book, and add an invariant test that a non-owner seed + swaps + exit cannot reduce existing per-share value beyond fees.

---

<a id="apex-2026-020"></a>

### APEX-2026-020: V4 DETF mint and bond are priced from the manipulable live reserve-hook book
**Severity:** Medium · **Status:** Live on Robinhood 4663 (DTF-DETF `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`, reserve hook `0x46E068c2393e189Fbc86632f67210aF253a42Aa8`; pre-HEAD source). Not shown exploitable in the current state: the third-leg lever is blocked by the disabled WETH-leg SE and DTF-only cycles were unprofitable on a live fork; the weighted bond composite was not run on the fork. · **Family:** DETF (Uniswap V4)

**Summary.** `UniswapV4Detf` prices mints from a spot `previewExchangeIn(pair -> DETF)` quote, and bonds from the live book (`g = reserveDetf * B / reservePair`, principal from spot), with no TWAP, deviation band, or `minPrincipal` on `bond()`. On the weighted hook the mint gate reads only the mint pair's balance, so dumping DETF into a third leg cheapens the mint while the gate stays open; dumping against the bond pair inflates `g` twice and the principal, and `g` is joined with `minLp = 0`. A permissionless dust first bond prices the next honest bonder against an empty reserve.

**Affected code.**
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:55-60` (`_requireReserveWired`), `204-207` / `221-228` (mint gate, own pair only), `259-263` (`_quoteMintGross`), `266-271` (`_openingBondQuote`), `274-289` (`_quoteBondG`), `292-297` (`_quoteBondPurchase`), `453-465` (`minLp = 0`)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:259-305` (`_mintPath`), `532-562` (`_entryBond`, pre-live branch `554-557`), `581-600` (`_purchaseBond`), `629-642` (`_joinBond`)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondTarget.sol:11-20` (no minimum-principal argument)
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:95-146` (`previewSynthetic`)

**Root cause.** The weighted gate values other legs off the `out_` leg only:

```solidity
// ...WeightedBufferHookExitQueryTarget.sol:126-136
for (uint8 i; i < l.numTokens; ++i) {
    if (l.tokens[i] == detf_) continue;
    if (i == j) { marked += rated[i]; continue; }
    ...
    marked += FullMath.mulDiv(rated[j], wIn, wOut);   // other legs valued off rated[j], not rated[i]
}
```

The mint quote is `out = rD * (1 - (rP0 / (rP0 + in))^(wP0/wD))`; selling δ DETF into pair1 scales it by about `(rD + δ) / rD` while `rP0` and the gate are unchanged. For bonds, `g = rD * B / rP` grows by `(rD'/rD) * (rP/rP')`. After a dust first bond, `_quoteBondG` falls back to `_openingBondQuote` when `reserveDetf == 0`.

**Attack.** (weighted 60/20/20 composite, one tx)
1. Obtain δ DETF (581e9, 62% of the pool's DETF reserve) from a lender charging 0.10%.
2. Sell δ against the pair0 leg.
3. `bond(pair0, 1000, 1 day)` in 2 chunks: inflated `g` is minted and joined with `minLp = 0` at depressed spot.
4. `exchangeIn(pair0 300 -> DETF)` in 3 chunks (the bond refilled `rP0`, reopening the gate).
5. Buy back only `δ + fee`; sell surplus DETF, repay the lender.
6. After the lock, claim, unstake and sell the principal.

Variants: third-leg spot mint (40/30/30); CP-reserve bond sandwich; dust first-bond front-run.

**Proof of concept.** `test/apex_audit/chain-detf-system/ChainDetfSystem.t.sol`; also `test/apex_audit/detf-spot-mint/DetfSpotMint.t.sol`, `test/apex_audit/detf-bond-spot/DetfBondSpot.t.sol`, `test/apex_audit/dry-r5-detf-first-bond-live-transition-frontrun/DryFirstBondFrontrun.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/chain-detf-system/ChainDetfSystem.t.sol -vvv`
```
[PASS] test_chain_max2() (gas: 138681465)
X2 COMPOSITE: attacker pair0 PnL after tx 1255540236800644013956; REALIZED 3089323316958235944940; protocol-LP backing delta -1260730559653864297021
pool pair value 14585414585414587248457 -> 11490901453430282337237 (lost 2121 bps); backing per 1e9 circ DETF 6714302583080458322 -> 5149880254458833612
[PASS] test_detfSpotMint_thirdLegDump() (gas: 28938092)
  == ATTACK ==  delta 598684940526 a 60e18 | gate open at mint true | user DETF minted 27986733562 | attacker pair0 PnL 32612163332085208191 | protocol-LP pair backing 3396603374595920507228 -> 3363444350580692129480
```

**Impact.** Composite (fee 0.03%, flash 62% of pool DETF): +3089.3 realized, +1255.5 atomic; reserve pair value −21.21%, backing per circulating DETF −23%. Third-leg mint: +32.61 net of the 0.10% flash fee (control −1.32); loses at a 5% dexSwapFee. CP bond sandwich (bond 50, sell 25% of pool DETF, 180d lock): +11.51 realized vs −5.88 for an honest bond. First-bond front-run: victim realizes 13.87 instead of 501.03 (−487.16, ~97%), attacker +15.146. Losses fall on DETF holders, bond-NFT holders and sDETF stakers (the reserve LP is protocol-owned).

**Design/config note.** Spot-priced issuance and per-pair gates are intended (`contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:41` D8, `:81` D41) and listed as accepted risk under the Policy deadband (`docs/security/audit/specialists/S-amm-oracle-flash.md:11,45`), but the deadband bounds neither ungated bonds nor the third-leg mint. Downgraded from High because the V4 PoolManager holds 0 DETF (no free flash source) and live TVL is about 2.1 WETH-eq; at production parameters a whale using its own DETF nets −148.51 to −329.57 if forced to liquidate at spot, but +47.84 to +2278.14 marked at backing, and it returns to High if DETF becomes flash-borrowable or TVL grows.

**Fix.** Add `minPrincipalOut` to `bond()`. Restrict the first (`!isReserveLive`) bond to owner/operator or require a minimum size. Cap mint `gross_`, bond `g_` and principal at quantities implied by a manipulation-resistant reference (hook TWAP or full-book backing per DETF), or revert on deviation. Make the weighted gate mark each leg by its own `rated[i]`, or check every pair. Defense in depth: non-zero `minLp` in `_joinUnbalanced`; per-tx bond cap; do not re-enable the disabled WETH-leg SE `0x999DaE02` until these ship.

**Related.** APEX-2026-021, APEX-2026-010

---

<a id="apex-2026-021"></a>

### APEX-2026-021: Balancer V3 DETF bond/mint priced off live reserve-pool spot with no `IVault.isUnlocked()` gate
**Severity:** Medium · **Status:** Latent: not deployed · **Family:** DETF (Balancer V3)

**Summary.** The Balancer V3 DETF families price bond liquidity (`g`), bond principal and (MixedBuffer/SingleSE) the mint quote and gate from the reserve pool's live balances, and no entry point checks `IVault.isUnlocked()`. Balancer V3 only settles at the outermost `unlock`, so an attacker contract opens its own unlock, dumps DETF it does not own into the pool on deferred credit, calls `bond()` or mints at the skewed spot, swaps back, and settles in one transaction. The skew costs only swap fees. Existing DETF holders and the protocol-owned reserve LP pay.

**Affected code.** (under `contracts/vaults/detf/protocols/dexes/balancer/v3/`)
- `standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol:20-32` (`bond()`, no min-principal, no unlock check), `34-47` (`_purchaseBond`)
- `standardExchange/single/SingleStandardExchangeDETFCommon.sol:362-371` (`_quoteBondJoinDetf`), `340-356, 373-376` (`_quoteReserveSwap` / `_quoteBondPurchase`), `284-304` (mint gate)
- `mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol:47-64`; `mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol:448-474`, `153-156, 476-485` (quotes and gate over live balances)
- `mixedBuffer/MixedBufferMultiVaultStableDetfExchangeInTarget.sol:74-85` (`_acquireDetf`)
- Same pattern, not executed: `multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol:45-67`, `MultiVaultWeightedDetfCommon.sol:404-442`; `stable/common/ComposedStableCommonDetfBondingFacet.sol:15-29`, `ComposedStableCommonDetfCommon.sol:693-698, 728-739, 746-750`
- `common/DETFBalancerReserveSwapTarget.sol:40-51` (nested `vault.unlock`, no already-unlocked check)
- `lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol:106-121` (`transient`: only the outermost unlock checks deltas)

**Root cause.**

```solidity
// SingleStandardExchangeDETFCommon.sol:362-371
(,, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
return Math.mulDiv(shares_, raw_[s_.detfIndex], raw_[s_.vaultShareIndex]);
// Vault.sol:106-121
bool isUnlockedBefore = _isUnlocked().tload();
...
if (isUnlockedBefore == false) {
    if (_nonZeroDeltaCount().tload() != 0) revert BalanceNotSettled();
```

`g = amount * raw[detf] / raw[share]` and the principal is a weighted quote over live balances; a 25% dump moves the ratio from 4400e9/1100e18 to 5500e9/451.64e18 (about 3.05x). The DETF's own reserve-swap unlock is nested, so the attacker's open DETF debt only has to net to zero when its outer unlock returns.

**Attack.** (SingleSE bond)
1. Attacker contract calls `vault.unlock(cb)`.
2. EXACT_IN swap of `X` DETF (not owned) into the pool for shares.
3. `DETF.bond(seShare, 30e18, DEFAULT_MAX_LOCK, attacker, false, deadline)` with its own 30 shares; `g` and principal priced at the skewed ratio.
4. Restore the pool's ratio with chunked share→DETF swaps (29% of balance, under MaxInRatio).
5. Settle both deltas (surplus kept as loose DETF); the outer unlock closes.
6. After the lock, `claimBond`, unstake, sell all DETF.

MixedBuffer mint: dump 7x the pool's DETF, call `exchangeIn(share, 2e18, DETF, minimum=0, ...)` with the gate still open, buy back exactly the dumped DETF, sell the minted DETF.

**Proof of concept.** `test/apex_audit/r2-h2v-balancer-detf-bond-mint-spot-no-unlock-gate/R2SingleSE.t.sol` and `test/apex_audit/r2-h2v-balancer-detf-bond-mint-spot-no-unlock-gate/R2MixedBuffer.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r2-h2v-balancer-detf-bond-mint-spot-no-unlock-gate/R2SingleSE.t.sol -vvv`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r2-h2v-balancer-detf-bond-mint-spot-no-unlock-gate/R2MixedBuffer.t.sol -vvv`
```
[PASS] test_sandwich25() (gas: 16263130)
    vault unlocked during bond: true
    principal DETF 91047926872
    REALIZED share PnL after lock + dump (signed):
  72462821269292429815
[PASS] test_assert_defaultFee_mintSandwich() (gas: 10212252)
  attacker minted DETF (pay 2 shares): 3361681203188
  DETF supply before: 2995074244970
  ATTACKER NET PROFIT (shares, realized, fees paid): 1213297346466965909586
```

**Impact.** SingleSE bond, 25% dump, 0.3% fee, 180d lock: realized +72.46 shares versus an honest +0.098 with the same capital; reserve share leg ends 1,027.54e18 versus 1,099.90e18 (−72.4). At a 10% dump: +17.85. MixedBuffer mint at the shipped 5e16 fee: a 2-share mint returns 3,361.68e9 DETF (more than the prior supply of 2,995.07e9) and realizes +1,213.3 shares; pool share leg 1,900e18 → 686.70e18, synthetic price 1.302e18 → 0.926e18 (−28.9%). No lender; the skew is financed by Balancer deferred settlement. SingleSE mint is refuted at fixture parameters (gate closed). Bond principal is realized only after the lock.

**Design/config note.** Downgraded from High: none of these families is deployed or has a production deploy script, and owner decision D60 (`DETF_ALIGNMENT_PRD.md:100`) stops functional work on Balancer-hosted DETF families. It is High for any instance that gets deployed.

**Fix.** At the top of every external entry point that prices off the reserve pool (`bond`, mint/burn `exchangeIn`/`exchangeOut`, reserve-swap and first-bond paths), in all four families and before `_requestReserveSwap`, revert `ReserveVaultUnlocked()` if `_reserveVault().isUnlocked()`. D30 expects DETF host operations inside an open unlock, so first confirm no router or SE wrapper legitimately enters from within one. Defense in depth: add `minPrincipalOut_` to `bond()`; derive `g`, principal and mint quotes from a manipulation-resistant reference with a deviation revert (an unlock gate does not stop an externally flash-loaned skew in separate unlocks); evaluate the mint gate against that reference and cap per-tx mint relative to `totalSupply`.

**Related.** APEX-2026-020

---

<a id="apex-2026-022"></a>

### APEX-2026-022: V3 FullSpread blocked mode can be entered from the pool's own swap callback, so zap-in plus zap-out becomes a fee-free x*y swap over a spot-repriced book

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V3 FullSpread

**Summary.** The vault picks between its idle path and its blocked path by reading `pool.slot0().unlocked`. That flag is `false` for the whole of the bound pool's own `swap` callback, which anyone can trigger, and by then `slot0.sqrtPriceX96` already holds the caller's post-swap price. In blocked mode, a single-sided zap-in followed by a single-token zap-out works as a fee-free constant-product swap over `free + deployed(slot0) + owed fees`. The payout comes from the free sleeve, which is not repriced. An unprivileged, flash-funded attacker netted +107.55e18 token1 against a 2000e18 vault.

**Affected code.** All under `contracts/vaults/standard/exchange/protocols/uniswap/`:
- `v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:125-128`: `canOpenBoundPoolOps()` returns `slot0.unlocked`, so the caller chooses the mode.
- `v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:183-186, 319-335`: deployed position valued at live `slot0`. The book is free + deployed + collectable fees.
- `v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:74-114`: blocked single-sided deposit priced over the book, with no rebalance.
- `v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:171-180, 227-240`: blocked zap-out pays `_singleExit` from the free balance. The only bound is `freeOut >= amountOut`.
- `v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:68-73`, `v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:38-52`: blocked exact-out exit, same book.
- `v3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:74-76, 86-102`: blocked dual exit, same book (not executed).
- `StandardExchangeConstantProduct.sol:58-64, 98-111`: `_sharesForDeposit` and `_singleExit`.

**Root cause.**
```solidity
// UniswapV3FullSpreadStandardExchangeVaultCommon.sol:125-128
function canOpenBoundPoolOps() public view virtual returns (bool) {
    (,,,,,, bool unlocked) = _pool().slot0();
    return unlocked;
}
```
Uniswap V3 sets `unlocked = false` and writes the new `sqrtPriceX96` before it calls `uniswapV3SwapCallback`. In blocked mode, all share math uses `R_i = free_i + deployed_i(slot0.sqrtPriceX96) + owed_i`. For a full-range position, `deployed0 = L / sqrtP` and `deployed1 = L * sqrtP`, so pushing the token0 price up inflates `R1`, while the payout sleeve (`free0`, `free1`) stays the same. Depositing `x` token0 and exiting every minted share to token1 returns `y ≈ R1 * x / (R0 + x)`, with no swap fee on either leg. Blocked-mode pricing has no TWAP, no deviation check and no single-sided restriction.

**Attack.**
1. Flash-borrow token0 and token1.
2. Call `pool.swap(attacker, zeroForOne=false, ..., sqrtPriceLimitX96 = target)` to push `sqrtP` up.
3. Inside `uniswapV3SwapCallback` (pool locked, slot0 at `target`), call `vault.exchangeIn(token0, x, vaultShares, ...)`. This mints shares over the spot-repriced book.
4. Still in the callback, call `vault.exchangeIn(vaultShares, shares, token1, ...)`. This pays `_singleExit` token1 from `free1`, sized to about 97% of `free1`. Then pay the pool for the push.
5. Call `pool.swap(zeroForOne=true, ..., sqrtStart)` to bring the price back.
6. Buy any token0 shortfall, repay the flash loan plus fee, and keep the remaining token1.

**Proof of concept.** `test/apex_audit/v3fs-blocked-cp/V3FSBlockedCP.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/v3fs-blocked-cp/V3FSBlockedCP.t.sol -vvv`
```
[PASS] test_blockedCP_lambda2() (gas: 23329620)
  attacker sold token0 to vault (e15): 72478
  attacker got token1 from vault (e15): 194259
  vault NAV at P0 before / after (wei): 1999999999999999999998 1882065102923600614719
  ATTACKER NET PROFIT (token1 wei): 107554380003949904491
  VAULT NAV LOSS at P0 (wei): 117934897076399385279
  victim (honest LP) loss bps of NAV: 589
  deep-pool control: attack reverts (cannot repay flash + fees with 100e18 own capital)
```
The tests assert that `canOpenBoundPoolOps()` was `false` during the vault calls.

**Impact.** Executed in one transaction against a 2000e18 vault (20% sleeve, 0.3% pool), net of the 9 bps flash fee and all pool fees:

| Vault share of in-range L | Attacker profit | LP loss |
|---|---|---|
| ~50% | +107.55e18 | 117.93e18 (5.89%) |
| ~20% | +81.06e18 | 100.59e18 (5.02%) |
| ~10% | +46.26e18 | 74.12e18 (3.70%) |
| ~5% | +6.26e18 | 41.56e18 (2.07%) |
| ~0.08% (fixture default) | reverts | none |

- **Who loses:** existing share holders, pro rata.
- **Preconditions:** `liquidReservePercentage > 0`, a vault holding a material share of in-range liquidity, and flash liquidity.
- **Limits:** each cycle is capped at the free `tokenOut` balance (≈200e18). Repeating after `rebalanceLiquidReserve()` refills the sleeve, and the mirror direction, were not executed.

**Design/config note.** The production fee-oracle script sets no V3 sleeve default (`scripts/foundry/anvil_robinhood_main/Phase_04_Stage_01_FeeCollectorAndManager.sol:46-47`), so the sleeve resolves to 0% and the attack reverts. With a 20% sleeve at about 2% vault share, the attacker loses about 40-45 per attempt and the vault loses up to 41.6 (2.07%). Severity stays Medium because the locked production matrix PRD sets the intended V3 SE default at `0.20e18` (`contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md:128-129`), and pons v1 V3 pools can be thin at creation. Do not rely on a 0% sleeve as the mitigation.

**Fix.**
- **Spec-compatible fix:** in blocked mode, value `deployed` at the last idle checkpoint or a `pool.observe` TWAP instead of the in-callback `slot0`, and revert when slot0 deviates beyond a small bound. Apply this before any V3 FullSpread vault gets a non-zero sleeve.
- **Alternative:** revert single-sided blocked routes (`_executeZapInDeposit` at `InBase.sol:74`, the blocked branches at `InBase.sol:227-240` and `OutExecutionDelegate.sol:38-52`, plus the matching previews) with `UniswapV3Exchange_BoundPoolInteractionBlocked`. This removes a PRD-preserved capability. No in-repo component enters the vault from a bound-pool callback.
- **Defense in depth:** charge at least the pool fee on the implicit swap, and cap how much of the free sleeve one blocked exit can take relative to its proportional share.

**Related.** APEX-2026-011, APEX-2026-023

---

<a id="apex-2026-025"></a>

### APEX-2026-025: Wings permissionless rebalance measures its loss cap at the manipulated or self-moved spot

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V4 UpperLowerWings

**Summary.** `RebalanceTarget.rebalance` has no access control and runs at whatever pool price is current. It sells pending target-token cash through `Planner.bestSwap`, whose price limit is just the projected post-sale price from the current `slot0`. The only economic guard, `_validate`, compares `LiquidationQuote.quote()` before and after against `progress / 100`. Both quotes are taken at the live spot: the pushed spot under a front-run (R2), or the spot the vault itself just moved (R1). The vault's price impact therefore cancels out of the measurement, and the 1%-of-progress cap never binds.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol:22-65`: no caller check. `before.value` is quoted at the current spot (27), and `_validate` (47-65) re-quotes at the post-swap spot (56). `minimum_` is chosen by the caller.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner.sol:11-47`: `bestSwap` sets `priceLimit = sale.sqrtPriceX96` (40), with no reference bound.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:108-153`: the quote reads live `getSlot0` (146) and `getLiquidity` (151).
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFacet.sol:11-13`: `rebalance` is exposed with no access modifier.

**Root cause.**
```solidity
uint256 maximumLoss = progress / 100;
valueAfter_ = Quote.quote(Common.quoteRequest()).value;          // live slot0 / liquidity, AFTER the vault's swap
if (valueAfter_ < before_.value && before_.value - valueAfter_ > maximumLoss) revert RebalanceLossExceeded(...);
```
The quote is `V = T + sell(O)`, starting at the current price.
- **R1:** the vault sells `x` token0 for `y` token1 (p0 → p1). `valueAfter` sells `y` back from `p1`, which reverses the vault's own trade, so the measurement sees only about two fees. The real loss is `x - y * P(p0)`.
- **R2:** `before.value` is quoted at the pushed price, where `sell(O)` is inflated (1.79e17 vs a fair 1.48e17). The measured delta is 179152854699968135 → 179046778813983188 (about 0.06%).

**Attack.** R2, in one transaction, with an attacker that holds no shares:
1. Swap token0-in by `push`, moving the price in the direction the vault will trade.
2. Call `wings0.rebalance(0, block.timestamp)`. `before.value` is inflated.
3. `bestSwap` sells the pending token0 deeper into the pushed curve.
4. `_validate` re-quotes at the displaced state, sees about 0.06%, and accepts.
5. Swap token1-in back to exactly `p0`, buying back cheap token0.

R1: with no manipulation, call `rebalance` when pending cash is large and back-run the vault's own oversized swap. `test_control_keeperThenArb` shows that an honest keeper followed by any arbitrageur causes the identical loss.

**Proof of concept.**
- `test/apex_audit/fz-wings-rebalance-sandwich/FzWingsRebalanceSandwich.t.sol` (R2): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-wings-rebalance-sandwich/FzWingsRebalanceSandwich.t.sol -vvv`
- `test/apex_audit/fz-wings-backrun-cap/FzWingsBackrunCap.t.sol` (R1): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-wings-backrun-cap/FzWingsBackrunCap.t.sol -vvv`

The first line below is a condensed transcription of the console output.
```
[PASS] test_PoC_final_pending5e16_push4e17(): baseline 147368916422241221 -> attack 136756748502693837; self-check 179152854699968135/179046778813983188; w/o rebalance -2068427301747557; profit 9085824211098070; victim loss 10612167919547384 (720 bps)
[PASS] test_PoC_backrunExceedsDesignedCap() (gas: 7366499)
  vault-measured loss / designed cap 225863871392249 946073961289528
  holders fair-mark loss @p0 (both vaults) 1688027299450192
  ATTACKER net profit @p0 (capital counted) 1463041355576058
  fair loss / cap x100 178
[PASS] test_control_keeperThenArb(): control holders fair loss 1688027299450192; control arb profit 1463041355576058
```

**Impact.**
- **R2** (5e16 pending, 4e17 push, L=1e18): the attacker makes +9,085,824,211,098,070 raw after all fees. The same push and restore without the rebalance loses -2,068,427,301,747,557. Holders lose 1.06e16 (720 bps) against an honest-keeper baseline.
- **R1:** the attacker makes +1.46e15 at D = 1e17, rising to +9.77e16 at D = 8e17. Holders' fair loss is 1.78x to 12.75x the designed cap (alice -11%).
- **At a 0% sleeve:** R2 +1.20e16 / 911 bps; R1 2.45x and 17.6x the cap.
- **Preconditions:** pending target cash, which is the normal state after any deposit. R1 exceeds the cap once pending is ≥ ~10% of external depth. On a settled vault (no pending cash), every push loses money for the attacker.
- **Who loses:** all remaining holders, pro rata.

**Fix.**
- **Smallest change:** record `sqrtPriceBefore` in `rebalance`. In `_validate`, value post-reshape inventory (locals + principal + fees) at that price instead of re-quoting at spot, or charge the realized impact against the cap: `impact = input - output * P(sqrtPriceBefore) <= maximumLoss`. This closes R1.
- **Bound the swap:** clamp `bestSwap`'s `priceLimit` to N bps of `sqrtPriceBefore`, or cap `input` per call.
- **Defense in depth:** a reference-price deviation guard (closes R2), optional keeper gating, and a regression test asserting fair loss ≤ `progress / 100`.

**Related.** APEX-2026-024, APEX-2026-012, APEX-2026-023

---

<a id="apex-2026-026"></a>

### APEX-2026-026: Wings liquidation quote hard-codes stepLimit=512, so dust ticks (or one trade at spacing 1) freeze deposit, redeem, getRate and liquidationValue

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** V4 UpperLowerWings

**Summary.** Every Wings valuation runs `LiquidationQuote._sell`. It removes the vault's own liquidity, then walks external liquidity one initialized tick (or one empty bitmap word) per step. `Common.quoteRequest()` hard-codes `stepLimit = 512`, and the walk reverts with `QuoteWorkExceeded(512)` if inventory is still unsold at that point. Deposit, redeem, the SY redeem, `getRate`, `liquidationValue` and `rebalance` all call the quote with no fallback. A few hundred liquidity-1 dust positions froze every holder exit. On a spacing-1 pool where the vault is the only LP, one ordinary trade has the same effect.

**Affected code.** Under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`:
- `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol:31`: `request_.stepLimit = 512;`, with no setter.
- `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:25, 302-303, 357-381`: `MAX_STEPS`, the revert, and `_next` (one step per tick or per word). `_removeOwned` (253-284) leaves foreign ticks in the walk.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:132, 160, 175, 228, 264`: the deposit, redeem, swapCost and preview quotes.
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:30` (`getRate`) and `UniswapV4UpperLowerWingsStandardExchangeVaultQueryTarget.sol:28-30` (`liquidationValue`).
- `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol:18` and `UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol:27, 56`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:124-126`: the pool is hookless (anyone can `modifyLiquidity`), and any `tickSpacing` in `[1, 32767]` is accepted.

**Root cause.**
```solidity
while (result_.unsold != 0 && result_.sqrtPriceX96 != priceLimit) {
    if (result_.steps == limit_) revert QuoteWorkExceeded(result_.steps);   // :303
    ++result_.steps;
    (step.tick, step.initialized) = _next(context_, result_.tick);          // one tick or one word
    ...
}
```
The walk takes about `steps ≈ (# foreign initialized ticks crossed) + (# empty bitmap words crossed)` steps.
- **Dust ticks:** a liquidity-1 tick absorbs nothing but still costs a step.
- **No external liquidity:** the walk runs to the price extreme, costing ≈ `|t − MAX/MIN_TICK| / (256 · spacing)` word steps. That is ≈3,466 at spacing 1 from tick 50.

**Attack.** Variant A (fee 3000, spacing 60, vault is the only LP):
1. Alice deposits 1e12 token0.
2. A trader swaps to tick 120. The vault now holds token1 (`unsold` 3,031,528,050), and the quote takes 58 steps.
3. An unprivileged attacker adds 480 adjacent `[k·60, (k+1)·60]` liquidity-1 positions starting at tick 180, using 120 `modifyLiquidity` calls in each of 4 transactions.
4. `quote()` now exceeds 512 steps and reverts.
5. Alice's redeem (100% and 1%), Bob's deposit, `getRate()` and `liquidationValue()` all revert.
6. Control: after the dust is removed, Alice's redeem returns 997,004,645,041.

**Proof of concept.** `test/apex_audit/wings-quote-cap-dos/WingsQuoteCapDos.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/wings-quote-cap-dos/WingsQuoteCapDos.t.sol -vvv`
```
[PASS] test_A_dustTicks_spacing60_freezesVault() (gas: 86343391)
  pre-attack quote steps 58
  alice redeem(all shares) -> QuoteWorkExceeded(512)
  alice redeem(1% shares) -> QuoteWorkExceeded(512)
  bob deposit -> QuoteWorkExceeded(512)
  getRate -> QuoteWorkExceeded(512)
  attacker net cost after unwinding 480
  alice redeem after unwind 997004645041
```
`test_B_natural_spacing1_soleLP` and `test_C_dustTicks_spacing1_withExternalLP` also pass, with the same reverts.

**Impact.**
- **Variant A:** 480 positions over 4 transactions cost 480 wei, which is not returned on unwind, plus ~80M gas (estimated). They freeze Alice's 1e12 position, new deposits and the rate feed (an `IRateProvider`).
- **Variant C** (spacing 1, external L = 1e12): 550 positions over 5 transactions, same result.
- **Variant B** (spacing 1, vault is the only LP): bricks after one trade, with no attacker.
- **Who loses:** no theft occurs. Shareholders cannot exit for as long as the dust remains and the vault holds opposing inventory.
- **Recovery:** swapping back through the wing, or adding concentrated external depth, unbricks the vault. There is no admin escape.

**Design/config note.** The owner explicitly requires work exhaustion to revert rather than be marked market-limited (`docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:30`, asserted by `test_liquidationWorkExhaustionIsNotMarketLimited`). A "break and set `marketLimited`" fix is therefore not acceptable. The same PRD also treats freezing all ordinary routes as a release blocker (:189, V2) and requires holder exits to be preserved (:308, SEC-10), so this remains a real liveness bug.

**Fix.**
- **Smallest change:** stop spending the step budget on dust. Skip initialized ticks with negligible `liquidityNet` under a separate, much larger iteration budget, or bound the walk by price distance instead of crossings.
- **Deploy-time check:** in `DFPkg._validate`, enforce `887272/(256*tickSpacing) < stepLimit` so that a full empty-word walk fits within the budget.
- **Optional:** a quote-free pro-rata in-kind exit would need a new owner ruling, because PRD :98 excludes a basket-exit fallback.

**Related.** APEX-2026-041, APEX-2026-012

---

<a id="apex-2026-027"></a>

### APEX-2026-027: Lido/EtherFi staking SE `rebalance()` re-queues the full deficit on every call, ignoring pending withdrawal face

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** Staking SE

**Summary.** `rebalance()` on the Lido and EtherFi staking SEs has no access control. When liquid WETH is below `target - band`, it queues `target - liquid` of LST for withdrawal, without subtracting requests that are already pending. Queuing moves value from LST into pending face, so `totalReserveEth()`, `target` and liquid WETH are all unchanged after the call, and the next call queues the same deficit again. Anyone can loop the call and push almost all LST into the withdrawal queue. NAV is unchanged; this is griefing, an in-kind exit freeze and lost yield, not theft.

**Affected code.**
- `contracts/protocols/staking/lido/LidoWstETHRebalanceTarget.sol:26-38` (l.34-35) and `contracts/protocols/staking/lido/LidoWstETHRebalanceTarget.sol:80-111`: `rebalance` and `_queueDeficit`.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:66-78, 300-304`: `totalReserveEth` includes pending face, and so does the target derived from it.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:97-102`: `_requireLockedWst` checks only the wstETH on hand.
- `contracts/protocols/staking/etherfi/EtherFiWeETHRebalanceTarget.sol:45-57, 84-116` and `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:84-96, 108-113, 317-321`: the same shape.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol:176-178` and `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeDFPkg.sol:193-195`: `REBALANCE_FACET` is always installed.

**Root cause.**
```solidity
function rebalance() external nonReentrant {
    _claimAndWrap();
    uint256 target = _targetLiquidEth();      // totalReserveEth() * pct; total INCLUDES pending face
    uint256 liquid = liquidReserveEth();      // WETH balance only; does NOT include pending face
    uint256 band = (target * REBALANCE_BAND_WAD) / ONE_WAD;
    if (liquid > target + band) {
        _stakeExcess(liquid - target);
    } else if (liquid + band < target) {
        _queueDeficit(target - liquid);       // pending face never subtracted
    }
    _syncAllExpectedHoldReserves();
}
```
With `total = W + L + P`, queuing `d = p*total - W` moves `d` from `L` to `P` and leaves `total`, `target` and `W` unchanged. The correct deficit is `max(0, target - W - P)`.

**Attack.**
1. An ordinary WETH exit drops `W` below `target - band`. In the PoC, a 3 WETH exit on a 200 ETH vault is enough.
2. The attacker's contract calls `vault.rebalance()` in a loop while `wstETH.balanceOf(vault) > 0`.
3. Each call queues another 2.85 ETH. After 67 calls in one transaction, the vault holds 0 wstETH.
4. Until the requests finalize, in-kind wstETH/stETH exits revert with `InsufficientLockedReserve`, and queued stETH earns no rewards.
5. After finalization, `rebalance()` claims and re-stakes the excess at the vault's cost. The attack can be repeated each time the sleeve dips below the band.

**Proof of concept.**
- `test/apex_audit/staking-requeue/StakingRequeue.t.sol` (Lido): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/staking-requeue/StakingRequeue.t.sol -vvv`
- `test/apex_audit/staking-requeue-etherfi/EtherFiRequeue.t.sol` (EtherFi, 20% default): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/staking-requeue-etherfi/EtherFiRequeue.t.sol -vvv`
```
[PASS] test_requeue_forcesWholeInventoryIntoQueue_DoS() (gas: 20066487)
  control: wstETH queued by one rebalance 2850000000000000000
  attacker rebalance calls 67
  wstETH left in vault 0
  ETH value forced into queue 190000000000000000000
[PASS] test_etherfi_requeue_prodDefault20pct() (gas: 9993297)
  attacker rebalance calls 34
  weETH forced into queue 160000000000000000000
```
The locked exits revert with `0x08e99b09` = `InsufficientLockedReserve`, decoded as `(50e18, 0)` and `(1e18, 0)`.

**Impact.**
- **Lido:** 67 calls in one transaction (~20.0M gas) queued 190 of 190 wstETH, ~67x the 2.85 ETH deficit and ~96% of the 197 ETH vault. NAV stayed at 197 ETH.
- **EtherFi** (20% default): 34 calls (~9.1M gas) queued 100% of the weETH.
- **Who loses:** all holders lose queue-period staking yield (analytic estimate: ~0.02-0.08 ETH over a 1-5 day queue) and pay for the unstake/restake round trip. In-kind exiters are blocked until finalization.
- **Attacker:** gains nothing and pays only gas.
- **No attacker needed:** an honest keeper calling `rebalance()` repeatedly causes the same over-queueing.

**Design/config note.** Permissionless `rebalance()` is intended (`ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md:26,51,193-213`). The `target - actualLiquid` deficit formula is written into the spec itself (`LIDO_WSTETH_STANDARD_EXCHANGE_VAULT_PRD.md:338-339`), while the same PRD counts in-flight requests as locked inventory (l.107, l.164, l.178). This is a spec inconsistency, not a chosen trade-off, so the spec should be corrected along with the code.

**Fix.**
- **Smallest change** (both families): subtract in-flight face from the deficit.
```solidity
} else if (liquid + band < target) {
    uint256 pending = LidoWstETHStandardExchangeRepo._pendingFaceStEthTotal(); // EtherFi: _pendingFaceEthTotal()
    uint256 covered = liquid + pending;
    if (covered + band < target) _queueDeficit(target - covered);
}
```
- **Coarser alternative:** skip queuing while `_requestIds().length > 0`.
- **Defense in depth:** cap total pending face at `target`, optionally keeper-gate or rate-limit `rebalance()`, and add a regression test that two consecutive calls queue exactly one deficit.

---

<a id="apex-2026-033"></a>

### APEX-2026-033: DETF primary redemption charges for a pro-rata slice of all protocol LP but pays only the tokenOut leg
**Severity:** Medium · **Status:** V4: code path present in deployed bytecode on Robinhood 4663 (DTF-DETF `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`, reserve hook `0x46E068c2393e189Fbc86632f67210aF253a42Aa8`), but not exploitable today: the burn gate is closed and the burn table accepts DTF only. ComposedStable / MixedBuffer / MultiVaultWeighted: Latent: not deployed · **Family:** DETF (ComposedStable, MixedBuffer, MultiVaultWeighted, UniswapV4 weighted)

**Summary.** When the burn gate is open (`synthetic < burnThreshold`), each affected family:
1. burns `detfIn`;
2. removes `lpOut = detfIn * protocolLp / totalSupply` through a proportional exit, which is a claim on all legs;
3. pays the redeemer only the `tokenOut` leg;
4. re-joins the other non-DETF legs into protocol LP.

The redeemer forfeits roughly `1 - v_out / Σ v_nonDETF` of their backing, and the forfeited value goes to the remaining holders. Previews return the same one-leg figure that execution pays, so `minAmountOut` / `maxAmountIn` give no protection. This is not a regression of this diff.

**Affected code.**
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:437-450` (`_burnHeld`), `:500-519` (`_payBurnOut` pays only `tokens_[i] == pair_`)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:485-507` (`_trySweepDust` re-joins the unpaid legs)
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:754-761` (exact-out sizing from one leg), `:917-935` (`_executeExactOutExit`, re-join at 934), `:843-851`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeOutTarget.sol:20-29`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeOutTarget.sol:23-28`

**Root cause.**
```
lpOut              = d * L / S                      // claim on ALL legs
(x_DETF, x_j ∀j)   = proportionalExit(lpOut)
paid               = x_out                           // only the tokenOut leg
rejoined           = x_DETF + Σ_{j≠out} x_j          // back into protocol LP
loss               = 1 - v(x_out) / Σ_j v(x_j)
```
For a weighted reserve, the loss is about `1 - w_out / Σ_{j∈J} w_j`. ComposedStable exact-out sizes the LP as if the selected leg were the whole backing (`lp_ = ceil(amount_ * totalSupply / raw_[leg_])`), so it charges 1.833x the DETF of the exact-in WETH route for the same output.

**Attack.** This is an honest-user loss; no attacker is required.
1. The DETF trades below backing, so `_isBurningAllowed()` / `_isBurningAllowedToken(tokenOut)` returns true.
2. A holder calls `exchangeIn(DETF, d, tokenOut, minOut, ...)`. On ComposedStable, `exchangeOut` also triggers it.
3. The contract burns `d` and exits `lpOut` proportionally.
4. It pays only `x_out`. The preview quoted the same amount, so `minOut` passes.
5. The other legs are re-joined. LP per remaining DETF rises, and remaining holders gain pro rata.

**Proof of concept.** Three test files:
- `test/apex_audit/sib-detf-leg-forfeit/V4WeightedLegForfeit.t.sol`
- `test/apex_audit/chain-detf-system/AdjRealCapital.t.sol` (production weights 60/20/20)
- `test/apex_audit/r3-H3SP-1/H3SP1_OneLegRedemption.t.sol` (ComposedStable)

Other runs: `test/apex_audit/sib-detf-leg-forfeit/MixedBufferLegForfeit.t.sol`, `test/apex_audit/sib-detf-leg-forfeit/MvwLegForfeit.t.sol`.
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/sib-detf-leg-forfeit/V4WeightedLegForfeit.t.sol -vvv
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/chain-detf-system/AdjRealCapital.t.sol -vvv
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r3-H3SP-1/H3SP1_OneLegRedemption.t.sol -vvv
```
```
  synthetic / burnThreshold  947539866948285181 950000000000000000
    slice tokenOut leg          1409412999629473520
    received                    1409412999629473520
    alice loss bps of backing   4836
  ADJCFG burn d / received / slice pair0 1233772759 3532905037806629593 3532905037806629593
  ADJCFG loss bps of non-DETF backing 4998
  exactOut/exactIn x1e4       18333
  alice loss bps of fair      4545
```

**Impact.** Executed loss per primary burn, as a share of the redeemer's non-DETF backing:

| Family | Loss |
|---|---|
| V4 weighted, 40/30/30 (production thresholds, gate opened by market sells) | 48.36% |
| V4 at production weights 60/20/20 (gate opened by config) | 49.98% |
| ComposedStable | 45.45% (10.1486 WETH on exact-out) |
| MixedBuffer | 54.50% / 45.49% |
| MVW, N=2 / N=3 | 50% / 66.66% |

Preconditions: the burn gate is open and the DETF has at least 2 non-DETF legs (2-token DETFs are unaffected). At production 60/20/20 weights the PoC could not open the gate through public selling, and the live instance's synthetic price is far above the burn threshold. The path is therefore reachable only in a real below-backing market. The redeemer loses and non-redeeming holders gain. No standalone attacker extraction was demonstrated.

**Design/config note.** The cited `DETF_ALIGNMENT_PRD.md` §15.3 ("rejoin all other legs") is ambiguous. The V4 routing law resolves it against the current behavior: `DETF_INSTANCE_IO_ROUTING_PRD.md:714` reads "Burn | Prop remove + **rejoin DETF**; **consolidate residual to `tokenOut` pair**." Medium rests on the V4 family. The Balancer parts are frozen under D60 (`DETF_ALIGNMENT_PRD.md:100`) and should be treated as Low unless they are revived.

**Fix.** Keep `lpOut`, the proportional exit and the DETF self-leg re-join, but convert every non-DETF leg into `tokenOut` before paying, and enforce `minAmountOut` on the total:
- **V4:** in `_payBurnOut`, swap each non-selected `withdrawn_[i]` into `pair_` through the hook. This is compatible with H10.
- **ComposedStable:** route all primary burns through the consolidating logic (852-860), and size exact-out from the consolidated value.
- **MixedBuffer / MVW:** convert the non-selected legs instead of re-joining them.

Update the previews in the same change. Defense in depth: add a fuzz test asserting `value(received) ≥ (1 - fee - ε) * Σ_j value(x_j)`.

---

<a id="apex-2026-034"></a>

### APEX-2026-034: First-deposit share inflation on the ReceiptBacked ERC-4626 SE (plus Morpho Blue SE variant)

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** ERC4626 SE / Morpho Blue SE

**Summary.** When the ERC-4626 SE has zero supply, it mints shares 1:1. Otherwise it mints `floor(delta * S / backing)`, and `backing` is the vault's live `balanceOf` of the receipt token, so a plain transfer counts as backing. There is no virtual offset, no dead-share seed and no `shares == 0` revert. `deployVault` is public and its salt depends only on the protocol vault. An attacker can therefore create the canonical SE, deposit 1 wei, donate `D` receipts, and take any later deposit below `D + 1` made through `IERC4626.deposit` or `exchangeIn(minAmountOut = 0)`. The Morpho Blue SE variant (offset 0 plus virtual +1) is Low on its own.

**Affected code.**
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:54-61` (`sharesFromReceiptUnits`: 1:1 at zero supply, else rounds down, no offset); `:23` (backing = live `balanceOf`)
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:100-112` (`deposit`: no `shares > 0` check)
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:53-63, 69-80` (`exchangeIn`: 0 shares passes when `minAmountOut == 0`)
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol:86-91` (public `deployVault`), `:197-199` (salt = `keccak256(pkgArgs)`), `:211-212, 228-230` (offset 0, no seed)
- Morpho: `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol:222` (offset 0); `MorphoBlueERC4626Target.sol:76-81` (`deposit` hard-codes `minAmountOut = 0`)

**Root cause.** With `S` = SE supply and `B` = receipt backing before the deposit:
```
shares(x) = (S == 0 || B == 0) ? x : floor(x * S / B)
assets(s) = floor(s * B / S)
B         = receipt.balanceOf(SE) + receipt.convertToShares(bookedUnderlying)
```
A direct transfer raises `B` without minting shares. With `S = 1`, any `x < B` rounds to 0 shares, and nothing reverts on a zero-share mint. In the Morpho SE the formula reduces to `shares = floor(x * (S + 1) / (NAV + 1))`, and NAV includes Morpho supply donated `onBehalf` of the SE.

**Attack.**
1. Call `ERC4626StandardExchangeDFPkg.deployVault(protocolVault)` for a protocol vault that has no SE yet. The new SE has `S = 0`, `B = 0`.
2. `SE.deposit(1, attacker)` mints 1 share.
3. `transfer` `D` receipts directly to the SE: `S = 1`, `B = D + 1`.
4. A victim calls `SE.deposit(X, victim)` with `X < D + 1`, or `exchangeIn(..., minAmountOut = 0)`. They receive 0 shares and the call succeeds.
5. `SE.redeem(1, attacker, attacker)` returns `D + 1 + X`.
6. If no victim arrives, the attacker redeems and recovers `D + 1`. There is no principal risk.

**Proof of concept.** `test/apex_audit/receiptbacked-inflation/ReceiptBackedInflation.t.sol` (Morpho variant: `test/apex_audit/gx-morpho-blue-se/MorphoBlueSE_GX.t.sol`, tests `test_T2*`)
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/receiptbacked-inflation/ReceiptBackedInflation.t.sol -vvv
```
```
[PASS] test_control_exchangeInWithMinOutReverts() (gas: 10995890)
[PASS] test_inflation_partialTheft_largerVictim() (gas: 11252929)
  attacker profit 4999499999999999999999
[PASS] test_inflation_victimGetsZeroShares_attackerStealsDeposit() (gas: 11210366)
  victim deposited receipts 9999000000000000000000
  victim shares minted 0
  attacker redeemed receipts 19999000000000000000001
  attacker profit (receipts) 9999000000000000000000
```

**Impact.** With `D = 10,000e18` donated and a victim deposit of `X = 9,999e18`, the victim gets 0 shares. The attacker redeems `19,999e18 + 1` and nets 9,999e18 receipts, the whole deposit. With `X = 19,999e18`, the attacker takes 4,999.5e18. Victims with `X <= D` lose everything. Those with `D < X < 2(D + 1)` lose `(X - D - 1) / 2`. The donation is fully recoverable. Slippage-bounded `exchangeIn` (`minAmountOut >= 1`) reverts, so only raw `IERC4626.deposit` callers and `minOut = 0` callers lose. Morpho: a single victim leaves the attacker at `-2,500.5e18` (griefing only). Four zero-share victims of `5,000e18` give the attacker `+5,000e18`, and victims lose `20,000e18`.

**Fix.**
- Revert with `ZeroShares()` when `shares == 0` in `deposit` and in every share-minting `exchangeIn` path (including the Stata equivalents).
- Add a virtual offset (for example `10**6`) to all four conversions in `ReceiptBackedERC4626AccountingLib` and remove the `supply == 0` 1:1 branch. The zero-share revert alone does not stop partial theft.
- Defense in depth: count only booked receipts as backing instead of `balanceOf`. Seed dead shares in `postDeploy`, or restrict `deployVault` to owner/operator.
- Morpho: initialise with `decimalOffset >= 6` (`MorphoBlueStandardExchangeDFPkg.sol:222`) and revert when `sharesOut == 0` in `_execWrapExactIn`.

**Related.** Aave V3 Stata SE shares the conversion shape (`contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:206-217`, not executed). APEX-2026-039 covers the Morpho B2 `owner = address(this)` case.

---

<a id="apex-2026-035"></a>

### APEX-2026-035: Aave cross-version loop floors the tokenB net at 0 and has no tokenA<->tokenB route, so a liquidation overpays the first exiter or locks most of NAV

**Severity:** Medium · **Status:** Latent: not deployed · **Family:** Aave cross-version loop

**Summary.** The loop's NAV is `netA*pA + max(0, S_B - D_B)*pB`, where `S_B` is V4 tokenB supply and `D_B` is V3 tokenB debt. Raw tokenB is not counted. Exits pay only tokenA, and the vault has no way to convert between tokenA and tokenB. In normal operation `S_B` and `D_B` move together. An Aave liquidation of either leg breaks that:
- **V4 liquidation:** NAV hides a tokenB deficit, so the first exiter is overpaid at the expense of the remaining holders.
- **V3 liquidation:** a tokenB surplus is counted in NAV but cannot be delivered, and 67% of NAV stays locked.

**Affected code.** (under `contracts/protocols/lending/aave/cross-version/`)
- `CrossVersionLoopExecutor.sol:271` (`netBalanceOf` floors a deficit at 0)
- `CrossVersionLoopExecutor.sol:392-399` (`navUsd`: floored tokenB, raw tokenB ignored; this prices deposits, redeems and `exchangeRate`)
- `AaveCrossVersionLoopExchangeBase.sol:143-149` (`_amountForShares`: tokenA-only payout, capped by `localTokenA + proportionalFreeableA`)
- `CrossVersionLoopExecutor.sol:316-318, 332-336` (`proportionalUnwind` repays V3 tokenB debt only from V4 tokenB supply)
- `AaveCrossVersionLoopRebalanceTarget.sol:72-102` (`forceRepay`/`rebalance` are permissionless and pay no reward)

**Root cause.**
```solidity
// CrossVersionLoopExecutor.sol:262-272
return supplied >= debt ? supplied - debt : 0;          // :271 floor
// :392-399
netB = netBalanceOf(tokenB);                            // floored; raw tokenB ignored
return netA*pA/1e18 + netB*pB/1e6;
// AaveCrossVersionLoopExchangeBase.sol:143-149
deliverable = localA + floor(phi*S_A) - ceil(phi*D_A);  // tokenA legs only
```
`NAV_rep - NAV_true = (D_B - S_B)*pB` when `D_B > S_B`. An exiter of fraction `phi` is overpaid by `phi*(D_B - S_B)*pB`. The remaining V3 tokenA collateral is pinned behind V3 tokenB debt that nothing in the vault can repay. When `S_B > D_B`, the surplus is in NAV but no exit path ever withdraws it.

**Attack.** (G7b. The attacker is an ordinary holder.)
1. Alice and the attacker each deposit 100 A (tokenA $2,000, tokenB $1).
2. tokenA rises about 28% until V4 HF < 0.97. Nobody calls the unpaid `forceRepay` in the 1.05 to 1.00 window.
3. A V4 `liquidationCall` seizes V4 tokenB supply. V3 tokenB debt (about 108,161 tokenB) stays.
4. The attacker redeems first and is paid at the overstated NAV.
5. Alice cannot fully exit, because her remaining collateral sits behind unrepayable V3 tokenB debt (V4 `sB = 0`).

Any first exiter after a V4 liquidation gets the same overpayment. The liquidator leg contributed only $561.

**Proof of concept.** `test/apex_audit/gx-aave-cross-version-loop/GxAaveLoopAdversarial.t.sol` (tests `test_G7b`, `test_G10`)
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/gx-aave-cross-version-loop/GxAaveLoopAdversarial.t.sol -vvv
```
```
[PASS] test_G7b_PoC_v4Liquidation_firstExiterOverpaid_victimLoss() (gas: 152366440)
  post-liq navTrue - navReported (USD 1e8): -10815809137900
  fair claim each holder post-liq (A): 99878414708319591315
  attacker exit received (A): 120962981337204176080
  alice received (A): 60481263444939433640
  alice loss vs post-liq fair (USD 1e8): 10104833458087
[PASS] test_G10_v3Liquidation_positiveNetB_lockedForAllHolders() (gas: 48375066)
  value left in vault (USD 1e8): 20890030988861
  holders realized % of true NAV: 33
```

**Impact.**
- **G7b:** the hidden deficit is $108,158.09. The first exiter receives 120.963 A against a fair 99.878 A, an overpayment of $54,079.05. Alice realizes 60.481 A, a $101,048.33 loss against her fair claim.
- **G10:** holders realize $104,545.82 (33%) of a true NAV of $313,446.13. $208,900.31 stays locked, owned by the 1000 dead shares.
- **Preconditions:** a move of about +28% or -19% that liquidates one leg before anyone calls `forceRepay`, and the attacker must already hold shares.
- **Who loses:** the last exiters (G7b) or all holders pro rata (G10).

**Design/config note.** The G7b deficit contradicts PRD decision 16 (`prds/AaveV3V4CrossVersionCarryLoopVault.md:56`: net reserves `R_A, R_B >= 0` must be maintained). The G10 off-token lock is largely a known v1 limitation (decision 17, `PRD:57`), and the unpaid keeper is accepted design (decision 7, `PRD:44`). Severity stays Medium.

**Fix.**
- Value tokenB signed and include raw tokenB in `navUsd`: `netB = S_B + rawB - D_B` (signed), so a deficit reduces NAV. This removes the G7b transfer. Apply it to every place `navUsd` is used.
- Add a delivery route for imbalances. Either a pro-rata dual-token exit or a tokenB exit for a surplus, or a bounded, oracle-priced tokenA->tokenB swap leg in the unwind paths to clear a deficit. Alternatively, block deposits and pay exits on the deliverable basis while `D_B > S_B + rawB`.
- Defense in depth: pay `forceRepay` a bounty or de-risk at a higher HF, and add a post-exit invariant on `|S_B + rawB - D_B|`.

---

<a id="apex-2026-023"></a>

### APEX-2026-023: FullSpread maintenance mints idle excess at a displaced spot (JIT impermanent loss)

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V3 FullSpread + V4 FullSpread hookless

**Summary.** Both maintenance entry points size and run the mint from the pool's current `slot0`: the permissionless `rebalanceLiquidReserve()` and the best-effort `_rebalanceLiquidReserveBestEffort()` that runs after deposits, redemptions and direct swaps. Nothing checks that price against a TWAP, an oracle or the pre-operation price. An attacker who first creates mintable idle excess and then displaces the spot can make the vault add liquidity at the displaced price. Swapping back to fair takes the impermanent loss on that new liquidity, and the honest LPs bear it.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol:75-79`: permissionless `rebalanceLiquidReserve()` with no price check.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:422-429, 673-751`: the mint is planned at live `slot0`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:540-565, 810-823`: the vault's redemption `_swap` uses a full-range price limit and `minAmountOut = 0` (line 821).
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:245-261`: `_executeFreeZapOutExactIn` runs the best-effort rebalance at line 260, right after the vault's own swap.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:129-169`: a blocked dual deposit skips maintenance (163-168).
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:630-652`: placement at the snapshot (live) price.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:145-191, 207`: `REBALANCE_IMPACT_BPS` is measured from the already-displaced spot.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol:190-233, 332-376`: same zap-out and blocked-deposit pattern (line 232).
- Pons V2 hook FullSpread (`ponsFamilyV2Hook/...InBase.sol:126, 232, 372`) has the same call sites. It was read but not executed.

**Root cause.**
```solidity
// Common.sol:422-428
function _managedLiquidityPlan(ManagedTicks memory managedTicks, uint256 available0, uint256 available1) ... {
    (,, uint160 sqrtPriceX96,,) = _loadPoolState();          // live slot0
    return _managedLiquidityPlanAtState(managedTicks, available0, available1, sqrtPriceX96);
}
```
Liquidity `dL` minted at `P'` and returned to `P0` loses `IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'` (full-range approximation, in token1). The attacker bears only its pro-rata share of that loss. An unprivileged user can create both preconditions:
- **Idle excess:** a two-sided deposit made while the pool is locked (from the attacker's own 1-wei swap callback or unlock session) skips maintenance. In V3, an idle single-sided zap-in also works.
- **Displaced spot:** an external push followed by `rebalanceLiquidReserve()`, or the vault's own unbounded redemption swap followed in the same call by the best-effort rebalance.

**Attack.** Route B (V3, one flash-funded transaction):
1. Flash-borrow.
2. Inside a 1-wei `pool.swap` callback, make a fair dual deposit (`exchangeInManyToOne`) at P0. Maintenance is skipped, leaving two-sided excess.
3. Push the price (x2 or x4).
4. Call `rebalanceLiquidReserve()`. Vault L goes from 800000e15 to 1318829e15 (x2 case).
5. Swap back to exactly sqrtP0.
6. Exit pro-rata at P0 and repay the loan.

Route I (V3, own capital, no blocked mode) differs: a large single-sided zap-in, then a zap-out of 67% of the shares. The vault's own swap moves sqrtP to 5.3955x, and the trailing rebalance mints at that price.

**Proof of concept.**
- `test/apex_audit/probe-maintenance-jit/MaintenanceJit.t.sol` (Route B): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/probe-maintenance-jit/MaintenanceJit.t.sol -vvv`
- `test/apex_audit/fz-v3fs-deep-inv1/SkewZapOutJit.t.sol` (Route I): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-v3fs-deep-inv1/SkewZapOutJit.t.sol -vvv`
- `test/apex_audit/fz-fs-self-jit-redeem/SelfJitRedeem.t.sol` (V4 hookless): `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-fs-self-jit-redeem/SelfJitRedeem.t.sol -vvv`
```
[PASS] test_B_blockedDeposit_push2x_lambda2() (gas: 25497027)
  vault L before / after rebalance (e15): 800000 1318829
  ATTACKER NET PnL (token1-equiv wei, P0): 25045680416561640738
  VICTIM LOSS (wei, P0): 30390788137266175697
[PASS] test_poc_skewZapOutJit_main() (gas: 3698660)
    [ev] VAULT MINT L / a0 / a1 946790819816840944904 175477452125483836188 5108421883447574797447
    ATTACKER NET PROFIT at P0 (wei) 78650522117261846607
    HONEST LP LOSS at P0 (wei) 91223069624740186313
```

**Impact.**
- **Route B (honest TVL 2000):** +25.05 (vault ~50% of L, price x2; LP loss 30.39, 1.52%); +68.09 (x4; 77.95, 3.90%); +4.06 (vault ~10%); +66.60 over 3 rounds (82.44, 4.12%).
- **Route I:** +78.65e18 with honest LPs -91.22e18 (~2.2% of ~4200e18). It needs capital several times honest TVL and tuned parameters; nearby parameter sets lose.
- **V4 hookless:** +5.91e18 (~0.16% of NAV); unprofitable at ~15% vault share.
- **Who loses:** honest LPs, pro rata.
- **Break-even:** about 10% vault share (Route B) and about 15% (V4).

**Design/config note.** The PRD specifies maintenance "at the current pool price" (`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` D21, l.50) and declines an independent-reference oracle (l.351), so this behavior is a documented trade-off. At production-like depth (~2% vault share, `test/apex_audit/adj-fullspread-blocked/AdjMaintJitProd.t.sol`), Route B either cannot repay its flash loan or loses -32.53e18 to inflict 2.91e18. Severity was lowered from Medium to Low. One hardening item remains (see Fix).

**Fix.**
- **Smallest change:** after the vault's own redemption swap, limit the trailing `_rebalanceLiquidReserveBestEffort()` to burn/refill only. The locations are V3 `InBase.sol:260`, V4 `InBase.sol:232` and Pons `InBase.sol:232`. This closes Route I and the V4 route without a reference oracle.
- **Defense in depth:**
  - Bound the redemption swap (`Common.sol:821`) with a price limit taken from the pre-operation price.
  - Record blocked-mode excess and gate when it can be deployed.
  - Optionally, add a spot-vs-TWAP deviation guard before maintenance mints. This closes Route B but conflicts with D21 / l.351, so it needs owner authorization.
- **Integrators:** document that a vault holding a large share of a shallow pool's liquidity (for example, Pons v1 V3 pools right after creation) is exposed.

**Related.** APEX-2026-022, APEX-2026-025

---

<a id="apex-2026-024"></a>

### APEX-2026-024: Wings redeem dumps the entire opposing balance at a MIN/MAX price limit when a large exit closes the core

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 UpperLowerWings

**Summary.** Sometimes a redemption exceeds local target cash plus the target wing plus the core's target-side principal. When that happens, `Money._fund` closes the core and calls `_swapDeficit`. That function sells the vault's whole opposing-token balance exact-in with a `MIN_SQRT_PRICE+1` / `MAX_SQRT_PRICE-1` limit, instead of selling only the shortfall. The staying holders' share of that inventory is sold at a heavily slipped price, and back-runners capture the difference. `HolderValueLoss` does not trigger, because it compares against a liquidation quote at the same state, and that quote already assumes the same full dump.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:190-209`: `_fund` closes the core (`_close(0)` at 206) and then calls `_swapDeficit` at 207.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:219-233`: `_swapDeficit` makes a whole-balance exact-in swap with a MIN/MAX limit.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:174-177`: remaining-holder check against a same-state liquidation quote.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol:157-167`: `liquidFloor`. With a 20% sleeve, only ≈16.7% of target-side holdings stays liquid.

**Root cause.**
```solidity
function _swapDeficit(uint256 required_) private returns (uint256 costBound_) {
    uint256 opposing = state.target0 ? state.local1 : state.local0;
    if (opposing == 0 || _localTarget() >= required_) return 0;
    costBound_ = Quote.swapCost(Common.quoteRequest(), opposing);
    operations[0] = Common.Operation(Common.Kind.Swap, 0, 0, 0, -int256(opposing), !state.target0,
        state.target0 ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1);
    Common.execute(operations);
}
```
- **Size:** the swap sells `opposing`, not `required_ - _localTarget()`. In the PoC the shortfall was about 2.7e16, but about 1.1e17 token1 was sold.
- **Price limit:** none, so the swap fills at a price the caller has already pushed.
- **Guard reference:** `value` (before) already prices the whole opposing inventory as dumped. After the dump, `afterValue ≈ value - assets_`, and `costBound = swapCost(opposing)` adds more slack. The check therefore passes by construction.

**Attack.**
1. The vault is settled at `p0` with most of its value in the core.
2. An honest holder of 2/3 of supply redeems with `minimum = 99%` of the liquidation quote.
3. (Optional) The searcher front-runs +200 ticks in the dump direction, which stays within the exiter's 1% slippage.
4. The redeem closes the core and sells the vault's entire token1 balance. sqrtP moves from 7.9228e28 to 8.9405e28 (≈ +27.3%).
5. `HolderValueLoss` passes. The exiter receives the liquidation-value entitlement.
6. The searcher swaps back to exactly `p0`.

Variant B (self-triggered, single transaction): deposit 2e17, call the permissionless `rebalance(0, ts)`, redeem everything, and back-run.

**Proof of concept.** `test/apex_audit/wings-forced-dump/WingsRedeemDump.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/wings-forced-dump/WingsRedeemDump.t.sol -vvv`
```
[PASS] test_PoC_redeemForcedDumpBackrun() (gas: 32814524)
    price after redeem (sqrtX96) 89404950766515596538724294705 p0 79228162514264337593543950336
  RESULT backrun profit 14278597739942753
  RESULT sandwich profit 16629355760207475
  RESULT staying-holder loss (backrun) 5002537745942445
  RESULT staying-holder loss bps (sandwich) 614
  RESULT self-triggered attacker profit 1428026812410084
  RESULT self-triggered holder loss 2167543007174308
```

**Impact.** Measured on a 66.7% exit at L=1e18:

| Scenario | Attacker profit | Staying holder |
|---|---|---|
| Back-run only | +1.428e16 | 9.448e16 → 8.948e16 (-5.00e15, 5.3%) |
| +200-tick front-run, then back-run | +1.663e16 | -5.81e15 (614 bps) |
| +300-tick front-run | exit reverts (`MinAmountNotMet`) | unchanged |
| Self-triggered, 2e17 deposit | +1.428e15 | -2.17e15 (2.2%) |
| Back-run only, L=3e18 | +5.27e15 | ≈2.1% |

- **Control:** a 50% exit does not close the core, and the stayer gains 5.00e15.
- **Precondition:** an exit larger than ~52% of supply in this fixture, or attacker capital of ~2x the existing supply (returned within the transaction, no flash loan needed).
- **Who loses:** the staying holders.

**Design/config note.** The PRD values shares at liquidation proceeds, not spot mark (`docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:107,181`), and favors sufficient over exact-fit conversion (:63, :245). On that basis, the back-run-only case preserves the stayer's share to the wei (`262512925164306537/3 = 87504308388102179` before vs `87504308388102178` after, 0% sleeve). That portion is a design trade-off, which is why severity was lowered from Medium to Low. The sandwich portion is a real bug. At the production 0% sleeve, after a +200-tick front-run, the stayer holds 86,634,731,327,479,503 versus 87,504,308,388,102,179 (8.70e14, 99 bps, in liquidation-value terms). SEC-08 (PRD :334) and PRD :247 forbid this.

**Fix.**
- **Smallest change:** in `_swapDeficit`, swap only `deficit = required_ - _localTarget()`, either exact-out or as a bounded exact-in from the `LiquidationQuote` stepper, with `amountIn` capped at `opposing`. Replace `MIN/MAX±1` with a limit derived from the pre-call `slot0` (or a stored mark/TWAP) plus a maximum deviation, and revert if the shortfall cannot be filled within it.
- **Defense in depth:** in the check at Money.sol:174-177, measure stayer harm against a fair mark at the reference price, and set `costBound = swapCost(deficit)`. Cap single-transaction exits that would close the core.

**Related.** APEX-2026-025, APEX-2026-012

---

<a id="apex-2026-028"></a>

### APEX-2026-028: DUAL CP buffer hook pays 0 on a single-asset exit to an identity leg but still burns the caller's LP
**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 SE buffer hooks (DUAL CP)

**Summary.** When a DUAL hook has an identity leg (the pair token is itself the wrapper-share SE, `tokenN == standardExchangeN`), a composed single-asset exit to that leg always returns `amountOut = 0`, but the caller's LP is still burned. `_exitSingleAssetFrom` measures the payout as the change in the hook's own balance of the out-token. On the identity path every step either does nothing or transfers from the hook to itself, so that balance never moves. The burned position's value goes pro rata to the remaining LPs. The preview functions return the correct non-zero amount, so callers who set a minimum from the preview always revert, and callers with `min = 0` lose the whole position.

**Affected code.** Paths are under `contracts/hooks/uniswap/v4/standardExchange/dual/`; `Common.sol` = `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`.
- `Common.sol:786-812` `_exitSingleAssetFrom`: `:798` snapshots `beforeOut`, `:809` `amountOut = balanceOf(pair) - beforeOut`
- `Common.sol:370-380` `_unwrap`, `:372` `if (se == pairToken) return seIn;`
- `Common.sol:740-779` `_withdrawFrom`: burns LP at `:759`; at `:761-764` the transfer is a self-transfer when `to == address(this)`
- `Common.sol:1079-1087` `_unwrapPlanned`, `:1081` `if (se == pair) return output.shares;`
- `Common.sol:1089-1099` `_executePlannedSwap`: its return value is ignored by `_exitSingleAssetFrom`
- Entry points: `UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol:140-148` (`exitSingleAssetExactBptIn`), `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityExecutionBase.sol:23-24` (`exchangeIn(LP -> token)`), `UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol:52-56` (SY `_redeemVaultHeld`, found by code reading)

**Root cause.**
```solidity
// Common.sol:798-811
state.beforeOut = IERC20(state.pair).balanceOf(address(this));
(uint256 a0, uint256 a1) = _withdrawFrom(holder, sharesIn, address(this), 0, 0, deadline, false);
uint256 residual = state.outIs0 ? a1 : a0;
if (residual > 0) {
    BookSwapPlan memory plan = _planExactIn(!state.outIs0, residual);
    if (plan.output.amount > 0) {
        _executePlannedSwap(plan, true, address(this));      // return value discarded
    } else { ... }
}
amountOut = IERC20(state.pair).balanceOf(address(this)) - state.beforeOut;   // :809
```
For an identity leg (`se == pair`):
- The withdrawn out-leg share passes through `_unwrap` unchanged (`:372`) and is then transferred from the hook to itself (`:763`).
- The swapped-in residual stays in the hook as `output.shares` (`:1081`).

The hook's `pair` balance does not change, so `amountOut = 0` for every input. The correct payout, `seOut_out + output.shares`, is computed during the call but never reaches `amountOut`. Non-identity legs (`se != pair`) pay normally.

**Attack.**
1. A DUAL hook is deployed with an identity leg: `token0 == standardExchange0 ==` a wrapper-share vault (e.g. `RebasingAwareERC4626`).
2. The attacker LP and the victim LP each make an ordinary balanced deposit.
3. The victim, or an integrator, router or vault acting for them, exits to the identity leg with `amountOutMin = 0` through `exitSingleAssetExactBptIn`, `exchangeIn(LP -> wrapper)`, or SY redeem of vault-held LP.
4. The hook burns the victim's LP, pays `0` and keeps all the underlying value.
5. The attacker calls `withdraw` (proportional) and receives its enlarged pro-rata share.
6. Any caller that sets its minimum from the preview gets a revert instead.

**Proof of concept.** `test/apex_audit/dual-identity-zero/DualIdentityOutlegZero.t.sol`
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/dual-identity-zero/DualIdentityOutlegZero.t.sol -vvv
```
```
[PASS] test_control_nonIdentityOutLeg_pays() -- control tokenB pred/got 49341567820148351517 73956800803229615683
[PASS] test_identityOutLeg_exchangeIn_LPtoWrapper_paysZero() -- exchangeIn preview LP->wrapper 666666666666666667102385405073; exchangeIn got 0
[PASS] test_identityOutLeg_minZero_paysZero_burnsLP_attackerCaptures()
  victim preview single-asset out (wrapper shares) 666666666666666667102385405073
  victim amountOut returned 0
  victim LP after 0
  hook wrapper bal before/after 2000000000000000000000000000000 2000000000000000000000000000000
  attacker profit (tokenA-eq) 110710570790547967012
  victim loss (tokenA-eq) 116008234486815018227
```

**Impact.** The victim's proportional claim was 116.008 tokenA-eq. It received exactly 0, and its LP (`50.491e18`) was fully burned. The hook's wrapper balance stayed at `2e30`. The remaining LP's claim rose from 228.619 to 339.329, a profit of **+110.711 tokenA-eq** against a victim loss of **116.008 tokenA-eq** (valued at an assumed 1:1 tokenA/tokenB). A minimum set at 99% of the preview reverts. Preconditions: a DUAL instance with an identity leg, and an exiting party that passes `amountOutMin = 0`. No third party can force the loss. The beneficiary is a passive co-LP who spends nothing.

**Design/config note.** Downgraded from Medium because:
- the loss happens only when the exiting party itself passes `amountOutMin = 0`;
- proportional `withdraw` still works as an exit;
- no deploy script or manifest references a DUAL buffer-hook package.

Identity legs are a supported configuration (`interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol:57`: "optional on an identity leg").

**Fix.** In `_exitSingleAssetFrom`, compute the payout from amounts the call already has, not from a balance delta:
- `outLeg = state.outIs0 ? a0 : a1` from `_withdrawFrom`;
- `swapOut` = the return value of `_executePlannedSwap`;
- `amountOut = outLeg + swapOut`;
- revert if `amountOut == 0`.

This is correct for both leg kinds. Defense in depth:
- revert whenever `sharesIn > 0 && amountOut == 0`;
- assert that `amountOut` is within rounding of `previewExitSingleAssetExactBptIn`;
- add identity-leg single-asset exit tests for every buffer-hook family that accepts `isWrapperShareInventory` legs.

Orbital uses the same pattern (`orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1378-1398`, `_freeTokenBalance` `:2197`; not executed) and needs the same fix.

---

<a id="apex-2026-029"></a>

### APEX-2026-029: SE rate provider's full-book valuation of a BPT-as-SE subject moves with pool composition; the Curve quad credits buffered inflow at the pumped rate
**Severity:** Low · **Status:** Latent: not deployed (Curve quad package `0x94d7aEFb0c6F5533432281C1c2591a37f422D7dC` registered with 0 instances; no Balancer V3 pool or BPT-as-SE subject on 4663) · **Family:** Balancer rate provider + V4 SE buffer hooks (curve quad)

**Summary.** `StandardExchangeRateProviderFacet._getRate` sets the rate to the quoted liquidation of the whole supply: `previewExchangeIn(subject, totalSupply, rateTarget) / totalSupply`. When the subject is a Balancer V3 pool (BPT-as-SE), a full-supply exit is quoted as the live face balance, so `RP = balanceLive[face] / totalSupply`. That rate ignores the pool's other tokens and moves linearly with pool composition. The Curve quad stable buffer hook values a buffered leg's reserve and inflow as `shares × RP`, and a stableswap curve is not invariant when one leg is rescaled. An attacker can therefore pump `RP` with a swap and sell into the quad at the pumped rate.

**Affected code.**
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61-83` (`_getRate`; `:80`, `:82`)
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolLiquidationLib.sol:251-259, 276-278` (`valuationOnly`), `:149-151`
- `contracts/protocols/dexes/balancer/v3/pools/stable/BalancerV3StableBufferPoolQuoteTarget.sol:199-203`
- `contracts/protocols/dexes/balancer/v3/pools/weighted/BalancerV3WeightedBufferPoolQuoteLib.sol:253`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:82-98, 114-124, 126-139, 212-227`

**Root cause.**
```solidity
// BalancerV3StableBufferPoolQuoteTarget.sol:199-203
uint256 newSupply = p.supply - p.amountScaled18;          // = 0
// Full-reserve valuation is defined even when execution capacity is smaller.
if (newSupply == 0) return (p.balancesLiveScaled18[p.index], fees);
```
This gives `RP = balanceLive[face] / totalSupply(BPT)`, so `RP' − RP = Δbalance[face] / supply`. In the quad:
```
rated reserve_i = seBal_i × RP_i
rated inflow    = previewExchangeIn(face_i → BPT_i, netIn) × RP_i
shares out_j    = budget_j / RP_j
```
Pumping `RP_i` by a factor `k` scales both `x_i` and `dx_i` by `k`. On a constant-product or weighted curve `k` cancels. On a high-amp stableswap near balance, `dy_j ≈ dx_i`, so the output scales by about `k`.

**Attack.** All steps run in one transaction; the attacker holds X face0 plus P face0 of flash principal.
1. Swap P face0 → DAI in leg 0's Balancer pool. `RP_0` rises (0.5455 → 0.6826 at P=600).
2. Call `quad.exchangeIn(face0, X, face1, …)`. The inflow is credited at `RP_0'` and the attacker receives more face1 than X.
3. Swap the DAI back to face0 in pool0.
4. Call `quad.exchangeIn(face1, sY, face0, …)` with rates back near rest.
5. Repay P plus the fee. Repeat in any transaction while the hook holds BPT.

**Proof of concept.** `test/apex_audit/probe-se-rate-provider/QuadStableBptRateManip.t.sol`. The production-parameter re-run is `test/apex_audit/probe-se-rate-provider/AdjProdQuadBptRate.t.sol`.
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/probe-se-rate-provider/QuadStableBptRateManip.t.sol -vvv
```
```
[PASS] test_attack_lp200_X150_P600() (gas: 15030915)
    RP leg0 / leg1 682597270785636319 545490642406790741
  sold face0 150000000000000000000 got face1 177484191417490612327
  attacker net face0 profit (signed, after flash fee):
  17446177430197279817
[PASS] test_control_lp200_X100_P0() (gas: 11171137)
  attacker net face0 profit (signed, after flash fee):
  -5517291397191163382
```

**Impact.** At a 0.1% Balancer pool fee and X=150 / P=600, the attacker nets **+17.45 face0** per transaction after a 0.1% flash fee. Removing a separate pool1 subsidy (APEX-2026-018) leaves a conservative **+10.96**. The no-pump control nets −5.52. Hook LPs lose 13.60 face-equivalent per transaction at P=600, on about 800 face of TVL. Preconditions:
- a quad whose buffered leg's SE is a Balancer V3 pool;
- a low Balancer pool fee;
- flash liquidity of 25-50% of the pool's face reserve;
- a hook position that is a meaningful share of the pool (about 9% in the PoC).

**Design/config note.**
- The full-book rate is a documented owner decision (`docs/testing/BALANCER_SE_LIQUIDATION_IMPLEMENTATION_PLAN_2026-10-10.md:5-8`), so the issue is an unsafe pairing with a stableswap consumer rather than a broken formula.
- At the shipped 5% default Balancer fee the attack loses money (`X150/P600 net -54453750871568896191`).
- At 1% it is marginal.
- It is profitable only when governance lowers the pool fee to about 0.1%.

**Fix.** Either one closes the issue:
- Do not feed a `StandardExchangeRateProvider` over a BPT-as-SE subject into stable, quad or orbital consumers. Reject that pairing at package `beforeInitialize`.
- Or route BPT subjects in `_getRate` (`:79-82`) to a composition-independent value: `invariant × 1e18 / totalSupply` for stable pools, or fair-LP for weighted pools.

Defense in depth:
- On the consumer side, cap the credited inflow at the deposited face amount (`ratedInflow ≤ scaleTo(netIn)`).
- Add a per-leg scale-invariance test: multiply one leg's `RP` by `k` and assert that a round trip gains no more than fees.

**Related.** APEX-2026-018, APEX-2026-013

---

<a id="apex-2026-030"></a>

### APEX-2026-030: Balancer quad protocol fee compares a rated "now" invariant with an unrated checkpoint, so every join or exit mints phantom fee LP
**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 SE buffer hooks (Balancer quad stable)

**Summary.** At the start of every liquidity operation, `_maybeMintProtocolFee` mints LP to `feeTo` in proportion to `rootKNow - rootKCheckpoint`. `_rootKNow()` values a raw leg that has a rate provider at `raw x rate`. `_rootKCheckpoint()` revalues the stored `feeReserves` through `_liquidityValue`, whose raw-leg branch applies only the decimal scale and no rate. With `rate > 1`, every join or exit therefore sees growth even when nothing has traded. The checkpoint is then reset to the same unrated basis, so the same gap is charged again on the next operation. Honest LPs are diluted, and the value goes to `feeTo`.

**Affected code.** Paths are under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`; `P` = `UniswapV4StandardExchangeBalancerQuadStableBufferHook`.
- `PTarget.sol:433-437` `_rootKNow` (rated, via `_ratedWadAll` `:337-343`)
- `PClaimLib.sol:33-46` `ratedPairUnits` (l.38-40: raw leg = raw x rate)
- `PTarget.sol:439-444` `_rootKCheckpoint` → `_liquidityAmounts` `:372-375` → `_liquidityValue` `:346-357` (raw branch l.349-350, no rate)
- `PTarget.sol:446-464` `_maybeMintProtocolFee` (l.451 mint, l.458-459 re-checkpoint)
- `PTarget.sol:467-476` `_previewSupplyAfterProtocolMint` (same comparison)
- `PDFPkg.sol:367-370` (D60: "a raw leg may carry one")

**Root cause.**
```
now        (rated)   : x_now[i]  = scaleTo(raw_i * rate_i / RATE_PRECISION, ratedScale_i)     // ClaimLib:40
checkpoint (unrated) : x_ckpt[i] = scaleTo(feeReserves[i], ratedScale_i)                     // Target:349-350
```
The `_rootKCheckpoint` NatSpec says both sides are revalued "at the same SE rates". That is true for buffered legs but not for raw legs. When nothing changes between operations, `x_now[i] = rate * x_ckpt[i]`. `protocolLpShares` then returns a positive amount every time. Afterwards `feeReserves = _nativeAll()` is set again, so the checkpoint never absorbs the rate. The `LiquidityValueLoss` guard does not catch this because it records its baseline after the protocol mint.

**Attack.** No adversary is needed; ordinary join/exit traffic triggers it.
1. A Balancer quad hook has a raw leg whose rate provider reports a rate above 1, and the protocol fee is on.
2. Any account calls `joinProportional`. There is no access gate.
3. `_maybeMintProtocolFee` sees phantom growth and mints `protocolLp` to `feeTo`.
4. The same account calls `exitProportional`, and another slice is minted.
5. Repeat. Each operation dilutes every holder except `feeTo` by about `usageFee * g`.

**Proof of concept.** `test/apex_audit/rawleg-rp-lp-and-fee/BalancerQuadPhantomFee.t.sol`. The production-fee re-run is `test/apex_audit/rawleg-rp-lp-and-fee/AdjProdBalancerQuadFee.t.sol`.
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/rawleg-rp-lp-and-fee/BalancerQuadPhantomFee.t.sol -vvv
```
```
  control feeTo minted 0
  feeTo LP after     560418376926447095591094
  feeTo value (fair) 1454162321028148715917502
  victim value before 3989948039196902446925981
  victim value after  2535786521618467672544240
  victim loss bps     3644
  attacker token cost 884716031267820533
```

**Impact.** At rate 1.1 and a 10% usage fee, 200 join/exit operations with zero swaps cut the honest LP's fair value from **3,989,948.04 to 2,535,786.52 (−36.45%)**. All of it went to `feeTo`, which received 560,418.38 LP. The caller's cost was 0.8847 tokens plus gas. At rate 1.0, nothing is minted. Dilution compounds with the number of operations, not their size. With `rate < 1` the error reverses and legitimate protocol fees are suppressed (derived from the code, not executed). LPs lose; the protocol treasury gains; no third party profits.

**Design/config note.** The code contradicts its own NatSpec, and D60 / PRD rules 1-2 (`docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:9-10`) define a provider-carrying plain leg as `balance x rate`. Severity is Low (originally Medium) because:
- no production script deploys a Balancer quad or a raw leg with a provider;
- the value goes to `feeTo`, not an attacker.

At the production `USAGE_FEE = 5e16` and rate 1.05, the re-run still showed `victim loss bps 1121` after 200 operations.

**Fix.** Rate the raw-leg branch of `_liquidityValue` and `_liquidityInventory` whenever a provider is set:
```solidity
// Target.sol:349 (and :362)
- if (l.standardExchanges[i] == address(0)) {
+ if (l.standardExchanges[i] == address(0) && l.rateProviders[i] == address(0)) {
```
After the change, check the `NotFullBook` revert and the rounding direction on exits. Defense in depth:
- add a fuzz test asserting that join/exit with no swaps mints 0 protocol LP;
- or restore the pre-D60 `RateProviderWithoutSE` check.

**Related.** APEX-2026-014, APEX-2026-015

---

<a id="apex-2026-032"></a>

### APEX-2026-032: Crane `PostDeployAccountHookFacet` delegatecalls any caller, letting an unprivileged deployer backdoor a registry-registered Balancer ConstProd pool
**Severity:** Low · **Status:** Latent: not deployed (live registry `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` has no Balancer pool package) · **Family:** Crane / Balancer V3 pool packages

**Summary.** `PostDeployAccountHookFacet.postDeploy()` delegatecalls `msg.sender` without checking who the caller is. The factory cuts this facet into every new diamond and removes it only after `pkg.postDeploy(proxy)` returns. During that window, any external code that receives a non-static CALL can run its own code in the new diamond's storage and rewrite the facet table. `BalancerV3ConstantProductPoolStandardVaultPkg.deployVault` is permissionless and passes a caller-chosen `hooksContract` to Balancer `registerPool`, which CALLs `onRegister` inside the window. The defect predates this diff.

**Affected code.**
- `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol:19-23`: unauthenticated delegatecall to `msg.sender`
- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:230-231`: `pkg.postDeploy` runs before the facet is removed
- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:287-294, 425-430, 442-450`: facet added, then only that facet removed
- `contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol:419-424` (public `deployVault`), `:335-340`, `:399-417`
- `lib/crane/contracts/external/balancer/v3/vault/contracts/VaultExtension.sol:302-309`: non-static `onRegister` CALL
- `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:64-77, 155`: the result is registered as a vault

**Root cause.**
```solidity
// PostDeployAccountHookFacet.sol:19-23
function postDeploy() public returns (bool) {
    address(msg.sender)
        .functionDelegateCall(abi.encodeWithSelector(IDiamondFactoryPackage.postDeploy.selector, address(this)));
    return true;
}
// DiamondPackageCallBackFactory.sol:230-231
pkg.postDeploy(expectedProxy);                      // external code can run here
IPostDeployAccountHook(expectedProxy).postDeploy(); // facet removed only here
```
The design assumes only the factory calls the facet, but nothing enforces that. The cleanup step removes only the `postDeploy()` selector, so any selectors the attacker added survive, and the registry records the vault without checking its facets.

**Attack.**
1. The owner has registered the ConstProd package in the VaultRegistry (as `Script_04` does).
2. The attacker deploys `BackdoorFacet` (an attacker-only `exec`) and `EvilHooks`. `EvilHooks` reports all-false hook flags, and its `onRegister` calls `pool.postDeploy()`.
3. The attacker calls `cpPkg.deployVault([DAI, USDC], address(evilHooks))`.
4. Inside `registerPool` → `onRegister`, the mounted facet delegatecalls into `EvilHooks`, which cuts in the `exec` selector.
5. The factory removes the hook facet, and the registry records `isVault(pool) == true`.
6. A victim adds 1000 DAI + 1000 USDC.
7. The attacker uses `exec` to replace `onSwap` and swaps 1e12 wei DAI for 99% of the pool's USDC.

**Proof of concept.** `test/apex_audit/r3-h3-crane-postdeploy-hook-unauth-delegatecall/R3PostDeployHook.t.sol`
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r3-h3-crane-postdeploy-hook-unauth-delegatecall/R3PostDeployHook.t.sol -vvv
```
```
[PASS] test_control_honestPoolHasNoBackdoor() (gas: 19732214)
[PASS] test_fixControl_factoryOnlyHookBlocksAttack() (gas: 28848264)  fix revert data: Error("PostDeployHook: not factory")
[PASS] test_unprivilegedDeployerBackdoorsRegisteredPoolAndDrainsLP() (gas: 24123041)
  attacker DAI spent: 1000000000000
  attacker USDC gained: 990000000000000000000
  victim loss: 989999999000001010001
  attacker net profit (fair 1:1): 989999999000000000000
[PASS] test_variant_tokenDecimalsPathBlockedByStaticcall() (gas: 14457409)  token-path revert data: 0xd6bda275
```

**Impact.**
- **Executed:** the victim deposited 2000e18 and lost about 990e18 (49.5%). The attacker spent 1e12 wei DAI and gained 990e18 USDC; the second leg was not drained in the PoC.
- **Beyond a normal malicious hook:** the attacker can replace pool code arbitrarily, the hook looks inert, and the registry vouches for the pool (`isVault == true`).
- **Preconditions:** the ConstProd package is registered, and victims LP into the attacker-created pool. Because the salt includes `hooksContract`, existing honest pools cannot be touched.
- **Who loses:** LPs in the attacker's pool.

**Design/config note.** The bug breaks Crane's documented trust model, which describes the hook window as "a **safe window for privileged one-time setup actions**" (`lib/crane/docs/deployment/dfpkg.md:151`). It is downgraded from Medium because:
- ConstProd is deployed only by `scripts/foundry/anvil_base_main/Script_04_DeployDEXPackages.s.sol` and is not on 4663;
- victims must LP into a pool that shows a non-zero third-party `hooksContract`;
- no other wired family reaches the window with a non-static CALL.

**Fix.** Make `postDeploy()` factory-only with an immutable `FACTORY` and `require(msg.sender == FACTORY, "PostDeployHook: not factory")`. Use one facet per factory, because the V4 hook factory mounts it too. Alternatively, remove the hook facet before calling `pkg.postDeploy`. Defense in depth:
- force `hooksContract = address(0)` (or use an allowlist) in the permissionless `deployVault`;
- after deploy, check that the proxy's facet set matches `pkg.facetCuts()` plus the base cuts.

---

<a id="apex-2026-037"></a>

### APEX-2026-037: Frozen WETH leg of the DTF-DETF weighted hook has drifted about 2.8x off market; re-enabling SE 0x999DaE02 without a rebalance opens a cross-leg drain

**Severity:** Low · **Status:** Live on Robinhood 4663, but exploitable only after an owner action (weighted hook `0x46E068c2393e189Fbc86632f67210aF253a42Aa8`; liquidity SE `0x999DaE02D22E5FEe1c4508430D5196d31d631009`, disabled; custody SE `0x2E9C1F705aB967c5Af59249203d7495bDabb223b`; DETF `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`) · **Family:** DTF-DETF stack (deployed, pre-HEAD bytecode)

**Summary.** Disabling `0x999DaE02` froze the hook's WETH leg. Every WETH route reverts with `VaultDisabled`, but DTF-route mints stay open and keep adding DTF to the DTF leg, so nobody can arbitrage the WETH leg back into line. The hook now prices DTF about 2.8x below market relative to WETH. If the owner re-enables `0x999DaE02` without rebalancing first, any unprivileged contract can drain the protocol-owned reserve by looping WETH -> DETF -> DTF on the hook and DTF -> WETH on the liquidity SE. Today's profit is 0.

**Affected code.**
- `contracts/registries/vault/VaultRegistryDisableManagerTarget.sol:18-24` (`setVaultAddressDisabled` flips a flag and triggers no rebalance)
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:78-92` (each leg is valued from its own balance and rate, with no cross-leg anchor)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:221-228` (the mint gate does not check that every reserve leg is live)
- `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:19-21` (previews quote WETH routes that revert)

**Root cause.** The hook's spot price of leg *i* in leg *j* is
```
P(i in j) = (B_j / w_j) / (B_i / w_i)        with B_k = ratedPairUnits(k) (shares × getRate) scaled to WAD
```
While `0x999DaE02` is disabled, `B_WETH` is frozen while DTF mints move the other legs. At the fork, 1 DETF was worth about 6093 DTF (≈0.00042 WETH) through the DTF leg, but only about 0.000148 WETH through the WETH leg.

**Attack.**
1. The owner calls `setVaultAddressDisabled(0x999DaE02, false)` without rebalancing. This is the only privileged step.
2. An unprivileged contract with 0.1 WETH calls `hook.exchangeIn(WETH -> DETF)`.
3. It calls `hook.exchangeIn(DETF -> DTF)`.
4. It calls `0x999DaE02.exchangeIn(DTF -> WETH)`.
5. It repeats steps 2-4 under `MAX_IN_RATIO` until a loop stops being profitable, and ends holding only WETH.

**Proof of concept.** `test/apex_audit/live-dtf-stack/LiveDtfStack.t.sol` (`test_B_wethLegFrozen_live`, `test_D_reenableCrossLegArb_whatIf`, `test_E_reenableCrossLegArb_total_whatIf`). The test forks live 4663, and the re-enable is simulated with `vm.prank`.
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/live-dtf-stack/LiveDtfStack.t.sol -vvv
```
```
  hook WETH->DETF reverts, sel:
  0x1ba84b43000000000000000000000000999dae02d22e5fee1c4508430d5196d31d631009
  weth in 100000000000000000 weth out 200587271096018820
  best profit wei WETH 100587271096018820
[PASS] test_E_reenableCrossLegArb_total_whatIf() (gas: 16640824)
  profitable loops 4
  attacker WETH start 100000000000000000
  attacker WETH end   214118996323698738
```

**Impact.** After the re-enable, an unprivileged contract turned 0.1 WETH into 0.214118996323698738 WETH (+0.114118996 WETH) over 4 loops, with no leftover DTF or DETF. The hook lost 4,371,984 DTF of custody. Its net value change at pre-attack prices is −0.15628 WETH (`hookDelta`, asserted `< 0`). DETF and sDTF holders bear that loss. The gap widens with every DTF-only mint, and the maximum extractable amount above 0.1 WETH per loop was not tested. Re-enabling also reopens APEX-2026-001 on `0x999DaE02`.

**Design/config note.** This is an operational risk, not a code bug. Re-enable is designed as a bare flag removal with no rebalance step (`docs/VAULT_REGISTRY_DISABLE_DESIGN.md` §2.3, §3.1). A later re-run showed the gap still growing: `best profit wei WETH 121186285916387439`.

**Fix.**
- Never re-enable `0x999DaE02` on its own. Bundle the re-enable with an `ownerSwapExactIn` rebalance in one transaction. A better option is to migrate the WETH leg off the old V4 SE.
- Until then, pause DTF-route mints on DETF `0x4a5cFDC2`.
- Defense in depth: make previews return 0 or revert when a leg's SE is disabled (this also fixes the info-level preview mismatch). Make the mint gate fail when any reserve leg is unavailable.

**Related.** APEX-2026-001, APEX-2026-010.

---

<a id="apex-2026-038"></a>

### APEX-2026-038: Same-transaction sDETF stake/unstake permanently ratchets fee-to/creator standing weights

**Severity:** Low · **Status:** Live on Robinhood 4663 (sDETF `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c`; DETF `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`; flash source V4 PoolManager `0x8366a39CC670B4001A1121B8F6A443A643e40951`) · **Family:** DETF staking (sDETF)

**Summary.** Every sDETF stake, unstake, `fundRewards` and `retireEscrowDust` calls `_topUpWeights`, which raises `feeWeight`/`creatorWeight` toward a target proportional to the current `totalGons` and never lowers them. Unstaking is instant, so the weights track the peak of `totalGons`. A flash-funded stake/unstake in one transaction sets a new permanent high-water mark, which dilutes every later ordinary-staker reward.

**Affected code.**
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:194-219` (`_exchange` runs `_topUpWeights` after stake and after an instant unstake, l.218)
- `contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol:165-175` (`_topUpWeights`, increment only), `:109-124` (`_debitPrincipal`, no lock)
- `contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol:18-34` (`_topUpDeltas`, positive deltas only)
- `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:79-94` (`_allocate`, pro rata over `ordinaryGons + feeWeight + creatorWeight`)

**Root cause.**
```
Wf(t) = max over s <= t of  f * O(s) / (1 - f - c)
Wc(t) = max over s <= t of  c * O(s) / (1 - f - c)
staking share of reward R = R * O_now / (O_now + Wf + Wc)
```
A transient peak of `O` (`totalGons`) inside one transaction raises `Wf`/`Wc` permanently. Nothing (no lock, epoch snapshot or time weighting) excludes it.

**Attack.** (One transaction, from an unprivileged contract.)
1. `PoolManager.unlock`, then `take` 100,000,000e18 DTF using flash accounting.
2. Buy about 3,471 DETF from the weighted hook in ratio-capped chunks.
3. Stake it in sDETF. The weights top up to the peak.
4. Unstake immediately. `totalGons` returns to its previous value, and the weights stay where they are.
5. Sell the DETF back to the hook, then settle the flash.

**Proof of concept.** `test/apex_audit/r3-H3-XF-01/R3StakingWeightRatchet.t.sol` (live 4663 fork)
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r3-H3-XF-01/R3StakingWeightRatchet.t.sol -vvv
```
```
  BEFORE
    ordinary bps of W 5834
    attack DTF cost 17800894059935899857541
  AFTER ATTACK
    ordinary bps of W 5111
  alice loss bps 1247
  fee+creator attacked 3648672286
  creator NET LOSS DTF 14375941423272069717906
```

**Impact.** The ordinary share of total weight fell from 5834 to 5111 bps, and the change is permanent. Over 3 honest 2M-DTF mints, fee+creator received 3,648,672,286 raw instead of 3,127,572,012. Alice's share of the pot fell 12.4% (a loss of 0.0202 DETF, about 190 DTF). The attack cost 17,800.89 DTF in hook fees. A third party makes no profit, so this is griefing. Creator self-dealing loses 14,375.94 DTF net unless roughly 31M DTF of later mint volume follows. A same-size repeat adds nothing (`test_C`), so the effect is bounded by the DETF depth reachable in one transaction.

**Design/config note.** The top-up-only weights are specified: "An unstake never reduces standing weights" (`contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` §4.4). Organic peaks had already pushed the live ordinary share to 5834 bps, below the 6000 bps target. The spec does not say whether transient peaks should count, so this is rated Low as a design trade-off.

**Fix.**
- Top up against `min(totalGons, laggedGons)`, where `laggedGons` is snapshotted on the first touch in each block (or timestamp), so a same-block peak cannot raise the weights. An epoch-settled `O` is the longer-horizon alternative.
- Structural alternative: allocate `fee = R*f` and `creator = R*c` per reward instead of standing weights. Keep the zero-stake behaviour asserted by `test_standingRecipientsReceiveNewExpansionAfterAllStakeUnstakes`.
- Add a test that a same-transaction stake plus unstake leaves the weights unchanged, and state in spec §4.4 whether transient peaks count.

---

<a id="apex-2026-039"></a>

### APEX-2026-039: Pretransfer credit is not tied to the depositor; exact-out refunds unattributed self-shares to the caller

**Severity:** Low · **Status:** Live on Robinhood 4663 (custody SE `0x2E9C1F705aB967c5Af59249203d7495bDabb223b`, which runs baseline code with no EOA gate; current exposure 0, self-share balance 0). The HEAD path is not deployed. · **Family:** RebasingAware ERC4626 custody vault (and protocol-wide D15/D28 pattern)

**Summary.** At HEAD, `exchangeOut(share -> asset, pretransferred=true)` sets credit to `min(balanceOf(vault, vault), maxAmountIn)`. Self-held shares are booked to no one, and the caller chooses `maxAmountIn`. The vault burns only what `amountOut` needs and transfers the rest to `msg.sender`. The only gate is a code-size check, so any contract can take shares another party left resting on the vault.

**Affected code.**
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:118` (code-size gate only), `:119-120` (credit = all self-shares, capped by the caller's max), `:135-137` (refund to `msg.sender`), `:83-91` (same issue on the exact-in route)
- `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol:346, 375` (`deposit`/`mint` accept `receiver = address(this)`)
- `contracts/utils/LocalCreditLib.sol:23-28`

**Root cause.** With `maxAmountIn = type(uint256).max` and `amountOut = 1`:
```
credit   = selfBal                                     (every share resting on the vault)
burned   = ceil(1 * (supply + virtualShares) / (assets + 1))   (about one asset-wei of shares)
refund   = selfBal - burned          -> msg.sender
```
Shares come to rest through a non-atomic two-step pretransfer, a mistaken transfer, or `deposit(receiver = vault)`.

**Attack.**
1. tx1: the victim calls `vault.transfer(vault, X)` as step 1 of a staged withdraw. Alternatively, the victim deposits with `receiver = vault`.
2. tx2: the attacker deploys a zero-capital contract that calls `exchangeOut(IERC20(vault), type(uint256).max, IERC20(asset), 1, address(this), true, block.timestamp)`. It receives `X - burned` shares.
3. The contract redeems those shares to the attacker EOA. The victim's own step 2 then reverts.

**Proof of concept.** `test/apex_audit/prepaid-refund-sweep/PrepaidRefundSweep.t.sol` (HEAD). Live baseline: `test/apex_audit/live-dtf-stack/LiveDtfStack.t.sol` (`test_A_custodyRestingShareSweep_live`).
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/prepaid-refund-sweep/PrepaidRefundSweep.t.sol -vvv
```
```
[PASS] test_control_EOA_blocked() (gas: 130959)
  attacker profit (assets) exact-in 50000000000000000000000
[PASS] test_sweep_exactOut_refundToCaller() (gas: 1051423)
  attacker profit (assets) 50000000000000000000000
  victim loss (assets) 50000000000000000000000
  alice value delta 0
```
Live fork (`LiveDtfStack.t.sol`, `test_A_custodyRestingShareSweep_live`):
```
  custody self-share balance (live exposure) 0
  attacker DTF profit (capital 0) 1000000000000000000000000
```

**Impact.** At HEAD, a zero-capital contract took 50,000e18 asset, 100% of the victim's resting value, through both the exact-out and exact-in (`receiver = vault`) routes. Honest LP delta was 0. On the live fork, a hypothetical victim's 1,000,000e18 DTF of resting shares was taken in full. Morpho B2 variant: a plain EOA calling `redeem(stranded, attacker, address(se))` took 50,000e18 loan token (the `withdraw` variant took 100,000e18), with LP value unchanged. The Morpho package is deployed on 4663 with 0 vaults. Live exposure today is 0. The attack needs a third party to leave value on the vault across a transaction boundary, and atomic integrators are unaffected. EOAs are blocked at HEAD but not on the live baseline. Only the victim loses.

**Design/config note.** Staged pretransfer is documented integrator risk: "Unrecorded balance across transactions may be consumed by the next contract caller" (`lib/crane/contracts/interfaces/IStandardExchangeOut.sol:63`; `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:135, :207`). The only undocumented path is `deposit`/`mint` with `receiver = address(this)`.

**Fix.**
- Reject `receiver == address(this)` in `executeDeposit`/`executeMint` (`RebasingAwareERC4626Common.sol:346, 375`). This closes the only undocumented path.
- Replace the refund at `RebasingAwareStandardExchangeTarget.sol:135-137` with a strict `credit == needed` check. If refunds are required, attribute pretransfers per sender in transient storage.
- Defense in depth: apply one rule in `LocalCreditLib` across the families with the same pattern (Slipstream, Wings, ERC4626 SE, Morpho, Aerodrome). Add an owner-gated rescue for unattributed self-balance. For Morpho, revert `withdraw`/`redeem` when `owner == address(this)`.

**Related.** APEX-2026-003 (only partly fixed), APEX-2026-010 (realization leg), APEX-2026-034, APEX-2026-036.

---

<a id="apex-2026-040"></a>

### APEX-2026-040: Wings bootstrap has no dead-share sink, and donated fee growth rounds later deposits down to 1 share

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 UpperLowerWings

**Summary.** When supply is 0, `Accounting.issue` mints 1 share per target wei. There is no dead-share sink, no virtual offset and no minimum bootstrap size. After that, share pricing uses `Quote.quote().value`, which includes each vault position's uncollected fee growth, and anyone can raise that fee growth with the permissionless `PoolManager.donate`. An attacker holding a dust supply on a near-empty pool can make the next honest depositor receive 1 share and lose up to about 50% of the deposit, then recover the donation on redeem. PRD SEC-03 names this exact sequence as one that must fail.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:18-23`: `issue()` (line 21). The only guard is `ZeroIssue`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:129-136`: `_deposit` runs `_harvest()`, then `value = Quote.quote(...).value`, then `Accounting.issue`, then the `MinAmountNotMet` check.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:264-273`: adds `Inventory.earnedFee` from live `getFeeGrowthInside`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol:39-49`: `earnedFee`.
- `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:329`: SEC-03.

**Root cause.**
```solidity
// Accounting.sol:21
shares_ = supply_ == 0 ? credit_ : FullMath.mulDiv(supply_, credit_, value_);
if (shares_ == 0) revert ZeroIssue();
```
`PoolManager.donate` pays only in-range liquidity. If the vault's position is the only active liquidity, it receives the whole donation, and `_harvest()` books it into `local0` before the quote. The pool must be hookless, so no hook can gate `donate`. Let W be the vault value after the donation. For W/S ≤ V < 2W/S:
```
shares_victim = floor(S·V / W) = 1
loss_victim   = (S·V − W)/(S + 1)
```
`minimum_` does not help, because `previewExchangeIn` already runs against the trapped state and returns 1.

**Attack.** (seed-10 case, as executed)
1. The attacker adds 1e12 of its own full-range liquidity, the pool's only external LP.
2. `exchangeIn(token0 → wings0, 10)`: supply 10, upper wing L = 9.
3. Inside one `unlock`, the attacker swaps to tick 90 so the wing `[60, max]` is in range. It then removes its own LP, calls `donate(key, 1e9, 0)`, re-adds the LP and swaps back to the original `sqrtPriceX96`. `liqValue` goes from 9 to 1,000,000,009 with supply still 10.
4. The victim's `previewExchangeIn(token0, 190e6, wings0)` returns 1. The victim deposits with `minimum = 1` and receives 1 share.
5. The attacker redeems 10 shares for 1,081,818,190. The victim redeems its share for 108,181,818.
6. The attacker removes its LP. Net result: +81,818,175 token0 and −5 wei token1.

**Proof of concept.** `test/apex_audit/dry-r5-wings-poolmanager-donate-inflation/WingsDonateInflation.t.sol`
`forge test --match-path test/apex_audit/dry-r5-wings-poolmanager-donate-inflation/WingsDonateInflation.t.sol -vvv`
```
[PASS] test_inflation_seed10() (gas: 7300506)
    supply 10 liqValue 1000000009
  victim preview shares 1
  victim deposited 190000000 victim shares 1
  attacker redeemed shares 10 for token0 1081818190
  victim loss (token0 raw)
  81818182
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 198.08ms (100.66ms CPU time)
```

**Impact.** With donation 1e9 in every case:

| Seed | Victim deposit | Victim loss | Attacker profit |
|---|---|---|---|
| 10 | 190,000,000 | 81,818,182 (43%) | +81,818,175 |
| 100 | 19,000,000 | 8,910,891 (47%) | +8,910,883 |
| 1000 | 1,900,000 | 899,102 (47%) | +899,093 |

The attacker gets the whole donation back. While the trap is in place, any deposit below W/S reverts `ZeroIssue`.

Preconditions:
- The attacker makes the first deposit. `deployVault` is permissionless.
- The vault's position is effectively the only active liquidity at the donation tick. Any honest in-range LP absorbs almost all of the donation and makes the attack lose money, so in practice only fresh or empty pools are exposed.
- The victim accepts a 1-share quote.

**Fix.** Owner rulings O3 (no permanent sink) and A2 (PRD :32, "No ... virtual denominator ... is authorized") probably rule out an OpenZeppelin-style virtual offset unless the owner issues a new ruling. Smallest compatible fix: add a round-trip guard in `_deposit` that requires `entitlement(supply + shares_, value + assets_, shares_) >= assets_ - tolerance` (for example, at most 1 bp plus 1 wei). This can optionally be combined with a minimum first-deposit size that is not locked. Excluding uncollected `earnedFee` from the quote is not enough on its own, because `_harvest()` books the donated fees before the quote runs. Add SEC-03 as a regression test that asserts `attackerProfit <= 0`.

---

<a id="apex-2026-041"></a>

### APEX-2026-041: FullSpread 64-step quote cap and single-step exact-out let dust ticks next to spot cap zap, redeem and swap sizes

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 FullSpread

**Summary.** The hookless FullSpread vault prices exact-in swaps and single-sided zap redemptions with `UniswapV4Quoter.quoteFromState(maxSteps = 64)` and reverts `QuoteWorkLimit()` if a quote is not filled within 64 steps. The zap-deposit planner has its own 64-step budget, and an invalid plan reverts `AlignmentNotAchievable()`. Exact-output is a single `computeSwapStep` toward the next initialized tick. On a hookless pool anyone can mint liquidity-1 one-spacing positions for about 1 wei each, and every such position becomes a step boundary that absorbs almost no flow. Only the attacker can remove them. No principal is lost or frozen, and proportional dual deposits keep working.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:28` (`MAX_CORE_STEPS = 64`), `:39-43` / `:47-51` (`QuoteWorkLimit` reverts), `:84-99` (`_tryForwardBounded`), `:113-129` (single-step `_exactOutput`), `:143-161` (`_firstTarget`)
- `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:174`: each initialized tick or word edge counts as one step.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol:29, 113-130, 277-300, 489-497`: `MAX_STEPS = 64`, `WorkLimit` / `OutOfDomain`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol:293-294`: `AlignmentNotAchievable`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:394-401`: requires `hooks == 0` and accepts any `tickSpacing`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookQuoteService.sol:29, 40-51`: same design (not executed).

**Root cause.**
```solidity
// QuoteService.sol:39-43
function _forward(Params memory params_) public view returns (Types.Swap memory result_) {
    bool filled;
    (result_, filled) = _tryForward(params_);
    if (!filled) revert QuoteWorkLimit();
}
// _tryForwardBounded: quoteFromState(..., maxSteps: MAX_CORE_STEPS /* 64 */)
```
The cap counts boundaries regardless of how much liquidity sits on them. That gives `maxIn ≈ L_active · Δ√P(64 · spacing ticks)`. `_exactOutput` targets the next initialized tick in the current word, so a single dust position next to spot limits exact-out capacity to `L_active · Δ√P(≤1 spacing)`. The zap planner is limited in the same way by initialized boundaries and its 64-step budget. V4 keys positions by owner, so nobody else can burn the dust.

**Attack.**
1. A hookless pool (spacing 1, fee 100) has an honest full-range LP of L = 2,000e18. Alice deposits 10,000e18 / 10,000e18 into the vault.
2. The attacker, unprivileged, calls `modifyLiquidity(liquidityDelta = 1)` for 150 adjacent one-spacing positions above spot and 150 below, using 6 `unlock` calls. Cost: 150 wei of each token and 24,783,338 gas.
3. Zap deposits, zap redeems and exact-in swaps above the new ceilings revert (`AlignmentNotAchievable` / `QuoteWorkLimit`).
4. When another contract tries to burn a dust position, the call reverts.
5. The attacker can withdraw at any time, which restores every baseline exactly, and can re-seed later.

**Proof of concept.** `test/apex_audit/r2-h2v-fs-dust-tick-step-cap-dos/R2FsDustTickStepCapDos.t.sol`
`forge test --match-path test/apex_audit/r2-h2v-fs-dust-tick-step-cap-dos/R2FsDustTickStepCapDos.t.sol -vvv`
```
  == baseline (no dust)
    ceiling zapDep(token0)    51429748535156250000
  attacker seeding gas 24783338
  == after dust seeding
    ceiling zapDep(token0)    636005401611328125
    ceiling swapIn(token0)    32623386383056640625
    ceiling zapRedeem (bps)   32
    ceiling Quotes._exactOutput 319290161132812500
```

**Impact.** At spacing 1 the ceilings fell as follows:
- Zap deposit: 51.43e18 to 0.636e18.
- Zap redeem: from at least 5000 bps of Alice's shares to 32 bps.
- Exact-in swap: from at least 900e18 to 32.62e18.
- Exact-out quote: 53.46e18 to 0.319e18. This is measured at the quote level only. End-to-end `exchangeOut` already reverts `InvalidRoute` at baseline for an unrelated reason.

At spacing 10, zap deposit fell from 49.20e18 to 8.96e18, swapIn from at least 900e18 to 295.4e18, redeem to 331 bps, and the exact-out quote from 638.99e18 to 0.0249e18.

The step-cap effect needs at least 64 positions on the trade side. The exact-out and zap effects need only one. The attacker gains nothing, and the effect lasts as long as the positions stay. Single-sided users and integrators are hit. They can split into smaller chunks or use proportional paths.

**Fix.**
- When a redemption hits the step cap, return the partial fill instead of reverting, as the code already does at the price limit, and pay the remainder in kind.
- For swaps, set `MAX_CORE_STEPS` to a bound calibrated to gas, or do not charge a full step for boundaries whose `liquidityNet` is negligible compared with active liquidity.
- Defense in depth: let `_exactOutput` cross a bounded number of initialized ticks. Have the zap planner fall back to a partial composition instead of reverting `AlignmentNotAchievable`. Prefer tickSpacing ≥ 60, or enforce a minimum spacing in `_validatePoolKey`.

**Related.** APEX-2026-026

---

<a id="apex-2026-042"></a>

### APEX-2026-042: FullSpread DFPkg `initAccount` makes a raw bool-returning `approve` to Permit2, so no vault can be deployed for a no-return (USDT-style) token

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 FullSpread (hookless, Pons) packages

**Summary.** During `initAccount`, both FullSpread packages call `IERC20(token).approve(address(PERMIT2), type(uint256).max)` as a typed call that decodes a `bool` return. If a token's `approve` returns no data (for example USDT), the call reverts, so `deployVault` reverts with `FailedCall()` (`0xd6bda275`) every time for any pool that contains that token. The Permit2 allowance is never used, because settlement goes through `currency.transfer` + `PoolManager.settle()`.

**Affected code.**
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:323-324, 378-385` (raw approve at 383)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookDFPkg.sol:332-333, 387-394` (raw approve at 392)

**Root cause.**
```solidity
function _approvePoolManagerIfErc20(address token) internal {
    if (token == address(0)) {
        return;
    }
    IERC20(token).approve(address(PERMIT2), type(uint256).max);            // L383 / L392
    PERMIT2.approve(token, address(POOL_MANAGER), type(uint160).max, type(uint48).max);
}
```
solc requires `returndatasize >= 32` before it decodes the declared `bool`. A token that returns nothing makes the call revert even though the approval itself succeeded. `initAccount` runs inside the proxy constructor, so the whole deployment aborts.

**Attack.** No attacker is involved. This is a deterministic compatibility failure.
1. A V4 pool is created with a no-return-`approve` token. The pool itself works.
2. Any account calls `deployVault(poolKey)` on either package.
3. `initAccount` reverts at L383/L392. The factory returns `FailedCall()`, and every retry fails the same way.

**Proof of concept.** `test/apex_audit/r2-h2tb-fullspread-dfpkg-raw-approve/RawApprove.t.sol`
`forge test --match-path test/apex_audit/r2-h2tb-fullspread-dfpkg-raw-approve/RawApprove.t.sol -vvv`
```
[PASS] test_noReturnToken_hookless_deployReverts() (gas: 16191334)
  PM NRT balance after honest LP 999999999999999999946
  deployVault ok? false
  0xd6bda275
[PASS] test_noReturnToken_pons_deployReverts() (gas: 9032855)
  pons deployVault ok? false
  0xd6bda275
[PASS] test_diff_onlyApproveReturnsBool_deployOk() (gas: 15735138)
Ran 3 test suites in 1.24s (3.56s CPU time): 7 tests passed, 0 failed, 0 skipped (7 total tests)
```
In the differential test, the token's `transfer` still returns nothing and only `approve` returns `bool`. That deployment succeeds, which isolates the raw `approve` as the blocker.

**Impact.** This is an availability issue only, with 0 funds at risk. While the current packages remain in use, no FullSpread vault can ever be deployed for a V4 pool containing a no-return-`approve` token. Existing vaults are unaffected. On chains where USDT's `approve` returns nothing (Ethereum mainnet), USDT/X FullSpread vaults would be impossible.

**Fix.** Delete the unused Permit2 grant in both packages, meaning the helper and its calls at hookless L323-324 and Pons L332-333. Settlement is `sync`/`transfer`/`settle` and never uses it. If the grant is kept, use `BetterSafeERC20.forceApprove`. Defense in depth: use `safeSymbol` (or try/catch) in `_symbolOrToken`, which calls `symbol()` the same way and could also block deployment. Add a deploy test that uses a no-return token.

---

<a id="apex-2026-043"></a>

### APEX-2026-043: Orbital buffer hook radius R is fixed at 10x the first mint, so fill-to-R griefing blocks swaps and joins, and a dust first mint caps the instance permanently

**Severity:** Low · **Status:** Latent: not deployed · **Family:** V4 SE buffer hooks (orbital)

**Summary.** The orbital hook sets its sphere radius `R = 10 * max(first-mint effective leg)` exactly once, in the `supply == 0` branch of `_applyAdd`. `MINIMUM_LIQUIDITY` is minted to `address(0)`, so supply never returns to 0 and `R` can never change. Every later join and swap reverts if any leg would reach `R`. When `ownerOnlyLiquidity == false`, any account can fill the legs up to just under `R`, which blocks swaps and honest joins while keeping 99.97% of its capital. Any account can also make the first mint with dust, which pins `R` for the life of the immutable instance. The fixed R is documented (PRD D21, non-goal 9). The finding is that a third party can trigger the cap on purpose, and that the first mint has no size floor.

**Affected code.**
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1309-1330`: `_applyAdd` writes `l.R` (line 1323) only when `supply == 0`.
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:593-598`: `_requirePostUnderRadius`. It is called after every swap (`:746`, `:764`).
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1016-1032`: a 3-leg join goes to `_computeFullBook`, which has no radius cap (the `_capFaceUnderRadius` cap at `:1071` covers partial joins only).
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol:65-68, 134-144`: the sphere domain check and `firstMintRadius`.

**Root cause.**
```solidity
// Common.sol:1309-1330
if (supply == 0) {
    ...
    l.R = Math.firstMintRadius(_toWad(l.token0, e0), _toWad(l.token1, e1), _toWad(l.token2, e2));
    _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);   // supply can never return to 0
    _mintLp(to, shares);
} else {
    _requirePostUnderRadius();                     // every later join: all legs < R
    _mintLp(to, shares);
}
```
Swap depth on the input leg is bounded by `R - x_in`. Adding liquidity therefore pushes the legs toward `R` and reduces swap capacity instead of increasing it. The DFPkg does not seed in the deploy transaction (`postDeploy` is a no-op), so whoever calls `addLiquidity` first sets `R`.

**Attack.**
A. Fill-to-R (temporary):
1. An honest LP seeds 1,000 per leg, so `R = 10,000e18`.
2. The attacker calls `addLiquidity(8,950e18, 8,950e18, 8,950e18, ...)`. The legs go to 9,931.13 / 9,950 / 9,950.
3. Swaps above about 68 tokens revert, and honest 3-leg joins revert with `ReservesExceedRadius`. Exits still work.
4. The attacker exits whenever it chooses.

B. Dust first mint (permanent):
5. On a freshly deployed hook, the attacker calls `addLiquidity(0.001e18, 0.001e18, 0.001e18, ...)`, so `R = 0.01e18`.
6. Every join of meaningful size now reverts. The hook has no admin surface, so it has to be redeployed.

**Proof of concept.** `test/apex_audit/r2-h2-orbital-fixed-radius-cap/OrbitalFixedRadiusCap.t.sol`
`forge test --match-path test/apex_audit/r2-h2-orbital-fixed-radius-cap/OrbitalFixedRadiusCap.t.sol -vvv`
```
  R after full exit: 10000000000000000000000
  R after dust first mint (wad): 10000000000000000
  honest 1,000/leg join: REVERTS
  baseline max swap t0->t1 (tokens): 1185
  after max swap t0->t1 (tokens): 68
  after honest 100 join revert data: 0x13e5fe33
  attacker capital in: 26850000000000000000000
  attacker capital out: 26841965574373116579653
```
`0x13e5fe33` = `ReservesExceedRadius()`.

**Impact.** No funds are lost and the attacker makes no profit.
- **Variant A:** the largest successful swap drops from 1,185 to 68 tokens, and an honest 100/leg join reverts. The griefer's net cost is 8.03 of 26,850 (0.03%), plus about 9x pool TVL locked for as long as the DoS lasts.
- **Variant B:** costs 0.001 token per leg and caps the instance permanently. It requires the deployer to seed in a separate transaction.
- **Who is affected:** swappers, honest LPs and the deployer.
- **Not exposed:** instances deployed with `ownerOnlyLiquidity = true`.

**Fix.**
1. Scale R with proportional joins. After a full-book join, set `R = R * (supply + shares) / supply` and keep `_recomputeL2()`.
2. Close the dust first mint. Either seed atomically in `deployVault`, or enforce a minimum first-mint size (or owner-only first mint).

Defense in depth: also apply `_capFaceUnderRadius` (or a proportional clamp) on the full-book path, so near-cap joins partially fill instead of reverting. Recommend `ownerOnlyLiquidity = true` for production instances until (1) and (2) ship.

---

<a id="apex-2026-044"></a>

### APEX-2026-044: Dilutive usage fee is minted on top of depositor shares, so existing LPs pay it; round trips grief LPs ~95x the griefer's cost; operator can set a 100% fee instantly

**Severity:** Low · **Status:** Latent: not deployed · **Family:** ERC4626 SE / Stata / Morpho / staking SEs; SE-buffered hook legs

**Summary.** On every route that mints shares, `_mintWithUsageFee` mints the depositor's full `userShares` and then mints another `userShares * usageFee` to `feeTo`. The fee therefore comes out of every holder through dilution, not out of the depositor's own shares. Redeems charge no exit fee, so deposit-and-redeem round trips move value from existing LPs to `feeTo` while the cycler pays only a small slice. Separately, as an Informational / centralization item, `setUsageFeeOfVault` accepts any value up to `1e18` (100%) and takes effect immediately. The "inflation style" fee is documented (D40/D57). What the docs do not say is that existing holders pay it.

**Affected code.**
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:220-234` (`_mintWithUsageFee`). Identical copies are in `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:540-549`, `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:528-537`, `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:377-386` and `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:206`.
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:61-62, 75-76`: `minAmountOut` is checked against pre-fee shares. Redeems at `:92-116` have no exit fee.
- `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol:94-98` and `contracts/oracles/fee/VaultFeeOracleRepo.sol:67-71`: the fee can be set up to `ONE_WAD` with no delay.

**Root cause.**
```solidity
function _mintWithUsageFee(address recipient, uint256 userShares) internal {
    ERC20Repo._mint(recipient, userShares);                       // depositor gets 100% of pre-fee shares
    uint256 feePct = VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this));
    ...
    ERC20Repo._mint(feeTo_, feeShares);                           // fee = extra supply, no backing
}
```
With backing B, supply S and `p = B/S`, a deposit of `s` shares gives `p' = p·(S + s) / (S + s + f·s)`. Existing holders lose `S·p·f·s / (S + s + f·s)`, while the depositor loses only about `f·s · s/(S+s)`. With no exit fee, the ratio of holder loss to cycler cost is about `S_holder / s`.

**Attack.**
1. An ERC4626 SE runs at the live-default 5% fee. An honest LP deposits 1000 receipts, and the LP's position is worth 952.38.
2. An unprivileged griefer runs `exchangeIn(receipt -> SE, 10e18)` and then `exchangeIn(SE -> receipt, s)` 20 times (200 volume).
3. Result: the griefer loses 0.0990, the LP loses 9.380 and `feeTo` gains 9.479.
4. In the privileged variant, the owner or operator calls `setUsageFeeOfVault(se, 1e18)`, which takes effect in the same block.
5. `feeTo` then deposits 1000 and redeems, five times. The LP's position falls from 952.38 to 67.01.

**Proof of concept.** `test/apex_audit/r2-h2-usage-fee-dilution-externalized/R2UsageFeeDilution.t.sol` (3/3 pass)
`forge test --match-path test/apex_audit/r2-h2-usage-fee-dilution-externalized/R2UsageFeeDilution.t.sol -vvv`
```
[PASS] test_A_unprivileged_roundtrip_externalizes_fee_to_LPs() (gas: 5464632)
  griefer cost 98956307405622880
  LP loss 9380242732469160880
[PASS] test_B_operator_fee100_feeTo_cycles_drains_LP() (gas: 2259705)
  LP value before 952380952380952380952
  LP value after 67011812225720088886
  feeTo excess extraction 885369140155232292067
[PASS] test_C_accounting_no_attacker_profit_loss_to_feeTo() (gas: 5553180)
  feeTo gain 9479199039874783760
```
For the hook variant, `test/apex_audit/p4-hooks/P4DualFeeLeak.t.sol` passes 2/2.

**Impact.**
- **Unprivileged griefing:** the LP's loss (9.380243) is 94.79x the griefer's cost (0.098956). It equals about 4.69% of cycled volume, and all of it goes to `feeTo`.
- **Privileged path:** the LP loses 885.369 (-92.96%) beyond the 47.619 legitimate fee.
- **Profitability:** a third party never profits. If the cycler is `feeTo` itself, its net equals the holders' loss at any fee above 0 (derived from the asserted accounting identity, not run separately).
- **Hook variant:** at a 1% SE fee, passive LPs in the dual hook change by -1,201,160,979,592,804 wei per 1e18 LP over the cycle.
- **Live config:** the manager `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` returns `defaultUsageFee() = 50000000000000000` and `feeTo() = 0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E`. No affected SE is deployed yet.

**Fix.** Mint `grossShares - feeShares` to the depositor and `feeShares` to `feeTo`, in every copy of `_mintWithUsageFee`. Supply then grows only by the backed `grossShares`. The call sites need matching changes:
- Exact-in: check `minAmountOut` against net shares.
- Exact-out: gross up with `ceilDiv(shares * WAD, WAD - feePct)`.
- Previews: return net shares.

Defense in depth:
- Add a `MAX_USAGE_FEE` cap (for example `1e17`).
- Put fee increases behind a timelock or queue.
- Optionally add a symmetric exit fee.
- Allow an explicit 0% per-vault override. Today a 0 override falls back to the 5% global default.

---

<a id="apex-2026-045"></a>

### APEX-2026-045: Lido/EtherFi/RocketPool staking SEs never check the registry kill switch, so inbound routes stay open on a disabled vault or package

**Severity:** Low · **Status:** Latent: not deployed · **Family:** Staking SE

**Summary.** `docs/VAULT_REGISTRY_DISABLE_DESIGN.md` §2.3 requires each vault to revert normal operations (deposit / swap / bond) when `isDisabled(vault) == true`. §2.1 says that disabling a package is enough to freeze every proxy deployed from it. The registry only answers the query, and enforcement is left to the vault. The Lido, EtherFi and RocketPool staking SEs are registry-deployed, but none of their targets ever calls `isDisabled`. After the owner disables both the vault and its package, unprivileged users can still mint through `exchangeIn`, mint-side `exchangeOut`, SY `deposit` and, on Lido, `exchangeInEth`.

**Affected code.**
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol:41-97, 113-125`: `_exchangeIn` and `exchangeInEth` check only deadline, amount and recipient.
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:35-47`: same gap in `exchangeOut`.
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInTarget.sol:34-45`; `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:31-42`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInTarget.sol:31-42`; `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:31-42`
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:47-58`: SY `deposit` calls `_exchangeIn`, so it inherits the gap.
- `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol:85-95`: the reference gate that these families lack.

**Root cause.**
```solidity
// LidoWstETHStandardExchangeInTarget.sol:49-52 (EtherFi l.42-45, RocketPool l.39-42 identical)
) internal override nonReentrant returns (uint256 amountOut) {
    if (block.timestamp > deadline) revert DeadlineExpired();
    if (amountIn == 0) revert ZeroAmount();
    if (recipient == address(0)) revert ZeroAddress();
```
`grep -rn "isDisabled\|VaultDisabled"` over the three family directories returns nothing. The gap already existed at aca16198, and this diff modifies all nine targets without adding the gate.

**Attack.** This is an incident-response failure, not a standalone exploit.
1. A staking SE holds honest deposits.
2. A separate bug in that SE is being exploited, for example APEX-2026-013.
3. The owner follows the playbook and calls `setVaultAddressDisabled(se, true)` and `setPackageDisabled(pkg, true)`. `isDisabled(se)` now returns `true`.
4. Any account keeps calling `exchangeIn`, `exchangeOut`, SY `deposit` or `exchangeInEth`, and every call mints. Asset<->asset routes also stay open.
5. New money keeps entering a vault the operator believes is frozen. The only remaining stop is a diamond upgrade.

**Proof of concept.** `test/apex_audit/r2-h2tb-staking-se-no-killswitch/NoKillSwitch.t.sol`
`forge test --match-path test/apex_audit/r2-h2tb-staking-se-no-killswitch/NoKillSwitch.t.sol -vvv`
```
  == Lido wstETH SE: registry.isDisabled(se)==true; inbound routes as unprivileged user ==
    exchangeIn(WETH->share) shares: 10009999999999999999999
    exchangeOut(WETH->1e18 share) WETH paid: 998910188983819
    SY.deposit ok: true shares: 5005455045454132685472
    exchangeInEth(5 ETH) shares: 5005672672044027056117
    totalSupply before/after: 100100000000000000000000 120142149845215657901328
  == CONTROL RebasingAware: deposit ok: false exchangeIn ok: false
  0x1ba84b43000000000000000000000000929627ea796725973acb22549f82d9be40b599c1
```
EtherFi and RocketPool behave the same way (supply 1.001e23 -> 1.15131e23). `0x1ba84b43` = `VaultDisabled(address)`. `IERC4626.deposit` failed for an unrelated Permit2 allowance reason, so it was left untested.

**Impact.** There is no standalone profit or loss, because shares mint at the normal rate. The harm is that the owner's documented no-upgrade emergency stop does nothing for these three packages. Harm arises only alongside a second bug that the operator is trying to contain. In that case, deposits made after the disable remain exposed, and integrators that read `isDisabled` as "frozen" are misled. The owner already relies on this switch on 4663: `disabledVaults()` returns `[0x999DaE02…]`.

**Fix.** Add the `_requireNotDisabled()` gate that UniV2/V3FS already use, built on `StandardVaultRepo._feeOracle()`, to each family's Common. Call it on the `asset -> SE` and `asset -> asset` branches of `_exchangeIn` and `exchangeOut` (this also covers SY `deposit`), and unconditionally in Lido `exchangeInEth`. Leave `SE -> asset` exits open. Gate any ERC4626 `deposit`/`mint` selectors too.

Defense in depth:
- Add a per-package regression test asserting that every inbound selector reverts `VaultDisabled` while exits succeed.
- Make the previews return 0 while the vault is disabled.
- Statically, the same gap was found on UniswapV2 `exchangeOut` and CamelotV2 (not executed).

**Related.** APEX-2026-013, APEX-2026-027

---

<a id="apex-2026-046"></a>

### APEX-2026-046: Balancer V3 SE router composite routes revert on settle misaccounting
**Severity:** Low · **Status:** Latent: not deployed · **Family:** Balancer V3 SE router

**Summary.** The SE router's composite "vault + Balancer pool" routes contain three separate accounting bugs. Each one makes the route revert inside `vault.unlock`. Route-2 exact-in (deposit then swap) and route-3 exact-out (swap then withdraw) always revert. Route-2 exact-out reverts whenever the SE exact-out mint rounds up by 1 wei. Every failure rolls back atomically, so no funds are at risk.

**Affected code.**
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapTarget.sol:531-548`: route 2 exact-in mints shares into the BV3 Vault. The swap is at :568 and the `settle(tokenInVault, actualVaultShares)` at :569 comes after it. `minAmountOut = 0` FIXME at 539-541.
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol:559-575`: route 2 exact-out settles shares with `actualAmountIn` (tokenIn units).
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol:795-922`: route 3 exact-out. The entry condition `tokenInVault == address(0)` is at :802 and the shares are sent to the router at :843.
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol:216-240`: `_exchangeOutFromVault` ("Placeholder to avoid compilation errors") always calls `params.tokenInVault`.
- `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol:512-517, 584`: the hook calls `vault.settle(shareTok, ...)` during the swap.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol:467-475`: the exact-out mint only requires `sharesOut >= amountOut`.

**Root cause.** Balancer V3 `settle` credits whoever settles first, up to the hint, and folds any excess into reserves:
```solidity
// Vault.sol:148-164
_reservesOf[token] = currentReserves;
credit = currentReserves - reservesBefore;
if (credit > amountHint) credit = amountHint;   // excess is silently absorbed
```
- **Route 2 exact-in.** The router leaves `actualVaultShares` unsettled in the Vault across a hooked swap. The hook's `settle(shareTok, smallHint)` syncs reserves to the balance and absorbs those shares. The router's later settle is then credited 0.
- **Route 3 exact-out.** The helper calls `IStandardExchange(address(0)).exchangeOut`, which reverts with empty data (`FailedCall()`).
- **Route 2 exact-out.** The hint is denominated in USDC (about 53.3e18), not in shares (about 22.5e18), so it does not cap the credit. A mint of `swapAmountIn + 1` is credited in full, which leaves a -1 share delta.

**Attack.** No attacker is needed. Any honest user hits these failures.
1. Route 2 exact-in: the user calls `swapSingleTokenExactIn(bufferPool, USDC, seVault, DAI, address(0), 50e18, 0, deadline, false, "")`, and about 24.94e18 shares are minted unsettled into the BV3 Vault.
2. `vault.swap(shares -> DAI)` invokes the hook. Its `settle(shareTok, smallHint)` absorbs the router's shares.
3. The router's `settle(shares, 24.94e18)` is credited 0, and `unlock` reverts `BalanceNotSettled`.
4. Route 3 exact-out: the swap runs and the shares are sent to the router. `_exchangeOutFromVault` targets `address(0)`, and the call reverts `FailedCall`.
5. Route 2 exact-out: the swap leaves a debt of `swapAmountIn` shares. The SE mints `swapAmountIn + 1`, and the USDC-unit hint credits all of it. The delta is -1, so the call reverts `BalanceNotSettled`.

**Proof of concept.** `test/apex_audit/fz-balancer-router-dead-routes/FzDeadRoutes.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-balancer-router-dead-routes/FzDeadRoutes.t.sol -vvv`
```
  shares pre-sent to BV3 vault      24936538295705904649
  router settle credit (hint = s)   0
  r2 exactIn amt 500000000000000000000 false
  0x20f1d86d
    DIAG2 swapAmountIn(sh) / usdcIn / minted 22467883393402675330 53330600379673194626 22467883393402675331
  r3 exactOut out 100000000000000000000 false
  0xd6bda275
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 1.20s (1.80s CPU time)
```

**Impact.** No funds are at risk. Every failure reverts the whole unlock, and the PoC asserts that user, router and Vault balances are unchanged. There is no attacker profit and no victim loss. This is a liveness failure:
- Route 2 exact-in: 0 of 6 tested sizes succeeded (0.01 to 500 USDC).
- Route 3 exact-out: 0 of 5 tested sizes succeeded (0.01 to 100 USDC).
- Route 2 exact-out: 58 random-state attempts gave 24 successes and 34 failures. The failures are a mix of `BalanceNotSettled` (this bug) and `SwapLimit` (legitimate slippage protection, out of scope). The 3 diagnosed `BalanceNotSettled` states all show `minted = swapAmountIn + 1`.

The user's only cost is gas for a reverted transaction. Users fall back to multi-step flows or to the working routes.

**Design/config note.** The buffer pool appears in no deploy script. The SE router does ship in `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol:253-304`, so the production-relevant shape is a plain weighted pool. On that shape (`FzDeadRoutesPlainPool.t.sol`), route-2 exact-in works and the scope narrows to the other two failures: route-3 exact-out reverts `0xd6bda275` at every size, and route-2 exact-out reverts `0x20f1d86d` at 200e18.

**Fix.**
- **Route 2 exact-in:** mint the shares to the router, run `vault.swap`, then call `safeTransfer(address(_balVault), actualVaultShares)` and `settle(tokenInVault, actualVaultShares)` immediately after the transfer. This ordering was verified in the PoC replicator.
- **Route 3 exact-out:** replace the placeholder with a withdraw helper on `params.tokenOutVault`. Send the shares to `address(params.tokenOutVault)` so that `pretransferred = true` holds. Pass a share-denominated bound, and in the WETH branch unwrap `params.amountGiven`.
- **Route 2 exact-out:** call `settle(tokenInVault, swapAmountIn)`.

Defense in depth: keep each transfer and its settle as one adjacent pair, always pass hints in the settled token's units, split the helper into explicit deposit and withdraw functions, and replace the `minAmountOut = 0` FIXME.

**Related.** APEX-2026-019 (different code path).

---

<a id="apex-2026-047"></a>

### APEX-2026-047: Aave V3 Stata SE: 1-wei underlying donation blocks every underlying entry; booked aToken counted as backing but never paid out
**Severity:** Low · **Status:** Latent: not deployed · **Family:** Aave V3 Stata SE

**Summary.** `_investUnderlyingIntoStata` calls `stata.deposit` on the swept booked underlying and on the caller's input. It never checks that either amount converts to at least one Stata share. StataTokenV2 reverts `StaticATokenInvalidZeroShares()` on zero shares, and `previewDeposit(1) == 0` once the liquidity index is above RAY. A 1-wei donation followed by any syncing route therefore makes every underlying-in entry revert (T1). Separately, booked aToken counts toward backing, but no exit pays it out, so early exiters are paid out of later exiters' Stata (T2). Both were introduced in this diff.

**Affected code.**
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:126-134`: the sweep `stata_.deposit(sweep_, ...)` has no zero-share check.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:135-140`: the invest `stata_.deposit(deposited_, ...)` has the same gap.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:108-111`: `_stataBacking()` includes booked aToken.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:80-92`: `_deliverStata` never pays from booked aToken.
- `contracts/vaults/basic/BasicVaultCommon.sol:48-54`: `_syncAllExpectedHoldReserves` books any donation.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:18-39`: `backingReceiptUnits` adds the booked aToken.
- Entry points: `AaveV3StataStandardExchangeInTarget.sol:62`, `AaveV3StataStandardExchangeOutTarget.sol:132`, `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18,56`.

**Root cause.**
```solidity
// AaveV3StataStandardExchangeCommon.sol:126-140
uint256 sweep_ = booked_ < capacity_ ? booked_ : capacity_;
if (sweep_ > 0) {
    ...
    stata_.deposit(sweep_, address(this));     // reverts if previewDeposit(sweep_) == 0
    ...
}
deposited_ = actualIn_ < capacity_ ? actualIn_ : capacity_;
if (deposited_ > 0) { ... stata_.deposit(deposited_, address(this)); ... }
```
- **T1.** Any `sweep_ < rate / RAY` rounds to 0 shares and reverts. The block sustains itself, because every underlying-in route reverts before it can change `booked_`. Only `_payUnderlying` (an exit to underlying) clears it.
- **T2.** `_convertSharesToStata(shares) = shares * _stataBacking() / totalSupply` includes the booked aToken, but no route converts that aToken to Stata or transfers it out.

**Attack.**
1. T1: the attacker transfers 1 wei of underlying to the SE (liquidity index > RAY).
2. The attacker runs any route that completes, for example its own 1e15 deposit. The end-of-route sync books `reserveOfToken(underlying) = 1`.
3. Every underlying-in entry (exact-in, exact-out wrap, SY `deposit(underlying)`) now reverts `0x645f628e`. Stata and aToken entries do not clear the block, and it survives a 7-day warp.
4. An exit to underlying clears the block. The attacker re-arms it with steps 1-2.
5. T2: holders A and B each deposit 100e18. The attacker transfers 10e18 aToken and syncs it with a 1e15 deposit.
6. A exits at the inflated claim. B's full exit reverts, and the aToken stays stranded.

**Proof of concept.** `test/apex_audit/gx-aave-stata/GxAaveStataAdversarial.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/gx-aave-stata/GxAaveStataAdversarial.t.sol -vvv`
```
  previewDeposit(1 wei) 0
  victim SY deposit ok? false
  0x645f628e
  victim exactIn ok? false
  victim exactOut wrap ok? false
  A got 104975099626370018059 B full exit ok? false
  B max realisable 96025900373629981938 B fair pre-donation 99999999999999999999
  aToken stranded in SE 10000000000000000000
```

**Impact.**
- **T1:** all three underlying-in faces revert. No funds are lost, and holders can still exit. The attacker pays 1 wei plus gas for each arm, and its 1e15 deposit stays withdrawable. Base-asset depositors and SY `deposit(underlying)` integrations are blocked. The only precondition is `liquidityIndex > RAY`.
- **T2:** after a 10e18 aToken donation, B can realise only 96025900373629981938 against a fair 99999999999999999999 (a shortfall of about 3.97e18). The 10e18 aToken is permanently stranded. This is griefing, not theft: the attacker nets about -5.0e18. An accidental aToken transfer has the same effect.

**Fix.**
- **T1:** skip any deposit that would mint zero Stata shares and leave the amount booked locally, using `if (sweep_ > 0 && stata_.previewDeposit(sweep_) > 0)`. Also set `deposited_ = 0` when `previewDeposit(deposited_) == 0`. Share minting already values the full input, so share math is unchanged.
- **T2:** either (a) convert booked aToken to Stata with `stata.depositATokens(bal, address(this))`, using the same `previewDeposit > 0` guard, or (b) pass `includeExpectedHoldExtra = false` in `_stataBacking()`. Option (b) is the smaller change.

Defense in depth: add an invariant that the sum of holder claims is no greater than the payable amount and that the last holder can always fully exit. Add dust-donation regression tests for every entry face.

---

<a id="apex-2026-048"></a>

### APEX-2026-048: Aerodrome SE fee compounding zaps sub-quantum dust with minOut 0, freezing every LP-moving route
**Severity:** Low · **Status:** Latent: not deployed · **Family:** V2-family SE (Aerodrome)

**Summary.** Every LP-moving Aerodrome SE route first calls `_claimAndCompoundFees`, with no try/catch. When the one-sided fee remainder exceeds a flat `DEFAULT_DUST_THRESHOLD = 1000` wei, that function sells about half of it with `amountOutMin = 0`. In pairs whose raw reserve ratio is above about 500:1, a remainder in the band (1000 wei, ~2·rIn/rOut] makes that half round to 0 output. `Pool.swap` then reverts `InsufficientOutputAmount()` (0x42301c23), and the user's whole operation reverts with it. In the PoC, a single 1e10-wei WETH swap froze every route tested. The vault can also freeze itself with no attacker at all.

**Affected code.**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:128`: `DEFAULT_DUST_THRESHOLD = 1000`, a flat raw-wei value.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:469-521`: `_claimAndCompoundFees`.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:566-588`: `_handleExcessTokens` zaps any excess above the threshold.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:635-655`: l.653 calls `swapExactTokensForTokens(saleAmt, 0, ...)`.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:41`: the SY `_redeemLpSharesFrom` (new in this diff) reaches the same compound.
- Callers: `AerodromeStandardExchangeInTarget.sol:374, 402, 434, 476` and `AerodromeStandardExchangeOutExecuteTarget.sol:260, 354, 400, 491`.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:801-811`: the preview uses the same threshold but does not revert.

**Root cause.** The sale size is `s ≈ x/2`, and the pool pays
```
out ≈ floor( (x/2)·(1-f)·rOut / rIn )
frozen band: 1000 < x < ~2·rIn / ((1-f)·rOut)
```
The band is non-empty whenever `rIn/rOut > ~500` (raw units). In the fixture pool the upper edge is about 6.7e8 wei of WETH. Inside the band, the router calls `pool.swap(0, 0, ...)`, which reverts. The revert also leaves the stored excess in place, so the vault stays frozen until external trading moves the vault's claimable fees out of the band. Each successful compound zap also returns a smaller one-sided fee to the vault, and that fee decays into the band.

**Attack.**
1. Setup: a WETH (18 dec) / USDC (6 dec) Aerodrome pool at a price of 3000, where Alice's vault holds about 50% of the LP.
2. The attacker swaps 1e10 wei of WETH for USDC through the public router and receives 29 USDC wei.
3. The vault accrues a WETH-only fee that falls inside the band.
4. Alice's withdraw, zap-out and exact-out zap-out, and Bob's zap-in, all revert `0x42301c23`.
5. The attacker re-arms after each unfreeze, using dust swaps or cheap, recoverable LP-deposit triggers.

**Proof of concept.** `test/apex_audit/gx-aerodrome-camelot-univ2/AeroCompoundDustDoS.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/gx-aerodrome-camelot-univ2/AeroCompoundDustDoS.t.sol -vvv`
```
  attacker WETH spent (wei): 10000000000
  attacker USDC received (wei): 29
  withdraw LP reverted: 0x42301c23
  bob zap-in reverted: 0x42301c23
  previewExchangeIn shares->LP (still quotes): 2738612787525830
  honest op FROZEN at: 3
  FROZEN  swap wei: 100000000000
  OK      swap wei: 500000000000
```
The control test, a 1:1 pool with 18 decimals on both sides, does not freeze.

**Impact.** This is liveness only: no principal is lost and the attacker makes no profit. Every LP-moving route that was tested reverts while the vault's pending excess is inside the band, and `previewExchangeIn` keeps quoting during the freeze. Each freeze costs the attacker one dust swap (about $0.00003) plus gas. The alternative trigger, LP deposits, is fully recoverable (20381390217 in, 20381395397 back). Depositors, SY wrappers and DETFs lose deposits and withdrawals for as long as the attacker keeps re-arming. The precondition is a raw reserve ratio above about 500:1, which covers most mixed-decimal pairs. With no attacker, the vault froze on the 4th consecutive honest operation. Recovery needs an external trade: in the PoC, 1 WETH or 100 USDC was enough.

**Fix.** Before zapping, check that the half-swap produces output. If `getAmountOut(sale, tokenIn) == 0` (or `sale == 0`), store the amount as excess instead of zapping. Apply the same condition in `_previewApplyZapSingleSided` so that preview and execution agree.

Defense in depth:
- Wrap the compound in a self-call `try/catch` so that compounding can never block exits.
- Replace the flat 1000-wei threshold with a value-aware one.
- Add an 18/6-decimal dust-fee regression test.

---

<a id="apex-2026-049"></a>

### APEX-2026-049: Camelot V2 SE exact-out LP-to-share deposit reverts on a strict `!=` share check
**Severity:** Low · **Status:** Latent: not deployed · **Family:** V2-family SE (Camelot)

**Summary.** The exact-out LP-to-vault-share deposit works in three steps:
1. It computes the LP needed with `_convertToAssetsUp(amountOut)`.
2. It converts that LP back to shares with `_convertToSharesDown`.
3. It requires `actualShares == amountOut`.

With `decimalOffset = 9`, one LP wei is worth about 1e9 shares. The round trip therefore overshoots by up to about 1e9 shares for any amount that is not on the grid, and the call reverts `AmountOutNotMet`. The UniswapV2 sibling uses `<` at the same point.

**Affected code.**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:591-593`: `amountIn = _convertToAssetsUp(amountOut, ...)`.
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:610-618`: `actualShares = _convertToSharesDown(amountIn, ...)`.
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:620`: `if (actualShares != amountOut) revert AmountOutNotMet(amountOut, actualShares);`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:208`: `previewExchangeOut` quotes without accounting for the equality requirement.
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol:584-585`: sets `decimalOffset` to 9.
- Correct sibling: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:649`, `:956` (uses `<`).

**Root cause.**
```
k = (S + 1e9) / (R + 1)          // ~1e9 shares per LP wei
amountIn     = ceil(amountOut / k)
actualShares = floor(amountIn * k)   // >= amountOut; == only on the grid
```
The overshoot is the intended vault-favouring rounding of an ERC-4626 mint. The strict `!=` treats it as a failure. Once fee shares change `S/R`, `k` stops being an integer, and after that even round amounts fail.

**Attack.** No attacker is needed.
1. The user calls `previewExchangeOut(pair, vault, amountOut)` and gets a valid LP quote.
2. The user calls `exchangeOut(pair, maxAmountIn, vault, amountOut, ...)`, and the vault pulls `ceil(amountOut / k)` LP.
3. `actualShares > amountOut`, so line 620 reverts and the pull is undone.

**Proof of concept.** `test/apex_audit/r2-h2-camelot-exactout-strict-share-equality/R2CamelotExactOutStrictEq.t.sol`. Aged-vault results come from `test/apex_audit/h2-camelot-exactout-skeptic/CamelotExactOutSkeptic.t.sol`.
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r2-h2-camelot-exactout-strict-share-equality/R2CamelotExactOutStrictEq.t.sol -vvv`
```
  preview LP for 1e18+12345 shares: 1000000001
  exact-out mints reverted: 20
  on-grid exact-out mints succeeded /10: 10
  requested shares: 3000000000000023757
  overshoot (shares): 999976243
  random exact-out mints reverted: 100
  aged: round 1e18 multiples failing /10: 10
```

**Impact.** The exact-out deposit route fails for 100/100 random amounts and for 20/20 ordinary amounts. On aged vaults it also fails for 10/10 round amounts. Only on-grid amounts, such as those derived from `previewExchangeIn`, succeed. Routers and integrators that trust `previewExchangeOut` are given quotes that cannot execute. No funds are lost: the LP balance and the share supply are unchanged (asserted). There is no attacker profit. Exact-in deposits still work.

**Fix.**
```diff
- if (actualShares != amountOut) revert AmountOutNotMet(amountOut, actualShares);
+ if (actualShares < amountOut) revert AmountOutNotMet(amountOut, actualShares);
```
The vault still mints exactly `amountOut`. The overshoot, which is worth less than 1 LP wei, accrues to existing holders. The caller never pays more than the previewed `amountIn`.

Defense in depth: add off-grid regression tests on fresh and aged vaults, and replace any `!=`/`==` share checks in other SE families with `<`.

---

<a id="apex-2026-050"></a>

### APEX-2026-050: V4 truncated TWAP credits the whole idle gap with the poked tick; permissionless update resets writeAge
**Severity:** Low · **Status:** Live on Robinhood 4663 (twapOracle `0xe473a78C654EDb7564B8f6393745d2bc6ABd8FA7`, twapAdapterFactory `0x90916b9EB39C4B7070aFC3065F3BfD492fa6dBac`), with no consumer reading it · **Family:** Oracle (Uniswap V4 truncated TWAP)

**Summary.** `UniswapV4TruncatedTwapOracleLib.write` credits the entire interval since the last observation with the spot tick read at write time, rather than the tick that held during the interval. `update(PoolKey)` is permissionless and reads live `slot0`. An attacker inside its own `PoolManager.unlock` can push the tick, poke the oracle and restore the price, paying only swap fees. After an idle gap of at least `W`, this skews the full window by 9116 ticks (2.49x). The same write resets `writeAge` to 0, so the adapters' `maxWriteAge` check passes. The bug predates this diff.

**Affected code.**
- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:86`: `recordedTick = truncate(tick_, state_.prevTick)`, where `tick_` is the live spot tick.
- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:98-107`: credits the whole gap with `recordedTick`. `:111-112` moves the anchor and resets the age.
- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:150, 239-251`: the read side extrapolates the live tick across the gap.
- `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol:32-45`: `update` has no access control and no `isUnlocked` check.
- `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol:126-133`: `writeAge` measures only the time since the last write.
- `contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol:90-94` and `contracts/oracles/uniswap/v4/twap/UniswapV4TwapAggregatorV3Adapter.sol:99-103`: the `maxWriteAge` gate.
- `contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol:19-43`: adapter creation is permissionless.

**Root cause.**
```solidity
int24 recordedTick = truncate(tick_, state_.prevTick);          // :86, live tick
delta = time_ - last.blockTimestamp;                             // :100
tickCumulative: last.tickCumulative + int56(recordedTick) * int56(uint56(delta)),  // :104
```
So `meanTick = prevTick + 9116` whenever `g >= W` and the push is at least 9116 ticks. Uniswap V3 credits the interval with the tick that held *before* the write. This library credits it with the tick at the end of the interval, so a single atomic push-poke-restore moves the whole window.

**Attack.** Precondition: a consumer prices off an adapter with window `W`, and the pool's TWAP has not been written for at least `W`.
1. Optionally call `increaseCardinalityNext(id, n)`, which is permissionless.
2. In the block's first oracle touch for the pool, the attacker calls `PoolManager.unlock`.
3. In the unlock, swap to `getSqrtPriceAtTick(t0 + 9200)`.
4. Call `twapOracle.update(key)`, which credits the whole gap with `prevTick + 9116`.
5. Swap back to the exact original `sqrtPriceX96` and settle. Only the fees are paid, and no flash loan is needed.
6. Borrow against collateral priced at `prevTick + 9116`. `writeAge = 0`, so `maxWriteAge` passes.
7. Optionally escalate: each subsequent first-in-block write can walk the price a further 9116 ticks.

**Proof of concept.** `test/apex_audit/probe-twap-retroactive/TwapRetroactive.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/probe-twap-retroactive/TwapRetroactive.t.sol -vvv`
```
  attacker net profit (fair px) 447133181374391205066726
  lender bad debt (debt - coll fair value) 450000000000000000000000
  spot tick after restore -1
  consult(W=1800) mean tick 9116
  morpho price (1e36 = fair) 2488187224469886597000000000000000000
  attacker cost token0 1109433808736718634280
  attacker cost token1 1757384816872076298994
```
The lender in the profit test is a hypothetical 86%-LLTV market written in the test file. It is not protocol code.

**Impact.** On a 1M/1M full-range pool with `W` = 1800 s, the attacker paid about 2,866.8 tokens in fees (about 0.29% of one side's depth). That moved `price()` to 2.488e36 against a fair 1e36. Against the hypothetical lender, the attacker made +447,133.18 tokens and the lender took 450,000 in bad debt. The attack is profitable only when LLTV > about 0.402, and it is bounded by the lender's liquidity. An honest write inside the window dilutes the skew to `9116 * g / W`. No contract, script or deployment reads the TWAP today, so the realised loss is 0. Adapters are permissionless, and any future integrator would be exposed.

**Fix.** Credit the elapsed interval with the anchor tick that held before the write:
```diff
-   tickCumulative: last.tickCumulative + int56(recordedTick) * int56(uint56(delta)),
+   tickCumulative: last.tickCumulative + int56(state_.prevTick) * int56(uint56(delta)),
```
On the read side, extrapolate with `state_.prevTick` instead of the live tick.

Defense in depth:
- Make `update` a no-op while `isUnlocked`.
- Have adapters require a minimum observation count or covered span, plus a deviation bound.
- Document the keeper-frequency and LLTV requirements.

The fix needs a new package version and new instances. Existing adapters will not pick it up.

---

<a id="apex-2026-054"></a>

### APEX-2026-054: Deployed CP buffer hooks never approve their SE, so DETF burn, `closeBondMature`, `redeemClaim` and hook `withdraw` revert
**Severity:** Low · **Status:** Live on Robinhood 4663 (RICH CP-DETFs `0xc2FBe67c`, `0xCE74BC02`, `0x40B61352`; e.g. RICH hook `0x25Ef9b3036Ac1faA5090bbFadC68b2EED0f56888`; SE `0x201d31a56c58a3489beC218c7A899d59A07A35f0`), pre-HEAD bytecode, fixed in HEAD source · **Family:** Deployed CP buffer hooks / CP-DETF (pre-HEAD bytecode)

**Summary.** The deployed constant-product buffer hooks (package `0x407A1e8e`) hold their pair leg as shares of the old V4 SE `0x201d…`. To pay WETH out, the hook calls `SE.exchangeIn(seShares, …, pretransferred=false)`, and the SE pulls the shares with `transferFrom(hook)`. The deployed hook never approves the SE, so every path that unwraps SE shares reverts with `TransferFromFailed()` (`0x7939f424`). This happens today, independent of any kill switch.

**Affected code.** (HEAD source containing the fix; the deployed bytecode predates it)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:82-94` (`unwrapSeShares`)
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:321-347`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:303-306`

**Root cause.** The pre-HEAD hook unwrap calls `exchangeIn(…, pretransferred=false)` without approving the SE. On chain, `0x201d….allowance(0x25Ef9b30…, 0x201d…) = 0` while `0x201d….balanceOf(0x25Ef9b30…) = 493973383033351884`. HEAD does `IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn)` before the call and resets it to 0 afterwards.

**Attack.** No attacker; user exits fail:
1. DETF burn to WETH (`RICH.exchangeIn(RICH → WETH)`) reverts `TransferFromFailed`.
2. Bond NFT `closeBondMature` reverts; real matured bond id 3 on `0xc2FBe67c` (owner `0xB36fcB6E…`, matured at ts 1787749021) cannot be closed.
3. Claim-token `redeemClaim` reverts.
4. Hook `withdraw` / `withdrawSingle` (owner = the DETF) reverts.

Still working: hook-pool sells RICH → WETH, `claimRewards`, `sellPositionToDetfNft`, ERC20 transfers, views.

**Proof of concept.** `test/apex_audit/p11-killswitch/KillSwitch.t.sol` (fork of live 4663, no state cheatcodes on the hook)
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/p11-killswitch/KillSwitch.t.sol -vvv`
```
real id3 owner / unlock / now 0xB36fcB6E… 1787749021 1792602837
  PROBE real id3 closeBondMature: REVERT 0x7939f424
  PROBE real id3 claimRewards: OK
  PROBE real id3 sellPositionToDetfNft: OK
sib DETF burn ->WETH: REVERT 0x7939f424 ; sib hook sell ->WETH: OK ; sib new mint: OK
RICH hooks value in SE201D wei 505628403878820
```

**Impact.** DETF holders cannot burn to WETH; bond holders cannot close matured bonds or redeem claim tokens. Value is frozen, not stolen, and small: the hooks' share of `0x201d` NAV is about 0.0005 ETH. Holders retain alternative exits (`sellPositionToDetfNft`, `claimRewards`, hook-pool sells). New mints still succeed, so new deposits enter a stack whose main exits are broken. Compounds with APEX-2026-010: the kill switch on `0x201d` also closes the hook-pool sell path, leaving no WETH exit.

**Design/config note.** Severity adjusted Medium -> Low: HEAD's `forceApprove` in `…WithdrawalLib.sol:82-94` shows the exits are meant to work, but the unwrappable WETH leg is about 0.0005 ETH, working alternative exits remain, and the RICH stack has had no on-chain activity since mid-September.

**Fix.** There is no owner setter to add an allowance or re-point the hook, and no diamondCut on the hook. Migrate to HEAD-built hooks/DETFs (which include the `forceApprove` fix), or use a registry-level diamondCut if available for these packages. Meanwhile stop new deposits into the RICH stack and announce the frozen exits before disabling `0x201d`. Defense in depth: fork tests exercising every exit path against deployed bytecode before calling a deployment live.

**Related.** APEX-2026-010, APEX-2026-036

---

<a id="apex-2026-036"></a>

### APEX-2026-036: Deployed CP buffer hooks still run the APEX-005 inverted pretransfer credit with no caller gate

**Severity:** Info · **Status:** Live on Robinhood 4663 (CP hook package `0x407A1e8e8799A30c111CCB7358B976FA9A30F876`, all 12 hooks. Armed on funded hooks `0x1ca1771d04366761a2aEf7Ea26F9e18bC8bb6888`, `0x25Ef9b3036Ac1faA5090bbFadC68b2EED0f56888`, `0x46D949601BAE5c7ae0d5792487758862FA6be888`, `0x923877336b14662cFb5B3A60b14e7d716d54A888`, `0xbbC8D3c8cF1149c36769b4FB0d6d6f8d2d34a888`) · **Family:** CP buffer hooks (deployed, pre-HEAD bytecode)

**Summary.** The deployed single-SE constant-product buffer hooks compute pretransfer credit as `U = B0 >= R ? B0 - R : B0`. For the pair leg, `R` is the hook's virtual SE claim and the face balance is normally 0, so `R > B0` always holds and the whole face balance is credited to the first caller. The deployed code has no caller check, so an EOA can claim pair tokens that someone else left on a hook. The source is fixed at `2ba07631`, but the deployed bytecode is not.

**Affected code.**
- Deployed source (`d148ca35`/`aca16198`): `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:768-783` (`_securePull`, inverted formula at `:778` in `d148ca35`), `:631-656` (`exchangeIn`, no caller check), `:190-194` (`R(pair) = _seClaim()`)
- Fix at `2ba07631`: same file `:885` (`LocalCreditLib.requirePretransferCaller`), `contracts/utils/LocalCreditLib.sol:14-16, 24-28`

**Root cause.**
```solidity
uint256 B0 = tokenIn.balanceOf(address(this));
uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
uint256 U = B0 >= R ? B0 - R : B0;          // :778
if (claimed > U) revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
return claimed;
```
On every funded hook `R(pair) > 0` and `B0(pair) = 0`, so the `: B0` branch is taken, and nothing on that path checks `msg.sender`.

**Attack.**
1. A third party transfers pair tokens (WETH) to a hook outside an atomic transaction, for example as a mis-send or a two-step integration.
2. Any EOA calls `hook.exchangeIn(WETH, B0, RICH, 0, eoa, true, deadline)` and receives RICH.
3. The EOA sells the RICH back through the hook for WETH. It spent no capital.

**Proof of concept.** `test/apex_audit/live-cp-hooks/LiveCpHooks.t.sol` (`test_B_invertedCredit_strayPairOnHook`). The test forks live 4663 through `LIVE_FORK_URL` or the public RPC.
```
FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/live-cp-hooks/LiveCpHooks.t.sol -vvv
```
```
[PASS] test_B_invertedCredit_strayPairOnHook() (gas: 8532404)
  R(WETH) stored 1833217760000000000
  B0(WETH) 0
  RICH received for WETH never sent by the attacker 662193285086465596
  WETH realised by attacker (cost 0) 10184122693012329
```

**Impact.** A victim's stray 0.01 WETH on hook `0x1ca1771d` was claimed by an unrelated EOA and sold back for 10,184,122,693,012,329 wei (about 0.010184 WETH) at zero cost. The 184,122,693,012,329 wei surplus came from hook/SE backing, and its source was not broken down. The loss requires someone else to leave pair tokens on a hook outside an atomic transaction, which normal protocol flow never does. All hooks hold 0 pair face today, so nothing is at risk at rest.

**Design/config note.** Downgraded from Low to Info. The owner's clarification states that "Any unrecorded local balance is treated as a valid pretransfer" and that multi-transaction pretransfer is unsupported use (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:8-9`). At HEAD a contract caller still gets `available(B0, 0) = B0`. The real gap is that the deployed bytecode lacks the R13 EOA guard.

**Fix.**
- Move the CP hooks to the `2ba07631` facets, either with a new package plus liquidity migration or with a diamond cut on the 12 hooks. This adds `requirePretransferCaller` to `_securePull` and `_secureSwapPull`.
- Until then, document that pair tokens must never be sent to a hook in a separate transaction from the call that consumes them.
- Defense in depth: buffer idle pair face into the SE before measuring credit. Add a deployment-checklist fork test that expects `EOAPretransferNotAllowed` from each live hook.

**Related.** APEX-2026-005 (source fix not deployed here), APEX-2026-010, APEX-2026-054 (migrate together). The same deployed facets also carry the pre-HEAD APEX-2026-007/008 dust-refund code.

---

<a id="apex-2026-051"></a>

### APEX-2026-051: AnalyticComposition._certify 50 bps impact check is a no-op (memory aliasing)
**Severity:** Info · **Status:** Latent: not deployed · **Family:** V4 FullSpread (hookless analytic planner)

**Summary.** `_certify` takes a "snapshot" with `Types.Snapshot memory original = walk_.state;`. That assignment copies a pointer, not the data. `_afterSwap(original, ...)` then also overwrites `walk_.state`, so the 50 bps price-impact gate compares a value with itself and always passes. `previewExchangeIn` and `quoteTransition` therefore certify zap-in plans that move the price well past 50 bps. `exchangeIn` rejects those same plans with `PriceImpactExceeded`. This was introduced in this diff.

**Affected code.** All paths are under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.
- `analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol:333`: creates the pointer alias.
- `analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol:343`: `_afterSwap(original, plan_.swap)` mutates the shared struct.
- `analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol:348-350`: the self-comparing `_priceWithin` check.
- `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:1113-1114`: execution re-checks the bound against live `slot0`.

**Root cause.**
```solidity
Types.Snapshot memory original = walk_.state;          // l.333: same memory
...
_afterSwap(original, plan_.swap);                       // l.343
if (!Protection._priceWithin(walk_.state.position.sqrtPriceX96,   // == sqrtPriceAfterX96
                             original.position.sqrtPriceX96,      // == sqrtPriceAfterX96
                             IMPACT_BPS)) { return (..., Failure.Rejected); }  // unreachable
```
Elsewhere the code deep-copies with `abi.decode(abi.encode(...))` (`_plan` l.103, `_zeroSwap`).

**Attack.** No attacker is needed.
1. On an idle vault, a caller requests `previewExchangeIn(token1, X, vault)` with an `X` whose composition swap moves the price by more than 50 bps. The preview returns shares > 0.
2. The caller submits `exchangeIn` with `minShares = preview`, and it reverts `PriceImpactExceeded()`.

**Proof of concept.** `test/apex_audit/analytic-impact-noop/AnalyticImpactNoop.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/analytic-impact-noop/AnalyticImpactNoop.t.sol -vvv`
```
  plan.valid true
  slot0 sqrtP before 79228162514264337593543950336
  planned sqrtP after 80015982406100339109357649329
  planned price move bps (approx) 199
  previewExchangeIn shares 9935505489740018676810
  RESULT: preview>0 but exchangeIn reverts PriceImpactExceeded; no value moved
    max price impact bps among valid 954
    valid plans exceeding 50bps 14
```

**Impact.** No funds move. The preview promises shares that execution refuses, and the caller loses gas on a reverted transaction. In the default fixture, 14 certified plans exceeded 50 bps (the worst was 954 bps), all in the token1-input direction. This is not a DoS: with a working gate, the same deposits would preview 0 and still be refused. Execution's own check against live `slot0` means an over-bound deposit can never settle.

**Fix.** Capture `uint160 priceBefore = original.position.sqrtPriceX96;` before `_afterSwap`. Then compare `_priceWithin(priceBefore, plan_.swap.sqrtPriceAfterX96, IMPACT_BPS)`. Alternatively, deep-copy the snapshot.

Defense in depth:
- Replace the three independent `50` constants with one shared constant.
- Add a preview/execution parity test over a geometric size sweep in both directions.

---

<a id="apex-2026-052"></a>

### APEX-2026-052: AaveCrossVersionLoop never initializes EIP712Repo, so permit fails with standard signers
**Severity:** Info · **Status:** Latent: not deployed · **Family:** Aave cross-version loop

**Summary.** `AaveCrossVersionLoopDFPkg` cuts `ERC5267_FACET` and `ERC2612_FACET` into every loop vault, but `initAccount` never calls `EIP712Repo._initialize`. `DOMAIN_SEPARATOR()` is therefore built from `bytes32(0)` name/version hashes, while `eip712Domain()` advertises `name = ""` and `version = ""`. Standard EIP-712 signers produce a different digest, so `permit` reverts. Every other share-token DFPkg in the tree performs this initialization.

**Affected code.**
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol:159-181` (`initAccount`; l.178 `ERC20Repo._initialize(...)`, no `EIP712Repo._initialize`)
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol:222-226` (`facetCuts()`; ERC5267 l.225, ERC2612 l.226)
- `lib/crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol:133-139`, `161-166` (`_domainSeparatorV4` / `_buildDomainSeparator`)
- `lib/crane/contracts/tokens/ERC2612/ERC2612Target.sol:39-59` (`permit`)
- Reference: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol:209`, `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol:219` (`EIP712Repo._initialize(name_, "1");`)

**Root cause.**
```
DS_onchain = keccak256(abi.encode(EIP712_TYPE_HASH, bytes32(0), bytes32(0), chainid, vault))
DS_5267    = keccak256(abi.encode(EIP712_TYPE_HASH, keccak256(""), keccak256(""), chainid, vault))
DS_erc20   = keccak256(abi.encode(EIP712_TYPE_HASH, keccak256("Aave Cross-Version Carry Loop"), keccak256("1"), chainid, vault))
```
`DS_onchain` differs from both. A signature over `DS_5267` or `DS_erc20` recovers an unrelated address and `permit` reverts with `ERC2612InvalidSigner`. Only a signer that hashes the raw on-chain `DOMAIN_SEPARATOR()` succeeds.

**Attack.** No attacker; honest-user failure:
1. Loop vault deployed via `VaultRegistry.deployVault`; `initAccount` initializes ERC20 but not EIP712.
2. Alice deposits and receives `axCARRY` shares.
3. Her wallet discovers the domain via `eip712Domain()` (`name=""`, `version=""`) and signs `Permit(...)`.
4. `permit(...)` reverts; allowance and nonce stay 0. Same result using `name()` with version `"1"`.

**Proof of concept.** `test/apex_audit/r3-h3-aave-loop-eip712-uninit/AaveLoopEip712Uninit.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/r3-h3-aave-loop-eip712-uninit/AaveLoopEip712Uninit.t.sol -vvv`
```
[PASS] test_r3_eip712_uninit_permit_dos() (gas: 36352027)
  ERC20 name(): Aave Cross-Version Carry Loop
  eip712Domain.fields: 0x0f
  DOMAIN_SEPARATOR(): 0xf203bb96e694da54bed36903948519b19de933d96f2d0e2f8855ca8ff69ab567
  built w/ bytes32(0) hashes: 0xf203bb96e694da54bed36903948519b19de933d96f2d0e2f8855ca8ff69ab567
  std signer from eip712Domain(): 0xfa1a87cb9dff1cba76cc28e45f9b0b812874481e52f77d36dc83e476287f7d3f
  std signer name()+'1': 0x3d85e533a2cdada7ccb10e464eaa8c2288d1fbd6213f0183cf7e1bc18ad8f529
```
Permits over both standard domains revert; a control permit over the raw `DOMAIN_SEPARATOR()` succeeds.

**Impact.** No funds at risk; attacker profit 0, victim loss 0. `axCARRY` holders and integrators lose ERC-2612 gasless approvals and router/zap flows that call `permit`. `approve`+`transferFrom` and Permit2 still work. The separator still binds `chainid` and `address(this)`, so there is no replay or forgery path. Every loop vault deployed from this DFPkg is affected.

**Fix.** In `AaveCrossVersionLoopDFPkg.initAccount`, after l.178:
```solidity
EIP712Repo._initialize("Aave Cross-Version Carry Loop", "1");
```
(plus the `EIP712Repo` import), matching the ERC4626 and Morpho siblings. Defense in depth: make `ERC2612Target.permit` (or `EIP712Repo._hashTypedDataV4`) revert when `_hashedName == bytes32(0)`; add a package-level test asserting `DOMAIN_SEPARATOR()` matches the separator derived from `eip712Domain()` for every DFPkg cutting `ERC2612_FACET`/`ERC5267_FACET`.

---

<a id="apex-2026-053"></a>

### APEX-2026-053: MultiStepOwnable `acceptOwnershipTransfer` skips the confirm step and buffer period
**Severity:** Info · **Status:** Live on Robinhood 4663 (IndexedexManager `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`, FeeCollector `0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E`, TokenStaking `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`; no transfer pending) · **Family:** Crane access control (IndexedexManager, FeeCollector, hook DFPkgs, TokenStaking)

**Summary.** Crane's EIP-8023 `MultiStepOwnable` is meant to run initiate → wait buffer → owner confirms → pending owner accepts. `_acceptOwnershipTransfer` checks only `msg.sender == pendingOwner` and never reads `pendingOwnerConfirmed` or `bufferPeriodEnd`, so the 1 to 3 day buffers configured across indexedex packages are not enforced. Ownership of the `diamondCut`-capable IndexedexManager can move in a single block. Only the owner key can start this. The bug is not introduced by the diff under review.

**Affected code.**
- `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:253-264` (`_acceptOwnershipTransfer`, the defect)
- `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:189-203` (`_confirmOwnershipTransfer`, the only buffer check)
- `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:158-166` (`_initiateOwnershipTransfer`, does not clear `pendingOwnerConfirmed`)
- `lib/crane/contracts/access/ERC8023/IMultiStepOwnable.sol:98,122` (spec: accept "a **confirmed** ownership transfer")
- Unenforced buffers, e.g. `contracts/manager/IndexedexManagerDFPkg.sol:261` (`3 days`), `contracts/fee/collector/FeeCollectorDFPkg.sol:192` (`3 days`), `contracts/protocols/staking/token/TokenStakingDFPkg.sol:130`, plus router, DETF-token, bond-NFT and buffer-hook DFPkgs (`1 days`)

**Root cause.**
```solidity
function _acceptOwnershipTransfer(Storage storage layoutStruct) internal {
    address pendingOwner = layoutStruct.pendingOwner;
    if (msg.sender != pendingOwner) {
        revert IMultiStepOwnable.NotPending(msg.sender);
    }
    // <-- no check of layoutStruct.pendingOwnerConfirmed
    // <-- no check of block.timestamp >= layoutStruct.bufferPeriodEnd
    address previousOwner = layoutStruct.owner;
    layoutStruct.owner = pendingOwner;
    ...
}
```
The buffer is checked only in `_confirmOwnershipTransfer`, whose sole effect (`pendingOwnerConfirmed = true`) is never read on any state-changing path.

**Attack.** Requires the current owner's key:
1. Owner key holder (legitimate or compromised) calls `initiateOwnershipTransfer(X)` on the IndexedexManager (`bufferPeriodEnd = now + 259200`).
2. In the same block, `X` calls `acceptOwnershipTransfer()`; only `msg.sender == pendingOwner` is checked.
3. `owner = X`. Monitoring has no window to call `cancelPendingOwnershipTransfer()`.

**Proof of concept.** `test/apex_audit/h3-crane-bundled-facets/MultiStepOwnableSkip.t.sol`
`FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/h3-crane-bundled-facets/MultiStepOwnableSkip.t.sol -vvv`
```
[PASS] test_managerOwnershipTransferSkipsConfirmAndBuffer() (gas: 150184)
Logs:
  configured buffer (s): 259200
```
Read-only `eth_call` with state override against live bytecode (block 94,274,003), on the manager, FeeCollector and TokenStaking. With `pendingOwner = 0x…dEaD`, `pendingOwnerConfirmed = false` and `bufferPeriodEnd = 0xffffffff`, `acceptOwnershipTransfer()` from `0x…dEaD` succeeded, while `confirmOwnershipTransfer` reverted `BufferPeriodNotElapsed(block.timestamp, 0xffffffff)`. Control: without the override, accept from `0x…dEaD` reverted `NotPending`. No transaction was sent.

**Impact.** Ownership of an IndexedexManager configured with a 259200 s buffer moved in 0 s with no confirmation. Precondition: the owner key. Marginal economic impact is none measurable: the live manager owner is an EOA (`0x72BeA6Fa…933B`) that can already call `diamondCut` and owner-only setters with no delay. What is lost is the advertised cancellation/monitoring window (`getOwnershipTransferBuffer()` = 259200 on the live manager); a mistaken `initiate` to a hostile address can be accepted immediately.

**Fix.** In `_acceptOwnershipTransfer`, revert unless `pendingOwnerConfirmed` is true and `block.timestamp >= bufferPeriodEnd`. Also `delete layoutStruct.pendingOwnerConfirmed;` in `_initiateOwnershipTransfer`, otherwise a confirm for A followed by `initiate(B)` would leave the flag set for B. Add regression tests: accept reverts before confirm, before `bufferPeriodEnd`, and after a re-initiate that follows a confirm. Deployed diamonds keep the old logic: replace `MultiStepOwnableFacet` via `diamondCut` on the manager, FeeCollector and TokenStaking. Consider a multisig/timelock owner so privileged actions are delayed too.
