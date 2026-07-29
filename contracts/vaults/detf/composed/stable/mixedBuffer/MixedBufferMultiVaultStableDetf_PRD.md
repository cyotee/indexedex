# Product Requirements Document (PRD)

## Title

**MixedBufferMultiVaultStableDetf** — DETF whose **reserve pool** is a `MixedBufferMultiVaultStablePool` (DETF unpaired + one common buffer + 1..3 SE vault shares)

## Status

**IMPLEMENTED — 2026-07-26** (requirements remain LOCKED D1–D30)

**Threshold modes:** Conforms to [`DETF_Threshold_Modes_PRD.md`](../../../DETF_Threshold_Modes_PRD.md) (formal LOCKED) — deploy-time Policy (default ±5% synthetic deadband) vs Open; gates always synthetic; trailing `PkgArgs.thresholdMode`. **Open does not unlock non-buffer burn** (burn remains buffer only).

Product decisions **D1–D30** are **LOCKED** from owner clarification. Do **not** reopen without an explicit PRD revision + log note.

- Implementation plan: **IMPLEMENTED** (`MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md`) — plan locks P1–P9.
- Hermetic suite: `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/` (52 tests green).

**Package path:** `contracts/vaults/detf/composed/stable/mixedBuffer/`  
**Product name:** `MixedBufferMultiVaultStableDetf`  
**Aliases:** “mixed-buffer stable DETF”, “stable mixed-reserve DETF”

**Reserve pool (normative dependency):**  
`contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/`  
(`MixedBufferMultiVaultStablePool` — PRD M1–M30 **LOCKED**)

---

## Living progress log

| Date | Note |
|------|------|
| 2026-07-26 | **Requirements LOCKED.** Owner: special first-bond bootstrap (user supplies non-DETF legs; DETF mints proportional self; init reserve; permissionless). Mint: buffer **or** any configured vault share. Burn: **buffer only**. Bond: full NFT + rebasing claim; bond inputs = buffer **or** vault shares. N∈[1,3]. No default RPs; user RPs except DETF (buffer RP blocked by pool M21 — see D19). Amp deployer-set; thresholds ±5%. |
| 2026-07-26 | Design draft opened. Examples (staking cash family / lending cash family) validate topology only — **never** encode as role names. |
| 2026-07-26 | **Implementation plan written.** Plan locks P1–P9: Single SE bootstrap fee/free DETF; rate-scaled peg seed; protocol bond/claim packages; unbalanced buffer join; dedicated `bootstrapFirstBond`; **post-live bond(reserveBpt) in scope**; nested DETF-as-leg required in v1. |
| 2026-07-26 | **IMPLEMENTED.** Production DETF family + 52 hermetic tests green; Agents.md family table pointer added. |

---

## Purpose

Ship an IndexedEx DETF for **one shared buffer asset** and **one to three Standard Exchange vaults** that all process that asset. The diamond **is** the share ERC-20. Seigniorage mint/burn, synthetic mint/burn gates, full bond NFT + rebasing claim, inert → live via a **special first-bond bootstrap**.

The Balancer **reserve** is a **`MixedBufferMultiVaultStablePool`** (not a Weighted Pool):

\[
U = 1,\quad 1 \le N \le 3,\quad T = 2 + N \in [3,5]
\]

| Leg | Role |
|-----|------|
| Unpaired | **`detfToken` only** (never SE-buffered) |
| Buffer | Exactly one **`bufferToken`** (every vault accepts + produces it) |
| Shares | **`vaultShare[i]`** for each configured SE vault |

Priced with **StableMath + fixed deploy amp**. Pool hooks rebalance free buffer into the **shallowest** vault and redeem from the **deepest**. The DETF does **not** reimplement pool routing.

### Instance examples (non-normative — do not encode in code)

| Scenario | `bufferToken` (instance data) | SE vaults (instance data) |
|----------|-------------------------------|---------------------------|
| ETH staking family | native-wrapped cash asset | several staking-protocol SE vaults that process that cash |
| Lending family | stable cash asset | several lending-protocol SE vaults that process that cash |

