# MiniMax M3 — NN-01 Dependency & Evidence Manifest (Bounded Round)

> **Scope:** explain only NN-01 (PRD_OPEN_QUESTIONS.md lines 67–72) in plain English; do not solve downstream items. Research-only; no shell/tests/RPC/browser/config/code, no delegation. Read PRD §§4.1, 8, 12.1, 16, CLAUDE.md excerpts, INDEXEDEX_AGENT_LAW.md excerpts. Context7 first for external library/API claims; primary docs fetched only where Context7 was insufficient. Routing metadata: `minimax/MiniMax-M3` (not provider attestation). Current date 2026-09-27.

---

## 1. What NN-01 actually asks (in plain English)

NN-01 is the **dependency and evidence manifest**: a deliverable that says, for every external contract or off-chain number this custom family depends on, **exactly which reference is pinned, what is verified, what is unverified, and where the gap is**. The PRD currently names nine dependency categories the manifest must cover (PRD §4.1, §8, §12.1, §16):

1. Existing Robinhood Vault Fee Oracle (PkgInit immutable)
2. NET, sNET, USDG token addresses and decimals (PkgInit immutables)
3. Canonical NET/USDG V2 pair address `0x59F95461E68e0c77605299791E1449f175165B54` (PRD §8)
4. Trusted Pendle Market Factory (PkgInit immutable)
5. Custom NetNet V2 SE address (PkgInit immutable)
6. Initial Pendle Market, NetNet Bond Depository, NetNet Staking (PkgArgs)
7. Reference math: V4 Weighted hook at `contracts/hooks/uniswap/v4/standardExchange/weighted/`; vendored Balancer V3 `WeightedMath.sol`; `BasePoolMath.sol:277–342`
8. NetNet on-chain: NET tax predicate/exemption; BondDepository vesting duration (PRD §12.1 records a 2-day code vs. 5-day prose discrepancy); Staking epoch/distributor
9. Standard Exchange rate-provider reference: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61–124`

The PRD §16 explicitly says **"Repository-relative paths and line ranges refer to inspected snapshots, not immutable pins. Future implementation must record deployed addresses, code hashes/revisions, constructor/configuration values and observation blocks."** That is the central gap NN-01 must close. The §16 caveat is also repeated at E04–E16 for every cited source.

The tracker closure criterion (PRD_OPEN_QUESTIONS.md line 72) is precise: **"Close when every required binding/capability has cited evidence or an explicit blocking gap; a package name, symbol, source pragma or historical address is not a release pin."** That sentence is the practical test: a manifest entry that names a path is insufficient unless it also names what is verified about the deployed instance versus what is merely a local snapshot.

---

## 2. Plain-English summary of the selected configuration (already settled)

The PRD has already chosen the **shape** of the manifest; what it lacks is the **contents**. From PRD §4.1 (lines 244–254):

- **PkgInit (immutable at Package deploy)** — six addresses: existing Robinhood Vault Fee Oracle, NET, sNET, USDG, canonical NET/USDG V2 pool, trusted Pendle Market Factory, custom NetNet V2 SE.
- **PkgArgs (per-instance)** — three addresses: initial Pendle Market, NetNet Bond Depository, NetNet Staking.
- **Discovered from market at deploy** (not Package-immutable): PT, YT, SY addresses (PRD §4.1 line 246 — "SY is not Package-immutable").
- **Package-side validation** of the SE's canonical NET/USDG V2 LP binding; hook-side validation of PT/YT/SY token relationships.
- **Hard-coded salt `"NET-DETF"`** with no caller-selected alternative; changed-args must not deploy a second instance.

PRD §8 (lines 523–540) further specifies:

- Robinhood mainnet `4663`.
- Pair `0x59F95461E68e0c77605299791E1449f175165B54` selected for NET/USDG (PRD acknowledges this address is **selected**, not verified live).
- Tax predicate depends on NET contract's `taxEnabled()`, `taxTotalBps()`, `isTaxedPair()`, `isTaxExempt()` (per §8 line 527).
- Previews and execution must verify "actual NET/USDG/LP deltas and recipient minima" (line 538) — tax is part of the quote, not slippage.

PRD §12.1 (lines 771–788) adds:

- Native BondDepository interface shape: `deposit(marketId, amount, maxPriceWad, to) → (noteId, payout)`; market 0 = USDG, market 1 = canonical NET/USDG V2 LP.
- `redeem(to)` scans **all of `msg.sender`'s notes** (no pagination).
- **Vesting duration discrepancy:** "Local implementation specifies two-day linear vesting, while historical interface prose says five days. Verify deployed code/note timestamps before relying on duration" (line 786). This is a literal unresolved deployment fact.

These are the **already selected** manifest categories. None of this is a new product decision; it is the PRD's own recorded selection. NN-01 is not asking the owner to pick categories; it is asking for an artifact that fills the values.

---

## 3. What the manifest must distinguish (the four boundaries the PRD itself draws)

The PRD implicitly distinguishes four classes of "binding." NN-01 must label each entry with one of them, because the closure test (a path is not a release pin) only makes sense once you say what the path is evidence for.

### 3.1 Fixed source/interface design (no live deployment needed)

Examples: the V4 Weighted hook math references (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:4–14,28–39,115–122,186–207`), Balancer V3 `WeightedMath.sol`, `BasePoolMath.sol:277–342`, `DETFFundedBondTarget.sol:93–125`, the bond quote chain (`UniswapV4DetfCommon.sol:104–135,267–289`), `DETFBondNFTMathLib.sol:17–50`, the `BasicVaultRepo` storage slot (`keccak256(abi.encode("indexedex.vaults.basic"))`), `StandardExchangeRateProviderFacet.sol:61–124`.

