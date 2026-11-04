# Astra research response

## Identity

- Assigned member: Astra.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, provider/account route, and reasoning setting: not exposed.
- Actual Native ancestry and coordinator identity: not exposed.
- Run: `se-weir-adaptation-fidelity-20261031-01a18660`.
- Date: 2026-10-31.
- This is the independent original research contribution, not an advisory response or a council consensus.

## Question and targets

Does the full-spread PRD adapt WeirVaults to the tokenized Standard Exchange standard, or import PairToken design without authorization?

**Conclusion: the current PRD imports a different economic design, not merely the packaging needed to tokenize Weir.** Its explicit PairToken precedence rule imports issuance, compounding swaps, withdrawal planning, inventory treatment, limits, fees, genesis, and terminal behavior. Removing the word PairToken, or just removing two package arguments, would not restore the authorized basis.

The authorized baseline is one Weir-derived position and its assets behind one Standard Exchange share token, with the accepted exchange routes and recorded owner locks. It is neither a multi-vault Weir manager with a token bolted on nor a PairToken sibling. A useful PairToken improvement is still a proposed change until separately authorized.

The inventory below distinguishes:

1. Weir behavior, including its limitations.
2. The tokenized-standard adaptation and explicit owner locks.
3. PairToken carry-overs to remove.
4. PairToken aspects I recommend only through explicit authorization cases.

“Remove” means remove the requirement from this adaptation's specification, not delete existing code or rewrite either source product. No implementation is authorized.

## Evidence

### Sources actually read

These aliases identify repository-relative paths throughout this response.

| Alias | Source and coverage |
| --- | --- |
| B | `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/brief.md`, complete. |
| F | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, complete, revision `fullspread-se-prd-final-r2` with later locks. |
| W | `contracts/protocols/strategy/weir/WeirVaults.sol`, complete, including imports, public entry points, callback, internal accounting, swaps, and administration. |
| I | `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, complete, including WI-01 through WI-37 and AC01 through AC69. Behavioral requirements, not import-path tables, are the comparison basis. |
| L | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, complete, including the locked basis and all function decisions. |
| P | `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, complete. Used only to resolve the material requirements inherited by F and identify their PairToken-stage-one provenance, not as authority for this vault. |

The repository router and the native-council workflow, research, and evidence guidance were also read. No peer response, previous council original, implementation of PairToken, current hook implementation, or external source was read.

### Source observations

- **The precedence inversion is explicit.** F sections 1 and 2 call the vault a PairToken sibling, inherit economics by ID, and let P control unnamed disagreements. L's locked basis expressly rejects that inheritance. B repeats the owner's rejection. The newer basis controls this assessment.
- **Weir issues liquidity-based shares.** W `_deposit` sizes liquidity at the post-zap price with a two-unit cushion per candidate amount. Genesis reserves `MIN_SHARES = 1,000` in total shares without assigning them to an address; later issuance is `newLiquidity * totalShares / existingLiquidity`. Existing idle is not priced into issuance. See I WI-13/14 and F3.
- **Weir returns entry remainder to the payer.** W `deposit` refunds declared input minus `used`; `_deposit` sends positive settlement credits to the depositor. This is not PairToken's mandatory no-share contribution of zap remainder. Refunds and credits can be in both currencies. See I WI-12/15.
- **Weir accepts swap partial fills.** W `_balance` uses actual swap deltas, and `_withdraw` settles both final currency nets. `_swap` uses the global directional sqrt-price limits, without a consumption-equality check, configured size cap, or tick-movement cap. See I WI-19/20 and AC25.
- **Weir compound does not swap.** W `_compound` collects, takes the performance-fee cuts, sizes a paired addition from net fees plus recorded idle, adds if positive, and retains leftover idle. `_balance` is called by `_deposit`, not `_compound`. See I WI-21/22.
- **Weir performs maintenance before entry and exit.** W `unlockCallback` calls `_compound` before `_deposit` or `_withdraw`, inside the same ordinary unlock. Permissionless standalone compound is also native Weir behavior. There is no collection-only withdrawal alternative in W.
- **Weir's fee attribution differs.** Fees produced by the depositing caller's balancing swap can enter that depositor's subsequent add-liquidity settlement. Fees produced by an exit swap accrue to remaining liquidity. See I WI-15/23 and AC16/37. “Compound before deposit” does not mean all fees through mint are isolated for incumbents.
- **Weir distinguishes recorded idle from physical custody.** Direct transfers do not automatically become idle, shares, or preview value. W has no explicit vault `donate` function. A PoolManager donation is a different action that changes pool fee growth. See I WI-24.
- **Weir retains administration and fees.** W has owner-controlled treasury, performance fee, and deposit pause; fee defaults to 500 bps, capped at 1,000 bps. Withdrawals and compound are not paused. P's fee-free, operationally ownerless policy is not a consequence of ERC-20 tokenization.
- **The copied limits have specific, non-generic meanings.** P S1-OP-02 caps entry input relative to the vault's input-side reserve and separately limits the entry swap's tick displacement. P S1-OP-05 uses a different active-pool reserve estimate and a quarter-cap for compound swaps; the tick limit does not govern compound. Neither parameter is a trading-fee cap.
- **Several locks supersede inherited requirements but not all their copies.** F still carries a last-committed Basic Vault snapshot, raw-ETH route promises, SY filenames/acceptance inheritance, and a withdrawn rate-supply error in its advisory table. L locks current local-plus-deployed reserves, accepted ERC-20 faces, no SY, and no designated rate. Those contradictions must not become implementation choices.

### Evidence classes

