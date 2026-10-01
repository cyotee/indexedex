# Grok original — NN-01 dependency and evidence manifest

| Field | Value |
| --- | --- |
| Reviewer | Independent Grok; observable routing name `grok-4.6`, ID `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| Scope | **NN-01 only.** No NN-02… solutions. No PRD edit. |
| Target | `PRD_OPEN_QUESTIONS.md` NN-01; PRD v0.23 §§4.1, 8, 12.1, 16; R55 |
| Reads | `CLAUDE.md`; local `.claude/skills/crane-architecture/SKILL.md` (PkgInit/PkgArgs on interface). Canonical `lib/crane/.claude/skills/` not re-opened this turn. No RPC, tests, or invented live addresses. |
| Context7 | Not used: no new external library API claim beyond PRD-cited Pendle/NetNet docs. |

**Status of this text:** research proposal. Any PRD wording below is **UNAPPROVED**.

---

## 1. What NN-01 is (plain English)

NN-01 is the **phone book and proof file** for this family: which contracts the package is allowed to trust, how each one is supplied, and what kind of evidence counts.

It is **not** “go live on Robinhood and freeze every address forever before we may design.” It is **not** permission to pick a different curve, tax model, or PkgInit/PkgArgs split. Those are already selected.

Three different jobs get mixed up if we are sloppy:

1. **Design pin** — repository path, git revision, Solidity interface, and “this role is PkgInit / PkgArgs / discovered.” Enough to write code and tests against **known ABIs**.
2. **Capability check** — does that ABI actually expose the methods the PRD assumes (`taxEnabled`, `epoch`, `deposit`/`redeem`, factory recognition, SY `getTokensOut`, etc.)? Still source- or hermetic-fork work, not a mainnet blessing.
3. **Live deployment verification** — chain-4663 address, code hash, constructor args, observation block. Required **before production use**, not before specification-closure of the *table shape*. A missing live hash is a **labeled gap**, not a fake pin.

A package name, token symbol, `^0.8.0` pragma, or a historical research address is **not** (3). PRD §16 already says local line ranges are snapshots, not immutable pins, and the earlier Pendle series expired 2026-09-17 UTC.

**Owner trigger (already in the tracker):** only if a **required** dependency class is unavailable or differs **materially** (wrong tokens, no factory recognition, depository ABI cannot support selected deposit/redeem). Do not re-ask family approval.

---

## 2. Already selected bindings (do not reopen)

From R55 and §4.1. Crane/IndexedEx: `PkgInit` / `PkgArgs` live on the **interface**, not the contract.

### PkgInit — package immutables (same for every instance of this Package)

| Role | Why immutable |
| --- | --- |
| Existing Robinhood Vault Fee Oracle | Usage fees + `seigniorageIncentivePercentageOfVault` + dynamic `feeTo()` |
| NET, sNET, USDG | Configured faces; decimals/identities still **verified**, not assumed from symbols |
| Canonical NET/USDG Uniswap V2 pool | Taxed pair identity; §8 names candidate `0x59F95461E68e0c77605299791E1449f175165B54` on chain **4663** as a **lead to verify**, not a certified pin |
| Trusted Pendle Market Factory | Provenance anchor; do not trust a market’s self-reported factory |
| Custom NetNet V2 SE | Hook holds **that** vault’s shares; package (not hook) asserts canonical V2 binding |

No post-deploy SE switch. Empty correctly configured SE is allowed; “contains LP” ≠ nonzero balance at deploy.

### PkgArgs — this instance only

| Role | Notes |
| --- | --- |
| Initial Pendle Market | Start of discovery; **not** the forever market |
| NetNet Bond Depository | Purchase **and** claims share this one address |
| NetNet Staking | Distinct from sNET token and from sNET-DETF |

Fixed salt `"NET-DETF"`; changed args must not mint a second instance through this Package (enforcement is NN-17, not a new address).

### Discovered at init / later (not Package-immutable)

From a **factory-recognized** market: PT, YT, SY (`readTokens()` / related). **SY must not be PkgInit.** Unrecognized market → reject **before** NetNet token checks. Successor markets after rollover are the same discovery path (NN-14), so NN-01 records the **rule**, not one eternal SY address.

Also discovered/configured into Repos: trusted factory copy in `PendleFactoryAwareRepo`; SE share token as hook custody unit.

### Not PkgInit/PkgArgs addresses (by design)

| Item | How it exists |
| --- | --- |
| NET-DETF proxy, custom hook, sNET-DETF, wrapper NFT | **Created by this family** — no pre-existing 4663 address. Manifest rows: “instance / CREATE3 or hook-factory output,” codehash **after** deploy |
| Custom NetNet V2 SE implementation | New code; **address supplied in PkgInit at deploy** of the Package, not invented now |
| Pendle router / static helper used in quotes | Must be a **named design pin** (which identity executes Keep-YT / `readState`) — still no invented live address |
| Rate providers | Design: USDG-targeted SE provider + reusable SY→sNET provider (NN-10). Addresses after those packages exist |
| Child wiring, hook CREATE2 flags | Architecture (NN-17), not extra PkgArgs |

---

## 3. What must stay *dynamic* (do not freeze as “the” pin)

- **Active Pendle market and SY** — change on successful atomic rollover; historical series remain claim locators, not the active pin.
- **NET tax/exemption** — live `taxEnabled()`, `taxTotalBps()`, `isTaxedPair`, **active** `isTaxExempt` per hop endpoints (§8). Queued exemption is not active. Cache of “untaxed” is invalid after state change.
- **Pair swap fees / LP composition** — verify before execution; treasury LP does not exclude public LPs.
- **Vault Fee Oracle terms** — `p`, `feeTo()`, bond min/max duration: three-tier, stored 0 = unset. NN-01 pins **which oracle contract**; it does not freeze numeric fees (C07 / NN-05).
- **Native-note vesting** — local source “two days” vs historical prose “five days” (§12.1). NN-01 records **both as unverified vs deployed code**; choosing duration is **not** this item’s job (NN-02/NN-15). Do not treat 2d as a release fact.
- **Token direction support** — `getTokensIn`/`getTokensOut` can list tokens that still revert at runtime (Pendle docs; NN-10). Manifest notes “listed ≠ always executable.”

External SE **upgrade/config risk** stays documented: deploy-time binding does not freeze another contract’s future bytecode (§4.1).

---

## 4. Practical closure criteria (no false certification)

**NN-01 CLOSES for specification** when a table exists with every required **role** below, each cell filled as one of:

- `DESIGN` — repo path + commit/tree id + interface; or “to be deployed by this Package”
- `CAPABILITY` — named methods/events the design relies on, traced to that interface/source
- `LIVE` — chain 4663 address + codehash + observation block, **or**
- `GAP` — explicit blocker (missing ABI, wrong tokens, factory not on 4663, etc.)

Required roles at minimum: chain; fee oracle; NET; sNET; USDG; canonical V2 pair; Pendle factory; custom V2 SE (PkgInit slot); initial market; depository; Net staking; discovery rule for PT/YT/SY; execution router identity; WeightedMath / BasePoolMath **source revision**; V2 SE **reference package** path (E14); bond-calc source chain (E15).

**Does not close NN-01:**

- Filling `LIVE` with symbols or the §8 pair **unchecked**
- Claiming local `lib/crane/...` NetNet/Pendle files equal Robinhood bytecode
- Waiting to design until every `LIVE` cell exists
- Inventing fee-oracle, staking, depository, factory, or SY addresses

**Does not reopen:** Keep-YT routing, four-leg HLP, salt, PkgInit vs PkgArgs split.

Live `LIVE` cells are a **later production gate**. Design may proceed on `DESIGN`+`CAPABILITY` plus labeled `GAP`s. Owner is asked **only** if a `GAP` says a selected role cannot be bound.

---

## 5. UNAPPROVED proposed PRD wording (narrow)

*Not operative. For owner/moderator acceptance into §4.1 or a new §16.1 only.*

```markdown
### 16.1 Dependency manifest (specification pin — UNAPPROVED draft)

