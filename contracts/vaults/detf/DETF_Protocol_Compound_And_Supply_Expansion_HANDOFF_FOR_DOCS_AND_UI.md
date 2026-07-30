# Handoff: Protocol Compound + Natural Supply Expansion

**Audience:** docs, research copy, and frontend agents  
**Date:** 2026-07-30  
**Status:** Product law **LOCKED**; Stages 00–09 shipped  
**You do not need to read Solidity** to update UI or documentation—this file is enough.

---

## 1. One-paragraph summary

True DETFs now do two new things (keeper-free):

1. **Protocol compound** — The **protocol-owned bond position** no longer sits on free DETF rewards. Its reward share is automatically turned into **more protocol-owned reserve liquidity (BPT)** via a single-sided DETF join into the reserve. That can improve **rebasing claim** redemption backing when claim is wired.
2. **Natural supply expansion** — On **Policy** instances only, while the unit is **live** and **synthetic price is above the mint threshold**, the system may mint **free DETF** over time to **bond holders** (same reward ledger as seigniorage). **Open** mode never does this.

Users still **claim free DETF** on their own bonds while locked. Nothing forces users to auto-compound.

---

## 2. Normative sources (if you need depth later)

| Doc | Role |
|-----|------|
| [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) | **LOCKED** product law |
| [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) | Stage catalog / status |
| Root [`AGENTS.md`](../../../AGENTS.md) | Common DETF expectations (includes this program) |
| Threshold Modes PRD | Policy vs Open **mint/burn gates** (orthogonal; expansion only uses Policy mint-allowed) |

**In-scope families (true DETFs):**

- Single Standard Exchange  
- Multi-vault weighted  
- Mixed-buffer multi-vault stable  
- Composed stable common  

**Out of scope:** `composed/single`, legacy seigniorage package, dual DETFs.

---

## 3. Product vocabulary (use these; avoid brand tokens)

| Term | Meaning for copy/UI |
|------|---------------------|
| **DETF / detfToken** | The vault’s share token (the diamond is the ERC-20) |
| **Synthetic price** | Reserve-backed unit price used for Policy gates (abstract ~1.0 peg narrative under Policy) |
| **Policy mode** | Default: mint/burn gated by synthetic vs thresholds; **can** expand when rich |
| **Open mode** | Threshold gates always pass when live; **never** natural expansion |
| **Bond NFT** | Locked position that earns DETF rewards |
| **Protocol / detf-owned NFT** | System-owned bond position (not a retail user) |
| **Fee-recipient NFT** | Fee position; rewards stay claimable free DETF (not auto-compounded) |
| **Seigniorage rewards** | Free DETF paid to bond effective shares when others mint/bond with capital |
| **Natural expansion** | Free DETF minted over time when Policy + rich synthetic (no new external capital) |
| **Protocol compound** | Protocol NFT’s free DETF rewards → more reserve BPT (protocol depth) |
| **Rebasing claim** | Claim on protocol-owned reserve BPT; improves when protocol BPT grows |
| **Reserve / BPT** | Balancer pool liquidity token; pricing engine for the unit |

Do **not** use product-brand leftovers (`RICH`, `mintWithWeth`, etc.) on generic surfaces.

---

## 4. What changed vs “before”

### Before

- Mint/bond seigniorage could put free DETF into the bond **reward** system.  
- Users could preview/claim those rewards while locked.  
- Protocol’s share could sit as **claimable free DETF** on the protocol NFT.  
- Claim redemption tracked **protocol BPT**, not free DETF on the NFT.  
- No continuous “rebase-like” expansion of DETF to bonders when the unit was rich but quiet.

### After

| Actor | Rewards behavior |
|-------|------------------|
| **User bond** | Still **claim free DETF** while locked (seigniorage + expansion when applicable) |
| **Fee-recipient NFT** | Still **claim free DETF** (v1; no auto-compound) |
| **Protocol NFT** | **Auto-compounds** rewards into **more protocol-owned BPT** (not long-lived free DETF) |
| **Claim holders** | **Indirect** benefit when protocol BPT rises after compound |
| **Unlocked free DETF only** | **No** expansion airdrop (must hold a bond to get expansion rewards) |

---

## 5. Behavior rules for UI and docs

### 5.1 Protocol compound

- Happens **without a keeper** on normal vault/DETF interactions, and via a public **`compoundProtocolRewards`** entrypoint (permissionless catch-up).  
- Method: **single-sided DETF join** into the reserve (self-leg only). Slight reserve skew toward the DETF leg is an accepted v1 tradeoff—do not market “perfectly balanced rebalance.”  
- If a compound join fails once, the system **retries later** (best-effort); user actions should not be described as “requiring compound success.”  
- **Success story for claim product:** protocol depth ↑ → claim redemption rate **can** improve (not a guarantee of APY).

### 5.2 Natural supply expansion

| Condition | Expansion? |
|-----------|------------|
| Instance not live (inert / pre-first-bond) | No |
| **Open** threshold mode | **Never** |
| **Policy** + live + synthetic **above** mint threshold | **Yes** (time-based accrual, caps apply) |
| Policy but synthetic in deadband or below mint threshold | No |

- Expansion is **premium-closure style**: while rich, free supply can expand in a way that pulls the synthetic narrative toward peg (dilution).  
- Distributed like seigniorage: **bond effective shares** (lock boost still matters as it does for rewards).  
- Users see it as **pending rewards** / claimable DETF on the bond—not a separate “stake DETF” product in v1.  
- Parameters are **fixed at deploy** (rate / catch-up caps). No admin knob in the app for “turn expansion on.”