The statements above are source observations. The dispositions and harm cases below are reasoned recommendations from those observations. Claimed runtime behavior in I is used as documented baseline characterization, not as a test executed by this member. No arithmetic, gas, deployed bytecode, dependency, live-chain, or hook integration result was independently reproduced.

## Assumptions

1. B and L's locked basis supersede F's PairToken inheritance rule. P's owner decisions were scoped to PairToken stage one; their presence in F does not transfer authorization.
2. The one-token, one-pool, one-position Standard Exchange adaptation and FS-OWN-01 through FS-OWN-10 remain authorized. Their expressly undecided details remain undecided.
3. A function-retention lock authorizes the function's stated purpose, not every algorithm, threshold, return tuple, error, or payable variant in P.
4. A standard interface determines its accepted route, asset representation, and return contract. It does not independently require geometric-mean genesis, zero performance fees, a swap during compound, or a reserve-denominated zap cap.
5. Shares should claim the accepted vault backing, including the owner-required sleeve and deliberately booked donations. This makes Weir's idle dilution material, but does not silently authorize a replacement issuance equation.
6. No independent pricing source is assumed. Entry caps and same-price accounting tests discussed below are not TWAP or fair-price defenses.
7. This is a static assessment of live files read in bounded chunks, not an atomic repository snapshot.

## Coverage

| Target area | Result |
| --- | --- |
| Entire F, sections 1 through 10, including all FS acceptance rows | Examined. The provenance error reaches package, economics, security, quotes, and tests. |
| Entire W | Examined. Both shared behavior and materially changed behavior are identified. |
| I behavioral requirements and characterization cases | Examined. In particular idle dilution, genesis, fee attribution, partial fills, native sync, guard coverage, and view limitations. |
| L locked basis and functions | Examined. Retention and omission decisions are preserved; conflicts are identified without voting locks away. |
| All inherited P requirement families and S1-A01 through S1-A70 | Examined for source identification. They are not adopted wholesale. |
| Seven specifically named items | Individually classified below, including getter versus policy and entry versus exit distinctions. |
| Other material carry-overs | Classified across issuance, fees, compound, lifecycle, pool domain, APIs, package shape, execution, inventory, views, governance, and acceptance. |
| Current standard interfaces, actual package code, factory implementation, hook consumers, and source dependencies | Not examined. References in F/P are not independent verification of those implementations. |
| Runtime, tests, builds, gas, deployment, license clearance | Not performed or claimed. |

## Conclusions

### 1. Classification rule

For a non-Weir requirement, the disposition is exactly **Remove**, **Authorization case**, or **Already authorized**. A row marked “Weir baseline” identifies behavior to adapt, not a fourth way to approve a PairToken change. “Both” means the two designs have a similarly named operation or purpose, not identical economics.

An authorization case is a recommendation to ask the owner for that particular change. Until approval, it is not part of the accepted baseline. Cases A1 through A10 below cover every unauthorised PairToken aspect I recommend retaining. A11 separately addresses a FullSpread addition whose caller-context authority is not established by an owner lock in the admitted record. Other PairToken details are removed rather than accepted by association.

### 2. The seven named items

| Item | Provenance and exact difference | Disposition |
| --- | --- | --- |
| `maxZapBps` policy / package argument | PairToken, not Weir. P S1-OP-02 uses it to cap a single-token input against the vault's input reserve. W can attempt a larger zap subject to available funds, protocol limits, and user minima. Its compound quarter-cap belongs to a separate PairToken swap algorithm. | **Authorization case A1** for an explicitly configured entry-size policy only. **Remove** the compound quarter-cap together with compound swaps. Do not call this a fee bound, infer a default, or treat its appearance in `PkgArgs` as approval. |
| `maxZapBps()` getter | PairToken query, not Weir or an accepted standard selector. L leaves it open and distinguishes getter from policy. | **Remove** the compulsory getter. If A1 is approved, config visibility can be decided separately; no admitted consumer proves this selector necessary. Removing the getter does not remove an approved policy. |
| `maxZapTickMove` policy / package argument | PairToken, not Weir. P measures absolute tick movement around the entry swap, not all maintenance or an external-price deviation. | **Authorization case A1** for that bounded entry domain. No number selected. It cannot be relabeled a manipulation defense or extended to compound by implication. |
| `maxZapTickMove()` getter | Same open getter question as above. | **Remove** the compulsory getter, independently of the policy decision. |
| `previewZapCredit` | PairToken-specific six-part accounting disclosure from S1-ACC-07/API-05. W has no such preview and returns entry credits/refunds rather than specifying uncredited zap donations. | **Remove** the required public selector and its PairToken `ZapCredit` disclosure contract. Accepted standard/bundle previews remain. If a new owner-approved credit model later needs additional disclosure, justify that API from its callers, not from P. |
| Booked no-share zap remainder `J_i` | PairToken S1-ACC-07/OP-02, not Weir entry behavior. Both have idle, but W's idle is retained maintenance inventory; unused deposit input and positive deposit credits go to the payer. Shared idle is not evidence for compulsory entrant donations. | **Remove** mandatory booking without credit. Keep deliberate `donate` separate. Weir-style payer ownership of unused entry inventory is the starting point; accepted scalar refund ABI alone cannot express an arbitrary second-currency refund. Resolve that route constraint explicitly, not by silently donating the residual. |
| `IncompleteConversion` on the selected entry half-swap | F FS-X04 is a FullSpread addition that tightens PairToken's entry behavior. Neither W nor P requires complete entry half-swap consumption; both account actual entry swap deltas. It is not an inherited PairToken requirement. | **Remove** this blanket entry rule and its compulsory error. A partly filled entry swap does not itself prove the entry cannot mint valid shares and return an allowed input refund. If a particular resulting remainder cannot fit an accepted route, reject that unsupported result for that reason; do not equate every partial fill with failure. |
| Full consumption on single-token exit | Both have a zap exit, but W can return two positive currencies after a partial swap; P requires complete unwanted-leg consumption or atomic revert. This is distinct from FS-X04's entry rule. | **Already authorized**, to the extent the accepted scalar route promises one chosen output. A successful scalar exit cannot pay an undeclared second token or donate the exiter's unsold allocation. The proportional bundle exit remains the separate two-token route under FS-OWN-09. No second-token-refund extension is assumed. |
| `donate(token, amount)` | PairToken explicit vault-book contribution, absent in W. W's passive transfers remain unassigned and PoolManager `donate` is not this function. | **Already authorized** by L Paired money / FS-OWN-09: add tokens to the vault book, mint no shares. Keep that purpose, with exact-receipt protection in A5. Positive-supply admission is separately proposed in A10. Payable raw-ETH variants, registry-disable policy, and arbitrary old-balance adoption do not follow from the lock. |
| `compound()` | Both, under materially different rules. W collects, charges its performance fee, adds paired liquidity without a swap, and keeps idle; P also ratio-swaps, applies DUST/quarter-cap rules, retains all fees, and performs final fee checkpoints. | **Already authorized** by FS-OWN-09, with Weir's collect/reinvest purpose and unchanged supply. **Remove** importing P's ratio swap, DUST, quarter-cap, fee-free policy, or fallback merely because `compound` is kept. Fee ownership corrections require A3; a withdrawal-only collection alternative requires A7. |

