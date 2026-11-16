# Original-wallet source category matrix

Date: 2026-11-11. **AdversarialVerify: confirmed for evidence reconciliation
only.** See `report.md` for authority, absolute E/N/R/M/O roots, historical pin
H, verification method and finite H1-H8 handoff. No row asserts all-category
support, current r3 runtime success or an approved compensation amount.

## 1. Identities, originals and live units

The 13 provenance category groups expand to 16 rows: two liquids, two NFTs,
two receipts, SY, weights, claim-vault rights, three SEs, two LPs, ETH and WETH.
All source contracts are chain 4663. Shared diamond proxy runtime is
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`;
it does not establish common facets or ABI. Producer identity tables retain
facet hashes and archive match qualifications; the direct source/result
locators below identify the narrower admitted methods.

Every compensated row requires approved original wallet, source/claim and
economic-origin identity, original ETH/DTF components with explicit knownness,
source-native original eligible units, evidence/configuration identity and
once-computed frozen C0. Current source state supplies only actual remaining
units/control. Missing original configuration rejects before custody,
consumption or issuance; unknown is not zero.

| Row / required category | Fixed source identity | Native eligible basis and authoritative remaining state | Original-record input still needed / limit |
| --- | --- | --- | --- |
| W-L liquid weighted DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` (WD) | 9-decimal token q; exact balance debit/receipt, capped by configured remaining Q | Original qualifying acquisition and WD quantity/component allocation, not all present liquid balance |
| E-L liquid earlier DETF | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` (ED) | 18-decimal token q; not weighted 9-decimal units | Six observed holdings have no approved original quantity/cost basis; no borrowing whole NFT purchase inputs for a liquid balance |
| W-N fixed-principal NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | `positionOf` P0/Pc in native 9-decimal principal; remaining P0-Pc, rewards/gons excluded | Original qualifying wallet and purchase inputs/P0. 43 joins exist, not 43 approved awards; IDs44/45 are postincident fixtures |
| E-N LP-lock NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` (EN) | `getPosition.originalShares` equals purchased S0>0; full live fraction, not effectiveShares or physical LP | 16 purchased IDs3-18/receipts provide original joins; wallet must be explicitly bound. Reward claims do not reduce S0 |
| W-R weighted sDETF | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` (WS) | 9-decimal display; canonical gons; transfer qNative*k at synchronized divisor k | Exact eligible original receipt/gon denominator and principal/reward mapping to Q/C, not a present-balance award |
| E-R earlier receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01` (ER) | 18-decimal display; internal shares, external shares=floor(internal/1e9); moved internal=floor(display*1e27/rate) | Original eligible share denominator/contributions and treatment of sub-external-share fractions. Floored recipient delta can carry old fractions; not exact attribution |
| W-Y weighted SY | `0xB55604CF4dcdABB362078e106D20F98512391EdF` (WY) | 9-decimal static shares; WS backing gons are the same economic claim | Original qualifying SY shares/components. Live wrapper exchange rate is recovery state, not C0 |
| T raw TokenStaking rights | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` | 18-decimal weight; balance/supply and actual claim consumption, not ERC20 units | Original wallet/claim/weight/components; exact same-origin claimed-SY quantity and remaining credit needed for any later SY route |
| C claim-vault rights / direct shares | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` | Direct ERC20 vault shares have **19 decimals**, SY output 9. Indirect claimant owns weight right, not infrastructure's shares | Approved direct-share original exposure/unit/C0 rows absent. 74 related rows are not a vault-share user census; fixture holder is TokenStaking |
| E-S earlier underlying SE | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` (ES) | 18-decimal shares, exact measured q; not DTF or LP | Original user acquisition/shares/components; fixture holder is EL. Zero standalone rows are not absence proof |
| W-SW weighted WETH SE | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` (WE) | 18-decimal shares; not DE units | Original user share acquisition/components; fixture holder is WL, not an authorized user |
| W-SD weighted DTF-custody SE | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` (DE) | **28-decimal** ERC4626 shares, asset DTF at 18 decimals | Original direct shares/components; fixture holder is WL. Demonstrated scale is not a frozen compensation price |
| E-P earlier fungible LP | `0x923877336b14662cFb5B3A60b14e7d716d54A888` (EL) | 18-decimal physical LP tokens, not EN original accounting shares | Original direct LP acquisition/native quantity/components; fixture holder is EN escrow |
| W-P weighted fungible LP | `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` (WL) | 18-decimal fungible LP, not W-N principal or WE/DE shares | Original qualifying direct LP quantity/components; fixture is fee collector, not proven user exposure |
| ETH recorded native exposure | Chain-4663 native currency, no legacy token address | Wei, 18 decimals; today's ETH balance is not remaining old claim | Original native amounts/source rights remain unknown; no old native claim-consumption method established |
| WETH recorded exposure | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` | 18-decimal token. Joined purchase input is not a separate remaining WETH entitlement | 27 partial inbound rows and NFT purchase joins, not complete standalone original-wallet units/C0 |

