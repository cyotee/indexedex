# Stage 04 — Composed Stable Common DETF — Phase 1 Protocol Compound

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **04** |
| **Phase** | **Phase 1** — protocol seigniorage compound |
| **Family** | Composed stable common (`composed/stable/common/`) |
| **This file is the sole implementation scope** | Do not implement Phase 2 or other families |
| **Depends on** | Stage **00** green; **prefer Stage 01 green** |
| **Blocks** | Stage **09** |
| **Program index** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) §3, C1–C8 — **claim coupling critical** |
| **Sell/claim law** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) (mature-only sell/close, 4626 `buyClaim`) |
| **Gold TestBase** | [`composed/stable/common/TestBase_ComposedStableCommonDetf.sol`](./composed/stable/common/TestBase_ComposedStableCommonDetf.sol) |
| **Pathfinder** | Stage 01 Single SE plan |
| **Family note** | Uses family bond NFT package + rebasing claim / rebasing DETF token surfaces more heavily |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. Detf-owned NFT seigniorage DETF → single-sided DETF join → detf-owned BPT principal ↑.
2. Lazy + required `compoundProtocolRewards()`; best-effort join failure.
3. User/fee claimable free DETF preserved.
4. **Claim coupling (C5 mandatory):** after compound, claim redemption / BPT backing path used by rebasing claim **can rise** vs pre-compound baseline (hold other factors equal).
5. C1–C8 green.

### Non-goals

- Expansion; redesign of rebasing DETF token product; other families.

---

## 2. Current state audit

| Item | Location |
|------|----------|
| Inventory to bond vault | `ComposedStableCommonDetfExchangeIn.sol` — `_mintDetf(address(bondNftVault), inventoryDetfOut_)` + BPT to detf NFT on some paths |
| Bond NFT package | Family-specific `ComposedStableCommonDetfBondNFTVault*` (not only shared `bondNft/`) — **wire compound against this vault’s APIs** |
| Claim / pricing | `RebasingClaimToken*`, `RebasingDETFTokenPricingTarget` — uses `originalSharesOf(detfNFTId)` style BPT |
| Exchange out / mint | `ComposedStableCommonDetfCommon._mintDetf` |

**Critical:** Confirm family bond NFT exposes `reallocateDetfNftRewards` / `pendingRewards` / `detfNFTId` / `addToDETFNFT` compatible with shared inventory policy. If names differ, adapt compound orchestration without changing product law.

---

## 3. Implementation design

Same Stage 01 pipeline. Specializations:

| Topic | Action |
|-------|--------|
| Join | Implement or reuse DETF-only unbalanced join into family reserve stable pool |
| Bond NFT | Prefer family vault package entrypoints; do not break composed-stable bond NFT deploy path |
| Claim tests | Extend redemption / pricing tests to prove compound → backing ↑ |
| Facets | Exchange / bonding / info facets as appropriate; update IFacet tests |

---

## 4. Files to touch

| File | Action |
|------|--------|
| `ComposedStableCommonDetfCommon.sol` | compound helpers |
| `ComposedStableCommonDetfExchangeIn.sol` | lazy hook after inventory |
| Bonding facet/target if separate | lazy hooks |
| Info / pricing targets | public `compoundProtocolRewards` if surface lives there |
| Family BondNFT vault targets | only if harvest API gaps block compound |
| Facet factory arrays | selectors |
| `TestBase_ComposedStableCommonDetf*.sol` | helpers |
| New `ComposedStableCommonDetf_ProtocolCompound.t.sol` | C1–C8 with strong C5 |

---

## 5. Test plan

| ID | Focus |
|----|--------|
| C1–C2 | Compound on mint/bond; BPT principal ↑ |
| C3–C4 | User/fee claim free DETF |
| **C5** | Claim redeem preview / rate after compound > before (or ≥ with documented dust) |
| C6–C8 | Public compound; production-first; best-effort failure |

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/*ProtocolCompound*' -vvv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**' -vv
```

---

## 6. Acceptance

PRD C1–C8 with **non-waivable C5** for this family (claim is core product surface here).

---

## 7. Definition of Done

- [x] Green tests + program index Stage 04
- [x] C5 evidence recorded in test names/comments

**Shipped 2026-07-29:** `_tryCompoundProtocolRewards` / `compoundProtocolRewards` / atomic pull pattern on ComposedStableCommonDetf; lazy hooks on mint + bond + sellNFT; family bond NFT owner-auth for harvest; facet selectors + C1–C8 suite green (non-waivable C5).
