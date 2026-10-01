# MiniMax M3 — NN-02 UI & Source-Disconfirming Findings

> **Scope:** actively seek disconfirming evidence that NN-02 (all-note loop) might not be a real problem. Read `lib/crane/contracts/protocols/pol/net/src/` directory, GenesisBond.sol, InverseBond.sol, StakedNET.sol, abstract/Wired.sol, ROBINHOOD_MAIN.sol lines 419–527 (NetNet section); webfetched `docs.netnet.capital/{mechanism, risks, founding-shareholder-guide, superstore, rwa-desk, FEES.HTM}`; webfetched Blockscout contract page for `BondDepository 0xff32…1980C1`; websearch for app source. Research-only; no RPC/shell/tests/code. Routing metadata `minimax/MiniMax-M3` only (not provider attestation). Date 2026-09-27.

---

## 1. Direct disconfirming evidence — what the prompt's challenge uncovered

### 1.1 PRD §12.1 NN-02 scope is narrower than "all NetNet bond holders"

PRD §12.1 line 778–782 describes `deposit(marketId, amount, maxPriceWad, to) → (noteId, payout); market 0 accepts USDG; market 1 accepts canonical NET/USDG V2 LP; redeem(to) collects currently vested amounts across all notes of msg.sender`. **This is the verbatim interface of `BondDepository.sol`** (verified: `IBondDepository.sol:28–42`). The wrapper's external-bond product routes through `BondDepository.sol` — not the RWA Desk, not the Superstore, not GenesisBond, not InverseBond.

### 1.2 GenesisBond.sol does NOT have the all-note loop problem

`GenesisBond.sol:55–57`: `mapping(address => uint256) public purchasedRaw;` (single uint256 per wallet), `mapping(address => uint256) public claimedNet;` (cumulative), `PurchaseRecord[] private _registry;` (array of all purchases for the founding register). **`claim()` (`:186–193`) reads `claimableNetOf(msg.sender)` (`:203–210`), which uses the single-per-wallet mappings — not the array.** `_registry` is exposed only via `registryLength()` / `registryAt(i)` (read-only views). `purchase()` is gated by `if (finalized || block.timestamp > saleDeadline) revert SaleClosed();` (`:91`), so the array is **closed at finalize()** and cannot be appended by third parties. **GenesisBond is not affected by the all-note-loop concern.**

### 1.3 InverseBond.sol does NOT have the issue

`InverseBond.sol:68–90`: `swap(netAmount, minUsdgOutRaw)` is a single-call atomic trade (NET in, USDG out, with epoch capacity check). **No notes array, no per-note selector, no redemption loop.** Not in NN-02 scope.

### 1.4 Staking/sNET/TaxCollector/Treasury/etc. — not in scope

`StakedNET.sol` (gons-based rebasing) and `Staking.sol` (epoch rebase) are not note-based. `TaxCollector.sol` and `Treasury.sol` are accumulator patterns. **None have the all-note-loop pattern.**

### 1.5 The RWA Desk and Superstore are EXTERNAL contracts, not in local source tree

`ROBINHOOD_MAIN.sol` pins RWA Desk (`NETNET_RWA_DESK = 0x99B6…1961`), RWA Sleeve (`NETNET_RWA_SLEEVE = 0x4987…7CB`), PackDesk (`NETNET_PACK_DESK = 0x7cf2…1eB`), DrandSigRegistry, ClimbDesk, CoinflipDesk, SpacexInvadersDesk, FlightSimDesk, TurboDesk, BlackjackDesk, PrizeVault, BonusBook, DrawController, NetNetGear (`0x6213…8eE`), BasketsDesk (`0xa8D5…9E416`), BoardroomDesk (`0xe109e…15eB`), NetNet Credit vault, StockMorphoOracles, etc. (constants lines 485–528).

**None of these contracts have source in `lib/crane/contracts/protocols/pol/net/src/`.** Only the **core protocol** (BondDepository, GenesisBond, InverseBond, NET, Staking, sNET, Distributor, PairOracle, PremiumSeller, PTeam, ShareCertificate, TaxCollector, Treasury) is vendored. The desks are external implementations; only their addresses are pinned.

### 1.6 `docs.netnet.capital/superstore` and `rwa-desk` claim "paginated redeem" — but for vesting wins on the EXTERNAL desks

`docs.netnet.capital/superstore` (retrieved 2026-09-27): "Vesting wins use the same note plumbing as Real World Bonds: an amount owed, per-address caps, and a **paginated redeem**." `docs.netnet.capital/rwa-desk`: "Claim it from the subscription ledger below the desk, alongside any standard bonds."

