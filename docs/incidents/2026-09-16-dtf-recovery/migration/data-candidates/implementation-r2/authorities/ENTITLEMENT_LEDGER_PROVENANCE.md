# Entitlement ledger provenance and script handoff

- **Prepared:** 2026-11-09.
- **Purpose:** Preserve how the recovery evidence was gathered, how the ledger was derived, and how to turn it into inputs for the future entitlement configuration scripts.
- **Governing requirements:** [MIGRATION_DETF_DRAFT_PRD.md](MIGRATION_DETF_DRAFT_PRD.md). This review was prepared against revision `migration-detf-discussion-r18`, SHA-256 `ead004ebe1fd9ac0deb845c0d84339ef741494e6c3fe7126d191942262cd0788`. On 2026-11-10, revision `migration-detf-discussion-r20` replaced the linear ETH/DTF output rates with the existing DETF mint preview against the post-funding reserve snapshot. Where this report tells a script to apply those output rates to remaining principal or accrued rewards, follow r20 instead.
- **Status:** Provenance and data-preparation handoff. The historical ledger is evidence-populated but remains **non-issuable**. This report does not approve recipients, calculate final awards, implement scripts, or submit transactions.
- **Scope of this review:** Inspected the saved CSV/JSON/Markdown artifacts and the original collection-session tool calls; verified recorded file fingerprints and selected integer reconciliations. No fresh RPC acquisition was performed.

## 1. Start here when implementing the scripts

There are three distinct layers:

1. **Frozen evidence:** transactions, event locators, observed balances, purchase records, staking indices and source manifests. Preserve these as historical observations.
2. **Historical recovery ledger:** positions, held exclusions, observed recoveries, account joins and exceptions derived on November 8. Its quantity accounting is useful, but several policy fields predate the current PRD.
3. **Future entitlement configurations:** recipient-keyed independent compensation allocations and source-specific surrender-triggered migration credit configurations. These must be derived under the current PRD; they are not already present as an approved upload file.

Do not upload `account-ledger.csv` directly. Every row has `issuable=false`, all final allocation fields are empty, and its old ETH-loss formula is not the current mint-preview rule.

The most direct existing input for bond-NFT configuration is:

- Weighted NFTs: `evidence/weighted-bonds.csv`, joined by purchase transaction to `evidence/transfers.csv`, with the pre-incident purchase detail file as a corroborating source.
- Earlier CP NFTs: `evidence/earlier-cp-bonds.csv`, which already separates original direct DTF/WETH contributions from routed intermediate DTF.
- Both: add the source NFT contract to the token ID, verify purchase attribution and refresh the position's current state. Loading the historical contribution configuration does not issue a new bond; the matching NFT must be surrendered.

The scripts must distinguish **configuration replacement** from **bond issuance**. Stage 1 setters receive complete replacement values and may correct previously processed configurations. Replay must not repeat donations, payouts or bond issuance. Stage 2 permanently removes configuration/amendment authority. These are PRD rules, not additional rules introduced by this report.

## 2. Chronology and reproducibility boundary

### 2.1 What was actually done

The original session records the following sequence on November 8, 2026, in UTC:

| Time | Work | Durable result |
| --- | --- | --- |
| 04:07-04:08 | Loaded the existing pre-exploit census, checked chain access and the attack receipt, and pinned a later evidence cutoff | Incident identity and cutoff in `sources.json` |
| 04:09-04:27 | Collected weighted-product events, reconstructed ownership, read current receipt balances, and separated DTF inputs/outputs from internal transfers | Weighted candidate and bond exports; later normalized Transfer evidence |
| 04:27-04:40 | Queried registry membership, discovered the earlier public CP product, decoded its different NFT model, and inspected purchase receipts | Earlier CP bond and wallet exports |
| 04:42-04:43 | Exported and checked the four candidate/bond datasets in a temporary research directory | Durable copies subsequently became sources S007-S010 |
| 07:35-07:47 | Reconstructed per-NFT staking gons, calculated non-overlapping positions, separated recoveries/conversions, wrote the durable ledger and checked it | `positions.csv`, `account-ledger.csv`, evidence, recoveries, conversions and manifests |
| 07:57-08:03 | Added conservative held-position exclusions, a current custody inventory and additional staking/claim proofs; independently recomputed them | Current November 8 ledger, `held-exclusions.csv`, `custody-inventory.csv`, S014-S015 |
| November 9 | Requirements evolved to contribution-based pricing, distinct compensation paths, editable Stage 1 configurations and activation-gated reward claims | Current PRD; the frozen ledger files were not rewritten to encode these decisions |