NN-01 evidence is a table, not a claim that Robinhood bytecode matches the worktree.

| Role | Supply | Evidence class | Notes |
| --- | --- | --- | --- |
| Chain | Selected 4663 | DESIGN | LIVE pair/factory/oracle still verified before production |
| Vault Fee Oracle | PkgInit | DESIGN path + LIVE later | Identity `address(this)` per proxy; `feeTo()` and terms remain dynamic |
| NET, sNET, USDG | PkgInit | DESIGN; decimals/LIVE later | Symbols do not prove address or units |
| Canonical NET/USDG V2 pool | PkgInit | DESIGN; candidate in §8 is unverified LIVE | Verify token0/token1, factory, codehash, fees |
| Pendle Market Factory | PkgInit | DESIGN + CAPABILITY | Recognition before token relationships |
| Custom NetNet V2 SE | PkgInit | DESIGN (“deployed by this effort”) | Package validates canonical binding; hook does not |
| Initial Pendle Market | PkgArgs | DESIGN; not immortal | Discover PT/YT/SY; SY not Package-immutable |
| Bond Depository | PkgArgs | DESIGN + CAPABILITY | Shared by purchase and claims |
| NetNet Staking | PkgArgs | DESIGN + CAPABILITY | Not sNET and not sNET-DETF |
| PT/YT/SY, successor market | Discovery | DESIGN rule | Rollover may change addresses; historical series retained |
| NET-DETF, hook, sNET-DETF, NFT | Created | DESIGN | No pre-existing address required to close this table |
| Tax/exemption, pair fees, oracle p | Live reads | CAPABILITY | Never a one-time pin |
| Note vesting length | — | GAP until deployed depository codehash | Local 2-day vs prose 5-day is not a fact |

A DESIGN+CAPABILITY row with GAP on LIVE is sufficient to continue specification.
A GAP on CAPABILITY (required method missing) is an owner trigger.
This subsection does not certify deployed equivalence.
```

---

## 6. Narrow human checkpoint (NN-01 only)

**Do not ask:** “Approve the family again?” “Pick live addresses from memory?” “Is 2-day or 5-day vesting?” “What are weights/fees?” (those are other NN items.)

**Ask only if needed:**

> A required PkgInit/PkgArgs **class** (oracle, NET/sNET/USDG, canonical pair, Pendle factory, depository, Net staking, or factory-recognizable market) cannot be bound on 4663, or bound bytecode **materially** lacks a capability the PRD already selected. If every class is bindable in principle, **no owner decision is required to accept the manifest schema.**

---

## 7. Limits

- No live addresses invented. §8 pair cited only as PRD candidate.
- Crane NetNet/Pendle files in E04–E06 **not re-read** this turn (prior session crane-tree denials). Treat as unpinned snapshots per §16.
- Confidence **high** that the PkgInit/PkgArgs/discovery split is already selected and that LIVE≠DESIGN is the right closure rule. Confidence **n/a** on any 4663 codehash.