**Normative code uses role names only** (`bufferToken`, `vaultShare`, …). Never `WETH` / `USDC` / protocol brands as roles.

### When to use this family vs peers

| Family | Reserve curve | Legs | Use when |
|--------|---------------|------|----------|
| `standardExchange/single` | Weighted | DETF + **1** SE share | Single external leg; classic weighted 80/20 |
| `composed/multi-vault-weighted` | Weighted | DETF + **1..7** SE shares | **Disparate** valuations / fixed basket weights |
| `composed/stable/common` | Stable intermediate + weighted top | Multi-hop composed graph | Like-kind vaults with dual intermediate pools |
| **`composed/stable/mixedBuffer` (this)** | **One** MixedBuffer **stable** pool | DETF + **1 buffer** + **1..3** SE shares | Like-kind multi-vault (or N=1) with **common buffer fan-out** |

---

## Naming rule

### Product / type names

- Full words: `MixedBufferMultiVaultStableDetf`, `MixedBufferMultiVaultStableDetfDFPkg`, …  
- Do **not** abbreviate Standard Exchange in **type** names. Short locals (`seVault_`, `share_`) OK.

### Role names only (contracts / storage / NatSpec)

| Role | Meaning |
|------|---------|
| `detfToken` / `address(this)` | DETF diamond share ERC-20 |
| `reservePool` / `reserveBpt` | The **MixedBufferMultiVaultStablePool** instance and its BPT |
| `bufferToken` | Single common bufferable ERC-20 on the reserve pool |
| `underlyingVaults[i]` / `standardExchangeVault[i]` | SE vault `i` (accepts+produces `bufferToken`) |
| `vaultShare[i]` | Share of vault `i` (often `address(vault)`) |
| `rateAsset` | Claim / synthetic unit; **equals `bufferToken`** for this family (like-kind cash) |
| `rateProvider` (per non-DETF leg) | Optional user-supplied Balancer `IRateProvider`; never auto-deployed |
| `rebasingClaimToken` | Rebasing claim on protocol-owned reserve BPT |
| `bondNftVault` | Full bond NFT vault (user + protocol + fee-recipient NFTs) |

**Forbidden:** product tickers as roles; `WETH` / `USDC` as role names.

---

## Product shape

| Concern | Decision | Status |
|---------|----------|--------|
| True DETF | Diamond **is** the share; seigniorage vs reserve (not pure pro-rata BPT vault) | **D1 LOCKED** |
| Opacity | SE + Balancer + MixedBuffer pool views only | **D2 LOCKED** |
| Governance | Instance **immutable, unowned** after deploy | **D3 LOCKED** |
| Liveness | **Inert** deploy; live after **special first-bond bootstrap** (D20) | **D4 LOCKED** |
| Pricing engine | **Reserve pool** only (StableMath balances, amp, fees, RPs) | **D5 LOCKED** |
| Synthetic gate | FD BPT claim on **math** balances (rate-scaled) ÷ supply; peg **1e18** | **D6 LOCKED** |
| Default thresholds | `mintThreshold = 1.05e18`, `burnThreshold = 0.95e18` (PkgArgs; `0` → default) | **D7 LOCKED** |
| Mint `tokenIn` | **`bufferToken` or any configured `vaultShare[i]`** | **D8 LOCKED** |
| Burn `tokenOut` | **`bufferToken` only** | **D9 LOCKED** |
| Share ↔ share / share as burn out | **Out of scope** on DETF (use Balancer on reserve for share↔share) | **D10 LOCKED** |
| Bonding | **Full bond NFT vault** + oracle lock clamp | **D11 LOCKED** |
| Claim | Rebasing claim; redeem to **`bufferToken`** | **D12 LOCKED** |
| Nested SE | Allowed; opaque | **D13 LOCKED** |
| Deploy path | Facets CREATE3; DFPkg via **Vault Registry / manager** | **D14 LOCKED** |
| Fresh codepath | `composed/stable/mixedBuffer/`; peers behavioral refs only | **D15 LOCKED** |
| Init permission | **Anyone** may run the bootstrap / first-bond path | **D29 LOCKED** |
| Amp | Deployer-set fixed amp on pool create; no post-deploy amp admin | **D17 LOCKED** |

