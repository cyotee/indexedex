# Astra — RC-01 explicit-holder implementation-plan draft

Date: 2026-10-11. **Draft input to the coordinator, not the final implementation plan.**

## Decision readiness and authorization

**An implementation plan can be written without a further owner decision.** The complete current 119-line `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` was read. Its 2026-10-11 owner decision settles the V3 target and withdraws the earlier self-delegatecall permission. The cited exact-input settlement exists, and both yield targets inherit it through their respective OutBase.

**Writing this plan does not authorize implementation.** No code, tests, configuration or PRD were edited. No shell, Forge, tests, deployment or cross-review was performed. No file under this task's reviewers directory was read. This draft is the only output written.

The plan follows the PRD's project law: no external call or delegatecall to the same vault to choose a holder or reuse redemption settlement. **The V3 FullSpread and legacy V4 yield facets call their inherited internal settlement and pass the holder. They do not call `address(this)` to reach settlement.** A call to a different execution delegate is not a self-call, but is not the yield reuse path for these two facets.

## 1. Freeze scope and inventory before editing

In a separately authorized implementation session:

1. Re-read the current PRD and repository coding/testing instructions; retain existing unrelated working-tree changes.
2. Inventory production `_redeemVaultHeld` and `_standardRoute` overrides, including typed external calls and delegatecalls. Do not equate absence of literal `.call` syntax with absence of calls to self.
3. Classify each occurrence as money-path self-dispatch, internal holder settlement, dispatch to a different execution delegate, or read-only discovery/preview. PRD line 74 expressly excludes inventing a defect from a view `previewExchangeIn`.
4. Cite already-conforming families and leave their settlement unchanged. Do not rewrite the shared base's ordinary dispatch for excluded families under PRD line 112. Another actual offending yield-redemption self-dispatch discovered by the required inventory is included only to remove that dispatch, not to redesign its family.

Fresh bounded symbol search under `contracts/**/*.sol` found the base plus 20 production `_redeemVaultHeld` overrides. `_standardRoute` overrides were found in V3 FullSpread and legacy V4, in addition to the base declaration. Other holder overrides are ERC-4626, Morpho, Lido, Rocket, EtherFi, Aave Stata, Aave cross-version, Balancer V3 pool, constant-product SY, Wings, hookless FullSpread, Pons FullSpread, single-CP, dual-CP, orbital, weighted, curve-quad and Balancer-quad hooks. This search is an inventory starting point, not a claim that every body was freshly audited in this planning turn.

Do not expand into other APEX remediations, change exact-output fill checks, delete retained packages, restore deleted packages, or change unrelated protocol economics.

## 2. Source-verified settlement and caller map

Path prefixes used in the tables:

- **V3:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- **V4:** `contracts/protocols/dexes/uniswap/v4/` — the retained legacy package, not hookless or Pons FullSpread.

Every call site below was located by a current source search and its relevant body re-read. Line numbers describe the pre-implementation tree.

### V3 FullSpread

| File / current lines | Current role | Required holder propagation |
|---|---|---|
| V3 `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:12–16` | Inherits InBase | Keep inheritance; the yield facet already has the internal settlement. No bridging self-call or second exit engine is needed. |
| V3 `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183–210` | `_executeZapOutExactIn`; sleeve-path burn at `:204`; calls free-path helper at `:210` | Add an explicit holder argument. Burn that holder in the sleeve path and forward the same holder to the existing free-path helper. |
| Same InBase `:213–228` | `_executeFreeZapOutExactIn`; free-path burn at `:224` | Add the holder argument and burn it. Keep existing pool-exit calculation, payout, reserve synchronization and rebalance sequencing. |
| V3 `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19–24` | Existing non-yield external wrapper `executeZapOutExactIn` calls internal settlement | Keep the wrapper's current external signature. Its internal call must explicitly pass `address(this)`, because the public SE path has already delivered shares into vault custody. Preserve its direct-call rejection at `:23`. Do not pass the unchanged external `msg.sender` as holder here. |
| V3 `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58–62,80–95` | Public exchangeIn share delivery, then dispatch to a different IN execution delegate | Preserve share-delivery and exact-delivery checks. Keep existing wrapper encoding/signature because only the internal settlement signature changes. This public path continues to burn delivered vault-held shares through the wrapper. |
| V3 `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24–34` | Vault-held yield route currently discovers and calls the IN execution delegate | Replace settlement dispatch with a direct inherited `_executeZapOutExactIn` call, passing the vault as holder and the requested shares. No self lookup or delegate dispatch is needed for this yield path. |
| Same OutQueryTarget `:39–53` | Ordinary yield route currently moves caller shares then self-delegatecalls exchangeIn with true | Remove the share staging and self-dispatch for redemption. Directly invoke inherited exact-input settlement with the original caller as holder. Do not authenticate an ordinary holder as an external pretransfer caller. Preserve unrelated non-redemption routing. |

