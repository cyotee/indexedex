# Astra — combined cross-review: concrete specification gaps

**Access date: 2026-09-28.** One combined review of the complete originals in this directory: Grok171 lines, MiniMax211 lines and Kimi113 lines. All reached end-of-file; no peer cross-review or historical council report was opened. My original remains unchanged. Research only; no shell, tests, deployments, implementation or delegation.

## 1. Answer in brief

The ordinary accounting/routing questions should remain **resolved policy with implementation/test work**, not another research gate. The human's documented-address/default-block/later-fork ruling remains controlling. G0 is process-only instruction maintenance.

I retain **two narrowly bounded current-text issues**, not a general unfinished-design claim:

1. **Creator binding at initialization:** source tracing establishes the reference recipient mechanism and zero-creator fallback, but does not supply the custom family's missing initial creator configuration. This can likely be closed by a small authoritative configuration statement, not by redesigning allocation.
2. **L4 terminal scope:** post-completion native excess release and irreversible retirement/late rights remain expressly undefined. Preservation constraints alone do not select a permanent NFT, a universally reverting retire method, or post-burn beneficiary rights.

I agree with Kimi on the narrow L4 issue and disagree with Grok/MiniMax's claim that protections alone close it. None of the peer originals actually traces creator initialization, so their “no gaps” or “only L4” totals do not rebut that issue.

## 2. Evidence and corrected own position

Current documents directly checked:

- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` **v0.9**, especially121–129,251–270,474–487,705–716.
- `NETNET_PENDLE_DETF_PRD.md` **v0.33**, especially931–957 and the operative configuration/allocation clauses cited in my original.

Additional source tracing in this review:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:32–47`.
- `.../UniswapV4DetfDFPkg.sol:250–259` and `.../UniswapV4DetfRepo.sol:58,82,109`.
- `.../UniswapV4DetfTarget.sol:793–798`.
- `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:81–90`.
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:170–182`.
- `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:265–288`.
- `contracts/registries/vault/VaultRegistryVaultRepo.sol:39–80,92–149`.
- `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:126–153`.

**Correction/precision added to my original:** the system does not lack a creator-recipient *mechanism*. The reference pays the current owner of the creator role NFT, and its initialization already has a zero-address→feeTo fallback. The unresolved value is the custom family's **initial input to that mechanism**, not who receives rewards after the role has been validly initialized. My initial report was too broad if read as requiring a new recipient lookup or allocation design.

I do not retract the narrow binding issue: the source's conditional fallback does not decide whether this custom family intentionally supplies zero, supplies a specified creator through another fixed binding, or preserves a creator from an already initialized role. Current Plan:128 expressly forbids guessing deployer/current feeTo and records the missing source.

All source observations are local code facts, not fork results. No new external library/API documentation claim is made; no Context7/network lookup was required. Access dates and address-policy facts are not deployment certification.

## 3. Creator binding — actual trace, not an invented oracle getter

### 3.1 What the reference actually does

```text
Universal PkgArgs.creator
  -> DFPkg CoreInit.creator
  -> Repo.creator
  -> Target.initializeReservedBondNfts(feeTo, Repo.creator)
  -> creator role NFT minted to (creator==0 ? feeTo : creator)
  -> reward payout uses ownerOf(DETF_CREATOR_BOND_NFT_ID)