Closure requirement for this class: **pinned local revision (commit hash), plus a stated compatibility claim with what the deployed instance does**. The PRD's §16 line 931 caveat ("refer to inspected snapshots, not immutable pins") is the explicit deficit. A manifest entry that says "`WeightedMath.sol:3–39,51–70` is the reference" without a commit hash and without an executable-compatibility check is not closure.

### 3.2 Live deployment verification (live-chain state, requires RPC/mainnet)

Examples: NET/sNET/USDG deployed addresses and decimals on 4663; canonical NET/USDG V2 pair `0x59F95461E68e0c77605299791E1449f175165B54` (PRD §8 line 525: "Verify pair tokens, factory, code and live fees before implementation"); NET contract's `taxEnabled()`/`taxTotalBps()`/`isTaxedPair()` return values on the active block; existing Vault Fee Oracle address; trusted Pendle Market Factory address; any deployed NetNet BondDepository/Staking addresses.

Closure requirement for this class: **explicit on-chain observation block (blockNumber + blockHash) and the queried values**. The PRD never claims this has been done; the manifest must record when and how. Closure criterion: an entry that says "we will look up at deploy" is not closure; an entry that records `block 12345, NET.taxEnabled() == true, taxTotalBps == 500` is closure for that observation. Note that PRD §8 line 525 already records that treasury ownership of the LP does not exclude public LPs — so the observation must check the pair's token identities, not just its address.

### 3.3 New custom components without addresses (this family introduces them)

Examples: the custom NetNet V2 SE diamond package; the custom Weighted-behavior Pendle Market Vault hook; the sNET-DETF rebasing token; the wrapping NFT for external bonds; the bond NFT for internal bonds. These have **no live address** at the time the PRD is being closed; their addresses are produced by the deployment pipeline.

Closure requirement for this class: **the PRD-level spec is closed (the package is named, the role it plays is named, and what the manifest expects to observe at deploy is named) — but the address itself is out of scope until the deployment pipeline runs**. The manifest records "expected at deploy: address produced by `indexedexManager.deploy*DFPkg(...)` per CLAUDE.md deploy path; salt fixed where applicable." Closure criterion: an entry that says "TBD" without naming the deployment route is not closure; an entry that names the deployment route and the expected Repo slot for the resulting address is closure of the **design** side, and a placeholder for the address itself. This is the canonical case where closure ≠ final address.

### 3.4 Rollover-changing markets / dynamic fees / dynamic exemptions (state-bound, not deployment-bound)

