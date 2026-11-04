# Owner decisions F1-F12

## Identity

- Member: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Actual model: not exposed
- Actual task ID: not exposed
- Runtime identity: not exposed
- Peers read before submission: no
- Fresh context: yes

## Question and targets

Question: For each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation?

Targets: the owner responses copied in `docs/research/se-fullspread-owner-decisions-20261103/brief.md`, and the recommendation sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`. Where the brief's short form and the report differ, the report was used.

## Evidence

Read for this response:

- `docs/research/se-fullspread-owner-decisions-20261103/brief.md`, including the verbatim owner responses
- `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`, the recommendation sentences
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, the lock authority
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`
- `lib/crane/contracts/access/operable/OperableRepo.sol`
- `lib/crane/contracts/access/operable/OperableModifiers.sol`
- `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol`
- `contracts/interfaces/IVaultFeeOracleQuery.sol`
- `contracts/oracles/fee/VaultFeeOracleRepo.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol`
- `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, the accepted `exchangeBundleOut` signature, used as a locator from the PRD
- The full-spread PRD only as a locator for FS-OWN-09, FS-OWN-30, FS-OWN-33, FS-X01, and FS-UNLOCK-01

No peer response was read. No Forge, test, install, or Git command was run. The fee-delta path was read and was not executed.

## Assumptions

- The blockers file and the pretransfer directive are the lock authority. The PRD is a locator. An unedited PRD sentence is not treated as a later lock.
- A difference from a recommendation is not itself a problem. The owner may change a recommendation.
- A misunderstanding is a restatement that does not match the sentence they said they accepted, or a reason aimed at a mechanism the recommendation did not propose.
- A problem is only a silent reversal of an already locked sentence, a split two implementors would execute differently, a decision the protocol that was read cannot perform, or an accepted sentence that is still not copyable.
- Owner typos stay the owner's. Reading "Ok, the seems like an acceptable definition" as acceptance of the F4 definition is inference.
- "This conclusion is correct", "Yes, that is correct", and "This is correct" accept the report sentence for that finding, not the brief's short form.

## Coverage

F1 through F12 are judged below. F13 through F15 were not decided. Code was read only where a decision had to be tested against a lock or against protocol behavior. No product question the owner left open is answered.

## Conclusions

### F1. Overstated maximum

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: yes
- Missing fact: when a declared maximum exceeds the unbooked balance, does the call refund that unbooked balance and process nothing, or credit the caller with another sitting balance, and which balance?

Observation: the report sentence snapshots each pretransferred input's unbooked balance before any pull or use. If any declared maximum exceeds its snapshot, the whole call processes nothing, pulls nothing, does not revert for the difference, and refunds that snapshot. It does not propose a new ERC-20 event, a recipient callback, or a per-sender attribution standard.

Observation: the owner rejected that snapshot. The stated reason is that no standard reliably alerts a recipient of an ERC-20 transfer, and that a new standard cannot be invented. The owner also wrote that if a caller overstates a maximum and is credited another pretransferred balance, that is the fault of the user who pretransferred outside an atomic operation. They did not say this replaces the 2026-11-02 lock.

Observation: `docs/vaults/PRETRANSFER_DIRECTIVE.md` lines 9-11, and the blockers file at lines 282 and 390, already lock the overstated case: if the maximum is larger than the unbooked balance, refund that unbooked balance, do not refund maximum minus used, and do not pull the shortfall. The same directive says the vault does not ask where the tokens came from, and that a non-atomic pretransfer is at the caller's risk. `IStandardExchangeIn.sol` line 56 says the declared input is processed only when present unbooked input covers it, and that a difference between the declaration and the surplus does not by itself revert.

Inference: the recommendation's snapshot is a read of the aggregate unbooked balance, not a recipient-alert standard. The reason answers a mechanism the recommendation did not propose. The credit sentence can be read either as the already locked non-atomic risk inside the maximum, or as a replacement of the overstated refund. The owner did not say which. One implementor keeps the 2026-11-02 refund and does not credit the overstated declaration. Another credits another sitting balance and does not refund. Those are not the same call.

### F2. Fees on a liquidity-adding user route

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: no
- Missing fact: on a deposit, a bundle deposit, and a share-minting `exchangeIn`, is the fee delta from `modifyLiquidity` booked, or left unaccounted?

Observation: the owner wrote that the conclusion is correct, and then wrote that compound is not interleaved with other operations, so fees are left untouched on every operation except donation and compound. They did not say the second sentence replaces the first, and they did not say it replaces the withdrawal booking lock.

Observation: the report sentence they accepted says those three routes book any position fees their liquidity modification collects, do not credit, refund, or deploy those fees, and do not call `compound()`. A pass-through collects none.

Observation: the blockers file at line 256 already locks a different route: a withdrawal's `modifyLiquidity` collects fees, those fees are booked, and the caller is paid only the principal fraction. Line 78 locks that a deposit, a withdrawal, and `exchangeIn` do not call `compound()`.

Observation: `Position.update` computes `feesOwed0` and `feesOwed1`, then writes `feeGrowthInside0LastX128` and `feeGrowthInside1LastX128` to the current inside growth (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol` lines 94-97 and 101-102). `Pool.modifyLiquidity` returns that amount as `feeDelta` (`Pool.sol` lines 189-193). `PoolManager.modifyLiquidity` adds that fee delta into `callerDelta` and accounts it to `msg.sender` (`PoolManager.sol` lines 119-120 and 132).