**The V3 target is `_executeZapOutExactIn` in InBase, not `executeZapOutWithdrawal`.** Do not edit `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.executeZapOutWithdrawal` to satisfy this task. That exact-output entry and its holder/refund semantics are explicitly excluded by PRD lines 29, 93 and 105.

### Legacy V4

| File / current lines | Current role | Required holder propagation |
|---|---|---|
| V4 `UniswapV4StandardExchangeOutBase.sol:17–24` | Inherits InBase | Keep inheritance; use inherited internal settlement from the yield facet. |
| V4 `UniswapV4StandardExchangeInBase.sol:121–154` | `_executeZapOutExactIn`; sleeve-path burn at `:147`; free-path call at `:154` | Add the explicit holder argument, burn that holder in the sleeve path, and forward it unchanged to the free-path helper. |
| Same InBase `:157–198` | `_executeFreeZapOutExactIn`; burn at `:195` | Add and use the same holder argument. Keep pool math, payout, synchronization and rebalance unchanged. |
| V4 `UniswapV4StandardExchangeInExecutionDelegate.sol:16–20` | Existing public-SE execution wrapper calls internal settlement | Mechanically update the internal call to pass `address(this)` while retaining the external wrapper signature. This dependency edit is necessary for the PRD's InBase signature change; it does not authorize a new externally supplied holder. |
| V4 `UniswapV4StandardExchangeInTarget.sol:70–74,92–108` | Public exchangeIn delivers shares then calls a different execution delegate | Preserve actual delivery, external wrapper encoding and post-execution TWAP update. The wrapper chooses the vault holder for shares already delivered by this public route. |
| V4 `UniswapV4StandardExchangeOutMultiQueryTarget.sol:17–24` | Vault-held yield path currently externally calls exchangeIn on the vault | Replace with direct inherited settlement, passing the vault as holder and requested amount. Remove the comment recommending external re-entry. |
| Same OutMultiQueryTarget `:27–34` | Ordinary yield path stages caller shares and changes the internal flag | Remove staging/flag substitution for redemption. Pass the original caller directly to inherited settlement. Do not route it through the vault-held override. Preserve unrelated non-redemption routing. |
| V4 `UniswapV4StandardExchangeCommon.sol:1299–1316` | `_secureShareDelivery` includes special self-caller acceptance | Delete only the self-caller false-flag bypass at `:1302–1305`. Preserve the ordinary public false-flag transfer and the real public true-flag caller gate/local-credit validation. |

### Signature-completeness check

Use one consistent holder-argument position for each internal settlement and its free-path helper, then update all direct callers in the tables as one change set. The current production search found the two IN wrappers as callers of these two families' internal `_executeZapOutExactIn`, and each exact-input function as the caller of its own `_executeFreeZapOutExactIn`. The yield paths become additional direct internal callers after the repair.

The public wrapper signatures can remain unchanged: their caller has already delivered shares, so they explicitly supply the vault holder internally. This avoids changing encoded selector strings in both InTargets or exposing a new holder-selectable wrapper API. The V3 yield target's old encoded wrapper call is removed, not updated into a new yield dispatch.

Repeat the caller search after editing, including string-encoded wrapper calls. Confirm there is no stale internal call shape, no ordinary yield path passing the vault holder, and no public-SE wrapper passing the original caller after its shares have already been transferred. Similarly named hookless/Pons functions are separate implementations and are not changed by this signature update.

## 3. Perform the holder refactor without changing exit economics

### 3A. Existing settlement only

Parameterize the current exact-input function and its current free-path helper in each family. Replace both hardcoded burn holders with the passed holder. Retain the existing exact-share amount, output minimum, fee collection, sleeve-versus-pool decision, receiver payout and final books. Do not consolidate exact-input and exact-output engines or copy settlement into the yield target.