**Entry remainder is a real design boundary.** W may credit the payer in the other currency after its swap/add sequence. FS-OWN-08 gives scalar `(amountOut, amountRefunded)`, not a general basket of refunds. The owner has not authorized converting that limitation into a compulsory donation. The coordinator should identify the residual states representable by the accepted routes and bring the remaining policy choice to the owner. This report neither adds a refund selector nor promises that every Weir zap outcome fits a scalar exchange.

### 3. Other material economics and lifecycle carry-overs

| Item and locator | Comparison | Disposition |
| --- | --- | --- |
| PairToken sibling, ID inheritance, and P-wins precedence; F sections 1/2/5 | Contradicts the locked Weir basis. | **Remove**. Restate independently approved behavior in a later PRD revision; do not retain hidden normative imports. |
| One diamond, one full-range salt-zero position, one public share supply; F goal; P S1-ARCH-02 | Full-range position is Weir; one fungible supply per instance is the authorized adaptation of Weir's per-pool internal ledger. | **Already authorized** by B's target and FS-OWN-02/06. Remove multi-vault enumeration/per-pool transfer API as part of that adaptation, not because P omitted them. |
| Geometric-mean genesis; P S1-ACC-02 | Replaces Weir's liquidity-denominated first issuance. No tokenization requirement demands `sqrt(a0*a1)`. | **Remove**. |
| Mandatory paired-only bootstrap and empty-supply zap rejection; P S1-OP-01/02, API-02 | Weir can create a vault and zap on first deposit where the initialized pool has usable external liquidity and the resulting addition satisfies its minimum. | **Remove** the unconditional PairToken bootstrap restriction. A given empty pool may make a zap impossible, but that is not the same as forbidding every funded first zap. |
| Removal of the 1,000-share genesis reserve; P S1-X02, F FS-PKG-02/A05 | W includes 1,000 unassigned shares permanently in total shares. P removes its own dead-share policy. These are different ledger representations, and P's owner choice does not authorize dropping W's reserve. | **Remove** the blanket zero-reserve requirement. ERC-20 supply representation of W's unassigned reserve needs an explicit adaptation decision; retaining an inconsistent unassigned amount in canonical ERC-20 supply is not a solution. Do not silently pick a burn address or delete the economic reserve. |
| Positive-supply basket pricing and attributable credit; P S1-ACC-01/02/07 | Replaces W's `newL*T/L` issuance, which excludes existing idle. The locked sleeve and explicit donation make that dilution more consequential. | **Authorization case A2** for including incumbent idle/fees and same-price attributable growth in issuance. This is a major accounting change, not packaging. The exact P formula is not retained wholesale: its zap `C_i=G_i` plus uncredited `J_i` policy is rejected above. |
| Round-trip addition-cost versus removable-principal protection; P S1-ACC-07 | W prices shares by liquidity added with a two-unit sizing cushion; P measures removable-principal growth and rejects zero credit. | **Authorization case A2** for the narrowly stated non-dilution property. Do not silently replace W's sizing cushion, nested floors, or liquidity algorithm with P's affordable-add engine. |
| Caller-only entry addition and fee ownership checkpoints; P S1-ACC-01/06, S1-X15/16 | W already funds entry from depositor inputs, but its add caller delta can offset them with incumbent fees generated by the same zap. | **Authorization case A3** for preserving those fees for incumbent holders and separating principal from fees. No permission for a compound swap follows. |
| Removal of all performance fees, treasury routing, fee settings; P S1-D03/X04; F FS-PKG-02 | W charges a performance fee and exposes owner-controlled settings. ERC-20 and SE do not require fee-free reinvestment. | **Remove** the imported no-performance-fee requirement. The owner must separately decide whether Weir's fee policy or a replacement applies. Do not import PairToken protocol fees or its 10-bps redemption retention either; W charges neither entry nor withdrawal fees. |
| Ratio-swap compounding, DUST=1,000 raw units, leftover tie direction, quarter-cap, active-liquidity branches; P S1-OP-05 | All arise from a compound swap absent in W. W can reinvest any positive cushioned paired liquidity and otherwise keep idle. | **Remove** as a group. Removing them materially reduces the projection and withdrawal-maintenance problem. |
| Collection-only withdrawal fallback and mode/reason machinery; P S1-EXIT-01 | W always attempts compound first and can fail there. L's removal of the public mode query does not approve an internal fallback. | **Authorization case A7** for a narrow, preflight-selected collection-only alternative. **Remove** the copied reason table, enums/event obligation, and swap-related predicates until re-derived for the selected Weir-derived compound. |
| Proportional liquidity/idle withdrawal; P S1-ACC-03 | Both use proportional liquidity and idle claims. W is already the source for this behavior. | **Already authorized** by FS-OWN-09's proportional bundle exit. Retain Weir basis, with scalar conversion constrained by the accepted route. |
| Zero-total-payout burn rejection; P S1-ACC-03, SEC-02 | W can burn a tiny share quantity for zero outputs if both minima are zero. | **Authorization case A8**. A one-sided positive payout remains valid; do not require both currencies positive. |
| True last-share full sweep, zero-supply reset, and rebootstrap; P S1-ACC-05/X10 | P's no-reserve policy permits a state W's permanent genesis reserve prevents after ordinary initialization. | **Remove** as inherited behavior. If the owner later removes the reserve, terminal ownership and restart need a new explicit decision; do not import the whole lifecycle preemptively. |
| Reject positive supply with both backing reserves zero; P S1-X14/ACC-02 | An explicit invalid-accounting rejection is P's replacement for its old geometric fallback. W has a different liquidity formula/failure domain. | **Authorization case A2** for fail-closed issuance under the proposed new accounting. The exact error is not a requirement just because P has it. |
| Canonical clamped principal math, exact receipt reconciliation; P S1-X13/ACC-01 | W's liquidity library already has below/inside/above-range branches. Clamping is not a newly borrowed economic strategy. | **Already authorized** as truthful position/reserve reporting under FS-OWN-06/07. Preserve Weir arithmetic unless a specifically approved deviation requires otherwise. |
| Full-precision substitutions, safe casts, and changed arithmetic errors throughout; P S1-ACC-01/OBS-01 | W's checked products, direct casts, and nested floors are observable source behavior; I expressly distinguishes them. | **Remove** blanket authorization to replace W arithmetic. A2/A3 may require new arithmetic for their approved calculations, not unrelated rewrites. |
| Self-recipient rejection for all money operations; P S1-SEC-02 | W accepts itself as a nonzero recipient/treasury; some receipts become unassigned and own-address shares can be stranded. | **Authorization case A9** for rejecting user mint/payout-to-vault mistakes. Treasury configuration is separate and is not changed by this case. |
| Operational ownerlessness, no fee/pause administration; P S1-ARCH-02/A68 | W has actual owner powers. One token and registry deployment do not eliminate them by definition. | **Remove** inherited elimination of those powers. Decide role/configuration mapping together with the fee policy. This is not a request to add an unrestricted upgrade or rescue function. |
| Registry-disabled issuance versus exits; F FS-A38; P S1-SEC-02 | An inbound issuance gate fits the accepted registry/SE surface; W separately pauses only deposits. | **Already authorized** for the stated inbound gate and preserved exits. Do not infer that this substitutes for every Weir admin function. |
| Blocking explicit donation while disabled; P S1-SEC-02 | A distinct capital-contribution policy, not implied by Weir or the donate retention lock. | **Remove** as inherited policy. Retaining exits and permissionless compound does not settle donation admission while disabled. |
| Fee/event details: all-fees-retained reports, `ZapCredit`, `WithdrawalMaintenanceSelected`, changed `Compounded` payload/returns | These reflect P's selected economics, not just event naming. W's compound event is conditional on positive harvested fees; idle-only addition may have no event. | **Remove** automatic ABI/event inheritance. Keep canonical share events and locked paired events; adapt other accounting events to approved behavior. `compound()`'s no-share-change purpose does not itself lock P's `(fees0,fees1)` return or event timing. |