**This claim is documentary, not source-verified.** Local search confirms `paginated` appears only in `lib/crane/contracts/protocols/pol/net/{2026-08-28-netnet-pol-port-prd.md, PLAN.md}` (the Crane port plan) — **not in any Solidity file.** No per-note or paginated redemption selector exists in the vendored `BondDepository.sol`. The "paginated redeem" claim applies to the **Superstore PackDesk and RWA Desk note systems**, which use a different (external) contract than BondDepository. The claim could be:
1. Real on the external desk contract (code not available to us);
2. Wrapper/UI-side pagination that batches on top of the underlying contract (still hits the loop bound on the contract side);
3. Aspirational / misremembered documentation.

**No way to confirm from local source tree.** Pending vendor-source review of the RwaDesk / PackDesk / Real World Bonds subsource or Blockscout verified-contract source.

### 1.7 BondDepository.sol source confirms all four previous-original claims

Verified by direct read of `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol` (200 lines), `IBondDepository.sol` (55 lines), `Constants.sol` (80 lines):
- `BondDepository.sol:104–140` deposit accepts arbitrary `to`; appends to `notes[to]`; no recipient check, no callback, no cap.
- `BondDepository.sol:143–153` redeem loops `notes[msg.sender]`; line 147 `if (claimable == 0) continue;` skips the body but the loop still walks every index; `paid += claimable; net.transfer(to, paid)`.
- `BondDepository.sol:156–166` pendingFor loops all notes (no skip).
- `BondDepository.sol:168–170` `noteCount(address)` exists; `notes(address,uint256)` getter exposes individual notes via auto-generated public-mapping getter.
- `BondDepository.sol:183–189` `_checkEpochCap` uses `Constants.BOND_EPOCH_CAP_BPS = 25` (0.25% of NET totalSupply per 8-hour epoch) — caps payout value, not note count.
- `Constants.sol:17` EPOCH_LENGTH = 8h. `Constants.sol:76` BOND_VEST = 2 days (code). `IBondDepository.sol:5` says "5-day linear vesting (DEFAULT — TUNE BEFORE DEPLOY)" — the 2d/5d prose-vs-code discrepancy.
- `BondDepository.sol:191–199` `_claimable` returns linear vested-minus-claimed; after `end`, returns `payout - claimed`.

### 1.8 Local vendor provenance and deployed-equivalence gap

- Local vendor tree: `lib/crane/contracts/protocols/pol/net/src/`. Pragma `^0.8.24` per file headers. Snapshot dated **2026-08-28** per `ROBINHOOD_MAIN.sol:9` ("NetNet pins 2026-08-28 from Official Channels"). NetNet vendor snapshot was reported as 2026-08-28 in prior rounds.
- **No Blockscout verified-contract source read this round.** Blockscout contract page for `0xff32a969A0c567129eECD926D04657728E1980C1` (retrieved 2026-09-27) returned the address page but not the verified-source panel. Whether deployed bytecode matches local source is unverified — pending NN-01.
- The standard-bond flow that PRD §12.1 wrapper exercises is the **BondDepository contract**, address `0xff32a969A0c567129eECD926D04657728E1980C1`, pinned in `ROBINHOOD_MAIN.sol:440` (`NETNET_BOND_DEPOSITORY`). The wrapper calls `deposit(marketId, amount, maxPriceWad, to=wrapper)` and `redeem(to=wrapper)`.

---

## 2. Common-user vs wrapper-added cost

**Common user (direct):**
- Typical standard-bond user buys 1–2 bonds over the bond's lifetime. `notes[user].length = 1` or `2`. Loop is trivial (O(1) or O(2)).
- Each `redeem(self)` iterates those 1–2 notes; transfer fails gracefully if no balance. Gas cost ≈ a few hundred thousand (rough; not measured).
- Common user is **not meaningfully affected** by the all-note-loop.

