# UniswapV4UpperLowerWingsStandardExchangeVault — Kimi K3 original PRD research

**Author:** Kimi K3 (independent first pass; no peer/council artifacts read). **Date:** 2026-10-05. Research only — no implementation, tests, git, or config. All prior assistant security/gas claims treated as unverified.

## 1. Product identity and paths (facts)

- No existing `UpperLowerWings`/`Wings` product files: grep across `contracts/` finds wing mentions only as **removal notes** — `…/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:663` and `…/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol:663`: "D30: center only. Wings are not created."
- Existing family tree: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/` (41-file hookless diamond package: In/Out + InMulti/OutMulti + PositionImport + LiquidReserve facets, ERC20Permit + MultiAsset vault facets, `IStandardizedYield` import in `…HooklessStandardExchangeVaultDFPkg.sol:25`). The preserved legacy V4 SE lives separately at `contracts/protocols/dexes/uniswap/v4/` with preservation evidence (`…/protocols/uniswap/PRESERVED_SOURCE_SHA256.json`, `VALIDATION.md`; README claims 654 tests/49 suites — recorded, not re-executed by me).
- **Proposed home (inference):** sibling `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, full product prefix `UniswapV4UpperLowerWingsStandardExchangeVault` on every type/file (naming law, `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:49-58` analog for vault packages; facets CREATE3, package via manager vault registry — `CLAUDE.md:28-29, 93-97`).
- **Preserve FullSpread:** the FullSpread packages and the preserved tree must not be edited; the wings product is additive.

## 2. Historical wings vs current center-only (facts)

- Historical book (`contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:64-84`): center ≈ ±1 tickSpacing (`centerWidthMultiplier = 2`); wings from `widthMultiplier`; **90% of deployable token1 in the lower wing, 90% of deployable token0 in the upper wing** (`activeLiquidityBps = 1000`); ticks frozen at first create; rebalance moved free↔deployed on the same ticks, never recast.
- Current law (same PRD §1.3, D30/D31; local-buffer PRD `…LOCAL_LIQUID_BUFFER_PRD.md:173-174`): one **full-range** center, always in range, no recast, `widthMultiplier` kept on PkgArgs for ABI but **does not size ticks**.
- Position storage today is a single `centerPosition` (`…HooklessStandardExchangeVaultPositionRepo.sol:9-22`).
- User-supplied provenance: commit `35f47b51…` named for three-wing evidence, but restored `92cdf89a^` is center-only; prior ~1.28M gas numbers are whole-test harness figures and **do not measure wings**. Unverified; the wings PRD must not cite them as wing cost.

## 3. V4 platform constraints (external, Context7 `/uniswap/v4-core`, accessed 2026-10-05)

- `PoolManager.unlock` reverts `AlreadyUnlocked` when nested (`PoolManager.sol:105`); delta functions revert `ManagerLocked` while locked; `CurrencyNotSettled` if deltas remain at callback end. One reentrancy lock per singleton — a vault called mid-outer-batch **cannot** open its own session (root cause documented in LOCAL_LIQUID_BUFFER_PRD §1.2).
- Position key = `(owner, tickLower, tickUpper, salt)` (`Position.sol:48`) → one vault **can** own center + two wing positions (distinct ticks and/or salts) and mutate all three inside **one** unlock callback. Wings are architecturally cheap to co-manage when idle; **impossible to touch while blocked**.

## 4. Accounting / custody vs economic backing (current hookless model to inherit or deviate from)