Examples: the **active Pendle Market** changes via §11 atomic rollover; SY address can change at rollover ("Pendle SY is not a Package immutable, and address inequality alone must not reject a valid successor NetNet market" — PRD §4.1 line 246, §11 line 709); the **current `feeTo()`** rotates dynamically (R36, §13); NET **tax exemption** membership rotates per address (active vs queued, §8 lines 533–534: "Use active membership, not queued status"); Pendle **fee override** depends on execution-router identity (§7.1.2 line 436: "The market may override its fee by this identity. RouterStatic's own identity is not necessarily equivalent."); Pendle **PY index** and **post-expiry frozen index** are time/state-bound (§7.1.2 line 451).

Closure requirement for this class: **the manifest cannot pin a single address**; it must record the **discovery protocol** (factory-recognition check, `readTokens()`/`readState()`/`pyIndexCurrentViewYt()`, `taxEnabled()` live query at call-time, dynamic `feeTo()` resolution) and the **compatibility predicates** that gate validity (e.g., the new SY address must integrate with the validated SY redemption path; the new market must have valid PT/YT/SY relationships and an unexpired series). Closure criterion: an entry that names "the current Pendle market" without naming the discovery method is not closure; an entry that names the factory check + `readTokens()` validation + expiry-gated rollover is closure of the **change protocol**. PRD §11.1 line 719 already establishes the discovery protocol for YT; the manifest records it as a recurring check, not a one-time pin.

---

## 4. The deployment-verification trap (and how to avoid false certification)

The closure criterion says "every required binding/capability has cited evidence **or an explicit blocking gap**." That is a deliberately low bar — it does not require the manifest to certify deployed equivalence. The PRD never claims deployed equivalence (PRD §16 line 966: "No active-market identification, deployment equivalence, current fee/exemption state, gas bound or economic safety is certified"). The trap is the temptation to fill manifest cells with assertions like "VERIFIED" when only a path is named.

**Practical avoidance rule for the manifest author:** every entry has two columns — **(a) what is currently verified and how**, and **(b) what remains to be verified, with a specific closure step that does not require deployment**. Examples of legitimate "current verification" rows:

- *"Weighted hook math revision"* — pinned local commit hash; compatibility claim stated (e.g., `mulDiv` semantics match `BasePoolMath`); explicitly not executed on a live chain.
- *"Existing Vault Fee Oracle"* — `address(this)`-keyed `seigniorageIncentivePercentageOfVault` resolution observed to return non-zero for a representative vault on a specific block.
- *"NET/USDG V2 pair"` — `token0()/token1()` read against `0x59F95461…` returns NET and USDG in some order; pair factory recognized as Uniswap V2; current reserves non-zero.

Examples of legitimate "blocking gap" rows:

- *"NetNet BondDepository vesting duration"* — 2-day (code) vs 5-day (prose); the deployed instance has not been queried; the dependency remains infeasible until NN-02 design accepts a duration.
- *"Active Pendle Market"* — discovery protocol specified (§11.1, factory check + readTokens); specific market TBD until deploy; **not a closure obstacle** for the manifest, because the discovery protocol is itself the closure.
- *"Pendle SY preview reliability"* — documented as off-chain-only per Pendle's own documentation (PRD §4.5 line 303, E04); not a manifest closure item; feeds NN-10 separately.

This dual-column structure is what stops the manifest from becoming a deployment-equivalence certificate.

---

## 5. Practical closure criteria the PRD can adopt (UNAPPROVED wording, narrow checkpoint)

The following are **proposed additions** to PRD §16 / §4.1 / §8 / §12.1. They are clearly marked UNAPPROVED. The proposed human checkpoint is narrow: approve the manifest structure, not the contents.

### 5.1 Proposed §16 amendment (UNAPPROVED)

```markdown
## 16.1 Dependency and evidence manifest (NN-01)

For each binding below, the manifest records: (a) **what is verified and how** — local revision pin and/or live-observation block with the queried value; (b) **what remains to be verified**, with a specific closure step that does not require live deployment of this family; and (c) the **change protocol** if the binding is state-bound (rollover, fee oracle rotation, exemption membership).