Inference: "do not call `compound()`" matches the accepted sentence and the 2026-11-01 lock. "Leave fees untouched" does not match "book any position fees their liquidity modification collects." A route that calls `modifyLiquidity` cannot leave accrued fees in the position: the fee-growth cursor moves, and the owed fees are added to the caller's delta. The untouched reading also covers withdrawal, which the 2026-11-02 booking sentence does not, and the owner did not say that sentence is replaced. One implementor books the delta and does not deploy it. Another tries to leave the delta unaccounted. The second cannot be performed by the PoolManager path that was read.

### F3. Booked total

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the report sentence and did not restate it. That sentence says the booked total after `donate` or `compound` is the vault balance after the one permitted deposit, a zero-size add is skipped, and a failed step reverts. The blockers file at lines 254-256 already locks booking the actual held balance after the deposit, forbids another attempt, and says a failed step reverts.

Inference: the zero-size skip is a refinement inside the accepted sentence, not a second booking rule. Skipping the liquidity-add call is executable, because it does not require `modifyLiquidity` to leave a zero-liquidity delta uncollected. Two implementors who follow the accepted sentence and the 2026-11-02 booking lock do the same thing.

### F4. Position ratio

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the definition and did not restate a different formula. The report sentence is the token amounts a full-range liquidity unit consumes at the current square-root price and the stored ticks, excluding unpaid fees and booked balances, read immediately before the proportional add.

Observation: the blockers file at line 174 locks this vault's range as the full-range position, with the ticks stored per instance. Lines 252-254 already use "the position's ratio" as the one-token swap target and as the scarcer-token comparison, without defining the unit.

Inference: for this vault, "full-range" and "stored ticks" name the same position. Accepting the definition does not replace a different locked formula. It gives the ratio those locks already use.

### F5. One-token swap size

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the report sentence and did not restate it. The swap input is the amount required by the greatest integer liquidity the following add can take, rounded so any remainder is in the processed token. If that input is zero, swap nothing. "About half" does not survive.

Observation: the blockers file at line 252 already requires the remainder to be in the token being processed. `docs/vaults/PRETRANSFER_DIRECTIVE.md` line 11 already requires the swap to be shaped so a remainder of the call is in the token the caller provided. FS-OWN-33's "about half" is a PRD locator, not the later lock.

Inference: the accepted sentence names the amount. It does not name a search procedure. That is not an unnamed amount. The F6 answer later says "swapping 48% of the provided token" and defers the algorithm to proof or fuzz. That sentence does not say it replaces this acceptance. It is not read here as a new F5 lock. The conflict is charged to F6.

### F6. Unconverted exit principal

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: no
- Missing fact: does a one-token exit that cannot convert all unwanted withdrawn principal revert `AmountOutNotMet` without burning shares, or leave a remainder of the provided token after a sized swap?

Observation: the owner wrote that they agree and accept the proposed sentence. That sentence scopes the no-leftover-shortfall-revert rule to the former sleeve top-up, and it requires a one-token exit to convert all unwanted withdrawn principal into the selected token or revert `AmountOutNotMet` without burning shares. It does not pay, book, or abandon that residual.

Observation: they then wrote that the swap is sized so there is always a remainder of the provided token, that this should be as easy as swapping 48% of the provided token, and that the algorithm still has to be proved or found by fuzzing. They did not say those sentences replace the exit sentence they accepted, and they did not say they replace the F5 acceptance.

Observation: the already-locked list at blockers line 380 says a redemption on the vault's own unlock does not have a leftover shortfall revert. The accepted sentence names that scope change, so the scope change is not silent. `IStandardExchangeErrors.sol` line 29 declares `AmountOutNotMet(uint256 amountOut, uint256 actualOut)`. The accepted sentence names the error and does not name the arguments.