The pre-exploit census existed before the November 8 collection. Its own documented reconstruction is described in [SNAPSHOT.md](../2026-09-16-dtf-pre-exploit/SNAPSHOT.md) and [DTF_SOLD.md](../2026-09-16-dtf-pre-exploit/DTF_SOLD.md). This report does not invent an earlier collection timestamp for those files.

### 2.2 No standalone generator located

No incident-specific generator was found in the repository script and research searches. The recovered session shows that collection and ledger construction ran as incremental JavaScript evaluation cells with in-memory state, including `completeHistory`, `capitalFlows`, `ledgerNftGons`, `ledgerPositions` and `holdingDeductions`. Later cells depend on earlier cells. They are evidence of the method, not a standalone script that can be copied and run without reconstruction.

The four initial exports were written under `/tmp/indexedex-dtf-history-20261108-01a1b2e8/`. Their durable CSV copies are now S007-S010 under `evidence/`. The temporary README and evidence summary were still readable during this review; the acquisition details needed for future work are recorded here. The future scripts must not require `/tmp`, a live agent kernel or private session files.

The recorded repository-wide search was size-limited/timed out in places; the narrower script search completed without a matching generator. The defensible finding is that no reusable generator was located, not that no related code ever existed.

## 3. Chain identity, cutoffs and units

### 3.1 Two different cutoffs

| Purpose | Recorded boundary |
| --- | --- |
| Chain | Robinhood Chain, chain ID `4663` |
| Incident transaction | `0x94e955638633b31a4bada2f8fecbb5f147ec2d0e0943b53e0bcb447fc755e658` |
| Pre-incident boundary | Last full block `64394556`; attack block `64394557`, transaction index `1` excluded |
| Parent block hash | `0x8c3cbc3f108fa7301f2209ad4dffb5bcb0e84980ef97aef2b95ad57c21ce657f` |
| Parent timestamp | `1789550226`, September 16, 2026, 09:17:06 UTC |
| Later weighted evidence cutoff | Block `108944663`, November 8, 2026, 04:08:21 UTC |
| Later cutoff block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Earlier CP receipt balances | Separately labelled latest-state calls on November 8, not pinned historical balance reads |

The only transaction before the attack in its block was a system transaction with no selected-contract events. Consequently, the ledger's `< 64394557` event filter matches the documented immediately-before-attack boundary for this dataset. Preserve the full block/transaction/log ordering in a regenerated pipeline rather than generalizing that shortcut.

The pre-incident boundary measures historical ownership. The later cutoff measures observed holdings and activity. Neither is the PRD's post-funding mint snapshot, and neither replaces surrender as the time custody is taken and credit is delivered.

### 3.2 Source identities

Addresses below identify the recorded legacy sources, not the new Migration DETF's deployment configuration.

