# MiniMax M3 — Holder-Proxy Proposal Assessment (Bounded Round)

> **Scope:** user proposes a small reusable NetNet Bond Holder Proxy Package; one proxy per NFT deployed at purchase; owner = NFT contract; PkgArgs accepts owner + `providedSalt: bytes32(tokenId)`; NFT maps tokenId↔holder; proxy purchases/owns one intended native note; NFT orchestrates claim into normal NET reserve contribution → mint/stake principal under same NFT. Accepts claim amount > expected (unsolicited notes), not full rejection. Acknowledges per-target attack persists but pooling mitigated, extra deployment cost accepted. New release rule: principal claim/reinvestment available NEXT processed epoch AFTER native bond fully claimed, vs. PRD v0.23 native-maturity-only rule. Reinvestment burns eligible old principal, creates new staked bond, preserves no incentive. PRD v0.24 §§4, 10, 12 / C08; local `BondDepository.sol`, `IBondDepository.sol`, `Constants.sol`; `DiamondPackageCallBackFactory.sol:201–232` salt namespace. Research-only. Date 2026-09-27. Routing metadata `minimax/MiniMax-M3` only.

---

## 1. Accepted from user proposal (already settled or consistent)

1. **Per-NFT isolation is selected.** PRD v0.24 §12.3 / C08 + NN-02 cross-review accept per-NFT escrows as a useful wrapper pattern. **Not reopened.**
2. **Reinvestment into normal NET reserve contribution → mint/stake principal under same NFT.** Matches PRD §12.2 line 793 ("Mint and stake NET-DETF only after actual receipt and reserve contribution, attributed under the same NFT"). Consistent.
3. **Reinvestment burns eligible old principal, creates new staked bond, no incentive.** Matches PRD §10.1 (reinvestment never applies the contraction input bonus).
4. **Atomic composition.** PRD §12.2 line 807 ("Mandatory reinvestment is atomic: collect → Keep YT → mint → stake. Any failed step reverts collection and all subsequent effects").
5. **Crane Diamond Package pattern; salt via `pkg._calcSalt(pkgArgs)` then `keccak256(abi.encode(pkg, salt))`.** Verified at `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–206`. The factory **early-returns the existing address if already deployed** (lines 215–217) — this is the collision-prevention mechanism the user wants preserved.
6. **User accepts per-target attack persists.** PRD §12.3 line 817 / NN-02 cross-review: "Unsolicited native-note proceeds are not automatically §13 fee-owned Pendle rewards; no feeTo sweep or change to their entitlement/maturity is selected here." The proposal is **consistent**: accept the excess, do not sweep.

---

## 2. Recommended factory-salt derivation (no tokenId mutation)

The user asked specifically: "recommend owner+providedSalt derivation without changing caller-provided bytes32 tokenId."

`DiamondPackageCallBackFactory.sol:206` hashes `keccak256(abi.encode(pkg, salt))` — the factory encodes `pkg` and the package's `_calcSalt(pkgArgs)` return. PkgArgs is the safe injection point for caller data **without** breaking the factory contract. The package's `_calcSalt` must include `providedSalt` in its hash, but it does NOT need to mutate `tokenId`. The cleanest derivation:

```solidity
// Inside HolderProxyDFPkg._calcSalt(bytes pkgArgs):
//   decode PkgArgs to (address owner, bytes32 providedSalt, ...);
//   return keccak256(abi.encode(providedSalt));   // or include owner too
```

The NFT contract computes `providedSalt = bytes32(tokenId)` once at purchase and passes it through `PkgArgs`. The factory hash = `keccak256(abi.encode(NetNetHolderProxyDFPkg, providedSalt))`. Two different NFTs passing the same `tokenId` produce the same proxy address; **salt namespace collision across NFTs is the intended behavior** — that proxy IS for that tokenId. **A collision only happens if two NFT contracts use the same tokenId, which the proxy must reject via `require(msg.sender == holderOf(tokenId))` on its `deposit` / `redeem` paths.**

The package itself does not need to know it's a HolderProxy; it is parameterized by `owner` and `providedSalt`. Reusability across other future bonds is therefore preserved (different NFT contracts can use the same Package with their own tokenId namespaces). **Per-tokenId uniqueness is enforced at the proxy level via `require(msg.sender == owner)`, not at the package level.**