- Aperture PRD §5 (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md:91-115`): `B_i = D_i + F_i + E_i` — deployed principal via **exact finite-range math**, spendable local sleeve excluding caller credit, uncollected own LP fees; collection moves E→F once; no amount double-counted or lost.
- Issuance: `m = min(floor(S·C0/B0), floor(S·C1/B1))` with 1 bp alignment (`10000·m·B_i ≥ 9999·S·C_i`); protection constants 1 bp alignment / 50 bp composition impact / 25 bp holder repair / 10 bp execution shortfall (A8). NAV/oracle issuance and idle internal-CP admission are **historically rejected** (aperture out-of-scope `:59`).
- Hookless inventory snapshot (`…Hookless…Common.sol:125-146`) values free + collectable fees + one position; a wings vault must generalize D_i and E_i over **three** positions (each computed at current price with finite-range math) and define which positions are "managed book" for repricing.
- Custody precedent: `reserveOfToken` = booked ERC-20 on the diamond; sleeve free = `balanceOf` (donations count, LOCAL_BUFFER D29); ERC-6909 claims not double-counted.

## 5. Sleeve / blocked state (must be settled by this PRD)

- Precedent law: blocked ⇒ deposits credit sleeve + mint on totals, amount-out pays requested token only if sleeve covers else reverts, no rebalance, no nested unlock (LOCAL_BUFFER D2/D4/D18; aperture A11: "deployed principal and E are not local cover").
- **Wings-specific tension:** wings concentrate capital one-sided; a blocked zap-out requesting the token whose sleeve is thin reverts more often than the full-range product at equal sleeve %. Whether the wings product keeps 20% type default, or defines wing-aware sleeve sizing, is an **owner decision** — do not silently inherit 20% as "economically safe."
- `_supportsInventoryQuote()` today requires `hooks == 0` and non-imported (`…Hookless…Common.sol:121-123`); DETF R20 (`contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md:122`) requires SE vaults proven against a **pons v2 graduated (hooked) pool** — the wings PRD must state transition-quote support on hooked pools explicitly.

## 6. Interfaces / SY / registry (facts + gaps)

- Surface precedent (FULL_RANGE PRD v1.1): `IStandardExchangeIn`/`Out` single-token zap + `IStandardExchangeInMulti`/`OutMulti` dual (join unbalanced allowed; **dual exit proportional-only**); `IStandardExchangeTransitionQuote` for hook simulation; native SY redemption path (README §"Native SY"); registry deploy via manager vault registry; disable surface allows share exits/SY redemptions.
- DETF composition (`DETF_INSTANCE_IO_ROUTING_PRD.md:106` R5): `IoRoute.vault` must be a bound SE on the hook; **token may be the vault's share or any token in `vault.tokens()`** — matches the owner's "SE vaults or bare tokens" clarification. The wings vault is composable wherever a FullSpread SE is, **if** it implements the same transition-quote + SY surface.
- D60 rate-provider law (`docs/agent/INDEXEDEX_AGENT_LAW.md:233-242`): any buffered leg on Weighted/Orbital/CP hooks needs an `IRateProvider` for this vault's share. **Owner decision:** the rate semantics for a wings-vault share (who computes it, manipulation resistance given wing concentration).

## 7. Consumer matrix (required by task)

- **Weighted SE buffer hook:** n∈[2,8] legs (`…WeightedBufferHookRepo.sol:11`). Matrix: wings SE on **1..8 buffered legs** × remaining legs raw (each raw combination), rate provider on every buffered leg (D60), identity/raw combos, mixed decimals (B_P18_R6-style rows).
- Orbital (3-leg) with wings SE on 1–3 legs; single-CP / dual-CP hooks; DETF mint/burn/bond/SY routes (R5); pons v2 graduated pool fixture (R20); `V4FundedBindings`-style consumer suites (distinguish wrapper fixtures from actual-position fixtures).
- Nested-lock matrix: wings vault as SE of a hook during outer `unlock` — deposits via sleeve; wing liquidity provably untouched; cover/short amount-out.

## 8. Adversarial matrix (wings-specific)

1. Donation via free balances (accepted D29 precedent — restate explicitly).
2. Price walking into a wing: one-sided conversion; redemption of the depleted token; blocked-state wrong-token reverts.
3. Wing-edge JIT/tick-crossing attacks around concentrated wing liquidity; self-composition swaps crossing the vault's **own** wing liquidity (price impact protection constants may not cover own-book interaction — analysis required, not assumed).
4. First-mint inflation (decimal-scaled dead-sink precedent, README activation rules) with three positions seeded vs lazily created.
5. Fee double-count across three positions; E→F single move; repricing must not create pretransfer credit (aperture §5).
6. `AlreadyUnlocked` griefing; malicious-token reentrancy during blocked deposit; tick-spacing alignment edges (wing bounds must be spacing-usable).
7. Import path (if kept): blocked import hard-revert precedent (D15).
8. Sleeve drain: blocked exits capped at free; wing capital unreachable while blocked — quantify expected failure rate vs full-range.

## 9. Gas (chain-appropriate vs harness — facts and gaps)

- `foundry.toml:38` `gas_limit = 30_000_000_000` is a **harness** ceiling; the repo's only chain-cap reference is a code comment citing a 31M chain cap (`orbital/…Common.sol:1929-1931`). Historical 1.28M whole-test results measure neither wings nor chain txs.
- Wings add per-op cost: up to 3 `modifyLiquidity` + collects inside one unlock (idle path), tick-initialization on first wing touch (bitmap/word writes), wing-aware repricing math in every quote. All **unmeasured** — the PRD must require matched-state tx-level gas evidence at a stated chain cap, not harness totals.

## 10. Owner decisions (explicit; no consensus-invented defaults)

- **OD-1 Geometry rule:** wing tick-bound derivation (fixed multipliers vs explicit PkgArgs), spacing alignment, and whether ticks **freeze at first create** (historical precedent) or are recastable (new design).
- **OD-2 Allocation:** center/upper/lower/sleeve split (historical reference: ~10% center / 90%-per-side wings / `activeLiquidityBps = 1000`; 20% sleeve default belongs to the *other* product).
- **OD-3 Sleeve policy for wings:** target %, wing-aware sizing, blocked-route set.
- **OD-4 Issuance model:** proportional whole-book CP (precedent) vs anything else (NAV/oracle historically rejected — changing requires an explicit ruling).
- **OD-5 Protection constants:** reuse 1/50/25/10 bp vs recalibrate for concentrated wings + own-book composition.
- **OD-6 Import support** (PositionManager NFT) yes/no; blocked behavior if yes.
- **OD-7 Hooked-pool transition quotes** (R20 pons requirement vs current `hooks == 0` gate).
- **OD-8 Rate-provider semantics** for wings-vault shares under D60.
- **OD-9 widthMultiplier/PkgArgs shape** (FullSpread keeps it inert; wings must define real width args or a new ABI — new ABI needs approval).
- **OD-10 Single-token zap composition when price sits inside a wing** (own-liquidity crossing: allow, bound, or reroute).
- **OD-11 Native currency** scope (local-buffer D26 excluded; hookless handles WETH face).
- **OD-12 Restoring vs new:** for each of OD-1..OD-3, state explicitly whether the historical wing behavior is being restored (and cite it) or a new design is being selected. The ~1.28M/commit `35f47b51` evidence may not be cited as validation of either.

## 11. Missing evidence (not gathered this pass)

Hookless In/Out target internals beyond `Common.sol:90-209`; LiquidReserve target details; Weighted hook liquidity internals beyond Repo header; native SY facet wiring; no test/gas execution; commit `35f47b51` and `92cdf89a^` contents not independently diffed (user-provided provenance accepted as premise, not verified); chain gas caps for target networks unverified.