| Binding | Class | Verified how | Blocking gap or change protocol |
| --- | --- | --- | --- |
| Robinhood Vault Fee Oracle | 3.2 (live) | blockHash+blockNumber; `feeTo()` and three-tier `seigniorageIncentivePercentageOfVault` queried against a representative vault | none for closure |
| NET, sNET, USDG addresses and decimals | 3.2 (live) | on-chain `symbol()`, `decimals()`; observation block | record any ERC-20 transfer-tax / rebasing flag observed |
| Canonical NET/USDG V2 pair `0x59F95461…` | 3.2 (live) | `token0()`/`token1()`/`getReserves()`/`factory()`; treasury-ownership of its own LP does not exclude public LPs (PRD §8) | n/a |
| NET tax predicate | 3.4 (state-bound) | live `taxEnabled()`/`taxTotalBps()`/`isTaxedPair()`/`isTaxExempt()` at call time; active-membership only, not queued | per-call; re-queries are the closure |
| Trusted Pendle Market Factory | 3.2 (live) | factory address; configuration recorded in `PendleFactoryAwareRepo` | registry-side validation per PRD §4.1 |
| Custom NetNet V2 SE | 3.3 (new component) | package wiring per `indexedexManager.deploy*DFPkg`; canonical-binding predicate per PRD §4.1 | expected address produced by registry path; recorded at deploy |
| Initial Pendle Market | 3.4 (state-bound) | factory-recognition check + `readTokens()`/`readState()`; subject to §11 atomic rollover | successor-discovery protocol |
| NetNet Bond Depository | 3.2 (live) | deployed address; verify vesting duration against code (2d) and prose (5d) before use (PRD §12.1 line 786) | record actual duration observed; PRD §12.1 must accept it before NN-02 can close |
| NetNet Staking | 3.2 (live) | `epoch()` getter signature; `Distributor.nextReward` semantics per PRD §9 | n/a |
| Custom Weighted-behavior hook | 3.3 (new component) | package wiring; reference math pinned at local revision; flagged for hook-deploy-path question (per PRD OPEN issues §11.x) | expected address produced by hook DFPkg path; **hook DFPkg vs. legacy monomorph remains an open architectural selection** |
| SY (reusable rate provider) | 3.4 (state-bound) | `exchangeRate()` and `previewRedeem(tokenOut, amountSY)`; preview reliability warning per Pendle docs | per-call; on-chain re-derivation if preview reverts (feeds NN-10) |
| V4 Weighted math / Balancer V3 BasePoolMath | 3.1 (fixed source) | pinned local commit; compatibility claim stated; not executed live | none for closure of design |
| sNET-DETF rebasing token | 3.3 (new component) | expected address from DETF-controlled child wiring; gons/K vs internal-shares model reconciliation per NN-12 | design closure pending; not a deployment equivalence claim |

A manifest row is **CLOSED** when it has either a verified record (blockHash, commit, or live observation) or an explicit **blocking gap** named with a specific closure step. Naming a package, symbol, source pragma or historical address alone is not closure.

**This amendment does not certify live deployment equivalence and does not require live deployment before design closure.** NN-01 is design closure; NN-19 covers the later quantitative acceptance matrix.