### 4. Standard surface, custody, execution, and packaging

| Item and locator | Comparison and authorization boundary | Disposition |
| --- | --- | --- |
| Canonical ERC-20/permit/domain, standard vault discovery, registry/CREATE3 lifecycle, separate storage namespace | Necessary standard/Crane packaging, not proof of PairToken economics. Metadata/domain must belong to the diamond and interfaces/cuts must be truthful. | **Already authorized** by B's tokenized standard and F's packaging requirements. |
| Exactly 18 share decimals solely “matching PairToken”; P S1-ARCH-02 | W has raw internal shares, not ERC-20 metadata. The admitted record does not independently establish that all such vaults must use this precision. | **Remove** PairToken's value as an inherited economic requirement. Use the actual standard's requirement if established; otherwise obtain the share-unit decision together with genesis. Do not normalize underlying token amounts by guess. |
| PoolKey, name, symbol instance inputs | Pool identity and token metadata have direct purposes in the authorized adaptation. | **Already authorized**; FS-OWN-02 specifically permits a pool-key initialization input. |
| Exact PairToken `PkgInit` order, fixed linked `address[6]`, mirrored Planner/Projection/ExecutionPreparation decomposition | A copy of an implementation's shape is not required by a registry-deployed vault. Some dependencies may be needed after behavior is chosen; their exact count and split are not established. | **Remove** compulsory PairToken shape and filename mirroring. Preserve only the actual standard lifecycle and approved components. |
| Manager, registry, oracle, wrapper, diamond-factory bindings; binding identity and initialization checks | These have independent purposes: pool settlement, registry authority, the locked sleeve target, ERC-20 native faces, and package lifecycle. | **Already authorized** to the extent actually required. Aware-repo installation, wrapper storage, and exact package field arrangement remain explicitly open in FS-OWN-01/10. No unused component binding is justified by the list in P. |
| Missing-component/duplicate-initialization/wrong-context rejection; factory-owned introspection exclusions | Ordinary integrity of the authorized package and standard surfaces. | **Already authorized** in principle. The exact current factory context and selector manifest must be verified during implementation; this report did not inspect that code. |
| Hookless/static-fee-only pool domain; P S1-ARCH-03; F FS-PKG-02 | W accepts initialized keys including hooks and does not impose this narrowed domain. | **Authorization case A6** for an explicitly limited first supported pool domain needed by exact local previews. Hookless is not a consequence of full range. |
| Ordered distinct currencies, real initialized pool, usable ticks, valid ERC-20 faces, no face collision | These underpin a real position and unambiguous standard asset routes. | **Already authorized** as standard/position validation. Do not turn them into a hidden token or issuer allowlist. |
| FoT/rebasing exclusions, non-18-decimal currencies, accepted pause/blacklist risk | Repository token law in CLAUDE.md, also stated in I; not PairToken policy imported by inheritance. | **Already authorized**. Exact delivery checks are separately proposed in A5. |
| Raw ETH methods and payable donation inherited from SY/paired APIs; F FS-MONEY-01/A10; P S1-NATIVE-01/API-03 | W supports raw ETH, but the locked accepted routes use ERC-20 faces and drop the named payable paired/SY routes. L explicitly says raw ETH is not decided. | **Remove** unconditional raw-ETH public entry/payout promises and tests. Preserve native PoolKey identity and required internal native settlement; do not add a payable extension by inference. |
| Wrapped-native boundary and no double counting | Required to expose the locked ERC-20 face for a native underlying; no separate wrapped investment or price model. | **Already authorized** by FS-OWN-09/10. The family `wrappedNative()` getter stays absent. |
| Exact-input refund tuple, accepted bundle methods, stable token order, paired events | Explicit locks, not P's old paired selector ABI. | **Already authorized**, FS-OWN-08/09. Remove `depositPair`, `redeemPair`, and both old previews. Their behavior must be expressed through accepted routes rather than reinstalling aliases. |
| Exact-output methods fail closed rather than silently approximate | W has no exact-output operation; the supplied standard surface explicitly permits an unavailable operation and F requires it. | **Already authorized** for the stated unsupported route. This does not license importing P's entire route table or paired-bootstrap restriction. |
| No `rateAsset`, `getRate`, SY, or ERC-4626 `asset()` workaround | FS-OWN-03/05 and the accepted two-token standard determine these exclusions. | **Already authorized**. Remove obsolete rate errors and SY files/acceptance obligations, including F section 2.1's lingering below-one-share error. No NAV substitute. |
| Aware manager components; reusable position/ticks; position-liquidity wrapper; no family `basket` | Explicit owner decisions, with Weir position identity retained. | **Already authorized**, FS-OWN-01/02/06/07. No re-vote. |
| Local sleeve and current local-plus-deployed-plus-owed-fee reserves | Explicit changes from Weir's incidental idle and P's no-sleeve/book-only model. | **Already authorized**, FS-OWN-04/07. Refill, shortfall, and locked-manager spending remain open; do not invent a maintenance algorithm. |
| Unsolicited inventory exclusion, pending-input reservations, pretransfer validation | W already leaves passive receipts unassigned; standard pretransfers add an attribution problem. | **Already authorized** for the custody distinction needed by accepted funding routes. Exact-receipt and callback reservation enforcement are A5; no permission to adopt historical balances as a donation. |
| Per-action ordinary unlock, relock between maintenance stages; F FS-UNLOCK-03/A17 | W uses one unlock around maintenance plus the requested action. P's decomposition is not necessary to tokenize it. | **Remove** this compulsory dispatch schedule. Keep the ordinary Weir transaction structure unless a concrete integration/size constraint justifies a different schedule. |
| Borrowed unlock on canonical `exchangeIn`; F FS-X01/UNLOCK-02 | Neither W nor P provides it. It is a separate FullSpread integration requirement, not a PairToken feature. The standard selector alone does not require this caller context. | **Authorization case A11**, unless the coordinator can identify the existing owner authorization for that context. Do not use the disputed PRD alone as proof. Per-address delta closure, no nested unlock, and no foreign credit consumption are necessary if this target is retained. They are not runtime-proven here. |
| Code-bearing caller requirement on self-funded borrowed entry | A special F restriction, not W behavior or an identified token standard necessity. A code check is not authority. | **Remove** as a compulsory extra restriction absent a consumer/standard reason. Preserve payer/share authority, route checks, and the separately stated borrowed-path pretransfer exclusion. |
| Active-operation guard and one-shot callback payload commitment; P S1-X11/SEC-01 | W checks the manager and has public-method reentrancy guards, but does not use the same callback commitment/phase policy. | **Authorization case A4** for cross-facet execution integrity. It does not require the per-action unlock schedule rejected above. |
| Explicit native sync reset and settlement-result validation; P S1-X18; F FS-A35 | W's native payment omission is characterized by I WI-29/AC51. Borrowed execution increases the importance of pre-existing outer sync state. | **Authorization case A5** for ordinary execution; the borrowed-path isolation requirement also directly needs correct native settlement. Never claim a native sync preserves an outer actor's prior checkpoint. |
| Read guards on economic views; P S1-SEC-01 | W allows intermediate reads. Canonical token methods must retain their standard semantics. | **Authorization case A4** for explicit economic-view phase behavior, not a proxy-wide read lock. |
| Last-committed Basic Vault snapshot; F FS-A32; P S1-API-01/SEC-01 | Copied from the unchanged shared Basic Vault facet. The owner instead selected a custom local-plus-deployed view. | **Remove** the automatic snapshot contract. Its current-value lock must not be silently replaced; in-flight behavior requires an explicit reconciliation with FS-OWN-07. |
| Execution-equivalent standard previews | W's `previewRedeem` omits pending fees, compound, and zap; it cannot simply be renamed to supply the accepted executable quotes. | **Already authorized** as the accepted quote surface's meaning. Use Weir-derived approved operations, not a mandatory simulation of P's compound swap. |
| Full projection stack, deterministic step/crossing/bitmap budgets, state-change rejection; P S1-QUOTE-01/GAS-01 | Particular P machinery for making preview/execution parity bounded and avoiding stale plans. | **Authorization case A6** for bounded shared planning and rejection of invalidated plans, not wholesale reuse of its implementation or limits. |
| Copied numerical work limits and 12M/5M gas ceilings | P-specific supported-domain engineering choices, not Weir behavior or a recorded owner decision for this adaptation. | **Remove** their automatic inheritance. Establish the new implementation's supported envelope from evidence after approving its operations. No replacement numbers are chosen here. |
| Transition/unlock-context/exact-output quote extensions or hook edits to green fixtures | Neither standard tokenization nor this report authorizes new interfaces to fix a rejected bind. | **Already authorized** exclusion under F FS-HOOK-04. Keep rejected bindings as unresolved, not passing proof. |
| No second pool/range/share ledger, no external PairToken holding, no unrelated rescue/rebalance | Matches B's one-position target. | **Already authorized**. It does not imply removing Weir's fee or pause policy. |
| Blanket S1-A01 through S1-A70 inheritance and PairToken as comparison oracle | Imports discarded economics and contradicted SY/basic-reserve assumptions. | **Remove** blanket acceptance inheritance. Keep standard/package checks under their own authority and map Weir preservation plus each explicitly approved change to new acceptance evidence. |
| Real-manager, public-route, production-first tests; compiler and deployment law | Independently required by the repository and reflected in I. | **Already authorized**. No SUT mocking or fake bootstrap is needed; bootstrap through an accepted public route, not a dropped `depositPair` selector. |
| Hook topology/recipient/caught-revert/disjoint-pool tests | F-specific integration evidence, not a source of new economics. | **Already authorized** within the stated integration target. A cited incompatibility remains unresolved; disjoint pools do not prove same-pool sequencing. |