**Do NOT mutate `tokenId`.** The NFT contract owns `tokenId` semantics (ERC-721 standard, transferable). Mutating it would break NFT portability and diverge from PRD §12.1 line 805 ("NFT transferability is selected: every remaining native-note entitlement and attributed participation component, with all locks, obligations and capabilities, follows authorized NFT control without duplication").

---

## 3. Disconfirming checks against the proposal

### 3.1 Native `noteId ≠ tokenId ≠ 0` due to preloads

`BondDepository.sol:130` returns `noteId = notes[to].length` (length-based index). The user's "one intended native purchase per NFT" assumes the holder proxy starts empty. **This is NOT enforced by `BondDepository.sol`.** Anyone can call `deposit(marketId, amount, maxPriceWad, to=proxy)` before the NFT's first purchase and append a note with `noteId = 0` (or any value), preloading the proxy's notes array.

**Disconfirming finding:** when the NFT's first purchase is later made, `noteId` is **not necessarily equal to tokenId or zero**. The proxy must record the **actual** `noteId` returned from `deposit`, not assume a known value. The NFT mapping should store `tokenId → (proxy, nativeNoteId)`, where `nativeNoteId` is what `deposit` returned, set in the same atomic transaction.

**Migration consequence:** the existing PRD's spec (line 779 "`deposit(marketId, amount, maxPriceWad, to) → (noteId, payout)`") does not bound `noteId` to be predictable. The proxy must defensively record the returned `noteId`.

### 3.2 Authorized note registration / no unselected sweep

PRD §12.3 line 817: "no feeTo sweep or change to their entitlement/maturity is selected here." The user's proposal accepts excess but does not select a destination for it. Three options, none owner-selected:

- **(A) Treat as wrapper-level treasury** (cumulative on proxy); claim sweeps to **wrapper-owned residual account**, balance carried forward. Excess is **not protocol backing**, not re-distributed. This is the user's "accept claim amount > expected" without a sweep.
- **(B) Forward to feeTo via the wrapper's `redeem(to=feeTo)`** — this is **NOT owner-selected** per NN-02 cross-review (sweep destination is a separate owner decision).
- **(C) Reject full redeem on excess** — contradicts the user's "accept claim amount > expected, not full rejection."

**Recommended:** (A) wrapper-level treasury, balance carried, used to fund future principal reinvestment on that NFT. Document as such in PRD §12.4; **no sweep to feeTo** without explicit owner approval.

### 3.3 Spoof owner / initialization / sibling cross-call protection

Holder proxy's mutable state: `address owner` (immutable is best), `bytes32 expectedTokenId` (immutable, set at deploy from `providedSalt`), `uint256 expectedNoteId` (set by NFT once at first deposit). Each function must guard:

- `deposit(...)`: `require(msg.sender == owner, "NOT_OWNER")` (NFT contract only); `require(amount > 0)`; pass through to `BondDepository.deposit(..., to=address(this))`; record `noteId = notes[to].length` after; **don't assume tokenId or 0**.
- `redeem()`: `require(msg.sender == owner, "NOT_OWNER")`; emit `Redeemed(amount, nativeNoteIds[])`; pass to `BondDepository.redeem(to=address(this))`; record excess separately.
- `pendingFor()`: `require(msg.sender == owner)`; or make public for off-chain `eth_call` (no gas).
- `noteCount()`: public view (mirrors BondDepository).
- `excess()`: public view (cumulative gifts).
- **Initialize once, refuse reinit:** owner stored at deploy as `immutable`; no setter. `initialize` function reverts if called twice (matches Crane's `Wired.sol:25–30` pattern).

**Sibling cross-call protection:** the proxy does NOT call back into the NFT contract. Composition is one-way: NFT → proxy. The proxy only emits events; the NFT observes them. **No reentrancy guard needed in the proxy** (no external calls back into attacker-controlled code during `redeem`). The BondDepository `redeem(to)` transfer is the only outgoing call, to a fixed address (Treasury), and is the last action.

### 3.4 One native intended purchase / no global iteration

The proxy's `deposit` path is invoked **once per NFT lifetime** by the NFT contract at purchase. Subsequent deposits to the proxy come only from upstream `BondDepository.deposit(marketId, amount, maxPriceWad, to=proxy)` calls from **anyone** (open, arbitrary `to`). The proxy cannot refuse upstream deposits (PRD §12.3 + NN-02).

**Atomic composition preview / failed collection:** the NFT's `harvest` path must preview `pendingFor(proxy)` (view), verify the expected amount equals the recorded `expectedNoteId.payout`, account for excess separately, then execute the redeem-then-collect-and-restake sequence atomically. If the redeem reverts (e.g., upstream pauses), the entire sequence reverts — matching PRD §12.2 line 807.

### 3.5 Excess vs expected / mixed receipts

The user's `accept claim amount > expected` requires: (1) recording the expected payout at purchase time; (2) at harvest, computing `actual - expected = excess`; (3) carrying excess to wrapper-level treasury; (4) using only `expected` for the active reinvestment cycle. **Excess cannot enter the active NET reserve contribution**, because that would mean unsolicited NET from a third party becomes common backing — exactly what PRD §12.2 line 803 ("Do not keep actually contributed assets excluded from protocol inventory") prevents for non-excess contributions. Excess is **wrapper-private** until owner-approved redistribution.

### 3.6 Persistent stranded notes

If the NFT retires (token burned) without final claim, the proxy's notes become permanently stranded. Per PRD §12.1 line 805 ("NFT transferability is selected: every remaining native-note entitlement ... follows authorized NFT control without duplication"), retirement should transfer control to the wrapper contract itself (or a designated retirement beneficiary) for one final harvest. Otherwise the proxy sits as unrecoverable dust. **Question, not answered by user:** does NFT retirement include a `transfer(to=retirementBeneficiary)` of the proxy's native entitlement? PRD line 804 names "Final release mechanics and NFT retirement remain O03/O08." This is open.

### 3.7 Deterministic pre-spam

Per Kimi's NN-02 cross-review and PRD §12.3 line 817: the proxy address is **CREATE2-derivable in advance**, so an attacker can call `BondDepository.deposit(..., to=proxyAddress)` **before the proxy is even deployed**, filling `notes[proxy]` with spam. The proxy inherits the spam on its first `deposit` call. **The proxy cannot prevent this.** Wrapper-level acceptance of the attack is the only mitigation; user's "pooling is mitigated" refers to one-NFT-per-position separation, not address-pre-positioning.

---

## 4. The release-clause question (NARROW remaining decision)

The user proposes:
> "principal claim/reinvestment becomes available NEXT processed epoch after native bond fully claimed, unlike current PRD native-maturity-only rule; reinvestment burns eligible old principal and creates new staked bond."

PRD v0.23 line 793: "Its maturity is the native NetNet bond's full-maturity timestamp, **not the next NET epoch or receiving Pendle maturity**." PRD line 613: "A claim after native full maturity must still collect NET, contribute it, mint/stake the actual funded DETF and attribute it to the NFT; **its release condition is already satisfied, so no fresh epoch/Pendle lock may be invented**."

**The user's proposal INTRODUCES a fresh NET-epoch lock on reinvested principal.** This is a **scope change** vs PRD v0.24 §10 / §12.2. Existing §10.1 reinvestment is incentive-free but does not impose a new epoch lock on the reinvested principal — it follows §9 (expansion) + §10 (lock) which are Pendle-maturity bound for fresh bonds (line 605 "Fresh bond: Assigned Pendle-maturity principal cliff with earlier funded rewards").

**Question for owner:** does the user's "next processed epoch after native bond fully claimed" **replace** the existing native-maturity-only rule (PRD §12.2 line 613) for external-bond wrapper reinvestment, or **add a new lock layer on top**? Per the prompt's instruction "don't claim every new phrase is settled beyond user": this is an **owner checkpoint**, not an implementer decision. The phrase "preserve no incentive" is accepted; the phrase "next processed epoch" is **not** reconciled with §10 / §12.2.

**Two narrow owner checkpoints:**

1. **(CK1)** Confirm the reinvestment release rule for external-bond wrapper is **next processed NET epoch** (user's phrasing), **NOT** native-maturity-only (PRD §12.2 line 613). If confirmed, PRD §10 / §12.2 / §12.3 amend.
2. **(CK2)** Confirm excess handling as **wrapper-level treasury, balance carried, not swept to feeTo** (per §3.2 (A)). If confirmed, PRD §12.4 amend. If user prefers a different destination, the proposal does not state it.

---

## 5. PRD amendment approach (proposed)

A new §12.4 with the holder-proxy pattern:

```markdown
### 12.4 Holder-Proxy NFT design (UNAPPROVED — owner checkpoints pending)

A small reusable NetNet Bond Holder Proxy Package is deployed **once** by the wrapper family. Per NFT, the NFT contract calls the factory's `deploy(NetNetHolderProxyDFPkg, abi.encode(PkgArgs{owner: address(NFT), providedSalt: bytes32(tokenId), ...}))` **at first purchase**. The factory's existing early-return-on-existing prevents salt collision across NFTs with the same tokenId within the same NFT contract. The package's `_calcSalt(pkgArgs)` returns `keccak256(abi.encode(providedSalt))`; the factory combines with the package address. PkgInit immutables: BondDepository address. PkgArgs: owner + providedSalt.

The proxy is parameterized by (owner, providedSalt); it does NOT interpret providedSalt as a `tokenId` itself, allowing different NFT contracts to share the Package with their own tokenId namespaces. Per-tokenId uniqueness is enforced at the proxy's `require(msg.sender == owner)` guard, not at the Package level.

Functions: `deposit(marketId, amount, maxPriceWad)` (only owner), `redeem()` (only owner), `pendingFor()` / `noteCount()` / `excess()` views. Excess handling: cumulative on proxy, used to fund future principal reinvestment on that NFT; **not swept to feeTo**, **not entered into common reserve contribution**. The `nativeNoteId` returned by `BondDepository.deposit` is recorded; it is NOT assumed to be tokenId or zero (anyone can append notes before the proxy's first purchase).

The NFT contract records `(tokenId → proxy, expectedNoteId, expectedPayout)`. At harvest, the NFT previews `pendingFor(proxy)`, computes `actual - expected = excess`, redeems, and routes only `expected` through the atomic collect→Keep-YT→mint→stake sequence (PRD §12.2 line 807). Excess remains on proxy.

**Owner checkpoints required (do not implement without resolution):**
- **(CK1)** External-bond wrapper reinvestment release rule is **next processed NET epoch** (replacing PRD §12.2 native-maturity-only for this feature), or the existing native-maturity-only rule applies? Per PRD §10.1 reinvestment does not impose a new epoch lock on reinvested principal; the user's phrasing is a new lock.
- **(CK2)** Excess destination is wrapper-level treasury (cumulative on proxy), not feeTo, not common reserve? Per PRD §12.3 line 817 "no feeTo sweep ... is selected here."
```

---

## 6. Questions and remaining narrowing

| ID | Question | Owner? |
| --- | --- | --- |
| Q1 | Reinvestment release rule (CK1): next NET epoch vs native-maturity-only | Yes |
| Q2 | Excess destination (CK2): wrapper-level treasury vs feeTo vs other | Yes |
| Q3 | NFT retirement transfers proxy control to retirement beneficiary, or abandons? | Yes (separate O03/O08) |
| Q4 | Mixed-receipt provenance: per-NFT separate accounting vs cross-NFT aggregation | Engineering (NN-11) |
| Q5 | Atomic composition preview: gas budget and reentrancy guard pattern | Engineering |
| Q6 | Persistent stranded notes after NFT burn | Engineering |
| Q7 | Salt-namespace cross-NFT safety: collision of `(pkg, providedSalt)` across NFT contracts | Mitigation: `require(msg.sender == owner)` at proxy (sufficient); package-level check unnecessary |

---

## 7. Confidence and evidence limits

- **High** that the proposal is consistent with PRD v0.24 §10, §12.1–§12.2 (atomic composition, no incentive on reinvestment, NFT transferability).
- **High** that the factory's salt namespace is `keccak256(abi.encode(pkg, salt))` and that the proxy must be parameterized by `(owner, providedSalt)` without interpreting providedSalt as a tokenId (verified `DiamondPackageCallBackFactory.sol:201–232`).
- **Medium** on the new release-clause question — the user's phrasing is **not** reconciled with PRD §12.2 line 613 / §10.1; needs owner confirmation.
- **Low** on the spoof / reentrancy / retirement details — engineering, not PRD-binding.
- **Not claiming** the proposal is fully specified, that every phrase is settled, that atomic composition succeeds, that excess is bounded.
- **Not reopening** per-NFT isolation decision, Keep-YT routing, shared-SY egress, four-leg HLP, atomic rollover, principal cliffs, native-wrapper exception, hold-interest-token, public HLP, DETF-as-SY, fixed `NET-DETF` salt.

**Saved:** `docs/research/netnet-holder-proxy-2026-09-27/minimax-original.md`. Originals and prior outputs untouched.