Ensure the requested amount is bounded by the named holder's balance and failures roll the operation back. Keep internal-balance validation at the shared external entry. Ordinary redemption burns the caller directly and requires neither a staged transfer nor a share allowance to the vault.

### 3B. Yield entry plumbing and protections

On both yield targets, connect ordinary and vault-held redemption directly to the inherited function with the correct holder. Preserve the external SY validation and minimum/output return contract. Leave the shared initiating-caller gate for internal-balance redemption in place at `NativeStandardYieldTarget.sol:41–44`.

The direct path must retain protection formerly supplied by the route it bypasses:

- V3's existing vault-held override is nonReentrant. Preserve that protection, and ensure the new ordinary internal route also acquires the money-operation lock once rather than relying on the removed exchangeIn dispatch. Do not double-enter the lock by placing overlapping guards on nested internal calls.
- Legacy V4 previously received exchangeIn's lock, disable check and post-settlement TWAP update through the external call (`UniswapV4StandardExchangeInTarget.sol:45–47,70–74`). Preserve those existing applicable behaviors in the direct yield path without re-entering exchangeIn or importing an unrelated disable-policy change.
- Keep receiver validation, zero-share handling, slippage rejection and rollback effective when the entrypoint changes. Do not add an ordinary-holder bytecode restriction to compensate for removal of the old dispatch.

Non-redemption uses of `_standardRoute`, including existing deposit routing, are not an excuse to leave a redemption fall-through to self-dispatch. Keep the share-redemption branch explicit and separate. Do not expand this task into redesign of other entrypoints or exempt families.

### 3C. Public SE behavior

Preserve public exchangeIn and exchangeOut interfaces and economic behavior:

- Public exchangeIn false-flag share delivery still pulls from the external caller under its existing transfer/allowance semantics. Having pulled shares, it settles against the vault holder, not the original caller a second time.
- Public true-flag share delivery retains the actual external-caller gate and unbooked credit check. It is not repurposed to mark internal SY bookkeeping.
- Existing public exact-input amount and minimum checks remain. Existing public exact-output maximums, actual share burn, credit/refund behavior and payout rules are not refactored by this task.
- The V3 OUT execution delegate remains unchanged. Do not use it to implement fixed-share SY redemption.

## 4. Update only the misleading redemption documentation

Replace the legacy V4 comment at OutMultiQueryTarget `:20–21` with the explicit-holder internal reuse rule. Update V3 comments that describe ordinary redemption as staged true-flag exchangeIn reuse. Remove yield-only binding/import declarations that become unused after the direct internal call, without altering public component bindings still used by other consumers.

Update only the native-SY self-call description at `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56` and directly related misleading NatSpec. Explain direct inherited settlement and original-caller/vault holder selection. Do not rewrite the rest of the README or treat this as package-deletion documentation work.

## 5. Production-proxy verification plan — two separate family results

Tests are authored and run only in a later authorized implementation/verification session. Use actual CREATE3 facets, manager/registry-deployed packages and production proxies; no mocked vault, package, manager or registry. Non-SUT funding/callback fixtures may support precise assertions under the repository testing rules.

### 5A. V3 FullSpread

Start from the existing `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` and its `TestBase_UniswapV3FullSpreadStandardExchangeVault`.

- Replace or supplement ordinary-success coverage at current `:96–104` with a **code-less holder** who actually owns shares. Verify exact caller-share debit and supply reduction, unchanged unrelated vault-held shares, and measured payout to the named receiver. No share allowance or caller-share staging is required by ordinary SY redemption.
- Retain the code-less internal-balance negative, but establish sufficient vault-held shares so the intended caller gate, not absent backing, is tested. Assert exact `EOAPretransferNotAllowed` and unchanged caller/vault shares, supply and payout balances.
- Retain a contract-caller internal-balance positive with more vault-held shares than requested. Assert only the requested vault shares burn, caller/third-party shares are untouched, remaining vault shares are not refunded, and the receiver receives the reported output.
- Exercise both existing burn sites: ordinary pool-access settlement and the existing blocked-pool/sleeve-only branch, using appropriate real protocol fixtures rather than replacing vault methods. Verify same holder identity and rollback rules in each.
- Add insufficient-holder-balance and output-minimum rejection controls with unchanged affected state, and retain the existing reentrancy protection coverage for both direct yield entry paths.
- Update the test's mechanism description at current `:48–65`: direct-call rejection of the existing IN delegate may remain as non-yield component protection, but is not evidence that SY should use that delegate. Verify the yield path no longer invokes exchangeIn or the IN execution wrapper. Use source/call-path inspection to distinguish external calls from delegatecalls; an exchangeIn call-count assertion alone is not the complete self-dispatch proof.

