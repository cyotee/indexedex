# DTF loss-and-recovery ledger

Prepared 2026-11-08 from the recorded research. Revised for the user's current-holdings exclusion and custody/harvest direction. Policy revision: `held-assets-no-upfront-credit-20261108`. Status: **evidence-populated, unpriced, not issuable**. This is the requested ledger under the proposed recovery method, not a contract change, final loss determination, approved allocation root, or authorization to issue bonds.

## Result

| Record | Count / quantity |
| --- | ---: |
| Account/product rows | 435: 422 weighted, 13 earlier CP |
| Position rows | 411: 382 weighted, 29 earlier CP |
| Weighted pre-incident position addresses | 331 after known-custody removal and address deduplication |
| Weighted nominal look-through exposure before held exclusions | 2,237.832428068 old DETF units |
| Confirmed still-held snapshot exclusion (lower bound) | 1,674.947599807 old DETF-equivalent units |
| Snapshot remainder after that exclusion | 562.884828261 units, unresolved and non-issuable |
| Weighted snapshot accounts fully excluded as held | 249 of 331 |
| Current token/claim/NFT inventory | 403 rows across both generations |
| Observed post-incident DTF exchange outputs | 69, totaling 59,027,441.289824656686224552 DTF |
| Explicit internal conversion records | 250 |
| Normalized Transfer evidence rows | 12,191 |
| Final ETH losses / new-share allocations | Unknown; no rows are issuable |

The 435 rows are account/product entries, not 435 people. The exposure is a nominal unit reconciliation, **not ETH loss, market value, or a new-share award**. The 69 outputs are observed assets received, not automatically deductions from the recipient's pre-incident claim. A wallet can have later purchases, transfers, or redirected payouts.

## Files

- [account-ledger.csv](account-ledger.csv): account/product index, policy priority, position links, observed recovery links, V/H/R/E fields and open exceptions.
- [positions.csv](positions.csv): source-unit positions and weighted nominal look-through exposure, including each pre-incident funded NFT.
- [observed-recoveries.csv](observed-recoveries.csv): individual DTF outputs with transaction/log locators, associated transaction-level DETF input and burn amounts, and unresolved attribution/valuation status.
- [held-exclusions.csv](held-exclusions.csv): one row per original position, with confirmed held overlap, matching method and unresolved snapshot remainder. Earlier CP values remain unpriced.
- [custody-inventory.csv](custody-inventory.csv): currently observed tokens, claims and individual NFTs, their custody registration fields and separately tracked harvest proceeds. No deposits or harvests have occurred.
- [CUSTODY_AND_HARVEST.md](CUSTODY_AND_HARVEST.md): no-upfront-credit rule, custody accounting, conservative matching and the future harvest record contract.
- [conversions.csv](conversions.csv): post-incident funded-bond claims, legacy staking claims, and stake/unstake movements. These are changes of representation, not automatic external recoveries.
- [exceptions.csv](exceptions.csv): open decisions and evidence gaps, keyed to account rows.
- [rounding.csv](rounding.csv): non-claimable residual units, separated by asset.
- [reconciliation.json](reconciliation.json): measured counts and exact integer conservation checks.
- [sources.json](sources.json): cutoffs, source paths, SHA-256 hashes and coverage boundaries.
- [evidence/](evidence/): durable frozen candidate/bond records, normalized transfers, and bond/index proofs. No /tmp file is required to use this ledger.

## Policy applied to this draft

1. Weighted product eligibility starts with beneficial ownership immediately before the attack: last full block 64,394,556. The preceding transaction in attack block 64,394,557 was a system transaction with no selected-contract events. Do not count the attack transaction.
2. Record liquid DETF, sDETF, SY, legacy TokenStaking claims and user NFTs through look-through accounting, then exclude the snapshot portion still represented by live holdings from upfront new bond credit. Do not credit the same custody account and its beneficiaries. The exclusion survives deposit into migration custody: users deposit for potential DTF harvest over time, not to unlock advance compensation for those same holdings.
3. Earlier CP positions remain a separate manual cost-basis cohort. Its LP locks and 18-decimal tokens are not the later product's fixed-principal, nine-decimal bonds.
4. Ordinary candidates precede deferred creator/deployer/fee-role review. A role label does not invalidate a documented personal contribution. Protocol inventory is not a separate user claim. Four account/product rows have a known deferred role; all other rows remain unclassified ordinary candidates, not approved recipients.
5. A historical payer or post-attack holder without a snapshot position has no automatic weighted snapshot entitlement. Such rows remain visible for review rather than disappearing from the record.
6. Post-cutoff ownership transfers require beneficiary review. Do not compensate original and current holders independently for one position.
7. Do not treat the reduced current market/salvage value of a live token or NFT as permission to pre-credit the rest of that same snapshot position. Withhold its full attributable snapshot-reference portion; later harvested DTF is a separate realized flow. Recoveries and held exclusions must be attributed to disjoint portions, not subtracted twice.
8. The proposed fixed migration allocation and 90-day linear bonds remain planning parameters. The proposed 90 ETH is not recorded as a verified deposit, a payout cap already allocated to recipients, or a multiplier on attacker proceeds. No deployment, custody registration or claim root has been performed.

