# Owner decisions F1–F12 — member response

## Identity

- Member: minimax
- Run ID: se-fullspread-owner-decisions-20261103
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3` (admitted adaptive thinking)
- Runtime identity beyond the assignment: not exposed
- Peers read before submission: no
- Owned artifact: `docs/research/se-fullspread-owner-decisions-20261103/members/minimax/response.md`
- Advisory only. This response does not authorize implementation or a PRD edit.

## Question and targets

- Question, as the brief puts it: for each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation.
- Required targets read: the owner responses copied in `docs/research/se-fullspread-owner-decisions-20261103/brief.md`, and the recommendation sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md` (the full F1–F12 paragraphs, not the brief's short locator).
- Optional context read: `docs/vaults/PRETRANSFER_DIRECTIVE.md`; the blockers file `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`; the full-spread PRD as a locator only; the local Uniswap V4 `modifyLiquidity`/fee code; Crane `Operable` and ERC-8023 ownership code; `IStandardExchangeIn` and `IStandardExchangeErrors`.
- Not read: any peer response, the coordinator draft, `RUN.md`, and the prior resolution draft. No sub-agent was launched. Nothing was built, tested, installed, or committed.

## Evidence

Sources and what each one establishes, all read in this session:

- `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md` — the recommendation sentence for each F1–F12, including the two the report itself flags as owner choices (F6, and the previously booked half of F7).
- `docs/vaults/PRETRANSFER_DIRECTIVE.md:9` — locked rule for an overstated maximum: "If the maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund the maximum minus the amount used, and do not pull the shortfall." `:7` — booked balances are the parking lot; a pretransfer uses the unbooked held balance. `:11` — a non-atomic pretransfer is the caller's risk.
- `IMPLEMENTATION_PLAN_BLOCKERS.md` — the lock authority. Relevant locked lines: `:74` sleeve dropped; `:80` and `:385` owner set to `feeTo()` at proxy initialization; `:104` no-fee call returns unchanged; `:128` `donate` is `onlyOwnerOrOperator`; `:162` and `:394` the seven package addresses are written once into the Protocol Aware Repo; `:208` borrowed one-token exit pulls the caller's deployed fraction on the open flag; `:234` and `:240` `Compounded()` has no fields and is "not emitted for a maintenance call that compounds no fees"; `:250`–`:252` the booking rule and the position-ratio reading; `:254` book the actual held balance; `:256` a withdrawal's collected fees are booked; `:282` and `:390` the overstated-maximum refund; `:380` a redemption "does not have a leftover shortfall revert".
- `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (locator only) — `:62` FS-OWN-09 selector mapping; `:108` FS-OWN-30 "There is no residual shortfall after that payment, and no revert for one"; `:114` FS-OWN-33 "swaps about half of the excess"; `:130` FS-X01; `:169` moneyFacet selector set; `:287` FS-UNLOCK-01; `:393` FS-A01 absences; `:400` FS-A08 single-token exit; `:414` FS-A22.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:146,147,149,193` — every `modifyLiquidity` returns a `feeDelta`, computed from the fees owed for the position.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:77,83,94` — fees owed are computed from the pre-update liquidity, so a positive liquidity delta also collects the position's accrued fees.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol:79` — `ModifyLiquidity` carries no token amounts; `:134` — `modifyLiquidity` returns `(callerDelta, feesAccrued)`.
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` — NatSpec: "The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall."
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol:29` — `AmountOutNotMet(uint256 amountOut, uint256 actualOut)`; `:18` — `MinAmountNotMet`.
- `lib/crane/contracts/access/operable/OperableRepo.sol:213` — `onlyOwnerOrOperator` is `MultiStepOwnableRepo._owner() != msg.sender && !_isOperator(...)`; `:134` global operator read; `:160` function-level operator read.
- `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:83` — owner stored by `_initialize`; `:109` — `_onlyOwner` compares `msg.sender` to the stored owner.
- `contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol:151` — the existing pattern for a live `feeTo()` read: `IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo()`.
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:37` — an existing `donate(IERC20 token, uint256 amount, bool prepaid)` in another family.

## Assumptions

- The blockers file is the lock authority. Its "Decision: locked" lines and its "Already locked, and not reopened by this list" bullets are owner locks; a decision that contradicts one and does not say it replaces it is a problem under the brief's rule.
- The PRD is a locator. A PRD row that still reads the old rule is an observation about the pending PRD pass, not a defect in the decision itself, unless the decision's own text is what leaves it contradictory.
- "Recommendation sentence" means the F paragraph in `REPORT.md`. Where the brief's short locator and the report differ, the report governs.
- The fee recipient can be the zero address: the usage-fee rule is conditional on `feeTo` being non-zero (`IMPLEMENTATION_PLAN_BLOCKERS.md:46`), so `feeTo()` returning `address(0)` is a reachable state.
- The V4 fee-delta path was read as code, not executed. No Forge, test, install, or Git command was run.

## Coverage

- F1 through F12: each answered below with Misunderstood, Problem, Changed the recommendation, the reason, and the one missing fact where the decision is not yet copyable.
- F13, F14, F15: recorded as not decided.
- Not done, by design: no implementation, no test or build, no PRD or blockers edit, no peer reads, no new council.

## Conclusions

### F1 — Overstated maximum

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: yes
- Reason: Observation — the recommendation sentence (REPORT.md, F1) is entirely about vault-side accounting: "snapshot each pretransferred input's unbooked balance. If any declared maximum exceeds its snapshot, the whole call is refund-only: process no leg, use no token, pull no shortfall, and do not revert for that difference. Refund each overstated snapshot to the payer in that token." It proposes no standard, no transfer hook, no callback, no ERC-20 change, and nothing about alerting a recipient. The owner's stated reason — "there is no standard that reliably alerts the recipient that a ERC20 token was transfered to them… we can't invent a new standard" — answers a mechanism the recommendation never proposed. Inference: this is a misreading of what was proposed, not a disagreement with it.
- Reason (problem, lock): Observation — the over-maximum behavior is already locked in two places: `docs/vaults/PRETRANSFER_DIRECTIVE.md:9` ("If the maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund the maximum minus the amount used, and do not pull the shortfall.") and `IMPLEMENTATION_PLAN_BLOCKERS.md:282` and `:390` (B-13, locked 2026-11-02, the same rule). Observation — the interface already carries half of it: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`, "The declared input is processed only when present unbooked input covers it… Booked inventory does not fill a shortfall." Inference — the owner's text rejects the mechanism without saying the locked refund rule is replaced, so an implementor can satisfy "no snapshot" by pulling the shortfall, by processing what is held, or by refunding the unbooked balance and pulling nothing. Those three are different code and only the third matches the lock. Two of them also contradict `IStandardExchangeIn.sol:56`.
- Missing fact: whether the locked over-maximum rule survives the rejection of the snapshot — that is, whether the vault still refunds the unbooked balance and pulls no shortfall when a declared maximum exceeds the unbooked balance, or instead pulls the shortfall.

### F2 — Fees on a liquidity-adding user route

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: no
- Reason: Observation — the recommendation (REPORT.md, F2) has two obligations the owner's restatement does not carry: the routes "book any position fees their liquidity modification collects", and "a pass-through collects none". The owner's restatement — "we leave fees untouched while processing any other operation besides donation and compound" — names only the other half ("they do not credit, refund, or deploy those fees… they do not call `compound()`"). Booking is a state write, so "untouched" does not match "book". Observation — the restatement's scope is also wider than the accepted sentence's: the accepted sentence names a deposit, a bundle deposit, and a share-minting `exchangeIn`; "any other operation besides donation and compound" also reaches a withdrawal, where the lock is explicit: `IMPLEMENTATION_PLAN_BLOCKERS.md:256`, "A withdrawal's `modifyLiquidity` collects fees. Book those fees."
- Reason (problem, consequence): Observation — the fees are real, not hypothetical: `Pool.sol:147-149` returns a `feeDelta` from every `modifyLiquidity`, computed at `:193`, and `Position.sol:83,94` computes fees owed from the pre-update liquidity, so a positive liquidity delta also collects the position's accrued fees. Observation — booked versus unbooked decides who may spend the tokens: `docs/vaults/PRETRANSFER_DIRECTIVE.md:7` ("A pretransfer call uses the unbooked held balance") and `IStandardExchangeIn.sol:56` ("Booked holder backing is never pretransfer credit"). Inference — if a deposit's or an `exchangeIn`'s collected fees are left unbooked, they stay in the unbooked held balance and become pretransfer credit for the next caller, which is exactly what the locked "book the actual held balance" rule (`IMPLEMENTATION_PLAN_BLOCKERS.md:254`) exists to prevent for `donate` and `compound`. Two implementors, one booking and one not booking, produce different vault balances after the same deposit and different credit for the next pretransferring caller.
- Missing fact: whether the fees collected by a deposit, a bundle deposit, or a share-minting `exchangeIn` are written to the booked balance — the accepted sentence says they are; the restatement says fees are left untouched.

### F3 — Booked total

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the acceptance matches the locked booking rule: `IMPLEMENTATION_PLAN_BLOCKERS.md:254`, "Book the actual held balance after the deposit, not a calculated leftover"; and the same line's "A failed step reverts" and "Do not invent an extra attempt, a fallback, or a swallowed failure" cover the sentence's revert half. Observation — the zero-size skip is compatible with B-03 at `:104`, where a call with no fees, no donation, and no booked remainder returns with no state change and no event. Inference — nothing in the owner's acceptance contradicts a lock, and the sentence is copyable as accepted.
- Missing fact: none.

### F4 — Position ratio

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the accepted definition matches the locked ratio reading in `IMPLEMENTATION_PLAN_BLOCKERS.md:252`, "The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance", and the ratio excludes what is not part of a liquidity unit: unpaid fees (the deployed read keeps them, `:257`) and booked balances ("A booked remainder is not deployed, so it is not in that read", `:257`). Observation — this vault's position is the full-range salt-zero position, so the stored ticks and the live square-root price are the ratio's inputs (`UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:287` area, FS-UNLOCK-02 item 5). Inference — the acceptance is consistent with the lock and copyable as accepted.
- Missing fact: none.

### F5 — One-token swap size

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the acceptance takes the report's sentence as written, including "size the one-token swap to the greatest integer liquidity the following add can take" and "'about half' does not survive", which retires the PRD text at `:114` ("A one-sided share mint swaps about half of the excess through the pool"). Inference — the decision on F5 is clean on its own. The F6 response adds a sizing rule that contradicts it; that is analyzed under F6 and cross-referenced here.
- Missing fact: none for F5 itself.

### F6 — Unconverted exit principal

- Misunderstood: yes
- Problem: yes
- Changed the recommendation: no (for the F6 sentence itself)
- Reason: Observation — the recommendation (REPORT.md, F6) decides what happens to the unwanted withdrawn principal on a one-token exit: "a one-token exit must convert all unwanted withdrawn principal into the selected token or revert `AmountOutNotMet` without burning shares. It does not pay, book, or abandon that residual." Observation — the owner's added sentences are about how much to swap ("we're sizing our swap so we will always end up with a remainder of provided token… as easy as swapping 48% of the provided token… we will need to either prove that mathematically, or through trial and error fuzz testing"). Nothing in the F6 paragraph proposes a sizing rule; the sizing rule is F5's subject. Inference: the added text answers a mechanism the F6 recommendation did not propose, and it contradicts one of two accepted sentences depending on which swap "our swap" names:
  - If it is the entry swap that funds the add (F5's subject), then "swapping 48% of the provided token" is "about half", which the owner's own F5 acceptance retired (REPORT.md, F5), and it re-opens the PRD text at `:114`.
  - If it is the exit swap that converts the unwanted withdrawn principal (F6's subject), then "we will always end up with a remainder of provided token" is the residual that the accepted F6 sentence forbids: the sentence allows exactly two outcomes, full conversion into the selected token, or a revert that rolls the call back, and it says the residual is never paid and never booked.
  Inference — under either reading two implementors write different code (liquidity-targeted sizing versus a fixed percentage of the input), and under the second reading one of them breaks the accepted F6 sentence.
- Reason (problem, scoping): Observation — the accepted sentence's first clause, "The no-leftover-shortfall-revert sentence removes only the former sleeve top-up", is load-bearing, because both the lock and the PRD state the no-revert rule without that scope: `IMPLEMENTATION_PLAN_BLOCKERS.md:380`, "It does not have a leftover shortfall revert"; `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:108`, "There is no residual shortfall after that payment, and no revert for one." Observation — the error named is real and takes two values: `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol:29`, `AmountOutNotMet(uint256 amountOut, uint256 actualOut)`. Inference — an implementor who reads the lock or the PRD without the scoping clause implements no revert at all, so the scoping clause must travel with the sentence into the lock.
- Missing fact: which swap the "48% of the provided token" rule governs — the entry swap that funds the add, or the exit swap that converts the unwanted withdrawn principal. Until that is named, the response set carries two incompatible sizing rules.

### F7 — `Compounded()`

- Misunderstood: no
- Problem: yes
- Changed the recommendation: yes
- Reason: Observation — the owner chose the branch the report explicitly reserved for them: "So we would emit Compounded when we deploy booked tokens", where REPORT.md's F7 said "A later deploy of fees booked on an earlier withdrawal does not emit under this sentence… Emitting for that later deploy needs a fee-origin store. This proposal does not add one." Observation — the owner also adds a donation event, which the accepted sentence forbade ("Do not add fields and do not name a donation event"); `Donation()` is written with no arguments. Observation — the booked balance is not tagged by origin: `IMPLEMENTATION_PLAN_BLOCKERS.md:254` books "the actual held balance after the deposit, not a calculated leftover… That books a stray transfer as well", and `:250` states that `donate()` and `compound()` process a combined balance "of collected fees and the booked remainder". Inference — "deploy booked tokens" has two readings that produce different code: (a) any deploy of the booked balance emits `Compounded()`, which would also fire on a donation-only deploy and on any deploy of a booked remainder, contradicting the accepted sentence's "Do not emit for a donation-only deploy" and the lock at `:240`, "It is not emitted for a maintenance call that compounds no fees"; (b) only a deploy of tokens known to be fees emits, which requires the fee-origin store the report named and the owner did not add. Under either reading the decision is not copyable as written.
- Reason (problem, lock): Observation — the locked B-11 sentence at `IMPLEMENTATION_PLAN_BLOCKERS.md:234` and `:240` reads "Emit `Compounded()` with no fields when fees are compounded into the reserve… It is not emitted for a maintenance call that compounds no fees." Inference — the owner's chosen branch makes a later deploy of previously booked fees emit, which is the opposite of how that lock reads, and the owner's text does not say the lock is replaced. The change itself is the owner's to make; the missing statement is that it replaces B-11's emission rule.
- Missing fact: whether the `Compounded()` trigger is any deploy of the booked balance, or a deploy of tokens known to be fees — equivalently, whether a fee-origin store is added so booked fee tokens can be distinguished from donation and stray transfers.

### F8 — Seven-address write

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the acceptance matches the lock: `IMPLEMENTATION_PLAN_BLOCKERS.md:162`, "When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. The repo is not given a second per-vault copy of the addresses", and the summary at `:394`. The report's clarifier removes the apparent conflict: "no second copy" forbids another instance store, not the initialization write, and the package immutables stay. Observation — the Crane side is not written yet: `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/` holds no Solidity file, and `UniswapV4SinglePositionAware` does not exist under `lib/crane`, which is what B-07 (`IMPLEMENTATION_PLAN_BLOCKERS.md:156` onward) directs to be built. Inference — the acceptance neither contradicts a lock nor leaves a gap; the sentence is copyable as accepted.
- Missing fact: none.

### F9 — Selector row

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the acceptance matches the lock: `IMPLEMENTATION_PLAN_BLOCKERS.md:156` onward, "The getters on that facet are externally callable on this vault. Do not implement a family `poolManager()` selector", and "Do not put a family-only `poolKey()` selector on the full-spread query facet", with the position getters on the `UniswapV4SinglePositionAware` pair. Observation — the report also states the PRD consequence, that the PRD pass replaces the FS-A01 absence assertion for `poolManager()` and family-only `poolKey()` (`UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:393`). Observation — the only `poolManager()` getters that exist in Crane are on the V4 router and position-manager interfaces (`lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IImmutableState.sol:11`), not on a vault, so nothing pre-existing is being overwritten. Inference — the acceptance is consistent with the lock and copyable as accepted.
- Missing fact: none.

### F10 — `donate` signature

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — a search of `lib/crane/contracts/interfaces` for `donate` returns no matches, so no Standard Exchange interface declares `donate` and the three-argument form creates no collision with an existing Standard Exchange selector. Observation — the accepted signature carries the two funding modes the locked booking rule names for `donate()`: `IMPLEMENTATION_PLAN_BLOCKERS.md:250`, "It uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise"; and the guard at `:128`, "`donate` is `onlyOwnerOrOperator`". Observation — one repository observation, not a defect: an unrelated family already declares `donate(IERC20 token, uint256 amount, bool prepaid)` (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:37`), which is the same ABI shape and therefore the same selector, with a differently named flag. Inference — different vaults, so no functional collision, but the flag name now carries two names in the repository and the owner should know that before the signature is locked.
- Missing fact: none.

### F11 — Batch-swap routes

- Misunderstood: no
- Problem: no
- Changed the recommendation: no
- Reason: Observation — the acceptance also settles the assumption the report put to the owner: "If the one-token exit is a different selector, say so. This sentence assumes it is the single-output `exchangeBundleOut`." The accepted sentence is consistent with the locked borrowed path at `IMPLEMENTATION_PLAN_BLOCKERS.md:208`, "A one-token exit pulls the caller's deployed fraction and swaps only the withdrawn net, on that same open flag", and with the PRD's mapped selectors at `:169` (`exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`) and the single-token exit row at `:400`, "Single-token exit pays only the selected token or reverts. Shares are not burned if it reverts." Observation — the PRD still reads the old rule at `:130` (FS-X01), `:287` (FS-UNLOCK-01) and `:414` (FS-A22), all of which say `exchangeBundleOut` reverts `ManagerAlreadyUnlocked`; the report named the PRD row for F9 but not for F11. Observation — `ManagerAlreadyUnlocked` is not declared in any `lib/crane/contracts` interface; it is a family error named in the PairToken baseline (`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md:1116`). Inference — the stale PRD rows are a pending-pass observation rather than a defect in the decision, but the accepted exception has no PRD row assigned to carry it, and the named error has to be declared by this family.
- Missing fact: none.

### F12 — Owner after initialization

- Misunderstood: no
- Problem: yes
- Changed the recommendation: yes
- Reason: Observation — the owner explicitly reconsidered and replaced the recommendation ("store `feeTo()` once… A later `feeTo()` change does not move the stored owner. No live read.") with a live read of the configured `feeTo()` plus new ownership modifiers and the existing Operable repo. The live read is mechanically available: `contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol:151` shows the pattern `IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo()`. Inference — this is a change, not a misreading, so the owner has earned it; what follows are the gaps the change leaves.
- Reason (problem, mechanism): Observation — Crane's authority is a stored owner. `lib/crane/contracts/access/operable/OperableRepo.sol:213` is `MultiStepOwnableRepo._owner() != msg.sender && !_isOperator(...)`; the operator reads are global at `:134` and function-level at `:160`; the owner is stored by `MultiStepOwnableRepo._initialize` (`lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol:83`) and compared at `:109`. Observation — the lock says the owner is set at initialization: `IMPLEMENTATION_PLAN_BLOCKERS.md:80`, "When a new proxy is initialized, set its owner to the address returned by `feeTo()` on the Vault Fee Oracle. That is the owner `onlyOwnerOrOperator` uses", and the summary at `:385`. Inference — a live read replaces that mechanism, and the owner's text does not say it replaces the lock; the new modifier the owner proposes is exactly what the Crane code requires to do it, so the decision is executable, but the locked initialization sentence and the decision now describe different owners.
- Reason (problem, zero address and the operator path): Observation — the recommendation handled the zero case explicitly ("including `address(0)`", "does not revert because that address is zero", "An operator who is already authorized may still call when the stored owner is zero"), and `feeTo()` returning `address(0)` is reachable because the usage-fee rule is conditional on `feeTo` being non-zero (`IMPLEMENTATION_PLAN_BLOCKERS.md:46`). Observation — `donate()` and `compound()` are `onlyOwnerOrOperator` (`:128`, `:385`). Inference — under a live read, a zero `feeTo()` leaves the vault with no owner at all, and the only cover the owner offers is "integrate the existing Operable repo if possible", which is an undecided condition. Two implementors: one wires the operator path and keeps those functions callable with a zero `feeTo()`, another treats the operator integration as optional and leaves the vault owner-less.
- Reason (consequence of the change, for the record): Inference — with a live read, whoever controls the oracle's `feeTo` becomes the vault's owner at the moment it changes, and the fee recipient is that address, because B-01 mints the usage-fee shares to it (`IMPLEMENTATION_PLAN_BLOCKERS.md:46`). That is precisely what the recommendation's "a later `feeTo()` change does not move the stored owner" was guarding. The owner has chosen it; the council does not answer that product question.
- Missing fact: what the owner is when the live `feeTo()` is `address(0)` — specifically whether an operator is guaranteed to be authorized, and set at initialization, so that `donate()` and `compound()` remain callable in that state.

F13, F14, and F15 were not decided. Silence is not acceptance.

## Limits

- The Uniswap V4 fee-delta and position-fee paths were read as code, not executed. No Forge, test, install, deploy, or Git operation was run, and no peer response was read.
- The F6 conflict depends on which swap "our swap" denotes. I give both readings and do not pick one; the owner's text does not settle it.
- The F7 finding rests on "deploy booked tokens" having two readings. Both are stated; the owner chooses between them.
- The F12 finding is about copyability and the lock, not about whether a live `feeTo()` owner is the right product decision. That is the owner's call.
- Where a PRD row still reads an older rule (F11), I recorded it as an observation about the pending PRD pass, not as a defect in the decision.
- This response is research. It does not authorize implementation or a PRD edit.