Inference: the 48% remainder is the entry and donation swap shape already locked at blockers line 252 and in the pretransfer directive at line 11. It is not the exit rule in the sentence they accepted. The reason answers a mechanism F6 did not propose. One implementor reverts the exit and burns no shares. Another sizes a swap near 48% and leaves a remainder. The 48% figure is also not a locked amount, because the same answer defers the algorithm. The existing error's two arguments are not what makes this answer uncopyable.

### F7. `Compounded()`

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: yes
- Missing fact: does `Compounded()` fire when booked tokens are deployed, when the call collects a nonzero fee delta, or only when both happen?

Observation: the report sentence emits no-argument `Compounded()` only when `donate` or `compound` adds positive liquidity and that call collects a nonzero fee. It does not emit for a donation-only deploy or for a later deploy of previously booked fees, and it does not name a donation event. It says a later fee-origin emit needs a store, and it does not add one.

Observation: the owner did not accept that sentence. They wrote that `Compounded` is emitted because fees are deposited, not because fees are claimed, and so it is emitted when booked tokens are deployed. They also wrote that a donation event is wanted, and that both `Donation()` and `Compounded()` are emitted when a donation also collects accrued fees. They did not say this replaces the 2026-11-02 emission lock.

Observation: blockers lines 234 and 242 lock no-argument `Compounded()` when fees are compounded into the reserve, and no emission for a maintenance call that compounds no fees. Line 254 locks that a booked balance includes a stray transfer and a non-atomic pretransfer, not only fees. A search of `contracts/` found no `Donation()` event. The pair-token vault emits `Donated(address,address,uint256)` and a fielded `Compounded`. The owner named `Donation()`, not `Donated()`.

Inference: "depositing rather than claiming" answers a mechanism the recommendation did not propose. The recommendation's condition was an add plus a nonzero collection on that call, not a claim-versus-deposit product choice. "Emit when booked tokens are deployed" is wider than "when fees are compounded," because the booking lock includes non-fee balances, and the owner did not say the 2026-11-02 emission sentence is replaced. The same answer also emits `Compounded()` when a donation collects accrued fees, which is the collection side the first sentence rejects. `Donation()` has no fields and no emit condition except that combined case. One implementor emits on every booked deploy. Another emits only when a fee delta is collected. Another emits only on the intersection. Those are not the same logs.

### F8. Seven-address write

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the report sentence and did not restate it. Initialization writes the seven package addresses once into that instance's Uniswap V4 Protocol Aware Repo. "No second copy" forbids another instance store. It does not forbid the initialization write, and it does not remove the package immutables.

Observation: blockers lines 158-166 and 394 already lock those seven addresses as package immutables and lock the one initialization write into the Protocol Aware Repo, with no second per-vault copy. The seven are the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router.

Inference: the accepted sentence restates the lock. It does not add a second store and it does not require a write the lock forbids.

### F9. Selector row

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the report sentence and did not restate it. `poolManager()` is served by the Crane Protocol Aware facet. `poolKey()`, `tickLower()`, `tickUpper()`, and `positionLiquidity()` are served by `UniswapV4SinglePositionAware`. No family-only duplicate is added.

Observation: blockers lines 166-180 and 395 already lock that split, and they say the position facet's code is not written by the lock. A local search found no `positionLiquidity()` under `lib/crane/contracts/protocols/dexes/uniswap/v4`. `poolManager()` exists on other Uniswap V4 interfaces, including `IImmutableState`.

Inference: absence of the position getter is the state the lock already describes, not a protocol behavior that cannot serve the accepted getters. The other `poolManager()` declarations are not a family-only duplicate on this vault. The accepted sentence and the lock name the same facets.

### F10. `donate` signature

- Misunderstood: no
- Problem: yes
- Changed the recommendation: no
- Missing fact: what `donate` does when `pretransferred` is true and the declared amount exceeds the unbooked balance, now that the F1 answer rejected the snapshot-and-refund-only rule this sentence calls F1?

Observation: the owner accepted the report sentence and did not restate it. The signature is nonpayable `donate(address token, uint256 amount, bool pretransferred)`, with no return value. `pretransferred` true is an underlying-token donation and uses F1. False pulls `amount`. A share donation requires false and burns only the caller's shares. `compound()` keeps no arguments.

Observation: blockers line 250 already says `donate()` uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise. `IUniswapV4Detf.sol` line 138 already declares `donate(IERC20 token, uint256 amount, bool pretransferred)` with no return. The ABI address and `IERC20` forms are the same selector shape.