## Meaning of the monetary fields

For each approved claimant, the proposed formula is:

`E_i = max(0, V_i - H_i - R_i)`

- V: approved reference value of eligible exposure, in ETH.
- H: the full snapshot-reference portion still represented by held tokens, NFTs or descendant claims, whether outside the migration or deposited into its custody. This is not the current discounted salvage value. Deposit does not clear H or restore upfront credit.
- R: attributed external economic recoveries from a disjoint portion of the exposure, under the approved valuation rule. Do not subtract a harvest again from R if its source portion is already withheld in H.
- E: potential upfront-eligible exposure only after complete held-position and recovery attribution.

This replaces the earlier `K_eth` retained-outside-only rule; `account-ledger.csv` now uses `H_eth`. The policy is fixed for held assets, but ETH valuation and complete attribution remain unresolved. Separate quantity fields carry the exclusions already provable.

All four ETH fields and the new-bond allocation are empty in CSV, meaning **unknown**, not zero. The available evidence does not yet fix a clean pricing window, family-specific external-backing valuation, full recovery attribution or custody/harvest reconciliation. Never fill these fields from the current thin-market quote, the pool's last pre-attack spot, gross deposits minus gross withdrawals, or an equal division of 90 ETH.

Once a funded new-share allocation N is approved, proportional allocation would be `N * E_i / sum(E)`, with explicit integer rounding and complete attribution. Do not use the unresolved remainder as E or allocate N against the unadjusted 2,237.832428068 units. N is currently unset. Current-held positions receive zero upfront credit. Reference-value allocation is not a guaranteed future ETH payout.

## Weighted nominal exposure calculation

All arithmetic uses integer units; DETF/sDETF/SY use nine decimals and DTF/WETH use 18. Legacy staking weights are 18-decimal DTF allocation units, not DETF.

- Liquid: use the event-replayed pre-incident DETF balance, excluding known custody and reserve accounts.
- Direct sDETF: use the existing pre-incident gons-replayed balance census. Never sum rebasing Transfer amounts as balances.
- Direct SY: `floor(SY shares * 73,604,571,731 / 66,535,753,862)` sDETF raw units. The SY wrapper's own sDETF is not a separate position.
- Legacy TokenStaking: first allocate `floor(user weight * 35,589,506,697 / 19,712,889,616,977,499,499,766,803)` SY raw units, then apply the SY conversion above. The claim vault's SY is not separately credited.
- Funded NFT: reconstruct each NFT's original staking gons from its matching Staked event, subtract gons moved by pre-incident claims using the event-time index, then divide by cutoff gons-per-unit 903962246886315724026911557873968023. This includes its pre-incident funded staking growth; it is not merely original principal.

Forty-one pre-incident NFT positions reconcile to exactly 208200941171774511655236409911455698947144975844 custody gons. Their 41 funding observations and 16 pre-incident claim conversions are recorded in S012. The 847 index changes are S013. The raw NFT custody balance is 230.320394340 sDETF; allocating per NFT leaves 20 raw units of rounding.

Nominal conservation, in old DETF raw units:

`2,237,832,428,068 attributed exposure + 2,702,841,305,735 reserve-held DETF + 100 account-rounding + 20 NFT-rounding + 100 SY/legacy-rounding + 3 funded-backing surplus = 4,940,673,734,026 total supply`

The 40 raw SY units left by legacy weight allocation are already included in the SY/legacy sDETF residual above; do not add them again as DETF. Dust is not allocated to a claimant. These checks establish quantity conservation, not historical ETH backing or losses.

## Held-position adjustment