| Role | Address | Unit/model |
| --- | --- | --- |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | 18-decimal contribution/recovery token |
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` | 18-decimal wrapped ETH input; normalize addresses for joins |
| Weighted DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | 9 decimals |
| Weighted bond NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | Fixed-principal funded bonds; purchased IDs 3-45 |
| Weighted sDETF | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | 9-decimal rebasing receipt; internal gons matter |
| Weighted SY | `0xB55604CF4dcdABB362078e106D20F98512391EdF` | 9-decimal wrapper shares |
| Legacy TokenStaking | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` | 18-decimal DTF-denominated allocation weights, not DETF units |
| Claim vault | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` | Holds SY for remaining TokenStaking claims |
| Weighted reserve hook | `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | Infrastructure; reserve settlement is not a user contribution |
| TokenStaking migration adapter | `0xC84999F31eA72A793a65ce73aa05ff624FDCBB51` | Routed collective migration input |
| Earlier CP DETF | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | 18 decimals |
| Earlier CP bond NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | LP-share locks; user IDs 3-18 |
| Earlier CP receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01` | 18-decimal rebasing receipt |

Sources: upstream `snapshot.json` and `DTF_SOLD.md`; `positions.csv`, `custody-inventory.csv`, S011; recovered acquisition records. Preserve source-address identity even when two collections share a numeric token ID.

Use raw decimal integer strings and integer arithmetic. Never parse economic amounts through floating-point numbers. An NFT count, LP share, staking weight, DETF principal, DTF contribution and ETH contribution are not interchangeable quantities. Empty numeric CSV cells mean **unknown**, not zero.

## 4. How the chain evidence was gathered

### 4.1 Discovery and event acquisition

The collection first inspected local deployment exports and the existing incident census. It then queried registry `vaultsOfToken(DTF)` membership and product metadata to find the earlier CP deployment that an exact-name search for the weighted DTF-DETF had missed. A separate rehearsal export at `0x8ff37779B8Fe866470aEcf64910F4Bf899d73705` had no code at the pinned head and was not treated as a proven public deployment.

The original run used read-only JSON-RPC methods: `eth_chainId`, `eth_getBlockByNumber`, `eth_getLogs`, `eth_getTransactionReceipt`, `eth_call` and code/metadata queries. It used the official Robinhood endpoint, PublicNode, dRPC and a configured Alchemy provider as available. These are historical acquisition observations, not guarantees of current provider capability. Provider credentials are not part of this report.

Weighted contract event ranges began at block `60000000`, before their deployment. The main collector divided the interval into 10-million-block ranges and bisected ranges when the provider returned a result-limit error. It tracked successfully completed ranges and resumed only missing ranges after provider failures. Earlier CP DETF/NFT/receipt collection began at block `40000000`, before their deployment. TokenStaking predates the weighted range: its pre-incident baseline came from the existing census, followed by later claim events.

A future collector must preserve the block hash, successful range coverage, address/topic filters and raw log locators. An empty successful range is not the same as a failed request. The highest event block in an exported CSV is not proof of the query's upper coverage boundary.

### 4.2 Balances and ownership

Historical contract storage at the incident block was unavailable from the queried providers. The run therefore used event replay and the saved census rather than claiming successful historical `balanceOf` reads.

- Plain DTF and DETF balances were reconstructed from ordered transfers, including mint/burn treatment and negative-balance checks.
- The original DTF census used 640,667 Transfer events from creation block `45332515` and reconciled 8,275 holders to one billion DTF. That broad DTF-holder list is not an entitlement list.
- Weighted sDETF requires gons and the changing `RewardsFunded` index. Summing rebasing Transfer amounts alone is invalid. The pre-incident replay used 684 stakes, 261 unstakes, 184 user transfers and 847 reward distributions.
- SY shares were replayed separately, then converted through the wrapper's recorded backing. Do not credit the wrapper's receipt holdings again as a direct user position.
- Legacy TokenStaking weights were treated as claims on the claim vault's SY, not as another liquid DTF or sDETF balance.
- NFT ownership was replayed from the source collection's Transfer events. Reserved weighted IDs 0-2 were not user purchases.
- Current weighted sDETF balances were read for event-discovered candidate addresses at the pinned cutoff. Earlier CP receipt calls used latest state and retain that weaker observation label.

### 4.3 Historical purchase inputs

The pre-incident sale record classified DTF transferred **into** the weighted DETF by the other events in the same transaction:

| Classification | Evidence used | Treatment |
| --- | --- | --- |
| Liquid purchase | DETF share transfer without a bond/donation/stake-on-purchase classification | Historical input, not automatically remaining exposure |
| Bond purchase | `BondPurchased` in the source NFT collection | Associate purchase transaction and token ID |
| Donation | Donation evidence, including forwarded tokens | Separate from user purchase consideration |
| TokenStaking migration | Input from the migration adapter | Collective source; not independently assigned to every weight holder |
| Reserve settlement | DTF from the reserve hook into the DETF | Exclude as a new user contribution |
| WETH input | WETH Transfer into the DETF | Keep separate from DTF; inspect transaction purpose and routing |

The upstream detail CSV contains 585 liquid, 27 DTF bond, four donation and 203 migration input rows. Its 211 direct DTF sellers are a payer population, not necessarily the later holders or recipients. Gross purchases minus gross redemptions does not reconstruct ownership after transfers.

For earlier CP bonds, the run recovered the older `NewLock` event model, fetched each purchase receipt, and separated owner-to-DETF direct DTF/WETH inputs from DTF received through an underlying exchange. LP-share amounts were not renamed fixed DETF principal.

### 4.4 Coverage limits retained by the export

S011 contains the selected weighted DETF/sDETF/SY/NFT Transfer histories plus DTF transfers to/from the weighted DETF and the completed WETH-inbound portion. It is not a dump of all chain transfers, all DTF market activity, all native ETH flows or the older CP purchase receipts.

The main DTF direct-flow history is recorded as complete through the later cutoff. WETH coverage is inbound only through block `69999999`; full post-incident WETH/native recovery coverage failed because of provider timeouts, archive requirements and range-plan limits. Failed transactions without relevant logs and off-chain ownership arrangements were not reconstructed.

The earlier CP rebasing receipt's seven observed positive balances sum to `57.880198310224980583`, versus reported supply `57.898677945502333609`. This difference remains unresolved; it is not rounding that may be allocated to recipients.

## 5. Durable source and output map

Paths in this section are relative to this report. Source IDs and their recorded SHA-256/byte counts live in [sources.json](sources.json); output fingerprints live in [manifest.json](manifest.json).

| ID | File | What it establishes |
| --- | --- | --- |
| S001 | `../2026-09-16-dtf-pre-exploit/sdtf-detf-holders.csv` | Pre-incident receipt balances and gons |
| S002 | `../2026-09-16-dtf-pre-exploit/stakers.csv` | Pre-incident TokenStaking weights |
| S003 | `../2026-09-16-dtf-pre-exploit/snapshot.json` | Cutoff, supply, custody and wrapper-backing totals |
| S004 | `../2026-09-16-dtf-pre-exploit/sy-sdtf-detf-holders.csv` | Pre-incident SY balances |
| S005 | `../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf.csv` | Per-payer historical input and return context |
| S006 | `../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv` | Transaction/log-level classified DTF inputs, including bond IDs |
| S007 | `evidence/weighted-candidates.csv` | 422 screening addresses and snapshot/current observations |
| S008 | `evidence/weighted-bonds.csv` | 43 purchases, token IDs, purchase transactions, principal and claims |
| S009 | `evidence/earlier-cp-bonds.csv` | 16 LP-lock NFTs and direct/routed purchase amounts |
| S010 | `evidence/earlier-cp-wallets.csv` | 13 earlier-product holder observations |
| S011 | `evidence/transfers.csv` | 12,191 normalized selected Transfer records |
| S012 | `evidence/bond-accounting.csv` | 41 funding and 16 pre-incident claim-conversion gons proofs |
| S013 | `evidence/index-events.csv` | 847 pre-incident staking-index observations |
| S014 | `evidence/all-index-events.csv` | 1,077 staking-index observations through the later cutoff |
| S015 | `evidence/post-incident-bond-claims.csv` | Seven post-incident bond claim/transfer/gons matches |

The upstream explanatory Markdown and `dtf-sold-to-detf-summary.json` are useful additional context, but are not separate S001-S015 entries. For weighted NFT input reconstruction, prefer the hash-verified S006/S008/S011 join rather than depending solely on an unmanifested summary.

| Derived file | Rows | Keys and interpretation |
| --- | ---: | --- |
| `positions.csv` | 411 | `position_id`; 382 weighted plus 29 earlier CP; source-unit positions, not awards |
| `account-ledger.csv` | 435 | `ledger_id = product:account`; 422 weighted plus 13 CP, not 435 distinct humans |
| `held-exclusions.csv` | 411 | `position_id` joins one-for-one to positions; conservative held overlap |
| `custody-inventory.csv` | 403 | `holding_id`; 374 weighted plus 29 CP observed holdings, not confirmed deposits |
| `observed-recoveries.csv` | 69 | `recovery_id`; actual observed DTF outputs with unresolved attribution |
| `conversions.csv` | 250 | `conversion_id`; changes of representation, not automatic external recoveries |
| `exceptions.csv` | 14 | `exception_id`; historical gap/policy register, to be interpreted under section 8 |
| `rounding.csv` | 5 | Residuals by asset/unit; non-claimable |
| `reconciliation.json` | n/a | Recorded exact totals, conservation checks and coverage limitations |

S011's `event_id` is source asset + transaction hash + log index. Sort by `(block, transaction_index, log_index)` for replay. Its NFT rows populate `token_id` and leave `amount_raw` empty; fungible rows do the reverse.

`source_id`/`source_ids` fields may be pipe-separated. Resolve them against `sources.json`. `position_ids`, `observed_recovery_ids` and `current_holding_ids` link the account ledger to the respective tables. These evidence keys are not a requirement for arbitrary on-chain allocation IDs.

## 6. How the historical ledger was defined

### 6.1 Candidate assembly and custody exclusion

The weighted pre-incident position union combined 34 liquid DETF holders, 198 direct sDETF holders, 17 direct SY holders, 92 remaining TokenStaking weight holders and 22 user-NFT owners. Address deduplication produced 331 position addresses. Adding historical payers, current holders and flow counterparties produced the broader 422-address screening dataset.

The infrastructure exclusion set included the weighted DETF, NFT vault, sDETF, SY, TokenStaking and claim vault, plus the reserve hook, WETH-leg SE `0x999DaE02D22E5FEe1c4508430D5196d31d631009` and DTF custody leg `0x2E9C1F705aB967c5Af59249203d7495bDabb223b`. Beneficiaries receive look-through attribution instead of a second credit for their custodian.

Creator/deployer/fee-role observations remained flagged for review rather than being silently removed. The historical ledger has four deferred-role account/product rows. Role classification is not itself final approval or rejection of a documented personal contribution.

### 6.2 Weighted nominal look-through arithmetic

These are the historical exposure checks, not the current historical-contribution-to-new-DETF conversion:

```text
direct DETF exposure = liquid DETF raw balance
direct sDETF exposure = reconstructed receipt raw balance