```

- `IUniswapV4Detf.PkgArgs` explicitly contains `address creator` at42.
- DFPkg passes `creator: args.creator` at258; Repo stores the supplied value.
- Target reads `s.creator` and `s.feeOracle.feeTo()` at794–796, passing both to reserved-role initialization.
- `DETFFundedBondTarget.sol:89` mints the creator role to feeTo only **if the supplied creator is zero**.
- `StakedDETFTarget.sol:177–180` obtains recipients through the role NFT owners. It does not ask the fee oracle for a creator address.

The fee oracle inspected here supplies **creator share percentages** and the split (`VaultFeeOracleQueryFacet.sol:265–288`), not an initial creator beneficiary. Registry storage and `_registerVault` record package/type/token/fee-type relationships, not an initial creator address (`VaultRegistryVaultRepo.sol:39–80,92–149`). Searches for `creatorOfVault` in both local contracts and Crane contracts found no matching implementation. That negative result is scoped to these trees, not a claim that such a name cannot exist elsewhere.

Thus neither a factory/deployer identity nor ordinary fee-type registration supplies the missing custom binding in the traced path. `msg.sender` at a factory/registry callback is not automatically the economically selected creator. Nor does reading the current creator role NFT solve the preceding question of who receives it at initialization.

### 3.2 Required transition and unresolved value

**Required transition:** initialize the custom staking/NFT roles, then perform the first funded distribution with creator participation under PRD:55,73,724. The recipient must be determined before that distribution.

**Unresolved value:** the initial creator argument/role owner and its authoritative configuration source. PRD:260 and Plan:125–126 select three instance addresses—market, depository, staking—and fixed dependency bindings. Plan:128 explicitly states no authoritative creator source is established and prohibits guessing deployer/current feeTo. The Universal reference's extra argument is not present in that selected custom instance argument list.

**Why this is not just missing code:** the implementation can technically initialize the role with zero, a deployer address or some Package-fixed creator. These can allocate the same creator fraction to different parties. The existing formula cannot distinguish the intended beneficiary. Choosing zero because storage defaults to zero would silently select the feeTo fallback that the plan specifically says not to guess.

**Minimal closure:** identify the intended existing immutable/role source and explicitly pass it through the established initializer; or explicitly state that this family uses the reference zero-creator fallback. If the intended source already exists in a selected child/package, a citation and binding row are enough. No new percentage, mutable admin, independent oracle or public creator selector is needed. This is a narrow configuration-specification repair, potentially author-resolvable before any owner question.

**Peer disposition:** none of Grok, MiniMax or Kimi's originals analyzed this chain. Their absence of a creator finding is not evidence that a getter/deployer convention answers it. I retain this finding with high confidence about the current text/source mismatch and moderate confidence that a fresh human choice is necessary; a missing citation to an already intended binding could close it.

## 4. L4 — preservation constrains the answer but does not choose it

### 4.1 Resolved behavior stays resolved

All four agree on ordinary behavior: intended-note registration, same-NFT excess beneficiary, purchase-epoch check, intermediate no-reset, final intended completion E→E+1, early rewards, independent destination locks and old-NFT preservation through partial/all-funded-principal reinvestment. Reopening these would be wrong.

The issue is not selecting a different ordinary maturity predicate. Plan:715 already defines a drained candidate: intended completion, release condition satisfied, no funded principal/rewards and no recognized unsettled obligations. MiniMax:119 incorrectly describes that candidate predicate itself as missing.

### 4.2 Post-completion excess: exact missing release value

**Concrete transition:** intended note is completely collected/contributed at epoch106; old NFT unlock107 is satisfied. A separate native note at the same dedicated holder pays additional vested NET at epoch109. The NFT owner invokes supported collection; PRD:935/943 mandates atomic contribution and credit of that excess as **same old-NFT principal**.

**Missing value:** the release condition for this newly funded principal. Does it inherit the already-satisfied107 target, or wait across a later processed epoch after its own contribution? This is not a new bond with its independent type lock and not an intermediate installment before final intended completion.

PRD:945 explicitly ties E to the registered intended note's final successful collection and retains late/prospective receipts under H01/H03. PRD:955 says late-proceeds timing remains; Plan:716 names late-principal timing. The conservation/beneficiary rules decide *whose* principal it is, not *when* that additional principal becomes withdrawable. Extending the wait without instruction or ignoring the expressly reserved late-timing clause are different availability decisions.

Native source demonstrates the transition is expressible: `BondDepository.sol:130–137` appends notes to the supplied recipient, while143–152 redeems vested amounts across all notes of the caller. It need not represent an incomplete intended note. No fork execution or attack-cost claim is needed to identify this specified excess-collection branch.

**Minimal closure:** one explicit release sentence for actual post-completion excess credited to an existing NFT. No repeat selection of the ordinary E+1 rule or the excess beneficiary.

### 4.3 Irreversible retirement: exact missing entitlement/authority

**Required operation:** Plan:264 exposes `retire(uint256 tokenId)`;270 expressly leaves the irreversible rights transition unresolved. Plan:716 preserves the mature-and-empty retirement intent and disallows adopting permanent DORMANT/nonburning behavior as if selected. PRD:945 calls retirement a separate mature-and-empty lifecycle action;957 requires eventual retirement and late-gift handling.

**Concrete transition:** an intended note is complete; principal/rewards and recognized obligations have been drained; the owner invokes retire. Later a third party purchases a native note for that same persistent holder address, or a previously appended separate note pays later. The holder remains permanently NFT-contract-owned. Collection normally requires tokenId authority/current NFT owner (PRD:933).

**Unresolved values:** whether/how retirement extinguishes or preserves rights to these later native proceeds, and what authority/beneficiary remains after the NFT no longer has a current owner. Already known pending rights and truly post-retirement gifts may receive different treatment, but the current text does not select either treatment.

A rule protecting *already recognized* claims can determine a pre-burn rejection condition. It does not determine treatment of a future receipt after a successful authorized terminal action. Similarly, no current-balance test can certify that all future gifts are impossible. This does not imply a duty to recover every unsolicited future token; it means the terminal entitlement boundary must state what the product actually promises.

### 4.4 Attributed agreement/dissent

- **Agree Kimi:81–91:** the two transitions remain narrow rights/availability issues. I do **not** adopt Kimi's suggested E′+1 generalization or permanent retention as the answer; those require confirmation and the latter conflicts with the current unselected-never-burn warning.
- **Disagree Grok:111–112:** “No user-facing transition requires destructive retirement” is contradicted by the expressly exposed `retire` and Plan:270/716. Removing it or always retaining the NFT is not merely applying protection rules. A protective revert can be a temporary implementation guard, not specification closure.
- **Disagree MiniMax:121–127:** burn after an apparently mature/empty predicate still leaves the post-burn recipient/authority unanswered. Those are not equivalent formulations of a Boolean predicate. The current plan explicitly says the terminal edge is not implementer discretion.

This retains only the terminal part of L4. It does not block normal funded-principal reinvestment, final E+1 withdrawals or claims. Minimal next deliverable is a short terminal transition/rights statement, not another comprehensive lifecycle redesign.

## 5. Ordinary “gaps” remain withdrawn — with two cautions

### Broad agreement

I agree with all three originals that the following are not new owner questions on current evidence:

| Item | Classification | Existing answer / remaining work |
|---|---|---|
| Force-claim/public credit/full sync | RESOLVED + IMPLEMENTATION/TEST | Capture declared origin-independent credit before sync; recompute native claims; protect booked exclusions; once-only consumption; final full sync. PRD§6.3, Plan§6.1/§6.6.4. No historical payer-provenance gate. |
| Provider/caller rounding | IMPLEMENTATION/TEST | Selected whole-SY sample/normalization and rate-provider pricing versus finite-size funding; preserve host adapter floors/fee order. Plan§6.4/§6.5.6. |
| Owned-HLP/Keep-YT/rollover chronology | IMPLEMENTATION/TEST | Already-selected modes, custody, pre/post-expiry source transforms, ordered snapshots, bounded claims, commit/rollback. PRD§7.1.2/§11.4 and Plan§6–§7/§10. |
| Exact-output arithmetic/domain | IMPLEMENTATION/TEST | Existing inverse/forward checks, actual receipt, truthful limits and required-route coverage. No new residual beneficiary on an unproven required-domain example. |
| Documented dependency addresses/default fork block | RESOLVED authority + IMPLEMENTATION/TEST | Pendle documentation is authoritative; use `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`, currently20,714,383; later fork validation. No independent research pinning gate. |
| G0 | PROCESS ONLY | Scoped maintainer instruction reconciliation and separate execution authorization, not repeat custom-family approval. |
| Source version, oracle terms, gauge identity, same-token case, warmup | IMPLEMENTATION/TEST | Inspect/adapt/test documented dependencies; escalate only a demonstrated incompatible required transition. No advance certification requirement. |

### Caution 1: do not introduce a new universal surplus-eligibility rule

Grok:47/50 and Kimi:34 offer useful role-exclusion interpretations of synced SY. They should not become a new blanket authorization to relabel every historical donation or same-token incentive as earned interest. The withdrawal of a provenance blocker follows explicit L2 plus existing role/sync law. It does not repeal PRD's listed exclusions or conditional incentive classification. Implementation should maintain the distinction without inventing a permanent new bucket or payer-authentication requirement. No concrete incompatible case is demonstrated here, so this is not retained as an actual specification gap.

MiniMax:39's shorthand adjustment from current PY minus stored PY is also not a replacement for the actual user-index-based net-C equation in Plan§6.6.2. Classification agreement does not endorse incorrect accounting formulas.

### Caution 2: “deliver or revert” is not permission to drop an otherwise required route

All peers lean harder than my original toward declaring every direct-SY nonrepresentable amount a mandatory revert. Current Plan:487 specifically says to prove the operative domain **or finish an existing-rights-compatible delivery/residual route for a reachable gap**; it does not universally prescribe an equality rejection before considering the actual composed route.

I retain my original narrower withdrawal: an I>1e18 toy jump does not demonstrate a new owner-level residual decision. A genuinely impossible/domain-invalid delivery reverts under existing law; a funded required route cannot be silently omitted merely because a simpler direct-call implementation cannot produce it. Existing input refunds likewise do not automatically assign converted-output excess. This remains source integration/domain testing, not a presently retained gap or permission for a new payout rule.

Kimi:67's maximum-rebase horizon estimate was not source-verified in this review and is unnecessary to the classification; do not use it as an established operational bound. MiniMax's references to a plan§11.1.2/§7.4 appear to mix PRD/plan numbering; use PRD§7.1.2/§7.4 and the actual Plan sections rather than perpetuate those citations.

## 6. Minimal surviving list and human checkpoint

### ACTUAL SPEC GAP — two narrowly scoped entries

1. **Initial custom creator binding:** which supplied/configured value initializes the existing creator role, including whether the reference zero fallback is intentional. Needed at initial role creation; not answered by oracle percentages or registration metadata. Minimal deliverable: one binding statement/citation. An already intended authoritative source can close it without a new economics decision.
2. **L4 terminal transition:** post-completion excess-principal release and retirement's treatment/authority for remaining or later native receipts. Needed for supported late collection and exposed retire. Minimal deliverable: the two explicit terminal rights/release rules, preserving ordinary lifecycle decisions.

### IMPLEMENTATION/TEST

All remaining ordinary source/quote/funding/provider/receipt/ABI/initialization/parity/resource/fork tasks. No new reserve model, Weighted inverse, percentage floor, payout beneficiary or unconditional broken-dependency survival guarantee. Preserve full required route coverage and actual failure rules.

### PROCESS ONLY

G0 instruction maintenance, separately authorized execution and mechanical documentation-status reconciliation. Address verification/block pinning must not reappear as an independent research prerequisite under the human's ruling.

**Concise answer to the user:** most old blockers should be retired as engineering work. I do not support “no gaps” merely by turning retire into a permanent revert or choosing zero creator silently. The checked sources give an existing creator mechanism but not this family's initial binding; the operative PRD/plan explicitly retain the two terminal-rights edges. These are narrow, local clarifications—not grounds to reopen approved economics or halt all implementation planning.

**Confidence:** high on the traced creator mechanism and explicit terminal clauses; moderate that creator needs a new human answer rather than documenting an already intended binding. High that ordinary source/test work and address/default-block policy are not new design questions. No tests ran and no deployment/economic-safety claim follows. Original preserved; one combined cross-review completed, then stop for moderator/human.