W-N credit is `floor(C0*(P0-Pc)/P0)` and whole identity consumption. E-N
uses full original-share credit for an eligible live lock and whole identity
consumption. All other compensated partial paths need proved source-native
q and the remaining-record rule `q==Q ? C : floor(C*q/Q)`. This arithmetic is
not admitted for a row whose original denominator/measurement is unresolved.

## 2. Exact method schemas, caller and custody

Notation: `MIG` is the Migration proxy/fixed custodian. `EX` means
`exchangeIn(address,uint256,address,uint256,address,bool,uint256)`,
selector `0xd02d3063`. `SR` means
`redeem(address,uint256,address,uint256,bool)`, selector `0x769f8e5d`.
Successful legacy WD/WS/ED source EX schemas are **one uint256**, not current
multiword exchange interfaces. A reverting call does not authenticate its
success return layout.

| Rows | Authentic surrender / preparation operation | Exact caller, approval and measurement boundary |
| --- | --- | --- |
| W-L, E-L, W-Y, C direct, E-S, W-SW, W-SD, E-P, W-P | ERC20 `transferFrom(wallet,MIG,q)`, `0x23b872dd -> bool`; `approve(address,uint256)`, `0x095ea7b3 -> bool`; `balanceOf(address)`, `0x70a08231 -> uint256` | Original wallet calls MIG, approves MIG. Require exact token/share debit and custody increase; source identities/units remain separate. Historical direct E-L transfer is not an integrated approved pull |
| W-R | WS same ERC20 signatures, receipt facet; `gonsOf(address)`, `0x79a67521 -> uint256`; `stakingState()`, `0xe082f1d4 -> seven uint256` | Allowance native display units. Source synchronizes; require exact transferred gons=qNative*k, with k from operation state. Tuple: totalGons,gonsPerUnit,accountedBacking,allocationDust,stakingDust,feeWeight,creatorWeight |
| E-R | ER same ERC20 signatures with rebasing facet; `sharesOf(address)`, `0xf5eb42dc -> uint256 external shares`; `redemptionRate()`, `0x540385a3 -> uint256` | Approval/input are displayed units; internal share movement differs. Read shares and balances; prove attributed eligible receipt units/floor carries before credit. Do not require display delta equal calldata |
| W-N | `ownerOf(uint256)`, `0x6352211e -> address`; `positionOf(uint256)`, `0x46f96023 -> five uint256`; `safeTransferFrom(address,address,uint256)`, `0x42842e0e -> no return` | Position tuple principal,claimedPrincipal,stakingGons,startTimestamp,vestingDuration. Original wallet=caller=live owner, approval to MIG. Receiver executes before owner update; validate expected callback then post-owner and full position fingerprint |
| E-N | Same owner/approval/safe transfer; `getPosition(uint256)`, `0xeb02c301 -> five uint256`; `originalSharesOf(uint256)`, `0x0f3767df -> uint256` | Tuple originalShares,effectiveShares,bonusMultiplier,unlockTime,rewardDebt. Same wallet/receiver boundary; post-check original shares only, not immutable reward debt. Locked custody permitted |
| T | `reassign(address,uint256)`, `0xcc447fba -> no return`; `withdrawClaim(uint256)`, `0xa224dcb7 -> uint256 SY` | Both debit source caller. Ordinary MIG cannot pull wallet weight. No recipient callback. In Wrapped phase holder may claim to itself before later SY surrender; that earlier transaction is not atomic with later credit/bond |
| C indirect | Weight holder uses T `withdrawClaim`; source redeems its own backing vault shares | No user approval over TokenStaking-owned shares is inferred. Do not credit weight and backing/SY again |
| ETH | No admitted old native surrender method | Fresh payable capital donation wraps exact value but creates no personal credit; do not invent a historical claim from payment |
| WETH | ERC20 signatures above for mechanics; current donation wrapping uses `deposit()`, `0xd0e30db0 -> no return` | NFT-backed WETH inputs use NFT surrender, not repayment of WETH. No separate compensated WETH path admitted without a distinct original record |