---

## Reserve topology

### Layout (**D16 LOCKED**)

\[
U = 1\quad(\text{only DETF}),\quad N \in [1,3],\quad T = 2 + N \in [3,5]
\]

| Kind | Token | Rule |
|------|--------|------|
| **Unpaired[0]** | `detfToken` | Always; never SE-buffered; TokenType **STANDARD**; **no rate provider** |
| **Buffer** | `bufferToken` | Exactly one; **TokenType STANDARD always** (pool **M21** — never WITH_RATE on buffer) |
| **Share[i]** | `vaultShare[i]` | Optional user `IRateProvider`; zero ⇒ STANDARD |

```
  SE vault₁ … SE vault_N
   (all accept+produce bufferToken)
         \      |      /
          \     |     /
           ▼    ▼    ▼
   MixedBufferMultiVaultStablePool  ← reservePool
   • unpaired[0] = DETF (self)
   • bufferToken
   • vaultShare[0..N)
              ▲
              │  seigniorage mint / burn
         DETF diamond
              │
      bond NFT / rebasing claim
```

### What the DETF must **not** reimplement

Buffer fan-out, pre-seat, virtual buffer, hook share deltas, StableMath `onSwap` — all **pool-owned**. DETF:

- Orchestrates bootstrap join / seigniorage join-exit / bond / claim,  
- Quotes with **StableMath-aware** helpers + math balances,  
- Reads `virtualBuffer` / derived share depths for synthetic (not physical buffer raw alone — pool **M14** eventual-zero).

---

## Locked decisions (normative)

| # | Topic | Decision | Status |
|---|-------|----------|--------|
| D1 | Product type | True seigniorage DETF; diamond is ERC-20 | **LOCKED** |
| D2 | Opacity | SE + Balancer + MixedBuffer views only | **LOCKED** |
| D3 | Governance | Immutable unowned instance | **LOCKED** |
| D4 | Liveness | Inert → live via D20 bootstrap first bond | **LOCKED** |
| D5 | Pricing engine | Reserve StableMath pool only | **LOCKED** |
| D6 | Synthetic | FD owned BPT claim on **math** balances (rate-scaled) ÷ supply; peg 1e18; include bond-NFT-held BPT | **LOCKED** |
| D7 | Thresholds | Defaults 1.05 / 0.95; PkgArgs override; deployer amp separate | **LOCKED** |
| D8 | Mint `tokenIn` | **`bufferToken` OR any configured `vaultShare[i]`** | **LOCKED** |
| D9 | Burn `tokenOut` | **`bufferToken` only** | **LOCKED** |
| D10 | Share↔share on DETF | Not supported (`InvalidRoute`) | **LOCKED** |
| D11 | Bond product | Full bond NFT + protocol NFT + fee-recipient NFT; oracle min floor / max bonus clamp | **LOCKED** |
| D12 | Claim | Rebasing claim on sell-to-protocol; redeem payout **`bufferToken`** | **LOCKED** |
| D13 | Nested | Any `IStandardExchange` | **LOCKED** |
| D14 | Deploy | CREATE3 facets; registry DFPkg | **LOCKED** |
| D15 | Codepath | Fresh under `composed/stable/mixedBuffer/` | **LOCKED** |
| D16 | Reserve layout | U=1 DETF + 1 buffer + N∈[1,3] shares | **LOCKED** |
| D17 | Amp | Deployer-provided fixed amp; no instance amp updates | **LOCKED** |
| D18 | Weights | None | **LOCKED** |
| D19 | Rate providers | **No defaults / no auto-deploy.** User may supply RPs for **vault share legs** (and only those among pool tokens). **DETF never has an RP.** **Buffer never has an RP** (pool **M21**). Deploy rejects non-zero buffer RP args if exposed | **LOCKED** |
| D20 | Bootstrap | **Special first-bond path** (see § Bootstrap). Permissionless (**D29**). Not a separate BPT-only bond-after-init UX | **LOCKED** |
| D21 | Accepted bond tokens | **`bufferToken` OR any configured `vaultShare[i]`** (bootstrap uses multi-asset first-bond path; ongoing single-asset bonds after live) | **LOCKED** |
| D22 | Mint shape (live) | Quote DETF from stable reserve math for `tokenIn` (buffer or share); seigniorage incentive; usage fee + mint split; join reserve; residual clean | **LOCKED** |
| D23 | Burn shape (live) | Exit reserve to **`bufferToken` only**; residual clean | **LOCKED** |
| D24 | Preview == execution | Shared quote path; exact when possible | **LOCKED** |
| D25 | Unsupported routes | `InvalidRoute` | **LOCKED** |
| D26 | Pool deploy | DETF DFPkg deploys MixedBuffer pool (package-owned create preferred) | **LOCKED** |
| D27 | Cross-chain | Out of scope v1 | **LOCKED** |
| D28 | Extra unpaired free assets | Out of scope (`U=1` only) | **LOCKED** |
| D29 | Who bootstraps | **Anyone** (permissionless first bond / init) | **LOCKED** |
| D30 | First-bond DETF mint | DETF mints a **proportional** self amount into the reserve (not open seigniorage to the user’s free wallet balance as the primary outcome); user receives **bond NFT** principal on the bootstrap position | **LOCKED** |