Inference: the signature itself is copyable, and accepting it does not reverse the three-argument lock. The true branch is not copyable, because the accepted sentence delegates it to F1, and the F1 answer rejected the report's F1 rule without saying the "uses F1" clause is changed. One implementor still runs the report's refund-only snapshot on `donate`. Another follows the F1 credit sentence and has no overstated procedure. The share-versus-underlying split is not the gap: true is an underlying donation, and a share donation is the false case that burns shares.

### F11. Batch-swap routes

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Missing fact: none

Observation: the owner accepted the report sentence and did not name a different selector. The report said to say so if the one-token exit is not single-output `exchangeBundleOut`. Acceptance adopts that assumption. While the PoolManager is unlocked, canonical `exchangeIn` may proceed on the borrowed path with `pretransferred` false. Single-output `exchangeBundleOut` proceeds. `exchangeBundleInForSingleOut`, both-output `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked`.

Observation: blockers lines 88 and 208, and the already-locked list at line 381, already say the borrowed path stays, the vault calls `modifyLiquidity` and `swap` directly, and a one-token exit pulls the deployed fraction and swaps only the withdrawn net on that open flag. The accepted bundle interface says `tokensOut` is not fixed at two and a subset is allowed when the route can settle it without an unrequested output (`docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` lines 181-185). The unedited PRD locator FS-X01 and FS-UNLOCK-01 still revert every `exchangeBundleOut` while unlocked.

Inference: the owner confirmed the selector the report left open. That does not reverse B-09. It names the call B-09 already allows to proceed. A one-element `tokensOut` is a call the accepted interface already permits. The stale PRD blanket revert is not the later lock. `PoolManager` can `swap` and `modifyLiquidity` only while unlocked (`PoolManager.sol` lines 48-56 and 94-96); the accepted exception uses that open flag and does not ask for a nested `unlock()`.

### F12. Owner after initialization

- Misunderstood: no
- Problem: yes
- Changed the recommendation: yes
- Missing fact: after `feeTo()` changes, is owner authority only the new `feeTo()` address, or both that address and the owner stored at initialization?

Observation: the owner wrote that they reconsidered this handling. They want `feeTo()` to have owner controls even when the value changes. They want a new set of ownership modifiers that check the caller against the currently configured `feeTo()` address, and they want the existing Operable repo integrated if possible for global and function-level operator authorization. They did not say this replaces the 2026-11-02 sentence that the initialization-time `feeTo()` address is the owner `onlyOwnerOrOperator` uses.

Observation: blockers line 80, repeated at line 385, locks that initialization sets the owner to the address returned by `feeTo()` on the Vault Fee Oracle, and that this is the owner `onlyOwnerOrOperator` uses. An operator may still call. The report sentence they reconsidered was the freeze reading of that sentence: store once, including zero, and do not live-read `feeTo()` later.

Observation: `IVaultFeeOracleQuery.feeTo()` returns `IFeeCollectorProxy` (`contracts/interfaces/IVaultFeeOracleQuery.sol` line 44). `VaultFeeOracleRepo._feeTo()` returns stored `layoutStruct.feeTo`, and `_setFeeTo` replaces it (`contracts/oracles/fee/VaultFeeOracleRepo.sol` lines 114-115 and 127). `OperableRepo._onlyOwnerOrOperator` authorizes `MultiStepOwnableRepo._owner()`, a global operator, or a function operator (`OperableRepo.sol` lines 213-216). `MultiStepOwnableRepo._owner()` returns `layoutStruct.owner` (`MultiStepOwnableRepo.sol` lines 285-286). Global and function-level operator mappings already exist (`OperableRepo.sol` lines 29-36).

Inference: this is a conscious change of the recommendation, not a restatement of a sentence they accepted. A new modifier can live-read `feeTo()` and can call the existing operator predicates. The existing `onlyOwnerOrOperator` cannot follow a `feeTo()` change, because it compares the vault's stored owner, not the oracle's current `feeTo()`. "If possible" does not lock the operator half: one implementor wires the existing predicates, and another skips them. The owner half is also not one execution. "Always have owner controls when `feeTo()` changes" does not say the initialization-stored owner loses authority, and it does not say the 2026-11-02 guard sentence is replaced. One implementor authorizes only the current `feeTo()`. Another authorizes that address and the stored owner. The zero-`feeTo()` case was not decided and is not answered here.

F13, F14, and F15 were not decided. Silence is not acceptance.

## Limits

- This response is research. It does not authorize implementation or a PRD edit. It does not replace the recommendation, the blockers file, or the owner responses.
- The fee-delta path was read and was not executed.
- Peers were not read.
- No product question the owner left open is answered here.