### 5B. Legacy V4

Add a separate focused production-proxy suite under `test/foundry/spec/protocol/dexes/uniswap/v4/`, using the existing `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` fixture chain. That base was located during this planning turn; verify its production deployment setup before extending it.

Independently assert:

- Ordinary success by a funded **code-less holder**, with direct burn from that holder and no pretransfer-caller rejection.
- Code-less internal-balance rejection with exact error before burn and unchanged affected balances.
- Contract-caller vault-held success with requested burn only, named receiver payout, unchanged third-party shares and no refund of other vault shares.

Cover both the local-sleeve and pool-access burn sites and relevant lock/disable/TWAP preservation separately from V3. Assert no external exchangeIn self-call and no ordinary-share staging into a synthetic internal-balance route. A passing V3 suite does not satisfy any of these legacy V4 assertions.

### 5C. Public-route preservation in each family

Retain or add focused controls for public share-input exchangeIn in both real pretransfer modes. Verify false-flag actual transfer then vault-holder burn, true-flag caller authentication and bounded credit, and no double burn of the original caller. Check funded success and precise rejection rollback.

Run existing public exchangeOut share-withdrawal regressions to ensure the internal signature refactor and removal of the legacy self-caller branch have not changed supported delivery/refund behavior. Do not modify V3's exact-output delegate or weaken its tests to achieve a green result. Keep ordinary SY's no-allowance success distinct from the unchanged allowance semantics of a public false-flag exchangeIn pull.

## 6. Build, test and review gates for the later authorized session

1. Review the complete edit against the holder/caller table before compiling. Search again for both internal function names, wrapper encodings, redemption exchangeIn calls and the removed self-caller branch.
2. Refresh affected production artifacts **before** running tests, following the repository artifact-build workflow. FactoryService-loaded bytecode must correspond to the edited sources. Do not claim a test validates source merely because an old artifact deployed successfully.
3. Build the concrete dependents of both changed InBases, including the yield query facets and the IN execution delegates. Preserve the no-via-IR and deployment-size constraints. Direct inherited settlement can increase the query facet runtime; verify the affected deployed units rather than substituting a prohibited self-call or yield delegate route if size becomes difficult.
4. Run and report V3 and legacy V4 focused suites separately, then relevant public SE and native-SY regression suites. Report exact commands, toolchain, source/artifact identity and results actually obtained. List failures and unrun cases explicitly.
5. Check proxy surface/ABI compatibility and absence of new external holder-selectable entrypoints. Keeping wrapper signatures unchanged should leave their encoded callers intact; verify rather than assume.
6. Confirm no implementation change to V3 `executeZapOutWithdrawal`, exempt-family settlement, unrelated APEX work or excluded package trees.

No build/test success, artifact freshness, final runtime size or complete deployment verification is claimed in this plan. If implementation encounters a genuine incompatibility with the fixed requirements, report it rather than silently choosing a self-call, second exit engine, relaxed gate or alternate economics.

## Completion criteria and handoff

The coordinator's final plan should require all of the following before an implementation session reports completion:

- Both yield facets call inherited exact-input settlement internally with the correct explicit holder.
- Both burn sites per family use that holder; every existing wrapper/helper caller is updated and public delivered-share paths still pass the vault holder.
- No affected yield redemption self-dispatches by external call or delegatecall, or substitutes a true pretransfer flag after staging caller shares.
- The legacy V4 self-caller share-delivery branch and misleading redemption comments are removed.
- Public exchangeIn/exchangeOut behavior is preserved within the PRD, including the unchanged V3 exact-output delegate.
- Three required proxy assertions pass **separately** for V3 FullSpread and legacy V4; ordinary success uses a code-less holder. Additional preservation/rollback checks and both burn branches are accounted for.
- Affected artifacts/builds and test results are recorded honestly; no unrelated change or live operation occurred.

**No blocking owner question remains in the updated specification. This is a plan draft only; implementation still requires a separate request. Stop and return to the coordinator.**
