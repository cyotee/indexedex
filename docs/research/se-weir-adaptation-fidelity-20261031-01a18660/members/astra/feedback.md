# Astra advisory

## Identity

- Assigned member: Astra.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account/provider route, reasoning setting, and ancestry: not exposed.
- This is one advisory on the coordinator's frozen synthesis, not a new original, peer review, or implementation instruction.

## Draft under review

- ID: `se-weir-adaptation-fidelity-20261031-01a18660-r1`.
- Path: `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/coordinator/draft.md`.
- Supplied SHA-256: `eafad1d94fdf7fd8cc4d291262d98698bce2767ee9a8b16410dac8b37858a0b8`.
- Independently computed raw-file SHA-256 using `shasum -a 256`: `eafad1d94fdf7fd8cc4d291262d98698bce2767ee9a8b16410dac8b37858a0b8`.
- Result: match. The complete draft was readable and read.
- Comparison basis: my original `members/astra/response.md`, retained in this session's context. No peer original or feedback was read.

The draft's internal “Fingerprint: not computed” line does not invalidate this independently verified match. Do not mutate the frozen draft merely to insert a fingerprint; record its identity in the coordinator's resolution/final metadata.

## Disposition

**REQUEST CHANGES for completeness and accurate attribution, not to resolve the preserved policy splits.**

The draft states my principal conclusion accurately: PairToken inheritance is the wrong basis, deleting the sibling sentence is insufficient, the written locks remain authoritative, and Weir compound does not contain PairToken's ratio swap. It also fairly preserves my conditional entry-size and entry-tick proposals as authorization cases rather than approvals.

It does **not** yet represent the substance of my original sufficiently to answer the entire assigned question. The original classifies materially more than the named seven items. The draft neither carries that inventory nor dispositions most of it. Several omitted cases determine whether the resulting product is a faithful adaptation, and two compressed statements can change the meaning of the accepted routes.

The coordinator need not adopt my proposals or obtain another round. It should preserve each load-bearing proposal as an attributed option, reject it with a reason, or carry it as an explicit owner decision. “Not adopted as council recommendations” is a valid position but is not a sufficient explanation for omitting the underlying ownership and interface issues.

## Concerns and exact corrections

### 1. Proposed text: scope the `IncompleteConversion` removal to entry

The row says:

> Remove. Weir accounts actual deltas and forbids a consumption-equality check.

That is broader than my position. My original distinguishes:

- F FS-X04's complete consumption of the selected **entry** half-swap: a FullSpread addition, absent from both Weir and PairToken stage one, which I recommend removing.
- Complete consumption of the unwanted allocation on a successful **single-token exit**: a deliberate constraint of the accepted output route, which I retain. The exit cannot silently return a second token, donate the unsold allocation, or leave it stranded after burning shares.

Weir source lacks an equality check; the source-import PRD forbids adding one to the faithful import. Neither fact forbids an explicitly authorized adaptation from having a stricter scalar output contract.

**Correction:** Replace this row's recommendation with:

> Remove FS-X04's blanket entry half-swap consumption check. Neither Weir nor PairToken stage one requires it. Preserve the accepted scalar exit contract: pay only the requested token or revert atomically, without donating an exiter's unsold allocation. Proportional two-token exit remains the accepted bundle route.

This is not a vote on caps or a demand to keep the error name.

### 2. Proposed text: do not promise that Weir refunds fit the scalar ABI

The introductory money-rule paragraph and the remainder row correctly identify the rejected compulsory donation. They omit my accompanying interface boundary: Weir can send the payer unused input and positive settlement credits in both currencies. The locked scalar `(amountOut, amountRefunded)` result is not a general two-currency refund basket.

**Correction:** Immediately after the table, add:

> Returning ownership of unused entry inventory to the payer does not establish that every Weir zap outcome fits the accepted scalar refund ABI. The supported result domain and any second-currency residual require an explicit decision. Neither an extra refund selector nor compulsory no-share donation is authorized by this report.

Otherwise “refund unused input” can be read as a complete implementation instruction when the original explicitly left this compatibility question open.

### 3. Proposed text and Preserved disagreements: distinguish explicit `donate` from passive receipts

The draft treats the absence of a Weir vault `donate` method, and its non-adoption of unsolicited transfers, as a contradiction sufficient to reopen whether the owner keeps the locked function.

My original classifies **explicit `donate(token, amount)` as Already authorized by FS-OWN-09**. It is a deliberate addition to Weir, not an inherited permission to book passive transfers. A same-call, explicitly funded donation can coexist with leaving unsolicited historical balances unassigned. Function retention does not authorize all PairToken admission rules or payable variants.

I am not voting away the other members' recorded concern. Their positions must remain attributed, and I have not read their originals to verify them independently.

**Correction to the table:** State:

> Already authorized by FS-OWN-09 as an explicit no-share book contribution. Weir has no equivalent function; passive transfers remain unassigned. Some members identify a fidelity concern for the owner, but the existing lock is not cancelled or made provisional by this draft.

**Correction to Preserved disagreements:** Add my position explicitly: the lock is a deliberate exception, and an explicit same-call contribution is distinct from automatic adoption of passive receipts. Separate any decision about retaining the already-locked function from decisions about positive-supply admission, donation while disabled, or raw-ETH forms.

### 4. Evidence gaps: the idle-aware issuance case is load-bearing

**Omitted case A2: charge for incumbent idle/fee backing and constrain attributable share credit.**

My original does not merely suggest optional polishing. Weir's liquidity-only subsequent issuance lets new shares participate in existing idle without paying separately for it. The owner has deliberately required a local sleeve and explicitly booked donations. These make the source's idle dilution consequential even after every obvious PairToken knob is removed.

**Correction:** Add a substantive accounting-decision row:

> Astra proposes an explicitly authorized idle-aware issuance change because the locked sleeve and booked donations enlarge the backing that Weir's liquidity-only mint formula does not price. The owner must either approve a complete alternative equation or deliberately retain that dilution. This proposal does not approve PairToken's geometric-mean genesis, zero genesis reserve, or compulsory uncredited zap remainder.

Preserve that my candidate same-price per-leg ownership predicate is not an external-price or manipulation guarantee. The draft may decline the proposed method, but cannot imply that restoring Weir's formula automatically satisfies the sleeve's ownership intent.

### 5. Evidence gaps: fee ownership and maintenance policy need dispositions

Two additional omitted cases are load-bearing:

| Original case | What it changes and why it matters | Required draft correction |
| --- | --- | --- |
| A3: incumbent entry-swap fee ownership and principal/fee separation | Weir's entry add-liquidity settlement can use fees earned by old liquidity during the entrant's own swap to reduce that entrant's net cost. My proposal isolates those fees rather than treating them as caller contribution. | Carry the proposed correction as a separate economic authorization case, or explicitly retain Weir attribution. “Actual swap deltas” does not answer ownership of fees embedded in later manager deltas. Any performance-fee treatment must be specified separately. |
| A7: preflight-selected collection-only withdrawal | Weir always attempts reinvestment before withdrawal. An otherwise removable position can face an addition-specific obstacle. My proposal separates collection/removal from blocked reinvestment. | Either reject this proposed availability change with a reason or carry it for the owner. Do not import PairToken's reason table, compound-swap obstacles, or public mode query. Dropping `previewWithdrawalMode` did not authorize an internal fallback. |

A3 affects the money allocated to holders; A7 affects which exits remain executable. Both need visible treatment even if the coordinator ultimately recommends unchanged Weir behavior.

### 6. Evidence gaps: tokenized execution and truthful quotes cannot be reduced to packaging

The following omitted cases are load-bearing for the new standard surface:

| Original case | Original authorization case | Required draft correction |
| --- | --- | --- |
| A4: cross-facet operation context, callback commitment, economic-view phases | Adapt Weir's public guards and manager authentication to a diamond with explicit callback context. Do not copy PairToken's ordinary per-action unlock schedule or stale Basic Vault snapshot. | Carry the guard/context recommendation and the unresolved in-flight custom-reserve behavior separately. The current local-plus-deployed reserve lock must not silently become the shared facet's last-committed snapshot. |
| A5: exact receipts, disjoint reservations, native sync validation | Prevent nominal funding from consuming existing custody, distinguish caller inputs from backing, and address the documented native-sync condition. This does not support FoT tokens or authorize taking another actor's credit. | State whether these checks are proposed changes, necessary enforcement of the accepted funding surface, or deliberately omitted. Preserve the difference between ordinary execution and borrowed-manager global sync effects. |
| A6: bounded truthful preview/execution domain | Weir's simple preview omits pending fees, compound, and zap. A local executable quote needs an approved model and support domain. I proposed bounded shared planning, stale-plan rejection, and a separately authorized initial hookless/static-fee domain. | Carry this as a scoped case, not inherited PairToken libraries, numerical work budgets, or gas ceilings. Do not imply the accepted previews can just use Weir's existing preview calculation. Hookless restriction is itself a change from Weir. |
| A11: borrowed unlock on canonical scalar `exchangeIn` | Neither Weir nor PairToken supports this context. It serves the draft PRD's stated hook-conversion target but needs existing owner authorization identified or a separate case. | Record it as a separate FullSpread capability, not a PairToken feature or an automatic implication of the selector. My original explicitly did not establish its authorization from the disputed PRD alone. |

A11 must stay distinct from the tick-bound split. My entry-bound recommendation was not made conditional on accepting borrowed unlock; the draft attributes that conditional position to Grok, not to me, and should preserve that distinction.

### 7. Coverage adopted from responses: restore the material non-cap inventory