### 5. Explicit authorization cases for the recommended PairToken aspects

#### A1. Entry-size and entry-tick policies, without PairToken compound

**Change to Weir:** W places no vault-configured size or tick-displacement restriction on its half-imbalance swap. Retaining the two entry policies narrows the amounts admitted by the same-pool zap.

**Harm without it:** A large deposit can execute a large own-pool trade, change the inventory ratio substantially, and leave a materially mismatched addition/refund. The user's share minimum protects that user's selected outcome, not a vault policy limiting the excursion of its existing LP position. This is an exposure/operation-domain concern, not proof of a profitable attack.

**Why authorize the mix:** These are small, explicit admission controls on an existing Weir swap, rather than a new strategy or an external pricing dependency. If desired, they allow the owner to define how much entry-driven disturbance the vault supports.

**Boundary and cost:** Do not choose values here. The reserve denominator must be specified against the new sleeve/reserve semantics; copying a field type does not settle it. A tick bound is not an oracle and can miss economically relevant moves within a tick. Both policies can reject otherwise valid deposits. Neither justifies P's quarter-cap, compound swap, or compulsory getters.

#### A2. Pay for incumbent idle and fees when minting, with attributable-credit rounding

**Change to Weir:** Replace liquidity-only subsequent issuance to the extent necessary to charge for the incumbent idle/fee claim acquired by newly minted shares. P's positive-supply per-leg reserve accounting and same-price attributable-growth test provide a candidate method.