NFT legacy approval is `approve(address,uint256)`, `0x095ea7b3`, or
`setApprovalForAll(address,bool)`, `0xa22cb465`, with no return. The same
selector as ERC20 approve does not make the return schema interchangeable.
Safe receiver returns `0x150b7a02`; MIG grants no user-selected legacy operator.
For every implemented compensated path, failed custody/unit checks or fresh
bond funding must revert the entire surrender's effects.

## 3. Recovery, captured results and retained blockers

Every admitted output goes to MIG; owner-only selected recovery and eventual
new-DETF donation do not mint personal credit. Partial/staged recovery uses
booked inventory, never raw balances. A failed batch rolls back its own
selected stages, not earlier committed transactions.

| Row | Exact recovery/return and captured evidence | Reconciled disposition / finite handoff |
| --- | --- | --- |
| W-L | WD EX(WD,q,DTF,min,MIG,false,deadline) -> uint256. Exact temporary WD approval to WD, cleared. `E/verification/weighted-replay.results.json:49447`; real NFT recovery reuses conversion | Usable custody/recovery primitive. Missing original per-record quantities/components and new fungible pull/consumption admission: H3-H4 |
| E-L | ED EX(ED,q,DTF,min,MIG,false,deadline) -> uint256 in archived source. `E/verification/cp-replay.json` liquid custody tx `0xb93cca719623ffb0014880437a5eabe5def921684a8d19fa3d6860e24b676f46` transfers 1e18 | Usable transfer; original mapping/integration missing. **ED liquidation unproved**, not a new disabled result: H3,H6 |
| W-N | NFT `claimBond(id,MIG)`, `0x084c59ae -> (principal,rewards)`; `claimPrincipal`, `0xf400c743 -> uint256`; `claimRewards`, `0x6c7b69cb -> uint256`. Output WS then W-R/W-L | Usable bounded NFT custody/recovery under old eligibility. ID32 fraction trace `N/verification/fork-independent.log:20099`; original-wallet binding still H1-H2. Legacy approved-operator redirection adverse result retained |
| E-N | EN `claimRewards(id,MIG) -> uint256 ED`. Mature parent ED `sellPositionToDetfNft(id,MIG)`, `0x6b7d927e -> uint256 retired original shares`; child `sellPositionToDetfNft(id,MIG,MIG)`, `0x2115e3dc -> (principalShares,rewardsClaimed)` is parent-owner-only | Accepted claim-and-hold / sale-and-hold. Sale returns **not** receipt output: measure ER external-share delta. ID4 retires 2281854312954086546 and receives 1967558883021387942 external shares; `R/correction-verification/fork-independent.log:68752`. H1-H2; liquidation limits below remain |
| W-R | WS EX(WS,q,WD,q,MIG,false,deadline) -> uint256; no receipt allowance for own unstake. Partial debit q*k, full-account retirement can burn fractional gons; preserve all unbooked gons | Usable transfer/unstake; approved original gon/credit mapping missing. Captured 38283506 WS and 33516514845772316453173092124488164768268274 gons; corrected NFT growth trace `R/correction-verification/fork-independent.log:66439`. H3-H4 |
| E-R | ER `redeem(display,MIG,false)`, `0x5236be40 -> uint256 pair-token output` (DTF despite `wethOut` name); ED `redeemClaim(display,ED,min,MIG,deadline)`, `0xbfe55606 -> uint256 ED` is different | Both actual exits reach disabled ES; original share mapping/fraction proof also missing. CP receipt input 1e18 receives display 999999999999999999; direct transfer PASS is not precise credited pull. H3,H6, no liquidation PASS |
| W-Y | WY SR(MIG,q,WS,min,false) -> uint256; burns caller's own SY, no share approval for redemption. Then W-R/W-L | Actual 8094 SY -> 9245 WS -> 9245 WD -> 52221256856930805 DTF, `E/verification/weighted-replay.results.json:50241-50958`. Usable primitive; original share mapping/new proxy stages H3,H5 |
| T | Custodian's own `withdrawClaim(q)` consumes weight/supply and redeems backing to SY. Historical `other-metered.json:8416-8715`: 64890781291192882058375 weight -> 117153341 SY, weight zero | Holder claim/reassignment usable; **direct ordinary-MIG atomic raw-weight surrender blocked**. Forwarding error `0x936d426d`; no callback, no approved pull. Claimed-SY same-origin unit/C mapping and integration also absent; no disguised two-transaction issuance |
| C | `redeem(q,MIG,MIG)`, `0xba087652 -> uint256 SY`, burns MIG-owned shares without allowance. `other-metered.json` claim-vault harvest tx `0xd03b842118e15cfc252766d7c8150d8e099818f3c326143a1d181d5e95748ed1` | Usable direct-share custody/redemption: 2769125838408621163 shares -> 276912584 SY. Missing original direct-user records and integration H3,H5; indirect rights retain T blocker |
| E-S | ES EX(ES,q,WETH-or-DTF,min,MIG,false,deadline) reverts. SR/ERC4626 redeem selectors unbound; no successful return decode inferred | Custody/outer rollback pass, actual **VaultDisabled(ES)**. Original user mapping absent; H3,H6, hold only |
| W-SW | WE SR or EX to WETH/DTF reverts; ERC4626 redeem selector unbound. `other-metered.json:10454-11076` | Mechanical custody/rollback pass; actual **VaultDisabled(WE)**. Original user mapping missing; H3,H6, hold only |
| W-SD | DE `redeem(q,MIG,MIG)`, `0xba087652 -> uint256 DTF`, asset DTF; own shares need no allowance. Actual tx `0xb9d405ac37e7aa22f544912461c9945bfeb8c858938bd4fdea7264674c5f0ba6` | Usable 28-decimal share custody and burn-to-DTF; not WE success. Missing original direct-user configuration and proxy composition H3,H5 |
| E-P | EL EX to ED/DTF -> `UnsupportedRoute`; native `withdrawSeShares(q,MIG,0,0,deadline)`, `0x84eb9bce -> NotOwner`. Current interface's candidate `(amountRaw,amountSe)` is **not** authenticated successful legacy return data | Mechanical custody/rollback pass. Owner ED, not EN/MIG; `ownerOnlyLiquidity` unbound. Native failed tx `0xef58704e0f466bc121512b940c5b31e13434c28f3581071ada88a53965565e0e`. Missing original mapping and source-authorized liquidation of this inventory; H3,H6 |
| W-P | WL EX/SR and native `exitProportional(q,MIG,minima,deadline)` `0x8b72d9e5`, `exitProportionalFlexible(q,MIG,flags,minima,deadline)` `0x94b74d12` -> `NotOwner`; no successful standalone output decode | Mechanical custody/rollback pass. Owner WD, `ownerOnlyLiquidity=true`; native failed tx `0xa10d7a7ee0f69cf886b6cbcf5f8eede817b7ea32beafa1048bf78182ac8c372f`. WD's protocol-managed LP burn does not recover arbitrary surrendered WL. H3,H6; hold only |
| ETH | No actual distinct old-native recovery established. Weighted admitted route ends in DTF | Missing original native source/amount/unit configuration; no new compensated native route or invented zero. Keep donation and original ETH quote component distinct |
| WETH | Original purchase joins retained; no admitted standalone WETH-to-native recovery execution | Recorded contribution inputs, incomplete standalone mapping. NFT inputs do not require WETH repayment; WE disable remains upstream. No second ETH/WETH award |