### 5.3 What did **not** change

- Primary mint/burn **routes** (e.g. MixedBuffer still burns **buffer only**).  
- Policy vs Open **threshold encoding** (Threshold Modes already shipped).  
- User still deposits via family routes; expansion is **not** a substitute for providing capital when minting primary DETF.  
- Instances remain **immutable / unowned** after deploy.

---

## 6. Surfaces useful for UI (names may match family APIs)

Prefer reading live contracts / ABIs; conceptual surface:

| Surface | UI use |
|---------|--------|
| `pendingRewards(tokenId)` | Show bond rewards (seigniorage + expansion after sync) |
| `claimRewards(tokenId, recipient)` | Harvest free DETF while locked |
| `compoundProtocolRewards()` | Optional “compound protocol rewards” / ops; not required for users |
| `thresholdMode()` | Policy vs Open badge / explanation |
| `isMintingAllowed()` / `mintThreshold` / synthetic price | When expansion can accrue; when primary mint is open |
| Protocol / detf NFT principal or BPT getters | Explain protocol depth / claim backing |
| `lastExpansionTimestamp` (if exposed) | Debug / advanced only |

**Preview rule:** after an update, pending should match claim (or tiny dust only). Show pending as the user-facing amount.

---

## 7. Copy guidance (docs + research + UI)

### Say

- Protocol-owned rewards deepen **protocol reserve liquidity** over time (compound).  
- Bond holders can earn **free DETF** from others’ mints **and**, on Policy units when rich, from **time-based expansion**.  
- Claim tokens track **protocol reserve BPT**; protocol compound can improve claim backing.  
- Open mode: free primary market gates when live; **no** expansion program.  
- Keeper-free / no bot required for correct accrual.

### Do **not** say

- Guaranteed peg, guaranteed APY, or “risk-free yield.”  
- That expansion pays **all** DETF holders (only bond reward ledger).  
- That Open mode rebases / expands.  
- That user bonds auto-compound into the pool (they claim free DETF).  
- That a keeper or team must run compound for the product to work.  
- Marketing “Olympus” as a legal or product affiliation—optional historical analogy only, carefully.

**Voice:** follow project product-voice rules (plain language; no hype jargon). Prefer “policy unit,” “bond rewards,” “protocol reserve,” “claim on protocol liquidity.”

---

## 8. Suggested UI / docs touchpoints

| Area | Suggested update |
|------|------------------|
| **Bond / portfolio** | Clarify rewards = seigniorage ± expansion; claim while locked |
| **Policy vs Open explainer** | Open: no natural expansion; Policy: expansion only when synthetic rich |
| **Claim / redeem** | Protocol compound can raise backing over time; not a fixed coupon |
| **Research / education** | Separate “capital-backed seigniorage” vs “natural expansion when rich” |
| **Deploy / factory UI** (if any) | Expansion params are deploy-time; show mode + thresholds; don’t imply post-deploy edits |
| **Advanced / protocol** | Optional compoundProtocolRewards for power users; not a main path |

---

## 9. Mode cheat-sheet

```text
Policy + live + synthetic > mintThreshold  → primary mint allowed; expansion may accrue
Policy + live + synthetic in deadband      → neither mint nor expansion from gates
Policy + live + synthetic < burnThreshold  → burn allowed; no expansion
Open + live                                → mint/burn gates pass; NO expansion
Not live                                   → no user mint/burn; no expansion
```

---

## 10. Implementation map (optional; for engineers, not required for copy)

| Layer | What shipped |
|-------|----------------|
| Core | `DETFProtocolCompoundLib`, `DETFNaturalExpansionLib` |
| Families | Single SE, multi-vault weighted, mixed-buffer, composed stable |
| Tests | `*ProtocolCompound.t.sol`, `*NaturalExpansion.t.sol`, core pure tests |
| Stage plans | `contracts/vaults/detf/00_…` through `09_…` |

---

## 11. Quick FAQ for writers

**Q: Do users need to click compound?**  
A: No for their own rewards (they claim free DETF). Protocol compound is automatic on touches + public catch-up.

**Q: Is expansion the same as staking OHM?**  
A: Conceptually similar (time/premium free float to lockers) but **not** a separate stake token in v1—it uses the **existing bond reward** path.

**Q: Will my claim token go up every day?**  
A: Only if protocol compound adds protocol BPT and other factors cooperate. No guarantee.

**Q: Open DETF “yield” from expansion?**  
A: No. Open does not expand.

**Q: Did mint/burn buttons change?**  
A: Route sets and fee logic are the same family rules; only protocol sink for protocol rewards + optional expansion accrual changed.

---

## 12. Handoff checklist for other agents

- [ ] Update research / education pages that describe seigniorage or protocol inventory  
- [ ] Update bond reward UX copy (claim while locked; expansion on Policy when rich)  
- [ ] Update Policy vs Open explainer (expansion = Policy only)  
- [ ] Update claim product narrative (backing can improve via protocol compound)  
- [ ] Avoid APY/peg guarantees  
- [ ] If showing advanced actions, optional `compoundProtocolRewards` only  

**Questions about product law:** PRD is **LOCKED**—change requires an explicit PRD revision, not UI invention.