### Clarification — rate providers vs owner wording

Owner: “user-provided rate providers for any token except the DETF token.”

Pool hard rule (**M21**): **`bufferToken` is always STANDARD (never RP).**

**Locked interpretation (D19):** user RPs are supported for **vault share legs**. DETF unpaired: never. Buffer: never. If a future pool revision allows buffer RP, revisit D19; until then deploy validation forbids it.

---

## Open items

**None for product requirements.** Implementation-only choices (exact proportional formula constants, error names, gas layout) belong in the implementation plan.

Minor implementation notes (not product forks):

| ID | Note |
|----|------|
| I1 | Exact “proportional” DETF self amount on first bond: rate-scale all user-supplied non-DETF amounts into a common unit, mint DETF self-leg so init balances sit on the stable peg (implementation plan freezes the formula + tests) |
| I2 | Whether ongoing bond of buffer joins unbalanced buffer leg vs internal path through shallowest vault is pool-hook driven after join; DETF only needs residual-safe join + bond principal accounting |
| I3 | Claim redeem graph: protocol BPT → proportional/exit toward buffer (pool may pre-seat from deepest vault) |

---

## Pricing

| Signal | Definition | Use |
|--------|------------|-----|
| **Reserve spot** | StableMath spot among DETF / buffer / shares | Diagnostics / UI |
| **Synthetic** | Fully diluted value of **owned reserve BPT** (DETF free inventory + bond NFT vault BPT) claim on **math balances**, rate-scaled, in abstract buffer units, ÷ DETF `totalSupply` | **Mint/burn gate** |

**Do not** value the buffer leg from physical Balancer raw alone.

| Condition | Allowed |
|-----------|---------|
| `syntheticPrice > mintThreshold` | Mint |
| `syntheticPrice < burnThreshold` | Burn |
| Inside deadband | Neither |

**Bootstrap first bond is ungated by synthetic** (no live free-float market yet / peer first-bond rule).

### Seigniorage and fees

1. Seigniorage incentive from Vault Fee Oracle applied to **input notional** (buffer or vault share, rate-scaled as appropriate) **before** curve quote.  
2. Gross DETF from quote → mint split via `DETFMintSplitLib` / `DETFUsageFeeLib` (user / protocol / fee).  
3. Non-dilutive accounting: never mint against optimistic fill that exceeds actual join.  
4. No fee-free mint side door (including buffer mint).  
5. Bootstrap proportional mint follows bond / seigniorage split policy as defined in implementation plan (must not leave free DETF stranded inconsistently with bond principal).

---

## User flows