Direct result files for SE/LP routing and units are
`E/verification/other-metered.sources.json` identities, and for their
executions `other-metered.json` named cases. Native LP attempts are in
`native-replay.json` named native staged harvest cases. These results use
infrastructure holders where marked; no original-user authorization is
claimed from impersonating them.

Earlier mature close
`closeBondMature(uint256,uint256[],address,uint256)`, `0x7c212893 ->
uint256[]`, reaches disabled ES even for the wrong external holder.
`R/correction-verification/fork-independent.log:67372` retains this masked
authorization result. Earlier optional facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE` source archive remains HTTP
404; excluded selectors remain excluded. Neither limit invalidates the
separately admitted bounded claim/sale nor proves complete recovery.

## 4. Shared finite acceptance requirements

| Obligation | Applies to / precise future check |
| --- | --- |
| Original wallet + present config + actual surrender | All compensated rows; wrong current holder/operator, unconfigured wallet, wrong source/claim and absent original inputs reject before asset movement, credit consumption, supply or bond changes. Original wallet without control rejects too |
| No transfer ancestry | Ordinary transfer cannot move record/credit; transfer away/back needs no history proof or notification and cannot reset consumption |
| Units and partial credit | Separate every original quote and unit class. Exact final remainder takes remaining C; zero credit reverts; rewards/index growth do not create credit |
| Permanent execution facts | Configuration replacement, including wallet correction, cannot reopen a consumed origin or retroactively resize delivered bonds; canonical economic collision key remains wallet-independent |
| Fresh funded bond / rollback | One exact-backed bond to that wallet per successful operation, its own actual 90-day clock; callback, pull, unit, minimum and funding failures roll back that transaction |
| Activation / operator parity | H7 removes all new configuration selectors irreversibly, leaves surrender/queries/recovery. Wallet field must match typed operator schema/ABI/config hash; stale ancestry gate wording is not current evidence |
| Claims/wrappers/backing | No credit twice for parent NFT, claimed receipt, weight, vault backing, SY or independent compensation. Prior own-wallet claim preparation is not atomic raw-weight surrender |
| Recovery / held failures | Current Crane owner, finite fixed source calls/receivers, booked native/share/gon inventory only; preserved disabled/caller failures leave held assets. No source governance/role impersonation, arbitrary target/calldata or source substitution |
| Independent / donations | Independent compensation remains separate no-surrender Stage1 issuance of disjoint originals. Permissionless fresh ETH/WETH/capital donations need no personal entitlement and create none |

These are required future tests, not tests run here. Missing source/unit rows
remain explicit configuration or source-route limitations, not omitted
categories and not a demand for renewed ancestry research. Current code has
only the bounded wallet-less NFT surrender surface: this handoff is complete
as evidence, while original-wallet runtime support remains unverified.