**Harm without it:** I's F3 demonstrates the source effect: a new proportional liquidity depositor obtains part of old one-sided idle without a separate buy-in. The owner-required sleeve deliberately keeps assets local, and explicit donations deliberately enlarge that book; treating them like negligible dust would systematically transfer existing holder value on entry.

**Why authorize the mix:** This change protects the economic meaning of the explicitly requested backing and sleeve. A per-token, same-price ownership test can address the transfer without designating a `rateAsset` or introducing an independent oracle.

**Boundary and cost:** This is the largest proposed economic deviation. Authorize the property and then a complete equation before implementation. In a P-style test, for each positive incumbent reserve `R_i`, new shares `q` must not overclaim the actual credited contribution `C_i` relative to existing supply `S`; `q*R_i <= S*C_i` is a candidate condition at one defined price/checkpoint. Existing inventory and fees cannot be counted as the caller's contribution.

I do **not** recommend authorizing P's full formula bundle unchanged: geometric-mean genesis, zero genesis reserve, and zap `C_i=G_i` with compulsory uncredited `J_i` are separately rejected. Any retained caller idle must either receive deliberately specified credit or remain the payer's refundable property; it cannot be confiscated to make the inequality hold. Exact scalar-route remainder handling and the Weir two-unit cushion must be resolved explicitly. The predicate protects ownership at its checkpoint, not against external price manipulation or LP market loss.

#### A3. Incumbent fee ownership through entry and exact principal/fee separation

