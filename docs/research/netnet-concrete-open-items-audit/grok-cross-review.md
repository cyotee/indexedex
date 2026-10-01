# Grok cross-review — concrete open-items audit

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`) |
| Access date | 2026-09-28 |
| Inputs | Own original unchanged. Untrusted originals: `astra-original.md`, `minimax-original.md` (complete through its status section), `kimi-original.md`. No peer cross-reviews |
| Rechecked | PRD v0.33 §§4.1, 10.2, 12.4, H01–H03, R22. Plan v0.9 §§2.2, 4.1, 5.4, 6.5.3, 6.6.4, 7.3. `IVaultFeeOracleQuery.sol:129`. `UniswapV4DetfDFPkg.sol:250–259`. `DETFSeigniorageShareLib.sol:18–46`. No `creatorOfVault` symbol in `contracts/` |
| Correction | Grok’s original was wrong to call L4 resolved, and it missed the creator-address binding. Those two are the only retained actual gaps |

---

## 1. Corrected Grok position

The ordinary alleged blockers stay withdrawn: force-claim provenance, provider rounding, Keep-YT/owned-HLP chronology, exact-output residual ownership, G0 as a product vote, and independent address or block pinning.

Two configuration/entitlement values are not determined by the current text, and absence of code is not what makes them gaps.

1. **Creator address.** Expansion must issue a creator receipt. The weight formula exists. The address source does not. Factory, deployer, `feeTo()`, and the fee oracle are not that source.
2. **L4 terminal edge only.** Post-completion excess unlock timing, and what `retire(tokenId)` does to later native receipts, are expressly unassigned. Keeping the NFT is a prohibition on silent burn during ordinary life, not a selected retirement outcome.

No new fee, weight, reserve, or lock baseline is proposed.

---

## 2. Agreement

Astra, MiniMax, Kimi, and Grok agree, and the current documents support:

| Item | Class | Why it is not an owner question |
| --- | --- | --- |
| Documented Pendle addresses and `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK = 20_714_383` | IMPLEMENTATION/TEST | Human ruling. Later fork tests validate. Not a research blocker |
| Force-claim versus L2 and full sync | RESOLVED | PRD §6.3 and plan §§6.1, 6.6.4. Unbooked surplus is origin-independent credit. Capture it before sync. Consumed credit is not also H. Native C is recomputed. Do not build a payer witness |
| Provider sample versus funding inverse | RESOLVED | PRD §4.5 and plan §6.5.6. Sample prices. §6.5.3 funds. Do not replace one with the other |
| Keep-YT / owned-HLP / rollover order | RESOLVED as behavior | PRD §§6.1, 7.1.2, 11.4 and plan §§6.2, 6.4, 7.1–7.2. Calldata is wiring, not a new sequence |
| Exact-out when `I > 1e18` | RESOLVED | R22 and plan §6.5.3: deliver the requested net amount or revert. No residual beneficiary. A toy gap is not a demonstrated required-domain conflict |
| G0 / NN-13 | PROCESS ONLY | Approval is recorded. Shared-instruction reconciliation is maintainer work |

MiniMax’s “no actual spec gap” conclusion is too broad. It is right on those rows and wrong on L4 and silent on creator.

---

## 3. Creator binding — retained actual gap

**Agree Astra. Grok’s original did not examine this. MiniMax and Kimi did not retain it.**

**Fact.** PRD §10.2 and R43 require fee and creator standing receipts as distinct roles. PRD §4.1 PkgArgs are exactly three addresses: initial market, bond depository, and NetNet staking. Plan §4.1 line 128: the record does not establish an authoritative creator-address source, and an implementation may not guess deployer or current `feeTo`. Plan §5.4 repeats that this is not permission to invent a beneficiary.

**Trace, not a new model.**

| Candidate | Result |
| --- | --- |
| `args.creator` on the Universal package | `UniswapV4DetfDFPkg.sol:258` passes `creator: args.creator`. This family’s selected PkgArgs omit that field. Reuse of the math does not add the field |
| Deployer / factory | Plan §4.1 forbids that guess |
| `feeTo()` | A different recipient. Plan forbids using it as creator |
| Fee-oracle registration | `IVaultFeeOracleQuery.sol:129` stores a creator **share weight**, not an address |
| `creatorOfVault` | No such symbol under `contracts/` |
| `DETF_CREATOR_BOND_NFT_ID` | An internal staking position id in `DETFSeigniorageShareLib.sol:39–46`, filled after a creator address already exists |

**Required transition.** First expansion or funded distribution with a positive creator weight must mint that recipient’s receipt. The fraction does not name the account. Without an address, the selected issuance has no payee.

**Unresolved value.** The immutable creator address, or the existing configuration field that already holds it. None of the sources above is that field.

**Not this gap.** Creator weight, fee split, or whether a creator receipt exists. Those are selected.

**Minimal deliverable.** One binding row: where the address is read at initialization. If no existing source is adopted, that is a human configuration choice, not a weight redesign. It blocks only initialization that must pay the creator. It does not block SY, claim, or HLP math.

---

## 4. L4 — corrected; two transitions stay undefined

**Grok’s original is withdrawn on this point.** Saying “do not burn, so retain forever” treats a prohibition as a selected retirement. Plan §5.4 says `retire(tokenId)` “does not select forfeiture or a never-burn NFT.” Plan §7.3 says the terminal edge is not implementer discretion and that permanent DORMANT is not adopted. PRD §12.4 says final retirement remains a separate action and late receipts remain H01/H03. Preservation during ordinary life does not choose `retire`.

**Agree Astra and Kimi that these two transitions are actual gaps. Disagree with MiniMax** that the implementer may compose the predicate inside the prohibitions. The plan forbids that assignment.

### 4.1 Post-completion excess unlock

**Required transition.** Intended note completes in processed epoch 106. Unlock target is 107. At epoch 109 the same holder collects further native proceeds of that note. They credit the same NFT as principal (PRD §12.4 excess rule; beneficiary is settled).

**Unresolved value.** Is that new principal withdrawable because 107 has passed, or does it unlock at 110?

Intermediate “no reset” applies before final completion. E+1 is keyed to the final intended installment, not to every later credit. A new bond’s own lock applies to a new tokenId, not to this old NFT. The purpose sentence (principal should see a later rebase after it enters) and the keyed E+1 rule do not pick the same result. Availability of this principal is therefore unspecified.

Direct donations are already not receipts (PRD §12.4). That edge is not reopened.

### 4.2 `retire` and later native receipts

**Required transition.** Drained candidate is reached (plan §7.3). Someone calls `retire(tokenId)`. The holder can still receive a later native note because the depository accepts arbitrary recipients. The holder’s only controller is the NFT contract (PRD §12.4).

**Unresolved value.** Whether `retire` burns, flags, or does not exist as a successful terminal action, and who may collect or must forfeit receipts after that action. Last-owner rights, forfeiture, treasury forwarding, and eternal retention are different entitlements. None is selected. A protective “just revert” is not in the PRD as the retirement rule.

**Not this gap.** Zero principal while the note still vests does not retire. Partial reinvestment keeps the old NFT. E+1 for the final intended installment. Purchase-epoch check. Those stay resolved.

**Minimal deliverable.** Two sentences: unlock class of post-completion same-NFT principal, and the entitlement that ends or survives `retire`, including already-known unsolicited notes versus later gifts. Do not change ordinary E+1, reinvestment, or holder ownership.

---

## 5. Dissent

| Peer | Dissent |
| --- | --- |
| MiniMax | “No actual spec gap” and “implementer composes mature-and-empty” conflict with plan §§4.1, 5.4, and 7.3. Those sentences leave creator identity and `retire` unassigned on purpose |
| Kimi | Agrees on L4 as the survivor and on the ordinary withdrawals. Does not retain the creator-address gap. The plan’s own §4.1 sentence is that gap |
| Astra | Agrees on both retained gaps. Grok adopts that correction. Astra’s medium confidence that creator might still be an uncited existing source is answered by the trace above: the cited existing sources are weights, `feeTo`, or a forbidden guess, not a creator address |
| Grok original | L4 “resolved by non-burn” is withdrawn. Creator gap is added |

---

## 6. Minimal list

**ACTUAL SPEC GAP**

1. Creator address binding for expansion receipts. Weight is selected. Address source is not.
2. Post-completion same-NFT excess unlock epoch.
3. `retire(tokenId)` effect and disposition of later native receipts.

**IMPLEMENTATION/TEST**

Force-claim booking order, provider sample wiring, Keep-YT/HLP calldata, exact-out revert vectors, YT V1/V2 body at `DEFAULT_FORK_BLOCK`, live fees, and the numeric vectors already in the plan.

**PROCESS ONLY**

G0 / NN-13 instruction reconciliation. Stale tracker labels (NN-20).

---

## 7. Answer to the user

Two configuration values are still unset: who receives the creator share, and what happens to same-NFT principal and later native gifts at the terminal edge. Everything else challenged in this round is already specified or is implementation and fork testing. No new economic model is required. Independent address rediscovery is not a blocker.

**Confidence:** high on the citations and the failed creator-source trace. High that L4’s two transitions are undefined. No test was run.