### Bootstrap / first bond (liveness) — **D20, D29, D30**

**Permissionless.** Special path because MixedBuffer init requires **all legs non-zero** (pool **M15**).

1. Deploy DETF **inert**: MixedBuffer pool registered with tokens  
   `[detfToken, bufferToken, vaultShare…]` (Balancer address-sorted), fixed amp, optional **share** RPs only. Pool **not** initialized / no BPT supply.  
2. Caller invokes **first-bond bootstrap** with the **non-DETF** reserve legs:  
   - **`bufferToken` amount**, and  
   - **each `vaultShare[i]` amount** required so every share leg is seeded non-zero (exact arg shape: structured multi-asset bond vs explicit array — implementation plan).  
3. DETF **mints a proportional `detfToken` amount** for the **self / unpaired leg** (into the reserve join, not as free user seigniorage inventory).  
4. DETF **initializes the reserve pool** with all tokens (DETF + buffer + all shares) in one bootstrap join; receives **reserve BPT**.  
5. DETF places the bonded principal on a **bond NFT** for the caller (lock terms from Vault Fee Oracle: min floor revert; max clamp for bonus).  
6. Instance marked **live**.  

```
  User: bufferToken + vaultShare[0..N)   (all non-DETF legs)
              │
              ▼
  DETF mints proportional detfToken ──► unpaired leg
              │
              ▼
  initialize reserve (all T legs non-zero)  →  reserve BPT
              │
              ▼
  bond NFT for caller  →  live
```

Pre-live: normal mint/burn/ongoing-bond routes revert (`ReservePoolNotInitialized` / family equivalent). Only the bootstrap first-bond path may initialize.

### Mint (live)

**`tokenIn` ∈ { `bufferToken` } ∪ { `vaultShare[i]` }.**

1. Gate: live + mint allowed by synthetic.  
2. Quote DETF out via stable reserve math for that input leg.  
3. Seigniorage boost + fee split; join reserve (unbalanced on input leg + DETF self-leg as required); mint DETF to user per split.  
4. Residual clean on diamond.  

Buffer joins may trigger pool post-add deposit into **shallowest** vault (pool-owned). DETF does not pick vault routing.

### Burn (live)

**`tokenOut` = `bufferToken` only.**

1. Gate: live + burn allowed.  
2. Burn DETF; exit reserve toward buffer (pool may pre-seat from **deepest** vault).  
3. Deliver `bufferToken`; residual clean.  

Burn to vault shares is **`InvalidRoute`**.

### Bond (ongoing, after live)

**`acceptedBondTokens()`** = `{ bufferToken } ∪ { vaultShare[i] for all i }`  
(not raw reserve BPT as a user bond surface unless implementation reuses BPT only internally inside bootstrap).

1. User supplies buffer or a configured vault share.  
2. DETF builds reserve principal (join path) and mints bond NFT with oracle lock terms.  
3. `sellNFT` → protocol NFT → `IRebasingClaimToken.mintFromNFTSale`.

### Claim redeem

1. Burn claim shares atomically with unwind.  
2. Unwind protocol-owned reserve BPT → **`bufferToken`**.  
3. Never treat claim amounts as free BPT without burning claim shares.

### Explicit non-flows (v1)

```
vaultShare_i  ──✗──►  vaultShare_j     on DETF
DETF          ──✗──►  vaultShare_i     (burn)
DETF          ──✓──►  bufferToken      (burn)
bufferToken   ──✓──►  DETF             (mint, live)
vaultShare_i  ──✓──►  DETF             (mint, live)
```

Share↔share: Balancer / SE router on `reservePool`.

---

## Route table (normative v1)

| tokenIn | tokenOut | Kind | When |
|---------|----------|------|------|
| buffer + all vault shares (bootstrap args) | Bond NFT | **First bond / init** | Pre-live only |
| `bufferToken` | DETF | Mint | Live |
| `vaultShare[i]` | DETF | Mint | Live |
| DETF | `bufferToken` | Burn | Live |
| `bufferToken` | Bond NFT | Ongoing bond | Live |
| `vaultShare[i]` | Bond NFT | Ongoing bond | Live |
| Other | Other | `InvalidRoute` | Always |