SY exposure =
    floor(SY_raw * 73604571731 / 66535753862)

legacy allocated SY =
    floor(weight_raw * 35589506697 / 19712889616977499499766803)
legacy exposure =
    floor(legacy_allocated_SY * 73604571731 / 66535753862)

funded NFT exposure =
    floor(remaining_snapshot_gons / 903962246886315724026911557873968023)
```

For each pre-incident funded NFT, the collector matched `BondPurchased` to its funding `Staked` event in the same transaction, using matching principal and consuming each match once. For each claim it matched the actual sDETF transfer by transaction, recipient and principal-plus-reward amount, then subtracted that amount multiplied by the index at the transfer's event position. The starting index was `10^36`. Do not use today's index for an earlier claim.

The 41 NFT positions reconcile to exactly `208200941171774511655236409911455698947144975844` custody gons. Dividing per NFT leaves 20 raw sDETF units relative to dividing the aggregate custody balance.

The saved total-supply check is:

```text
2237832428068 attributed weighted exposure
+ 2702841305735 reserve-held DETF
+ 100 sDETF-account rounding
+ 20 NFT-position rounding
+ 100 SY/legacy look-through rounding
+ 3 funded-staking backing surplus
= 4940673734026 total DETF supply
```

Amounts here are nine-decimal DETF-equivalent raw units. The 40 raw SY units left by the legacy-weight allocation are already represented in the SY/legacy look-through residual; do not add them again as DETF. Earlier CP positions have no invented common DETF-equivalent or ETH value.

### 6.3 Held-exclusion construction

The November 8 correction computed a conservative lower bound on the snapshot exposure still represented by live holdings:

| Source | Computation |
| --- | --- |
| Liquid DETF / SY | `min(current_balance, max(0, snapshot_balance - all_post_incident_outgoing))`; ignore self-transfers; convert SY at the snapshot backing ratio |
| sDETF | Subtract outgoing gons at each transfer's preceding staking index from snapshot gons; clamp at zero; divide at the snapshot index |
| Legacy weight | Retain the remaining original weight, capped by snapshot weight; apply the two-stage SY look-through |
| Funded NFT | Match the exact token ID; subtract post-incident claim gons from its snapshot gons; burned NFTs have zero remaining NFT overlap |
| Earlier CP | Preserve observed holdings and purchase records, but leave incomparable value fields unknown |

Each weighted position partitions into `held_exclusion_detf_raw` and `unresolved_snapshot_remainder_detf_raw`. The totals are `1674947599807` held and `562884828261` unresolved, summing to `2237832428068`. Of 331 weighted snapshot accounts, 249 are fully excluded as held and 82 retain unresolved quantities.

These bounds are not FIFO/LIFO attribution and do not implement the current proportional contribution-history rule for mixed fungible balances. A zero overlap does not prove no remaining holding, and the unresolved remainder is not an approved loss or allocation.

### 6.4 Recoveries, conversions and account assembly

The collector identified 69 post-incident DTF outputs totalling `59027441289824656686224552` raw DTF. It linked external DETF inputs in the same transactions and classified the rows as `detf_exchange_output`. Every row retains `deduct_from_R=false` until its economic attribution is established.

Transaction-level input totals must not be assigned in full to every output recipient. Later purchases, transferred holdings and redirected payouts can make a received DTF output unrelated to that recipient's original snapshot exposure.

The 250 explicit conversions are seven bond-to-sDETF claims, 18 legacy-weight-to-SY claims, 138 DETF-to-sDETF stakes and 87 sDETF-to-DETF unstakes. SY flows and other transfers also remain in S011, but this decoded subset is not a claim that every route has been reconstructed.

The account builder grouped positions and recoveries by `(product, account)`, linked source records and marked all accounts unapproved/non-issuable. The held-exclusion revision replaced the older `K_eth` field with `H_eth` and added held/custody links. It deliberately left `V_eth`, `H_eth`, `R_eth`, `E_eth` and `new_detf_bond_allocation_raw` empty.

The initial temporary research narrative called the November 3 exchange a burn. The durable ledger corrected this: transaction `0x00565ab940ab97deaf111d5dfe56ad6441fb3a1b5c93b4efde9d3c037fe1a33d` moved DETF through the diamond into the reserve hook; its transaction-level DETF burn field is zero. Use the corrected durable record, not the earlier wording.

## 7. Bond-NFT contribution configuration: concrete handoff

### 7.1 Weighted purchase join

The original ETH/DTF contribution is not available from S008's principal field alone. A future normalizer should:

1. Read each S008 row's `token_id`, `purchase_tx` and `purchase_recipient`; identify its weighted generation from the source dataset, not a nonexistent generation column.
2. Bind the row to weighted NFT contract `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E`.
3. Join S011 by `tx = purchase_tx`; select DTF/WETH transfers into the weighted DETF.
4. Verify payer and transaction purpose. Distinguish direct contribution from intermediate routed assets, settlement, refunds or unrelated transfers. Match S006's `category=bond`, token ID and transaction for pre-incident DTF purchases.
5. Retain separate original DTF and ETH-equivalent WETH raw inputs and exact source event IDs. Preserve that the observed input asset was WETH; native ETH handling remains a separate script/runtime concern.
6. Link principal/claim records separately. Do not substitute original principal, current principal or snapshot DETF-equivalent exposure for original contribution quantities.

This review found input-transfer matches for **all 43 S008 purchase transactions**, with input payers matching the recorded purchase recipient. This is a local evidence join, not an approval of all 43 NFTs or a fresh validation of their live state.

| Weighted NFT | Observed original DTF raw input | Observed WETH raw input | Evidence note |
| --- | ---: | ---: | --- |
| 3 | `362893857600000000000` | `999999000000000` | Same purchase transaction has both direct inputs |
| 4 | `0` | `30000000000000000` | WETH-only purchase |
| 44 | `1000000000000000000000` | `0` | Post-incident purchase; not a pre-incident snapshot position |
| 45 | `100000000000000000000000` | `0` | Post-incident purchase; not a pre-incident snapshot position |

Example event locators:

- NFT 3 purchase transaction `0x140c83d7c5a5170424fe13788194f21d1f30694bc166134ae486681a1fa3c624`: WETH log 6, DTF log 8.
- NFT 4 purchase transaction `0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe`: WETH log 211.

There are 41 pre-incident purchases, IDs 3-43, and two post-incident purchases, IDs 44-45. The later inventory also contains 41 weighted NFTs, but it is **not the same set**: IDs 25 and 42 are absent/recorded with zero current owner, while IDs 44 and 45 are present. Do not infer membership from equal row counts.

### 7.2 Earlier CP purchase join

S009 supplies `token_id`, `purchase_tx`, `original_lp_shares_raw`, `direct_dtf_paid_raw`, `direct_weth_paid_raw` and `routed_dtf_received_by_detf_raw`. Bind its IDs to earlier NFT contract `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`.

For example, CP NFT 3 records `2000000000000000000` raw WETH and zero direct DTF, while `1778859964387451305574664` raw DTF was received through the routed exchange. That DTF is not a second user contribution. CP NFT 9 similarly records `100000000000000` raw WETH and routed DTF separately.

Those sixteen purchase records came from inspected transaction receipts. The normalized S011 file does not preserve the older receipts. Refetch and archive them when building a fresh independently reproducible pipeline, using S009's transaction hashes. Preserve the historical event decoder or verified ABI provenance; the older `NewLock` LP model must not be decoded as the newer funded-principal model.

### 7.3 Data to retain for the future script

This is a data-preparation checklist, not a deployed ABI:

| Dataset | Configuration key | Data and provenance to preserve |
| --- | --- | --- |
| Independent compensation allocations | Recipient address | Reconciled eligible ETH/DTF contribution components; disjoint source exposure links; recipient/role review; full replacement configuration value; issuance/checkpoint reconciliation |
| Bond-NFT migration credit configuration | Chain + source NFT contract + token ID | Original ETH/DTF purchase contributions; purchase transaction/logs; source generation/model; original principal or LP basis needed for source-specific attribution; configuration revision |
| Fungible/wrapper migration credit configuration | Source identity plus the plan's ownership/accounting representation | Historical contribution components, balance units, wrapper conversions, proportional transfer/surrender attribution and consumed-credit accounting |
| Execution journal | Target deployment + configuration key/revision | Input dataset fingerprint; desired full value; transaction/receipt; confirmed on-chain value; actual issuance/consumption recorded separately |

The independent allocation on-chain key is the recipient address, even though the historical ledger key includes the product. Consolidation must retain disjoint per-source evidence underneath that aggregate. NFT configuration remains asset-specific, not permanently bound to the original buyer or the holder observed on November 8.

Keep configured historical purchase amounts separate from execution-time remaining principal, previously claimed principal and accrued unclaimed rewards. Under r20, those execution-time balances do not scale the mint input. The original ETH/DTF contribution is quoted with the existing user-mint preview against the post-funding reserve snapshot. Frozen `current_owner` and claim totals are observations to refresh, not constants to upload as permanently current.

## 8. Historical policy fields that must not control the new scripts

The current PRD takes precedence over the November 8 policy revision `held-assets-no-upfront-credit-20261108`. Preserve the old artifacts and their hashes; transform their evidence into a new versioned configuration dataset rather than silently editing their meaning.

| Historical text/field | Treatment under the current PRD |
| --- | --- |
| `E = max(0, V - H - R)` and proportional allocation of a fixed `N` | Historical proposal, not the current conversion formula. Use the original verified ETH/DTF contribution and the existing user-mint preview against the post-funding reserve snapshot. Do not use the retired linear output rates. |
| `V_eth`, `H_eth`, `R_eth`, `E_eth` blank fields | Remain unknown historical fields. Do not fill them merely to satisfy an obsolete allocation formula. |
| No credit after depositing held assets; `no_restore_on_deposit`; `held_exclusion_survives_deposit` | Held assets still do not receive independent compensation allocations, but actual surrender now earns separately calculated migration credit. The old fields cannot disable that path. |
| `upfront_bond_credit_for_this_holding_raw=0` | Does not mean zero surrender-triggered migration credit. Loading configuration itself still awards no bond. |
| Future harvest use "not decided" | Superseded: recovered assets are donated into the new DETF under the PRD; no second personal entitlement or ordinary bond for harvested DETF. |
| Return/release contemplated in custody notes | Superseded: successful surrender is final under MIG-R35. |
| Linear new-bond principal vesting | Superseded: full 90-day lock from actual creation. |
| Configuration amendments limited to unconsumed definitions | Superseded: Stage 1 permits correction of both configuration types; Stage 2 removes all configuration/amendment authority. |
| Reward claims available while new-money deposits are closed | Superseded: new-instance rewards cannot be claimed before activation. Legacy harvesting into recovery custody remains distinct. |
| Fee-recipient migration administration | Superseded: the current proxy owner configured through Crane Ownable is the migration administrator. |
| `issuable=false`, `entitlement_status=not_approved` | Still accurate for this saved dataset. The PRD settles behavior; it does not approve these rows as final awards. |

Interpret `exceptions.csv` in the same way:

- **V1/V2:** the historical valuation proposal is superseded. Unit/source reconciliation and capture of the post-funding reserve snapshot remain necessary. Do not reinstate a pre-exploit ETH-loss valuation or the retired linear contribution prices.
- **H1/H3:** preserve separation of held assets from independent compensation, but replace the old denial of surrender credit and undecided harvest destination with the PRD's rules.
- **A1:** actual funding and operational amounts still require verification; a fixed proportional `N` allocation is not the adopted rule.
- **R1/R2, C1/C2/C3, H2, D1:** attribution, coverage, receipt-accounting and stale-cutoff evidence gaps remain real.
- **P1/P2:** retain role and cohort observations for recipient/source reconciliation. They are not automatic exclusions from every migration path and cannot override the PRD's transfer/surrender rules.

No report or CSV declaring an old policy "fixed" overrides the later explicit requirements.

## 9. Reproduction and preparation sequence

### 9.1 Offline reconstruction from the saved bundle

1. Read the current PRD and this report; retain their revisions/fingerprints alongside the derived dataset.
2. Resolve every S001-S015 path from `sources.json` and every output path from `manifest.json`. Verify SHA-256 and byte count before parsing. Report mismatches; do not rewrite the frozen manifests to hide them.
3. Parse raw integers as exact integers and preserve empty/unknown fields. Normalize address case for joins, retaining source identity.
4. Reconstruct the position/look-through calculations in section 6 and compare to `reconciliation.json`. Validate source keys, duplicate event IDs and position/account joins.
5. Recompute held lower bounds from S011/S014/S015 and compare the saved partition. Keep this historical diagnostic separate from the new proportional contribution-history accounting.
6. Build the NFT purchase joins in section 7 and classify contribution versus intermediate conversion. Preserve every source locator.
7. Reconcile independent compensation exposure separately from holdings awaiting surrender. Do not allocate the unresolved nominal remainder or an entire gross-purchase column automatically.
8. Produce reviewable configuration inputs under the current PRD with unresolved records explicitly held out. No current saved file is an approved loader input.

### 9.2 Refresh needed before actual configuration

1. Pin a new block number/hash and record per-source query coverage. Keep the original bundle intact.
2. Refresh transfers, current NFT ownership, burns, claims, staking indices and relevant economic recoveries after block `108944663`.
3. Complete missing WETH/native recovery coverage and archive older CP purchase receipts. A successful receipt fetch or balance read must be distinguished from a failed/unavailable one.
4. Resolve the older receipt supply discrepancy and missing acquisition histories. Reconstruct proportional historical contribution attribution for fungible holdings and wrappers rather than reusing same-wallet held lower bounds as if they were that attribution.
5. Inventory every accepted PRD source category. The present eight position kinds do not prove complete standalone underlying-vault-token or fungible-LP coverage. Discover the actual accepted source addresses and add verified mappings; do not silently omit accepted categories.
6. Validate actual custody/claim routes on the supported generations, including nontransferable TokenStaking claims. An observed holding or old successful DTF exchange is not proof that every route works.
7. Verify funding, capture the post-funding reserve snapshot, evaluate original contributions with the existing mint preview, reconcile the two configuration datasets, and review the desired full configuration values.
8. During Stage 1, submit bounded idempotent full-value updates, retain transaction checkpoints and read back the effective configurations. Keep donation, configuration and actual issuance checkpoints distinct. Stage 1 is expected to take minutes to hours; reward claims remain closed.
9. Verify the completed configuration before the single activation transaction permanently removes both configuration/amendment surfaces and opens ordinary deposits and reward claims. Future surrender uses the frozen source configuration and the post-funding mint snapshot. It does not reprice the original contribution from live remaining principal or rewards.

These are preparation and implementation obligations, not authorization to run an upload, deploy a contract, issue compensation or change the PRD.

## 10. Verification performed for this report

On November 9, this review loaded the complete local files rather than relying on truncated previews:

- Verified all **36 recorded SHA-256 and byte-count entries** across `sources.json` and `manifest.json`, covering **27 unique files**. All matched.
- Recounted all 17 recovery CSVs listed in section 5.
- Recomputed weighted nominal exposure `2237832428068`, held exclusion `1674947599807`, unresolved remainder `562884828261`, and observed DTF output sum `59027441289824656686224552`.
- Confirmed S012 contains 41 funding and 16 pre-incident claim-conversion records; counted seven later claim proofs and 1,077 all-period index observations.
- Confirmed unique keys in the account, position, held-exclusion, inventory, recovery, conversion and normalized-transfer tables.
- Confirmed zero issuable account rows.
- Matched all 43 weighted purchase transactions to saved DTF/WETH inbound transfers and checked payer equality with S008's purchase recipient.
- Distinguished the 41 snapshot NFTs from the different set of 41 later inventory NFTs.

These checks establish file integrity, selected arithmetic consistency and join coverage. They do not independently prove every original RPC observation, complete missing cash-flow coverage, approve a beneficiary, validate a deployed migration route, or calculate final compensation.

No existing CSV, historical policy document, manifest or PRD was changed to produce this report. No build/test suite, deployment or live RPC refresh was run.

## 11. Optional original-session audit trail

The original acquisition and ledger-building session is `01a1b2e8-bdd5-77a2-b519-ddeb2a1f8df8`, stored locally at:

```text
~/.omo/agent/sessions/--Users-cyotee-Projects-indexedex--/
2026-11-06T22-09-19-829Z_01a1b2e8-bdd5-77a2-b519-ddeb2a1f8df8.jsonl
```

The session started on November 6, but the ledger work occurred on November 8. A search restricted to sessions created on November 8 can miss it. Record IDs are more useful than relying on a temporary export directory.

| Record ID | Original JSONL line | Evidence inspected |
| --- | ---: | --- |
| `de1ba210` | 11044 | Pinning the cutoff block |
| `a645998a` | 11050 | Bounded log ranges and recursive splitting on result-limit errors |
| `6adff16b` | 11052 | Main contract history acquisition |
| `5bb61348` | 11106 | Infrastructure exclusions and cohort deduplication |
| `e6dc7cf3` | 11188 | Registry discovery |
| `e5e27050` | 11220 | Historical LP-bond ABI lookup at `b9e074cf^` |
| `ff41b0a2` | 11226 | Earlier purchase receipts and rebasing-receipt balance observations |
| `d800d00b` | 11230 | Direct contribution extraction and candidate assembly |
| `6d7b1856` | 11242 | Temporary CSV export |
| `397d1a2b` | 11340 | Per-NFT gons reconstruction |
| `35692c3c` | 11343 | Positions, transfer normalization and conversion assembly |
| `a34ac32d` | 11345 | Correcting exchange-output classification and transaction-level input linkage |
| `d444489d` | 11347 | Account ledger, exception register and initial reconciliation |
| `b9e8b182` | 11352 | Durable artifact generation |
| `b25b1673` | 11386 | Held-exclusion formulas and later NFT claim matching |
| `0939df96` | 11388 | Custody inventory and account adjustment |
| `d74f2cfe` / `71134c37` | 11391 / 11393 | Applying the held-exclusion revision and updating manifests |

This trail is optional audit evidence, not a runtime dependency. The future scripts should operate from versioned repository inputs, archived chain evidence and explicit deployment configuration, with the transformations and boundaries above implemented and tested.