`held-exclusions.csv` partitions each weighted snapshot position into confirmed held overlap and unresolved remainder, in snapshot-basis old DETF units. It is an evidence lower bound, not a policy for allocating fungible lots. For same-wallet liquid DETF and SY, subtract all post-incident outgoing units from snapshot units and clamp at zero, then cap by the observed current balance. For sDETF use original and outgoing gons at each event-time index, excluding post-incident growth from the snapshot measure. Inbound purchases are never added to snapshot exposure. For legacy claims use remaining original weights. For NFTs match the exact ID and its remaining snapshot gons, even if ownership changed; the current holder is a custody candidate, not automatically the original claimant.

This confirms **1,674.947599807** units still held and excludes them from upfront compensation. The other **562.884828261** units remain held for review: they can include conversions or transfers to another form, actual recoveries, ambiguous lots or true loss. There is no award calculated from that remainder. Exactly 249 weighted snapshot accounts are fully excluded; 82 still have unresolved quantities. All role classes are included in those accounting totals; priority decisions remain separate. The earlier CP current positions are also excluded from upfront credit, but no common DETF-unit or ETH deduction is invented for them.

Every currently observed holding is separately recorded for custody and possible DTF harvesting. This does not establish that a legacy staking claim is transferable, or that every asset can be exited while its underlying is disabled; use only validated custody and claim routes. No recovery contract is implemented by this ledger revision.

## Recoveries, conversions and transfers

The 69 observed DTF outputs total 59,027,441.289824656686224552 DTF and all have associated external DETF inputs in their transactions. Their classification is `detf_exchange_output`. All remain `deduct_from_R=false` until pre-incident provenance and valuation are resolved. Transaction-level input quantities are evidence, not automatically apportioned among multiple recipients.

The 250 conversion rows consist of seven post-incident BondClaimed events, eighteen legacy ClaimWithdrawn events, 138 stakes and 87 unstakes. Bond claims pay sDETF; legacy claims release SY; stake/unstake changes the representation of DETF exposure. None of those event names alone demonstrates recovered ETH or DTF value outside the claim stack. Subsequent actual external outputs must be linked rather than counted twice. SY deposit/redeem and wallet transfers remain in normalized transfer evidence for beneficiary tracing; conversions.csv is the explicit decoded subset, not a claim that every route has been semantically reconstructed.

The main pre-incident DTF purchase and redemption columns are historical context. Earlier returns are already reflected in snapshot ownership and must not be subtracted again from snapshot V merely because the wallet received them.

**Correction to earlier narrative:** transaction 0x00565ab940ab97deaf111d5dfe56ad6441fb3a1b5c93b4efde9d3c037fe1a33d on November 3 exchanged 1,309.386196475 DETF for 10,376,565.125097551654717625 DTF. Its DETF moved through the diamond into the reserve hook; it was not burned. The separate transaction-level burn field is zero. This still proves DTF output was obtainable while the WETH-leg SE remained disabled.

## Earlier CP cohort

Its sixteen user NFT locks, IDs 3-18, and purchase inputs are retained in S009. Original LP shares are not fixed DETF principal. Two routed purchases paid 2 WETH and 0.0001 WETH respectively; the DTF received from the underlying SE in those transactions is an intermediary conversion, not an additional direct user contribution.

The historical input columns for CP rows cover verified bond purchases only. A zero there does not establish zero lifetime acquisition cost for liquid or receipt holdings. Those acquisition histories and external recoveries remain C3/R2 exceptions. Older staking receipt balance calls were latest-state observations on November 8; they sum to 57.880198310224980583 against reported supply 57.898677945502333609. The unresolved difference is not distributed to users or silently treated as rounding dust.

## Evidence coverage and required closure

Main evidence is frozen at block 108,944,663 (2026-11-08 04:08:21 UTC), hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733. It is not a live claim ledger. Refresh intervening activity before custody registration or awards.

Complete direct DTF transfer-to/from-DETF history is available through cutoff. Full post-attack WETH/native recovery history is not: providers returned timeouts, archive-token requirements and range-plan caps. Historical storage at the incident block was unavailable; snapshot balances use event reconstruction and the existing census. Failed transactions and off-chain payments/ownership arrangements are outside the evidence.

To close the ledger: approve a clean ETH valuation reference and family-specific backing method; attribute later outputs to original exposures without including later purchases; complete missing asset recoveries and older CP accounting; resolve transfer and role exceptions; refresh held-position exclusions and register migration custody; reconcile harvest receipts separately without restoring already excluded upfront credit; verify funding and fix N. Only then calculate E and issue new bonds. The missing values remain explicit holds rather than fabricated losses.