**Active user / wrapper pattern (per PRD §12.1):**
- Wrapper owns one upstream position per NFT; wrapper holds `notes[wrapper].length` notes. Wrapper can bound its own voluntary acquisitions via local cap.
- Each `harvest()` call: wrapper calls `BondDepository.redeem(to=wrapper)` → iterates wrapper's `notes[wrapper]` → transfers NET sum to wrapper → wrapper executes atomic Keep-YT contribution + mint + stake.
- Wrapper adds **one redeem call per harvest**, not per note. Loop bound on the contract side is the same as for any common user (the wrapper's own note count).

**Attacker-injected (the residual concern):**
- Anyone can call `BondDepository.deposit(marketId, amount, maxPriceWad, to=wrapper)`. Wrapper cannot refuse. Each call appends one entry to `notes[wrapper]`. Attacker cost per call ≈ `deposit` gas (mint, push, two transfers, TWAP read, cap check) ≈ a few hundred thousand gas + dust payment.
- If attacker spams dust-payout notes (where `payout = mulDiv(valueWad, NET_UNIT, price)` rounds to ~0 with positive payment, because `BOND_EPOCH_CAP_BPS = 25` does not cap note count), the wrapper's `notes[wrapper].length` grows linearly with attacker calls. `redeem` walks every entry.
- **Wrapper bears the loop cost; attacker bears the deposit gas cost.** Common users who never interact with the wrapper are not affected; only the wrapper's harvesting/claiming operation is.

**Concentration:** the wrapper pattern **concentrates** the per-position loop cost into a small number of contracts (one per NFT). It does not increase common-user cost but it makes the wrapper's harvest call **the** target for an attacker-injected-note grief. **All common-user bond holders interact with `BondDepository` directly** (own note array, their own scale); they are not concentrated through the wrapper.

---

## 3. What is and isn't settled

**Settled (verified by direct read):**
- BondDepository.sol has no per-note selector. `redeem(to)` and `pendingFor(address)` are O(N) over `notes[msg.sender]`. Confirmed.
- `deposit` accepts arbitrary `to`. Confirmed.
- Line 147 `continue` skips body, not index. Confirmed.
- GenesisBond.sol uses single-mapping claim, not array iteration. Confirmed.
- InverseBond.sol is one-shot swap, no notes. Confirmed.
- Local source pragma `^0.8.24`; vendor snapshot 2026-08-28. Confirmed.
- The RWA Desk, PackDesk, and other desk contracts are **external**, not in local tree. Confirmed.

**Not verified (pending NN-01 / external-source review):**
- Whether deployed BondDepository bytecode matches local source.
- Whether deployed RwaDesk / PackDesk have a paginated redeem selector (docs.netnet.capital claim).
- Whether Blockscout verified-source matches local vendor (would resolve both above).

**Not closed / open design questions:**
- NN-02 closure per PRD §14.1 C08 (Astra: "must be demonstrated, not solved by an escrow label"; Grok: "no enforceable gas bound on this ABI"; Kimi: "wrapper-side bookkeeping bounded; upstream scan unbounded by design; quantified envelope").
- BondDepository.sol is the upstream source of NN-02. PRD §12.1 wrapper is downstream.

---

## 4. Corrections to prior conclusions (per prompt's instruction to actively seek disconfirming evidence)

1. **Earlier conclusion that "the all-note loop affects all NetNet bond holders" overgeneralizes.** It affects (a) standard-bond direct holders, who typically have 1–2 notes — trivial loop cost; (b) wrapper per-position escrows, which can be griefed. GenesisBond, InverseBond, Staking, sNET, TaxCollector, Treasury are unaffected. The RWA Desk and Superstore are external and may differ.
2. **The "paginated redeem" claim is documentary for the Superstore/RWA Desk, not for BondDepository.** The standard-bond flow that PRD §12.1 wraps is BondDepository.sol, which has no per-note selector.
3. **Wrapper does not change the loop bound for common users.** It concentrates per-position cost into a small set of contracts but does not increase the bound per se — the bound grows with cumulative note count regardless of holder identity.
4. **No claimed observed outage, attacker cost model, or measured N\*** (per Kimi's NN-02 cross-review framing — placeholders are not measurements).

---

## 5. NN-02 conditional recommendations (not owner decisions)

- **(R1) Scope NN-02 to `BondDepository.sol`** explicitly in PRD §12.4 / NN-02 closure; clarify that GenesisBond, InverseBond, and the external desks are separate products with separate redemption designs.
- **(R2) Document the per-note-cost-plus-attacker-economic-cost model as the residual mitigation.** Loop cost is bounded by attacker cost-per-call (deposit gas + dust payment); attacker budget is the only bound. Requires quantified measurement (NN-18).
- **(R3) Distinguish display vs write.** `pendingFor(address)` is a view — every-user observation of own state is `O(N)` but free (off-chain `eth_call`). Common user display is not the same as the on-chain claim work; it is the wrapper's `redeem(to)` write that bears the cost.
- **(R4) Vendor-source review of the external desks.** Pending whether the RWA Desk / PackDesk actually have a paginated redeem selector (docs.netnet.capital claim is unverified from code). If they do, NN-02 closes cleanly for those products; if they don't, the same grief applies to those holders.

---

## 6. Confidence and evidence limits

- **High** that BondDepository.sol has no selective redeem (direct read).
- **High** that GenesisBond / InverseBond / Staking are not affected (direct read).
- **Medium** that the RWA Desk / Superstore "paginated redeem" claim is documentary, not source-verified.
- **Low** on deployed-vs-vendor equivalence (no verified Blockscout source panel read this round).
- **Low** on attacker-cost economics (no measurement).
- **Not claiming**: any observed outage; selective redeem exists somewhere we missed; wrapper-only design bounds the work; "attack costs money" is C08 closure.
- **Not reopening**: any settled owner decision; PRD §12.1 wrapper design.

**Saved:** `docs/research/netnet-nn02-ui-2026-09-27/minimax-original.md`. Originals and prior round outputs untouched.