**Change to Weir:** Isolate fees earned by the pre-mint position during an entrant's own swap instead of allowing those fees to offset the entrant's add-liquidity settlement. Separate principal costs, fee receipts, and caller funds; use only the checkpoints needed by the adopted sequence.

**Harm without it:** A depositor can receive or spend fees generated for old liquidity in its own settlement. With a tokenized book and an intended per-share claim, that shifts incumbent earnings into the new caller's effective contribution. Conflating a whole-position fee receipt with a partial withdrawal's principal can similarly misattribute value.

**Why authorize the mix:** P's explicit ownership ledger/checkpoints address a documented Weir attribution limitation without changing the pool, adding a strategy, or needing a rate token. Exit-swap fees already belong to remaining liquidity in W; preserve that behavior.

**Boundary and cost:** Extra checkpoints cost gas and change event/accounting attribution. Weir's performance-fee treatment for newly isolated fees must be decided with its fee policy; this case does not silently abolish or extend the fee. There is no P-style compound swap here, so its extra swap-generated fee checkpoint is not automatically necessary.

#### A4. Cross-facet operation integrity and explicit economic-view phases

**Change to Weir:** Add a shared operation context and one-use callback commitment around the authorized diamond execution, with narrowly specified economic-view behavior during external interactions.

**Harm without it:** W's manager-address check alone does not express which callback the diamond has authorized. Splitting entry, callback, and quotes across facets without a shared phase invariant risks accepting the wrong payload or exposing a mixed accounting state as an executable quote.

**Why authorize the mix:** The diamond adaptation is already accepted; the context guard makes its new execution boundary explicit and also supports the borrowed-unlock capability proposed in A11. It is not a new investment policy.

**Boundary and cost:** Do not make every ERC-20 read revert or impose P's last-committed Basic Vault implementation. The custom reserve lock requires a separate explicit in-flight rule; do not call a stale snapshot the current local-plus-deployed amount. A commitment can cover Weir's one ordinary unlock; it does not authorize one unlock per internal action. No callback policy is claimed tested here.

#### A5. Exact receipt, disjoint reservations, and native settlement validation

**Change to Weir:** Check supported-token delivery, reserve pending caller assets and payouts separately, and explicitly establish native sync state before payable settlement. W's nominal pulls and native branch do not provide all these checks.

**Harm without it:** I AC55 characterizes short-delivery paths that may consume pre-existing custody; I AC51 characterizes native settlement failure under an outstanding ERC-20 sync. New pretransfer and wrapper boundaries also make accidental adoption or double counting of pending assets a concrete integration risk.

**Why authorize the mix:** These checks enforce the tokenized standard's ownership and funding contract. They protect booked assets from being used to satisfy somebody else's promised input and let native settlement operate correctly in the newly required manager context.

**Boundary and cost:** This is not support for rebasing/FoT tokens and not permission for a token allowlist. Validate only current receipts; direct historical transfers remain unassigned. A native sync replaces global sync state, so an outer actor cannot assume its earlier checkpoint survived. Close only this diamond's deltas in borrowed execution and never appropriate another actor's credit.

#### A6. A bounded, truthful preview/execution domain

**Change to Weir:** W has no full compound-and-zap executable preview, no local tick-traversal work budget, and broader hooked-pool acceptance. Retain P's concept of one economic model, explicit operation-domain bounds, and stale-plan rejection for the accepted standard quotes. Initially limiting supported keys to hookless/static-fee pools is a proposed accompanying scope restriction.

**Harm without it:** Rebranding W's principal-plus-idle preview would omit fees and same-pool execution effects. Unbounded projection can become unusable for callers, while an arbitrary hook can introduce effects a local deterministic preview does not model. Executing after token/wrapper callbacks invalidate a preflight plan risks settling against the wrong attribution snapshot.

**Why authorize the mix:** The standard needs meaningful amount-specific output/refund quotes. Bounded exact behavior with explicit rejection is more honest than fabricated successful quotes. A limited pool domain can make that promise testable.

**Boundary and cost:** This narrows Weir's pool and amount support, potentially significantly. Hookless/static fee is a proposed first domain, not a mathematical impossibility claim for every other pool. Include the real fee/state behavior of whatever domain is approved. Do not import P's six libraries, budget numbers, gas ceilings, second candidate, or compound simulation automatically. Preserve Weir's simpler no-swap maintenance unless separately changed.

#### A7. Collection-only withdrawal when reinvestment alone blocks exit

**Change to Weir:** Permit an explicitly defined withdrawal plan that collects owed fees but skips reinvestment when a known maintenance obstacle would otherwise prevent the exit.

**Harm without it:** Mandatory compound can fail because an attempted addition exceeds a relevant liquidity/delta limit, even though collecting fees and removing existing liquidity could still serve the holder. The deposit/compound policy should not silently become an unnecessary exit dependency.

**Why authorize the mix:** P's preflight-selected alternative separates earning/reinvestment from ownership redemption. It can improve exit availability without a queue, keeper, or implicit change from single-token to paired output.

**Boundary and cost:** Re-derive the obstacle set for Weir's no-swap compound and the owner-required sleeve. Do not inherit price-limit or quarter-cap obstacles for a swap that no longer exists. Do not catch actual manager/token/wrapper failures, skip required fee accounting, or use fallback to evade minima. The public mode query remains dropped. The mechanism needs explicit approval; FS-OWN-10 did not grant it.

#### A8. Reject positive-share burns that pay nothing

**Change to Weir:** Reject a successful withdrawal with zero total actual payout instead of allowing a dust share burn when both minima are zero.

**Harm without it:** A user or integrator can destroy a positive share balance while receiving no assets, especially through a generic route that supplies zero minima.