```

### 5.2 Proposed §4.1 amendment (UNAPPROVED, narrow)

```markdown
**Dependency and evidence manifest (NN-01):** the Package immutables listed above are pinned at deploy and recorded with the observation block in the NN-01 manifest (§16.1). The `PendleFactoryAwareRepo` slot is populated from the validated factory. The trusted factory's `isValidMarket(market)` (or equivalent) is the factory-recognition check; the manifest records the call shape and block, not a fabricated "current" market address. SY is not Package-immutable; the successor-discovery protocol (§11.1) is the closure.
```

### 5.3 Proposed §8 amendment (UNAPPROVED, narrow)

```markdown
**Pair binding evidence (NN-01):** the pair address `0x59F95461E68e0c77605299791E1449f175165B54` is selected; the manifest records its `token0()`/`token1()` match to NET/USDG, the factory identity, current reserves and a specific observation block, before the custom NetNet V2 SE accepts it. "Contains the canonical NET/USDG V2 LP position" is verified by token-identity + factory evidence plus the SE's directional USDG/share capability, not by an incidental nonzero LP balance.
```

### 5.4 Proposed §12.1 amendment (UNAPPROVED, narrow)

```markdown
**Native-note vesting duration (NN-01):** the deployed `BondDepository` vesting duration is recorded in the manifest from the actual contract, not from prose. PRD §12.1 prose vs. local code (2 days vs. 5 days) is resolved by observation, not by assumption. The manifest row for `BondDepository` is BLOCKED until the duration is read; the external-bond product (NN-02) inherits this closure.
```

### 5.5 Narrow human checkpoint

The owner is asked to approve **only** the four-amendment structure (the dual-column table plus three anchor amendments). The owner is **not** asked to approve specific addresses, decimals, fees or live values. Those populate the manifest at the implementation stage.

---

## 6. What NN-01 deliberately does NOT close (and why that is correct)

- **It does not close NN-02** (external-note liveness). NN-01 supplies the manifest row for `BondDepository`; the liveness design is NN-02.
- **It does not close NN-03** (full-set sync vs. hostile rewards). NN-01 lists the relevant token addresses; the state machine is NN-03.
- **It does not close NN-04** (C05 duration compatibility). NN-01 lists `DETFBondNFTMathLib` and `UniswapV4DetfCommon._effectiveLockDuration`; the per-position-class duration policy is NN-04.
- **It does not close NN-09** (TWAP interface). NN-01 lists the hook and DETF as hosts; the standard interface is NN-09.
- **It does not close NN-10** (SY preview reliability). NN-01 lists the SY address and the preview caveat; the on-chain re-derivation design is NN-10.
- **It does not close NN-12** (recipient/zero-share formulas). NN-01 lists the staking child as a new component; the model reconciliation is NN-12.
- **It does not close NN-13** (authority handoff for FoT/rebase). That is a separately authorized maintainer process; NN-01 only records that the family uses FoT NET and rebasing sNET and notes the dependency.

The tracker already encodes these dependencies (PRD_OPEN_QUESTIONS.md §3 table column "Depends on" / "Feeds"). NN-01's specific contribution is the **manifest artifact**: a single, sourced table that downstream items can reference.

---

## 7. Confidence and evidence limits

- **High confidence** on the manifest's category taxonomy (fixed source / live / new component / state-bound) because the PRD itself draws these distinctions implicitly through §4.1, §8, §12.1 and §11.
- **High confidence** that a path-named-only row does not satisfy "evidence" — this is the explicit PRD §16 line 931 caveat and the PRD_OPEN_QUESTIONS.md line 72 closure criterion.
- **Medium confidence** that the proposed amendments integrate without contradicting existing PRD text. I checked §4.1, §8, §12.1, §16 for direct conflict; none found. The amendments are additive only.
- **Not verified in this pass:** specific live addresses and current state for NET, sNET, USDG, the pair, the oracle, the factory or any NetNet contract on chain 4663. PRD §16 line 966 confirms none of this has been certified by the research round. The PRD also does not require me to invent live values; the manifest records the closure step, not the values.
- **Not asserting** that `docs/plans/detf/` exists (it does not — verified by PRD §10.2 line 637's broken citation; cross-confirmed by my prior council work and the v0.23 §18 provenance).
- **Not reopening** any settled owner decision (FoT NET, rebasing sNET, Keep-YT ingress, shared-SY egress, four-leg HLP, atomic rollover, principal cliffs, native-wrapper exception, hold-interest-token, non-blocking fee forwarding, public HLP, DETF-as-SY, fixed `NET-DETF` salt).

The narrow human checkpoint proposed in §5.5 keeps the owner decision bounded to the manifest's **structure and closure test**, not its contents.

---

**Saved file:** `docs/research/netnet-nn01-2026-09-27/minimax-original.md` (preserved unchanged). PRD itself is **not** modified.
