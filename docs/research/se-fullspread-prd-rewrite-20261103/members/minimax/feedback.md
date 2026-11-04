# MiniMax advisory — `se-fullspread-prd-rewrite-20261103`

## Identity

- Member: `minimax`. Requested route: `minimax/MiniMax-M3`. Profile: research. Phase: advisory on the coordinator's merged text. Role: council member, one advisory pass.
- Reviewed artifact: `docs/research/se-fullspread-prd-rewrite-20261103/coordinator/draft.md`, revision `fullspread-se-prd-rewrite-20261103`, the coordinator merge of the four initial responses in `docs/research/se-fullspread-prd-rewrite-20261103/members/`.
- Sources this advisory rests on: the merged draft as read, the run brief, and the lock passages cited below from `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` (B-09, the 2026-11-03 override section, the "Already locked, and not reopened by this list" section, N-01) and `docs/vaults/PRETRANSFER_DIRECTIVE.md`. No peer response and no peer feedback was read.

## Draft under review

The draft is the single replacement text for `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. It keeps the section order and the requirement IDs, states the 2026-11-03 overrides as applied sentences, and carries the accepted return ABI, the six fail-closed preview consumers, and the three one-word ABI bindings.

## Disposition

**support-with-reservations.**

The draft copies the locked decisions without adding economics and without leaving a contradicted lock sentence standing beside its replacement. I found no invented fee, event, error, selector, or share formula, and I found no place where a 2026-11-03 override is contradicted by an older sentence that survived the merge. The six reservations below are copyability and classification gaps. Three of them (C1, C2, C3) are implementation-visible and should be applied before publication. None of them changes an owner lock, and none of them opens a product question.

## Concerns

### C1. The one-token exit has no named route

- Location: FS-OWN-30 (first paragraph on exits), FS-OWN-09 ("The mapped redeem is the both-token exit... The one-token exit is FS-OWN-30."), FS-FACET-01 (`moneyFacet` selectors: `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`), FS-OWN-13, FS-OWN-31, FS-UNLOCK-01, FS-A22.
- Why two readers diverge: `exchangeBundleOut` takes `address[] tokensOut`, so the one-token exit can be read as `exchangeBundleOut` with one element. That reading then collides head-on with FS-UNLOCK-01 and FS-A22, which keep `exchangeBundleOut` reverting `ManagerAlreadyUnlocked` while the manager is unlocked, and with FS-OWN-31, which requires a borrowed one-token exit to work on that same open unlock. The other reading is that the one-token exit is the canonical exact-input `exchangeIn` with the share as `tokenIn` — the only remaining selector, since `exchangeOut` reverts `ExchangeOutNotAvailable` and FS-OWN-09 already maps the both-token exit to `exchangeBundleOut`. The two readings differ in selector set, in unlocked-path behavior, and in which requirements (FS-UNLOCK-01, FS-A22, FS-OWN-31) apply. As written, the sentence cannot be copied into an implementation without the implementer choosing.
- Fix direction: one sentence naming the selector for the one-token exit and stating that it is the canonical exact-input `exchangeIn` with the share as `tokenIn` and one underlying as `tokenOut`, keeping `exchangeBundleOut` as the both-token exit of FS-OWN-09. Do not restate the amounts; FS-OWN-30 already owns them.

### C2. The family error list does not cover every error the requirements use

- Location: FS-FACET-01 ("Family errors, declared on the family interface, with selectors computed later" lists only `InvalidUnlockedContext()` and `SettlementMismatch()`; the accepted-interface list that follows does not contain the others either), against FS-UNLOCK-01 and FS-A22 (`ManagerAlreadyUnlocked()`), FS-UNLOCK-02 item 1 (`ReentrantOperation`), FS-OWN-32 (`InvalidRoute`), FS-OWN-13 (`AlreadyUnlocked`).
- Why two readers diverge: the draft states two different rules for declaring errors — family errors are declared with computed selectors, accepted interface errors are not redeclared — and then names three errors that fit neither rule. An implementer must guess whether `ManagerAlreadyUnlocked`, `ReentrantOperation`, and `InvalidRoute` are new family declarations (and compute their selectors) or are inherited from an accepted interface (and not redeclare them). The naming also reads as one condition described by two names: FS-OWN-13 says `unlock()` reverts `AlreadyUnlocked` (the manager's own error), while FS-UNLOCK-01 and FS-A22 require `ManagerAlreadyUnlocked` (the vault's guard), and the draft never says that these are two different errors raised on two different sides.
- Fix direction: classify each of `ManagerAlreadyUnlocked()`, `ReentrantOperation`, and `InvalidRoute` as either a family error declared on the family interface or an error inherited from a named accepted interface, and state in one clause that `AlreadyUnlocked` is the manager's error and `ManagerAlreadyUnlocked` is the vault's. Do not add an error that the requirements do not already use.

### C3. The six architecture addresses are not visibly covered by `bindingHash`

- Location: FS-OWN-01 ("The Uniswap V4 architecture addresses are package immutables, set when that package is deployed, as the other package bindings are... A deployment on another chain uses the same package code and passes that chain's addresses."), FS-OWN-16, FS-OWN-18, FS-PKG-01 (`PkgInit` lists `poolManager`, `registry`, `oracle`, `diamondFactory`, `linkedLibraries`; "The other six architecture addresses are package immutables of the same deployment. This text does not invent their struct field names."), FS-PKG-01 ("`bindingHash` covers every `PkgInit` field"), FS-A02 ("`bindingHash` changes if any facet, library, or infrastructure binding changes"), FS-PKG-02.
- Why two readers diverge: the PoolManager address is in `PkgInit` and is covered by `bindingHash`. The other six addresses are described as package immutables of the same deployment, but their fields are deliberately not named, so a reader cannot tell whether they are `PkgInit` bindings covered by `bindingHash` or package-level immutables outside it. If they are outside, then two package deployments that differ only in those six addresses share a `bindingHash` and therefore a salt, which contradicts FS-A02 for exactly the class of address FS-A02 calls an infrastructure binding. The consequence is a wrong vault address, not only a wording problem.
- Fix direction: state that all seven architecture addresses are `PkgInit` bindings covered by `bindingHash`, or state how a deployment that differs only in those addresses is distinguished. Keep the existing restraint about not naming struct fields the PRD does not have to invent; the coverage sentence does not require field names.

### C4. The floor mint is named as a mechanism, and the mechanism has two possible referents

- Location: FS-OWN-11 ("The mint uses `_mint`, which writes `balanceOf` and `totalSupply` directly. It does not use `ERC20Repo._increaseBalanceOf`. That helper reverts `ERC20InvalidReceiver` for `address(0)`."), FS-A05 ("The floor is `MIN_SHARES` of supply, minted to `address(0)` through `_mint`"), FS-FACET-01 (`erc20Facet` is a shared Crane facet with the nine canonical ERC-20 and metadata selectors), and N-01 in the blockers file, which records the same Crane behavior and states "Not a blocker. The holder does not change."
- Why two readers diverge: the sentence identifies the Crane repo helper by its neighbors, not by name. A reader who wires the shared ERC-20 facet's own mint path has a different `_mint` in front of them, and the PRD never says the floor mint must be the repo helper rather than the shared facet's path. A reader who treats "through `_mint`" as a mechanism requirement also inherits a Crane-internal detail as a product rule that no test can assert and that no lock states.
- Fix direction: keep the behavioral requirement as the requirement — the floor is `MIN_SHARES` of supply held at `address(0)`, included in `totalSupply()`, and the mint does not revert — and name the helper explicitly as the currently correct implementation, so that an implementer does not pick a different `_mint`. One clause, no storage design.

### C5. "That call spends nothing" is wider than the refund arithmetic it states

- Location: FS-OWN-32 ("If the maximum is larger than the unbooked balance, refund that unbooked balance. Do not spend it. Do not pull the shortfall. Do not refund maximum minus used. A larger maximum is not a revert. The caller may declare any maximum. That call spends nothing and does not mint shares from the unspent balance."), FS-X04, FS-OWN-20.
- Why two readers diverge: the 2026-11-03 override in the blockers file states the refund arithmetic for an over-declared leg — refund the unbooked balance, do not spend it, do not pull the shortfall, a larger maximum is not a revert — and it records that this is the earlier lock and not a new question. It does not say what happens to the other legs of a bundle when one declared leg is over-declared. "That call spends nothing" can be read as the declared leg spends nothing while the bundle's other legs still process, or as the whole call is inert. The two readings give different share counts and different refunds on a bundle deposit.
- Fix direction: scope the sentence to the declared leg, or state explicitly that the whole call is inert. Whichever is intended, the sentence should not appear to settle a branch the override did not settle, and no new refund rule should be added.

### C6. The WETH substitution address has no source for a deployment on another chain

- Location: FS-OWN-17 ("That substitution reads the network `WETH` constant, `WETH9` on Robinhood. Removing `PkgInit.wrappedNative` and the getter did not withdraw that constant. This PRD does not add a package field or a getter for it."), FS-OWN-22 ("The address read for that substitution is the network `WETH` constant in FS-OWN-17."), against FS-OWN-01 ("Do not hardcode `ROBINHOOD_MAIN.sol` into the package. Those constants are the Robinhood values, not the storage rule. A deployment on another chain uses the same package code and passes that chain's addresses.") and FS-OWN-18.
- Why two readers diverge: on a non-Robinhood chain a reader either hardcodes Robinhood's `WETH9`, which makes `vaultTokens()` substitute an address that is not that chain's WETH for native, or adds a package binding for the substitution address, which N-05 locked out ("Remove `PkgInit.wrappedNative`... There is no `wrappedNative()` getter"). The draft does not say which reading is intended, and the two readings differ in observable behavior on exactly the deployment shape FS-OWN-01 authorizes.
- Fix direction: state the source of the substitution address for a deployment on another chain, or record that source as an unresolved owner item. Do not name a new package field; N-05 removed the field, and this reservation does not reopen it.

## Borrowed unlock: `donate`, `compound`, and the bundle routes

I do not believe any of them must run on a borrowed unlock, and I do not ask the coordinator to change FS-UNLOCK-01, FS-A22, or the section 2 constraint list.

The lock text that reaches a borrowed unlock is the one-token exit, and it reaches it through the canonical exact-input route. `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-09 ("Borrowed one-token exit units"), states: "On a borrowed unlock the vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly. A one-token exit pulls the caller's deployed fraction and swaps only the withdrawn net, on that same open flag." The "Already locked, and not reopened by this list" section repeats it: if another caller holds the PoolManager unlock, this vault does not call `unlock()`, it calls `modifyLiquidity` and `swap` directly, pulls the caller's deployed fraction, and settles its own deltas before returning. The draft carries this as FS-OWN-13 and FS-OWN-31.