**Why authorize the mix:** This is a narrow user-loss check with a clear failure result and no alternative investment behavior.

**Boundary and cost:** It makes some W withdrawals unavailable. It does not require both legs positive, change proportional rounding, guarantee a useful token value, or justify removing the genesis reserve.

#### A9. Reject user mint/payout recipients equal to the vault

**Change to Weir:** Reject those self-directed user destinations rather than treating them like any nonzero address.

**Harm without it:** W allows proceeds to become physically held but unassigned, and shares to be held at an address with no ordinary user recovery path. The tokenized adaptation must not inadvertently turn that address into a generally claimable pretransfer pool either.

**Why authorize the mix:** P's explicit self-recipient rejection prevents a recognizable routing mistake without a rescue role or a new withdrawal mechanism.

**Boundary and cost:** This removes valid source calls and must be documented. It does not forbid legitimate transient custody required by the accepted pretransfer protocol, and it does not settle the independent treasury-self case or authorize an administrator to sweep backing.

#### A10. Explicit donation requires existing shares

**Change to Weir:** Weir has no equivalent vault-book donation. This retains one P-specific admission rule on the newly owner-authorized function: do not book an explicit no-share donation before a share population exists.

**Harm without it:** The intended beneficiaries are undefined at zero supply. A later bootstrap can capture previously donated backing, or the implementation must invent ownership rules for it.

**Why authorize the mix:** The lock says donate adds backing without minting shares. Requiring existing shares gives that action an identifiable beneficiary set while leaving passive unsolicited receipts unassigned.

**Boundary and cost:** This excludes prefunding through `donate`; it does not prohibit an ordinary first deposit or authorize the PairToken paired-only bootstrap. Positive amount and exact receipt are ordinary input/funding checks. Donation while disabled and raw-ETH payable forms remain separate policy decisions.

#### A11. Borrowed unlock for the stated hook-driven exchange target

**Change to Weir:** Allow the canonical, self-funded scalar `exchangeIn` to execute without opening another unlock when the bound manager is already unlocked. W and P both reject that ordinary nested-unlock situation.

**Harm without it:** F's targeted buffer-hook conversion cannot call the vault to mint or redeem inside its existing manager unlock. Merely installing the standard selector or passing an identity-share trade does not provide that conversion.

**Why authorize this addition:** It serves a concrete stated integration target while retaining one position and the canonical exchange selector. This is not PairToken borrowing, and it should not be removed just to make the implementation resemble W.

**Boundary and cost:** The admitted owner locks settle selectors and asset representation, not all caller-context policy. If an earlier explicit authorization already covers this target, cite it rather than requesting a duplicate decision. Otherwise obtain authorization for this expanded execution context. Self-funded input, caller-owned burns, no borrowed-path pretransfer, context integrity, and closure of only this diamond's deltas define the proposed narrow capability. Do not imply that every maintenance or bundle method becomes unlocked-capable. Recipient freedom and shared global sync state require actual integration evidence; no hook allowlist or foreign-credit settlement is proposed.

### 6. Reconciliation needed before a faithful implementation specification exists

The owner locks remain in force. The following are not invitations to vote them away:

- **Sleeve versus Weir issuance:** Keep the locked sleeve. Either expressly approve an idle-aware issuance change such as A2 or acknowledge Weir-style idle dilution as a deliberate product choice. Do not claim “liquidity shares are unchanged” while charging a PairToken reserve price.
- **Canonical ERC-20 supply versus Weir's unassigned reserve:** Tokenization requires a coherent supply representation. It does not itself select P's zero-reserve policy. The reserve representation/economic choice is unresolved.
- **Scalar refunds versus Weir's possible two-currency entry credits:** Keep the locked ABI. Specify the supported result domain or seek an explicit residual policy. No compulsory donation is authorized by the ABI.
- **Current custom reserves versus stale shared snapshots:** Keep FS-OWN-07. Remove P's shared-facet storage assumptions and decide the in-flight response explicitly.
- **Native pool versus raw-ETH public routes:** Preserve native position identity and accepted wrapped faces. Raw-ETH extension is undecided, not silently required by P or silently impossible because SY was dropped.
- **Keep compound versus change compound:** Preserve the locked function and unchanged supply. Neither the sleeve lock nor compound retention approves a ratio swap, a new reinvestment schedule, or removal of Weir fees.
- **Fee/admin policy versus ownerless PairToken:** Decide explicitly whether to retain, freeze, or replace Weir settings. Registry packaging does not answer that question.
- **Hook integration versus removed rate:** Keep the no-rate lock. A hook needing a rate provider or an `asset()` identity workaround remains an integration gap, not a reason to reinstall a forbidden selector.

The resulting PRD should be a standalone Weir-adaptation specification with a short explicit deviation ledger. Its acceptance should preserve Weir behavior where unchanged, prove owner locks, and test each approved deviation on its own merits. PairToken's entire PRD and test matrix must not remain the fallback authority.

## Limits

This response authorizes no implementation and changes no PRD, function-review file, project code, package, test, configuration, or deployment. It is not a safety clearance or a whole-repository review.

No peer was read, no sub-agent was launched, and no test, build, shell/Git operation, wallet, deployment, or external message was performed. No public search was necessary for this repository-text provenance comparison. No current package/hook/API implementation was independently verified; claims about those surfaces are limited to the admitted documents.

No cap value, new raw-ETH route, fee replacement, genesis-reserve representation, complete revised issuance formula, or sleeve refill rule is selected here. Those are substantive owner decisions or later specification work, not hidden defaults. The classified inventory and authorization cases are complete for the material carry-overs found in the admitted documents; this is not a claim that unread implementation files contain no additional ones.