---

## Package and deployment

### DFPkg

`IMixedBufferMultiVaultStableDetfDFPkg` with **`PkgInit` / `PkgArgs` on the interface** (Crane rule).

**`PkgArgs` (conceptual):**

```solidity
struct PkgArgs {
    string name;
    string symbol;
    IERC20 bufferToken;
    // 1..3 SE vaults (distinct); each must accept+produce bufferToken
    IStandardExchange[] standardExchangeVaults;
    // length == vaultCount; address(0) => STANDARD share leg; non-zero => WITH_RATE
    // NEVER auto-deploy providers. No buffer RP field (buffer always STANDARD).
    IRateProvider[] vaultShareRateProviders;
    uint256 amplificationParameter; // deployer amp; StableMath range
    uint256 mintThreshold;          // 0 => 1.05e18
    uint256 burnThreshold;          // 0 => 0.95e18
    // bond NFT pkg / claim pkg / MixedBuffer pool pkg refs as needed
}
```

Validation (minimum):

- `1 ≤ N ≤ 3`; distinct vaults/shares  
- Each vault `IStandardVault` lists `bufferToken`  
- Amp in StableMath min/max  
- Share RP array length == N; zero allowed  
- No RP for DETF; no RP for buffer  

### Composition order (sketch)

1. ERC-20 facet stack for DETF.  
2. Deploy MixedBuffer pool: unpaired = DETF, buffer, vaults, amp, share RPs only.  
3. Persist indexes, layout, thresholds, aware repos.  
4. Deploy full bond NFT vault + protocol NFT + feeTo NFT.  
5. Wire rebasing claim package.  
6. Register instance; **inert** until first-bond bootstrap.

### Facet inventory (expected)

| Component | Role |
|-----------|------|
| `…Repo` | Vaults, buffer, pool, indexes, amp, thresholds, bond/claim, live flag |
| `…Common` | Synthetic (math balances), stable quotes, join/exit, residual, lock clamp, proportional bootstrap mint |
| `…ExchangeIn*` | Mint buffer/share → DETF + query |
| `…ExchangeOut*` | Burn DETF → buffer + query |
| `…Bonding*` | First-bond bootstrap + ongoing bond buffer/share; sell → claim |
| `…Info*` | Layout, synthetic, mint/burn allowed, accepted bond tokens |
| `…DFPkg` + FactoryServices | Crane + Vault Registry |

Reuse `detf/core/*` and `detf/reusable/*`. Do **not** subclass other DETF families.

---

## Architecture diagram

```
                 Balancer V3 Vault
                        │
                        v
         MixedBufferMultiVaultStablePool  (reservePool)
           StableMath(amp)
           unpaired: DETF
           buffer: virtualBuffer → SE fan-out
           shares: derived depth d_i
                  │                    │
                  │ BPT                │ exchangeIn/Out
                  v                    v
            DETF diamond        standardExchangeVault[i*]
         seigniorage + bond        (shallowest/deepest)
         + rebasing claim
```

---

## Testing expectations

Production-first (`indexedex-testing` + DETF common expectations):

1. **No mocks of SUT** (DETF, facets, DFPkg, manager, registry, fee oracle, SE vaults, MixedBuffer pool under test).  
2. Gold TestBase chain through MixedBuffer + real SE TestBases.  
3. Cover at least:  
   - inert deploy; N=1 and N=2 (and N=3 smoke);  
   - **permissionless first-bond bootstrap** with all non-DETF legs + proportional DETF self mint + pool init + bond NFT + live;  
   - pre-live mint/burn/ongoing-bond blocked;  
   - mint with **buffer** and mint with **each vault share**; preview == execution;  
   - burn **only** to buffer; burn to share reverts `InvalidRoute`;  
   - threshold gates; price movement under default thresholds via real underlying trades/dilution;  
   - ongoing bond buffer and bond vault share; lock clamp; sell → claim → redeem buffer;  
   - residual inventory zero;  
   - RP: zero ⇒ STANDARD on shares; non-zero share RP wired; DETF/buffer never WITH_RATE;  
   - reject deploy if vault cannot accept+produce buffer.  