The three coverage rows do not show review of the entire PRD. My original also classified the following carry-overs. They cannot all disappear under the statement that additional authorization cases are not adopted:

| Material item omitted from the synthesis | My original disposition to preserve or explicitly decline |
| --- | --- |
| Geometric-mean genesis and mandatory paired-only bootstrap | Remove as inherited requirements. Weir can permit a first zapped deposit against an initialized pool with usable liquidity; that is different from a guaranteed zap into an empty pool. |
| Removal of Weir's 1,000 unassigned genesis shares | Remove the inherited no-reserve decision. Coherent ERC-20 representation of the reserve needs an explicit decision; do not silently choose zero reserve or a burn address. |
| True terminal withdrawal, zero-supply reset, rebootstrap | Remove automatic inheritance because it depends on eliminating the source reserve. Do not adopt this lifecycle before that economic decision. |
| Fee policy and operational administration | Removing PairToken's no-fee rule is correct but insufficient. Weir's fee/treasury/pause configuration needs an explicit mapping; registry packaging does not establish an ownerless vault. |
| Exact PairToken `PkgInit` field order, six linked libraries, mirrored file split | Remove compulsory implementation-shape copying. Preserve genuine registry/Crane requirements and actual required infrastructure, not a named predecessor's layout. |
| Share precision and blanket arithmetic rewrites | Do not import “18 decimals because PairToken” or broad safe-cast/full-precision substitutions as authority to change source economics and failure behavior. Follow an established standard or make the specific decision. |
| Raw-ETH public-route promises | Owner locks dropped the named paired/SY routes and left raw ETH undecided. Preserve native PoolKey/internal settlement and accepted ERC-20 faces without inventing a payable extension. |
| Legacy Basic Vault snapshots, SY/rate requirements, and blanket S1 acceptance inheritance | Remove contradicted assumptions and inherited tests. Custom reserves and rate/SY locks control; a standalone Weir-adaptation acceptance matrix must reflect actual chosen behavior. |

**Correction:** Expand the classification/coverage section with these topics and the cases above, or provide an explicit disposition ledger keyed to them. An undispositioned pointer to my original is not a substitute for the promised whole-PRD synthesis.

I do not ask the coordinator to copy the full original, approve every proposal, or relitigate settled selector choices. This is the minimum material scope needed to keep the report from becoming only a zap-parameter discussion.

### 8. Evidence gaps: retain narrower proposals without overstating their priority

My remaining omitted authorization cases are:

- **A8:** reject positive-share withdrawals with zero total payout, instead of preserving Weir's possible zero-output burn.
- **A9:** reject user mint/payout destinations equal to the vault, instead of preserving self-directed unassigned or stranded receipts; treasury and legitimate transient custody are separate.
- **A10:** require existing shares for explicit donation, so the no-share contribution has an identifiable beneficiary set rather than leaving a future bootstrap to capture it.

These are narrower than A2 through A7 and A11. They are not necessary to establish that the PRD mixed economic designs, and omitting them from a short executive summary would be reasonable. They still belong in the disposition ledger if the final claims comprehensive classification. In particular, A10 is **not** already authorized merely because `donate` is locked.

**Correction:** Mark each as an attributed, unapproved narrow behavior change or explain its rejection. Do not describe these protections as Weir behavior or quietly install them.

## Original representation and preserved splits

**Accurately represented:** wrong inheritance basis; removal of compulsory uncredited zap remainder; removal of `previewZapCredit`; Weir's no-ratio-swap compound; no cap numbers; separate optional entry-size/tick cases; no approval by field presence.

**Needs qualification:** the unscoped `IncompleteConversion` removal, the assertion that Weir “forbids” adaptation checks, the unresolved scalar refund boundary, and the characterization of `donate` as a lock that needs a fresh keep/remove decision merely because W has no such method.

**Materially omitted:** the load-bearing cases and non-cap inventory identified above, especially sleeve-aware issuance, fee ownership, source genesis reserve, preview support domain, callback/custody boundaries, and borrowed-unlock authority.

I do not resolve the entry-size, tick/price-bound, or donation-fidelity splits by vote. I do not independently certify the other members' positions, participation, or unanimity claims. Preserve those as coordinator attributions, and preserve my actual position separately.

## Limits

Only the exact frozen draft was newly read for this advisory; my original was compared using retained session context. No peers, PRD, function-review file, source tree, current external documentation, or memory file was opened. The only shell command was the raw-file SHA-256 verification requested by this assignment.

Only `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/members/astra/feedback.md` is written. The original response, frozen draft, PRD, and review file remain unchanged. No test, build, Git operation, implementation, deployment, wallet operation, or delegation was performed.

This advisory neither replaces the original nor authorizes implementation. It requests corrections to the coordinator's final synthesis, not another council round. The frozen draft remains preserved, and any final revision is the coordinator's responsibility.