The coordinator's record of the batch-swap lock — that `ManagerAlreadyUnlocked` stays for `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`, and that the borrowed path is `exchangeIn` only — is the reading I tested against, and I found no lock sentence in the admitted sources that requires a bundle route, `donate`, or `compound` to work while the manager is unlocked. The draft's own internal rules agree: FS-OWN-14 and FS-UNLOCK-02 item 4 forbid `compound()` from the borrowed path, FS-UNLOCK-03 forbids it from the callback, and FS-OWN-14 forbids a deposit, a withdrawal, and `exchangeIn` from calling `compound()` or `donate()`.

The one place this could break is C1, and it breaks through naming rather than through economics. B-09's borrowed one-token exit is only reachable while the borrowed path is `exchangeIn`, so the PRD has to say the one-token exit is `exchangeIn`. If an implementer reads the one-token exit as `exchangeBundleOut` with one element in `tokensOut`, the same draft sentence that keeps `exchangeBundleOut` reverting `ManagerAlreadyUnlocked` would block the exit that B-09 keeps. Naming the route resolves it in the direction the locks already point; widening the borrowed path to `donate`, `compound`, or the bundle routes is not required by anything I read.

## What was not adopted from others

- No peer response and no peer feedback for this run was read, so this advisory adopts and rejects no member's position. The draft's section 10 participation table is treated as history from revision `fullspread-se-prd-weir-align-r1` and is not evidence about this revision.
- The draft's section 2.1 "Dispositions retained from advisory" is confirmed rather than reopened: the "Unlocked surface" row (canonical `exchangeIn` only) and the "Quote method" row (the mathematical result of the operation, no step cap) both match the locks I read.
- Not adopted: any reading that widens the borrowed-unlock path to `donate`, `compound`, `exchangeBundleInForSingleOut`, or `exchangeBundleOut`, which no admitted lock requires.
- Not adopted: any reading that places the one-token exit on `exchangeBundleOut`, which would contradict FS-UNLOCK-01 and FS-A22.
- Not adopted: a WETH substitution address taken from a hardcoded `ROBINHOOD_MAIN.sol` constant on a chain other than Robinhood, and a package field for that address, which N-05 locked out. C6 asks which reading is intended; it does not choose one.

## Limits

- This advisory rests on the merged draft as read plus the cited lock passages. It did not re-derive the whole lock set, did not re-read the four initial responses, and did not check the merged draft against every line of the current PRD. Where the merged draft and the current PRD differ, this advisory judges the merged draft.
- C3 and C6 are consistency questions about coverage and chain portability. They are stated as copyability gaps and not as proposed designs; the owner may close either with an existing mechanism the PRD already names.
- C5 concerns wording scope only. It does not propose a refund rule and does not reopen the 2026-11-03 override.
- No claim here is a safety clearance, an audit result, or an implementation authorization. Compiler, gas, fork, and test evidence remain future work.

This advisory neither replaces the merged draft nor authorizes an implementation, a deployment, or a PRD edit. The coordinator holds the merge and the single PRD write. No further round is requested.
