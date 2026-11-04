# MiniMax - initial independent response

## Identity

- Member: minimax.
- Profile: review.
- Phase: initial independent response.
- Owned path: `docs/reviews/se-fullspread-prd-quality-20261103/members/minimax/response.md`.
- Requested role: council-member.
- Requested model: `minimax/MiniMax-M3`.
- Adaptive thinking: requested by the council skill; this runtime did not expose that setting. Recorded as not exposed.
- Write: not exposed for any runtime identity not given here.
- Peers read before submission: no.
- Mode: single initial independent pass. No sub-agents. No Forge, tests, installs, deploys, wallets, or Git. No public search of private excerpts.

## Question and targets

Question: Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?

- Required target, read in full: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-rewrite-20261103`, 644 lines, sections 1 through 10 read end to end.
- Clarity standard: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including the "Owner overrides, 2026-11-03" section (F1, F2, F5, F6, F7, F12). A later override wins.
- Binding for pretransfer sentences: `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- Defect test applied: a sentence two implementors would copy differently, a contradicted sentence left beside a lock, or a requirement too unclear to test. Prose style alone is not a defect.

Result: defects found. Eight, listed in Review findings, each with a location I read, the requirement that failed, the impact, and a fix direction that is advice. The rewrite is materially better than a from-scratch PRD: the 2026-11-03 overrides are carried through, the sleeve removal is consistent, the fee rule and the exit apportionment are stated in arithmetic, and the acceptance rows mostly match the body. The defects below are concentrated in the interface surface, the maintenance routes, the fee source, and two boundary rules, not in the economics.

## Evidence

Read for this review:

1. The PRD in full (lines 1 through 644). Locations cited below are PRD line numbers.
2. The lock file in full, including F1 (line 21), F2, F5, F6, F7, F12 in the 2026-11-03 override section, the B-01 through B-13 decisions, the "Donation and compound booking" lock, the N-series notes, and the closing "Already locked, and not reopened by this list" recap (line 401 is the bullet quoted in Finding 5).
3. The pretransfer directive in full.

Two read-only code checks were made outside the three documents, to avoid reporting findings that the code contradicts. No file was modified.

4. `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` read in full. It declares exactly two functions, `previewExchangeIn` and `exchangeIn`. Line 11 carries `@custom:interfaceid 0x8c8035da`. The `previewExchangeIn` block is at lines 45 to 48 with `returns (uint256 amountOut)` and `@custom:selector 0x89d61912`, which matches the PRD's citation in FS-OWN-08. The `exchangeIn` block carries the comment selector `@custom:selector 0x05562cc8`, the value the PRD says not to adopt.
5. `contracts/protocols/strategy/weir/WeirVaults.sol`, function list only. It has `compound(PoolKey key, bytes calldata hookData)` at line 207 and no `donate`.

Arithmetic I performed for Finding 1 (derivation from the two selectors the PRD itself adopts, offered as evidence and not as a proposed requirement):

- `0x89d61912` XOR `0x05562cc8` = `0x8c8035da`, which is the interface id the Crane interface currently advertises.
- `0x89d61912` XOR `0xd02d3063` = `0x59fb2971`, which is not the advertised value.

## Assumptions

1. "Two implementors would copy it the same way" is read as: two competent engineers working only from the PRD and the named lock sources, without access to this council's discussion, produce the same public surface, the same revert behavior, and the same balances.
2. The PRD's own Precedence paragraph (line 5) is the tie-break rule I test the PRD against. Where the PRD defers to an accepted interface or report, the deferral is acceptable on its own; I report only where the deferral leaves a locked requirement undetermined.
3. A locked owner decision is not a defect just because the PRD words it differently. I report a contradiction only where the PRD's own text pulls in two directions, or where a later override is not applied to a sentence the PRD keeps.
4. Where the PRD fixes behavior but leaves the ABI or error identity open, I treat it as in scope only when the locked behavior cannot be exercised without that choice, or when the PRD presents a closed list that the omission contradicts.
5. The PRD's own statement that the Crane facet code is not written by this text means the Crane getter set is a deliverable of the same directive, so an unspecified getter is a specification gap rather than a deferred decision.

## Coverage

Covered, with no defect found:

- Precedence, goal, and the "what this family is not" list (PRD lines 1 through 60): the not-ERC-4626 rule, the `asset()` prohibition, the no-sleeve rule, the no-`getRate` rule, and the hook-redesign gate are stated once and are not contradicted elsewhere in the file.
- The 2026-11-03 overrides as carried into the PRD: F12 (live `feeTo()` owner check, new modifier, `OperableRepo`) at FS-OWN-14 and FS-PKG-02; F7 (`Donation()` on every successful `donate()`, `Compounded()` only when a deposit is made, both fieldless) at FS-OWN-14; F5 (greatest-liquidity sizing, remainder in the input token) at FS-OWN-33; F6 (one-token exit converts the unwanted side or reverts `AmountOutNotMet`) at FS-OWN-30 and FS-OWN-15; F2 (book `feesAccrued`, pay the caller's rounded-down share of fees and booked balances on exit) at FS-OWN-30, FS-OWN-15 and FS-MONEY-01. No stale sentence from the withdrawn rules sits beside these locks in the PRD body.
- The fee rule (FS-OWN-24): netting from `grossShares`, the 30 percent clamp, the `1e13` precision requirement, no fee on a pass-through, no exit fee. The PRD statement that a pass-through takes no fee also covers the share-as-input exit, since it mints no shares, so I did not report the single-direction wording of "`previewExchangeIn` ... use the depositor's net shares" as a defect.
- Genesis and burn arithmetic (FS-MONEY-01, FS-OWN-24, FS-OWN-27): the first-deposit floor, `grossShares = added liquidity * totalSupply / existing liquidity`, `liquidity * sharesBurned / supplyBeforeBurn`, and the rule that token decimals never enter the share formula. The floor is stated consistently as `MIN_SHARES` minted to `address(0)` and excluded from `grossShares` and from the fee.
- The sleeve removal (FS-OWN-04, FS-OWN-12, FS-OWN-31, section 1.1, section 2): no sleeve target, no `localReserves()`, no `UnderlyingUnavailable` for an unpullable fraction.
- The borrowed-unlock path (FS-UNLOCK-01 through FS-UNLOCK-03): the two dispatch paths, the settlement rules, the guard, the `ManagerAlreadyUnlocked` surface list, and the prohibition on copying the global delta-count check. FS-UNLOCK-02 and FS-OWN-13 and FS-OWN-31 agree.
- The accepted return ABI and the bundle signatures (FS-OWN-08, FS-OWN-09): the tuple return, the four bundle signatures, the computed selectors, the six length-gated consumers, the three ABI bindings, and the index rule are stated once and are not contradicted. The PRD's citation of `IStandardExchangeIn.sol` lines 45 to 48 is accurate.
- The exit apportionment and the preview/execution match (FS-OWN-30): the fee claim, the booked claim, the principal removal, the one-token and both-token behaviors, and the explicit statement that the exit quote is the share valuation and is not `getRate()`.
- The quote rule and the withdrawn rate (section 6, FS-RATE-01): no step cap, no `QuoteWorkLimit`, no vault rate, and the FS-OWN-29 external-provider rule.
- The hook section (FS-HOOK-01 through FS-HOOK-04), the test harness and acceptance rows (FS-TEST-01 through FS-TEST-04), the audit absence table, and the non-goals in section 9. The acceptance rows match the body on every rule I checked, including FS-A08, FS-A11, FS-A19 through FS-A23, FS-A30, FS-A32 and FS-A34.
- The pretransfer refund arithmetic in FS-OWN-32: in the case where the declared maximum is within the unbooked balance, the refund is the maximum minus the amount used; in the case where it is larger, refunding the whole unbooked balance pins the amount used at zero, which agrees with F1's "Do not spend it" and with the directive's "Do not refund the maximum minus the amount used". The PRD's wording differs from F1's wording but does not change the arithmetic, so I did not report it as a divergence. Finding 8 covers the part that the arithmetic does not settle.

Not covered, and out of scope for a clarity review of this file:

- Whether the accepted ABI report's consumer enumeration and the 1626-occurrence index are complete, and whether the 64-byte return migration is correct.
- The 45-ID audit disposition and the second-review findings.
- The correctness of the economics themselves, the hook family topologies, the gas ceilings, and the Crane implementation of the two facets.

## Review findings

Severity is my own judgment of how much copy-divergence the defect permits.

### Finding 1 - The ERC-165 interface id sentence in FS-OWN-08 cannot be copied as written

Location: PRD line 67 (FS-OWN-08) and PRD line 111.

Requirement that failed: FS-OWN-08's sentence "The ERC-165 id of `IStandardExchangeIn` stays, because it is the XOR of those selectors", read together with the same paragraph's "Selectors stay `0x89d61912` and `0xd02d3063`" and line 111's "Do not adopt the comment selector `0x05562cc8`".

What the evidence shows: the Crane interface declares exactly those two functions and advertises `@custom:interfaceid 0x8c8035da`, while its `exchangeIn` block carries the comment selector `0x05562cc8`. The advertised id is the XOR of `0x89d61912` and the comment selector the PRD rejects, and it is not the XOR of the two selectors the PRD adopts.

Impact: one implementor reads "stays" and keeps advertising the currently published id; the other reads "because it is the XOR of those selectors" and registers the recomputed value, which is also the value FS-OWN-09's "Recheck those ids with `type(I).interfaceId` before any ERC-165 registration" points at. The two vaults answer `supportsInterface` differently for the same interface, and a consumer or hook that gates on that id works under one and fails under the other. FS-A01's "The reviewed selector manifest succeeds through the proxy" cannot be asserted from the PRD alone.

Fix direction: state which interface id this vault advertises for `IStandardExchangeIn` and on what basis, and reconcile that explicitly with the id the Crane interface currently publishes, so that the word "stays" is either justified or removed. Leave the computation to the implementor; the arithmetic in Evidence is offered as a check, not as a new requirement.

### Finding 2 - `donate` and `compound` have no stated public signature although locked behavior depends on their inputs

Location: PRD line 42 (FS-OWN-09 delta table), PRD line 113 (FS-OWN-09), PRD line 168 (FS-OWN-14), PRD line 190 (FS-OWN-21), PRD line 410 (FS-MONEY-01), and the `moneyFacet` row in FS-FACET-01.

Requirement that failed: FS-MONEY-01 calls `donate` and `compound` "locked" public selectors, and FS-FACET-01 forbids inventing selector hex beyond the accepted ones, but the PRD never states the parameter list of either route. The locked behavior depends on inputs the PRD never fixes: which underlying tokens are processed, the amount directed, the share-donation leg, and how the `pretransferred` flag is carried. FS-OWN-21 says `donate` "accepts `vaultTokens()` and the share" and "uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise", which reads as a token set, a share amount and a flag; it does not say whether the flag is one value or one per token, or whether the share leg is a separate entry point.

Impact: two implementors build different public surfaces for the two maintenance routes, so the selectors, the caller shapes, and the FS-A rows that call them differ. The F12 live-`feeTo()` authorization and the operator path in `OperableRepo` attach to a surface that has no agreed shape. Weir offers `compound(PoolKey key, bytes hookData)` and no `donate`, and the PRD itself calls `donate` "not a Weir function", so no template is named as the adopted source.

Fix direction: state the inputs each locked maintenance route takes, or name the accepted interface whose signature these routes adopt, so that the behavior in FS-OWN-14 and FS-OWN-21 can be exercised against a single agreed surface. Keep the encoding and the selector computation as implementation choices; I am not proposing a selector or a signature.

### Finding 3 - The maintenance call's fee source is unstated, and the PRD does not say whether taking it changes position liquidity

Location: PRD line 168 (FS-OWN-14), PRD line 176 (FS-OWN-14 event paragraph), PRD line 220 and 222 (FS-OWN-30), FS-OWN-07's deployed-reserve paragraph, PRD line 417 (FS-MONEY-01).

Requirement that failed: FS-OWN-14 says both maintenance routes "take collected fees and the booked remainder and process that combined balance", but "collected fees" has no stated source and no collection step is described. Nothing states whether the maintenance call changes the position's liquidity, and that number is the `existing liquidity` denominator for the next mint and the principal removed on the next exit. Separately, the PRD never states whether the `feesAccrued` a deposit books and the "collected fees" a maintenance call processes are one accrual or two.

Impact: two implementors produce different existing-liquidity denominators, different minted amounts on the following deposit, different exit principals, and, in the case where one accrual is both booked and collected, a double count of fees in the booked balances. FS-A05, FS-A07 and FS-A11, and the APEX-2026-048 absence row that a no-op maintenance call returns unchanged, cannot be written from the PRD alone.

Fix direction: state, in requirement terms, where the maintenance call's fee balance comes from, whether taking it changes the position's liquidity, and whether the deposit-booked `feesAccrued` and the maintenance fee balance are the same accrual or separate ones. The collection mechanism itself should stay an implementation choice.

### Finding 4 - Two locked rejections name no error while every neighbouring rejection names one

Location: PRD line 416 (FS-MONEY-01), PRD line 242 (FS-OWN-32), PRD lines 321 to 327 (section 3 family-error list), PRD line 556 (FS-A05).

Requirement that failed: FS-MONEY-01 says "reject added liquidity less than or equal to `MIN_SHARES`" with no error. FS-OWN-32 says "A zero recipient, or the vault as recipient, reverts" in a sentence run that names `InvalidRoute` for `tokenIn == tokenOut`, `EmptyExchange` for `amountIn == 0` and `TokenNotExchangeable` for `address(0)`. Section 3 presents a fixed family-error list and then forbids declaring `IncompleteConversion`, `QuoteWorkLimit` and `ExchangeInWithRefundNotAvailable`, so the list reads as closed.

Impact: one implementor reuses an accepted interface error, the other adds a family error, and the family list's closedness becomes ambiguous. The two rejections are then assertable only as a generic revert, which is weaker than the rest of the row set and leaves the manifest in FS-A01 open to a new selector.

Fix direction: name the error for each of these two rejections, or state that the family-error list is open for them and that the choice belongs to the implementor. I am not choosing an error here.

### Finding 5 - The precedence rule does not settle a dated override against an undated recap line that restates the superseded rule

Location: PRD line 5 (Precedence), FS-OWN-30 at PRD lines 220 to 222, lock file F2 in the 2026-11-03 override section, lock file line 401 in the closing recap.

Requirement that failed: the PRD's precedence sentence says a 2026-11-03 override "wins over an earlier sentence in that file". The recap bullet at lock file line 401 sits later in that file, carries no date, and says "A withdrawal pays only the principal fraction. The 2026-11-02 sentence that the withdrawal collects and books fees is overridden on 2026-11-03." F2, dated 2026-11-03, is the override of exactly that principal-only rule and requires the withdrawal to pay the caller's share of `feesAccrued` and of each booked balance. The PRD's own FS-OWN-30 is correct, but nothing tells the implementor that the recap bullet is superseded.

Impact: an implementor who treats the lock file's "Already locked" list as operative copies "a withdrawal pays only the principal fraction" and implements the rule F2 withdrew, contradicting FS-OWN-30 and the FS-A11 and APEX-2026-048 rows. The divergence F2 exists to prevent is reintroduced by a summary line rather than by a lock.

Fix direction: extend the PRD's precedence sentence so that a dated 2026-11-03 override wins over any undated recap or summary sentence in the lock file, and name FS-OWN-30 as the operative withdrawal rule. The coordinator may prefer to route this to the lock file's recap bullet instead of to the PRD; either resolution removes the contradiction, and the PRD is not the only place it can be fixed.

### Finding 6 - `bindingHash` is given two different scopes in one paragraph

Location: PRD line 375 (FS-PKG-01) against PRD line 385, and PRD line 552 (FS-A02).

Requirement that failed: line 375 says the six Uniswap V4 architecture addresses "are package immutables of the same deployment. They are infrastructure bindings and are covered by `bindingHash`, the same as `poolManager`." Line 385 says "`bindingHash` covers every `PkgInit` field", and the six addresses are not listed `PkgInit` fields; line 375 also says the text does not invent their struct field names. FS-A02 then uses the broader wording, "changes if any facet, library, or infrastructure binding changes", so the acceptance row and the two sentences do not describe the same set.

Impact: one implementor hashes only the listed `PkgInit` fields and fails FS-A02, the other hashes the six addresses too. The observable consequence is package identity: whether two chains' address sets produce the same binding hash, and therefore the same salt and the same deployed package address.

Fix direction: state in FS-PKG-01 whether the six architecture addresses are part of the binding hash as infrastructure bindings alongside the `PkgInit` fields, so that FS-PKG-01 and FS-A02 describe one set.

### Finding 7 - Whether `poolKey()` remains callable on the vault reads two ways

Location: PRD line 53 (FS-OWN-02), PRD line 61 (FS-OWN-06), PRD line 314 (the `queryFacet` row), PRD line 552 (FS-A01).

Requirement that failed: FS-OWN-02 opens "`poolKey()` stays as information, not as a full-spread-only getter", which can be read as a getter that remains callable through the Crane pair, or as the pool key remaining known to the vault without a getter. FS-OWN-06 enumerates the getters to keep, "`tickLower()` and `tickUpper()`" and "`positionLiquidity()`", and `poolKey()` is not among them, while the same sentence says the pair stores the full `PoolKey`. FS-A01 then requires the family-only `poolKey()` to be absent and the Crane getters to be callable, which both readings satisfy.

Impact: the vault's external selector surface differs between the two readings, so the manifest check in FS-A01 and any consumer that expects `poolKey()` on the vault behave differently. Since the PRD makes the Crane facet part of this directive rather than a later decision, the getter set is chosen by the same implementor, and the PRD does not fix it.

Fix direction: state whether `poolKey()` is exposed through the Crane pair for this vault, or state that the pair's getter set is decided in Crane and that FS-A01 asserts only the family-facet absence. Both are consistent with the PRD's statement that the Crane code is not written by this text.

### Finding 8 - The over-declared pretransfer case fixes the refund but not what the route then does

Location: PRD line 238 (FS-OWN-32, the pretransfer paragraph), lock file F1 at line 21, and the pretransfer directive.

Requirement that failed: FS-OWN-32 restates the case where the caller's maximum exceeds the unbooked balance as "refund that unbooked balance. Do not spend that declared amount. Do not pull the shortfall. Do not refund maximum minus used. A larger maximum is not a revert", and then states that "This sentence does not say what the other declared amounts in the same call do." The arithmetic settles the refund, and F1 rules out the revert answer, so the route continues with nothing consumed for that token, but the PRD never says what the route does next, and it expressly leaves the other declared amounts in the same call open.

Impact: in a bundle route where one token's declared maximum exceeds its unbooked balance, one implementor processes the remaining token and refunds the shortfall while the other refuses the whole call, and the two produce different refunds, different minted amounts and different revert behavior. The same gap exists for the single-token route, where a zero contribution is not described. FS-A07 and the APEX-2026-039 absence row cannot be written for this case.

Fix direction: state what the route does when a declared maximum exceeds the unbooked balance, including what happens to the other declared amounts in the same call, without changing the locked refund rule. The gap is partly disclosed in the text, so the coordinator may treat it as an accepted boundary; I report it because F1 forbids the answer the reader would otherwise reach for.

## Limits

- This advisory does not authorize implementation, a PRD edit, or a lock-file edit. It is a copy-divergence review only.
- I did not run Forge, tests, builds, installs, deploys, wallet operations, or Git, and I did not read any peer response.
- The only files I opened beyond the PRD, the lock file, and the pretransfer directive were `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and the function list of `contracts/protocols/strategy/weir/WeirVaults.sol`, read only to avoid reporting findings the code contradicts. I did not verify Uniswap V4 PoolManager fee-collection semantics, so Finding 3 states the PRD gap and not any claim about how the pool behaves.
- I did not verify the accepted return-ABI report, the consumer enumeration, the occurrence index, the 45-ID audit disposition, or the hook family topologies. The PRD's own citations into the Crane interface were checked and are accurate.
- My severity labels and my reading of "two implementors" are judgment, not measurements. The coordinator may reasonably downgrade Finding 6 and Finding 7 and treat Finding 8 as an accepted boundary.
- No requirement, economics, event, error, or selector is invented in this review. Where a fix direction asks the PRD to name something, I state what must be named and leave the value to the owner or implementor.