4. Adversarial: reentrancy `IsLocked`; hostile ERC-20 as share only where peers do.

---

## Risks and sharp edges

| Risk | Mitigation |
|------|------------|
| Bootstrap multi-asset UX heavier than Single SE | Document first-bond args; permissionless but structured |
| Proportional DETF seed wrong → bad init peg | Freeze formula + hermetic tests (I1) |
| Synthetic understates if physical buffer used | Math balances / `virtualBuffer` only |
| Always-route pool surprises | Pool docs; DETF residual policy only |
| Owner wants buffer RP | **Forbidden** by pool M21; D19 documents interpretation |
| Confusion with Single SE burn-to-share | This family burns **buffer only** |

---

## Comparison table

| Dimension | Single SE DETF | MultiVault Weighted | **This family** |
|-----------|----------------|---------------------|-----------------|
| Reserve | Weighted 2-token | Weighted 2..8 | **MixedBuffer Stable 3..5** |
| Mint in | vault share (+ allowlisted via SE) | vault shares | **buffer + vault shares** |
| Burn out | vault share (+ allowlisted) | vault shares | **buffer only** |
| Bootstrap | First bond shares | Init + bond BPT | **First bond multi-asset + proportional DETF + init** |
| Bond inputs | shares | BPT + shares | **buffer + shares** |
| N | 1 | 1..7 | **1..3** |

---

## File structure (proposed)

```text
contracts/vaults/detf/composed/stable/mixedBuffer/
  MixedBufferMultiVaultStableDetf_PRD.md
  MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md  # next
  MixedBufferMultiVaultStableDetfRepo.sol
  MixedBufferMultiVaultStableDetfCommon.sol
  … ExchangeIn / ExchangeOut / Bonding / Info / DFPkg / FactoryServices
  TestBase_MixedBufferMultiVaultStableDetf.sol
```

---

## Implementation checklist (after explicit implement instruction)

- [x] PRD requirements locked (D1–D30)  
- [x] Implementation + test plan (incl. I1 proportional formula + plan locks P1–P9)  
- [ ] Repo + Common  
- [ ] DFPkg: MixedBuffer pool + inert DETF + bond + claim  
- [ ] First-bond bootstrap (permissionless)  
- [ ] Mint buffer / share → DETF  
- [ ] Burn DETF → buffer  
- [ ] Ongoing bond buffer / share; sell → claim → redeem buffer  
- [ ] Production-first matrix N=1..3  
- [ ] Adversarial P0  
- [ ] AGENTS.md family table pointer  

---

## Document control

| Item | Value |
|------|--------|
| PRD path | `contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_PRD.md` |
| Reserve pool PRD | `…/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_PRD.md` |
| Status | **REQUIREMENTS LOCKED** — 2026-07-26 |

---

## Appendix A — Owner answers (plain language)

| # | Owner said | PRD encoding |
|---|------------|--------------|
| 1 | Special first bond: user provides other tokens; DETF mints proportional self; initialize reserve | **D20, D30** |
| 2 | Mint with buffer or any SE vault share | **D8** |
| 3 | Burn to buffer only | **D9** |
| 4 | N=1 allowed | **D16** |
| 5 | Full bond NFT + rebasing claim | **D11, D12** |
| 6 | Bond with buffer or SE vaults; bootstrap special multi-asset path | **D21, D20** |
| 7 | No default RPs; user RPs except DETF | **D19** (+ buffer never RP per pool M21) |
| 8 | Deployer amp + ±5% thresholds | **D7, D17** |
| 9 | Anyone may initialize / bootstrap | **D29** |

## Appendix B — Acceptance

Product requirements are **LOCKED**. Implementation plan is written (`MixedBufferMultiVaultStableDetf_IMPLEMENTATION_AND_TEST_PLAN.md`). Implement only on explicit instruction (or phase-by-phase from that plan).
