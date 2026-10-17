# Astra independent plan draft — legacy V4 ERC-5115 replacement

**Date:** 2026-10-15. **Status:** Draft for a separately authorized implementation session. No implementation or execution is authorized by writing this plan.

**Controlling PRD:** `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md`, read in full. **Named interface, not PRD:** `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`, also read in full.

The PRD and current owner instruction expressly close the deposit flag: true uses the existing token pretransfer path **without adding `LocalCreditLib.requirePretransferCaller`**. My earlier recommendation to add that gate is not adopted and is not an implementation option. Preserve the existing gate on internal-balance redemption and share delivery. Do not repair the existing stored-reserve credit calculation.

No peer notes were read. The existing money/query targets, affected facet declarations, package interface registration, internal funding route, shared validation bodies, and artifact workflow were spot-checked.

## 1. Fixed scope and destination surface

Use `V4/` for `contracts/protocols/dexes/uniswap/v4/` and `T4/` for `test/foundry/spec/protocol/dexes/uniswap/v4/`.

Edit these five existing production files only:

1. `V4/UniswapV4StandardYieldExecutionTarget.sol`
2. `V4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
3. `V4/UniswapV4StandardExchangeInFacet.sol`
4. `V4/UniswapV4StandardExchangeOutMultiQueryFacet.sol`
5. `V4/UniswapV4StandardExchangeDFPkg.sol`

Do not rename either target or add a parallel class, shared selector helper, new facet, or replacement execution hop. The package retains sixteen cuts in its current order. Shared SY files and other families retain Pendle behavior unchanged. The canonical ERC-5115 and Pendle interface files are read-only.

### Selector accounting

Remove exactly these nine current identities from legacy V4:

- `deposit(address,address,uint256,uint256)`
- `claimRewards(address)`
- `rewardIndexesCurrent()`
- `assetInfo()`
- `isValidTokenIn(address)`
- `isValidTokenOut(address)`
- `getRewardTokens()`
- `accruedRewards(address)`
- `rewardIndexesStored()`

Add the nonpayable `deposit(address,address,uint256,uint256,bool)`. Retain the identical redeem selector and six common query selectors. Do not retain the old deposit as an alias. Leave ERC-20/metadata/permit and all Standard Exchange selectors unchanged. The resulting package product-selector count is 52, excluding factory-installed introspection.

## 2. Ordered source edits

### Step 1 — implement the two money functions in the existing target

Current `UniswapV4StandardYieldExecutionTarget.sol:10-24` inherits the shared Pendle execution target and forwards its four-argument deposit. Remove that shared execution inheritance/import. Retain inheritance from `UniswapV4StandardExchangeInTarget` so the existing internal SE funding path remains available. Import the local ERC-5115 interface for its event declarations, and the existing independent error, share-repo, caller-check and insufficient-credit declarations needed by the local redeem body.

Do not inherit the full eight-function ERC-5115 interface on the money-only concrete facet in a way that forces its six query methods onto that facet. The proxy implements the interface across the two existing owners. Explicit function declarations matching the canonical interface, typed selector arrays, package registration, and proxy tests establish that composition; no additional fragment interface or target class is introduced.

#### Deposit

Replace the old overload with:

`deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public returns (uint256 shares_)`

It is **nonpayable**, with no inherited four-argument deposit. Remove the payable-only native-payment check from the legacy implementation; the shared error declaration stays unchanged for its other users.

The exact local operation sequence is:

1. Preserve the existing `Config._requireNotDisabled()` check before movement.
2. Reject zero receiver, zero amount, and invalid token using the existing `NativeStandardYieldErrors` signatures; use `Config._isValidToken(tokenIn_)` internally, not a public validity method.
3. Call the inherited internal SE operation as:

   `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)`.

4. Preserve the zero-shares rejection and final minimum enforcement that applied to the effective old deposit path. Emit `IERC5115_StandardizedYield.Deposit` with the original caller, receiver, input token, amount, and returned shares.

Current InTarget `:43-73` already supplies the operation lock, funding helper, share issuance, and TWAP update. Do not add another `nonReentrant` modifier around this internal call, another TWAP poke, or a public `exchangeIn` self-call. Its existing disable check remains even though the yield entry also validates disablement, matching the prior effective validation path.

**Flag mapping is literal:** false forwards false and pulls tokens; true forwards true and does not pull. Neither branch adds a new token-path caller-bytecode gate. Do not send this flag through `_standardRoute(..., internal_)`, whose true branch means redemption, and do not change `Custody._secureTokenTransfer` or its arithmetic.

#### Redeem

Retain the exact signature:

`redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_) public returns (uint256 amount_)`.

Removing the parent means `super.redeem` cannot remain. Preserve the **effective existing body** locally, using the shared body's current checks at `NativeStandardYieldTarget.sol:30-44` as the source, without editing that shared file:

1. Keep the legacy disable check, then receiver/amount/token validation using the same errors and `Config._isValidToken`.
2. If internalBalance is true, retain `LocalCreditLib.requirePretransferCaller(msg.sender)`, require the requested shares to fit the vault-held ERC20Repo balance with the existing `TransferDeltaInsufficient` error, and name `address(this)` as holder.
3. Otherwise name `msg.sender` as holder. Do not transfer those shares onto the vault or apply the internal-balance gate to this ordinary redemption.
4. Call the existing `_settleNamedHolder` with that holder and existing token/amount/minimum/receiver arguments. Preserve its `nonReentrant`, internal PoolOps call, and TWAP update (`legacy target:66-75`); do not add a second lock.
5. Retain the final `SYMinimumNotMet` check and emit the identical Redeem event ABI through `IERC5115_StandardizedYield.Redeem`.

Remove legacy-only `_standardRoute`, `_redeemVaultHeld`, and public validity overrides once these two local bodies replace their uses. The corresponding share-balance validation is performed locally as described, not removed. Do not inherit the reward target or retain reward entrypoints as uninstalled compatibility methods.

### Step 2 — detach the existing query target from Pendle inheritance

In `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, remove the imports/inheritance of the shared Preview/Discovery/Validation targets and Pendle interface. Remove `assetInfo` and both public validity functions. Drop `override` annotations that referred to those removed bases.

Keep these existing bodies and results:

- `getTokensIn` and `getTokensOut`: the two configured faces in their current order.
- `yieldToken`: its existing zero-address answer; do not replace it with PoolManager metadata.
- `exchangeRate`: current complete-book calculation and zero-supply result.
- `previewExchangeOutOneToMany`: unchanged Standard Exchange behavior.

Implement the two yield previews directly in this existing query target:

- `previewDeposit(address tokenIn_, uint256 amount_)`: return zero if Config's input predicate rejects; otherwise return `Accounting._previewExchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)))`.
- `previewRedeem(address tokenOut_, uint256 shares_)`: return zero if Config's output predicate rejects; otherwise return `Accounting._previewExchangeIn(IERC20(address(this)), shares_, IERC20(tokenOut_))`.

This reproduces the shared preview behavior at `NativeStandardYieldPreviewTarget.sol:10-17` without inheriting Pendle's extra functions. Remove the now-unnecessary forwarding `_previewExchangeIn` override after those direct calls are installed. No new query selector or validation policy is added.

### Step 3 — replace the two facet arrays explicitly

Remove use/import of `NativeStandardYieldSelectors` from the two legacy facets, leaving that shared file untouched.

`UniswapV4StandardExchangeInFacet.facetFuncs` is exactly:

1. `IStandardExchangeIn.exchangeIn.selector`
2. `IERC5115_StandardizedYield.deposit.selector`
3. `IERC5115_StandardizedYield.redeem.selector`

Its existing SE-only `facetInterfaces` declaration remains unchanged.

`UniswapV4StandardExchangeOutMultiQueryFacet.facetFuncs` is exactly:

1. `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector`
2. `IERC5115_StandardizedYield.exchangeRate.selector`
3. `IERC5115_StandardizedYield.yieldToken.selector`
4. `IERC5115_StandardizedYield.getTokensIn.selector`
5. `IERC5115_StandardizedYield.getTokensOut.selector`
6. `IERC5115_StandardizedYield.previewDeposit.selector`
7. `IERC5115_StandardizedYield.previewRedeem.selector`

Replace only its current Pendle interface-ID entry at `:20` with the canonical ERC-5115 interface ID. Keep the other entry and two-entry declaration length. Do not introduce a new helper file or move selectors to another owner.

### Step 4 — replace package interface registration in place

In `UniswapV4StandardExchangeDFPkg.sol`, replace the Pendle import used for registration with the named ERC-5115 interface and replace `interfaces[13]` at current line 162 with `type(IERC5115_StandardizedYield).interfaceId`.

Keep the fifteen-entry interface array, other entries, sixteen cut owners/order, package arguments, initialization, factory identities, and callback wiring unchanged. The two affected cuts obtain their changed selector arrays from the edited facets. No live-instance upgrade or removal transaction is performed by this fresh-source change.

## 3. Legacy test migration and required new assertions

Search current legacy V4 tests and their local helper callers for casts to Pendle on this vault. A call on another product is not migrated. Repoint legacy casts to ERC-5115; existing pull-funded deposit calls gain explicit false; redeem/query signatures remain unchanged.

Update the existing legacy-only files:

- `T4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`: three selectors instead of five; keep the SE interface declaration.
- `T4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`: seven selectors instead of thirteen; replace the interface ID in place.
- `T4/UniswapV4StandardExchange_Architecture.t.sol`: retain sixteen owner checks and callback ownership; change the affected selector counts to three/seven; update disabled-SY and no-self-call calls.
- `T4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`: change interface references, preserving all holder/balance/minimum checks.
- `T4/UniswapV4StandardExchange_FullRangeBook.t.sol` and `T4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol`: replace interface registration expectations and remove assertions requiring assetInfo; retain all unrelated book/lifecycle assertions.
- `T4/UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` and its decimals behavior file: update only legacy-yield calls, preserving genuine outer-unlock coverage.

Add `T4/UniswapV4StandardExchange_ERC5115.t.sol`, using the existing production package/TestBase fixture, with separate assertions for:

1. **Surface:** all eight named ERC-5115 selectors resolve to the prescribed existing owners; all nine removed identities have no installed owner; the old four-argument deposit is not an alias. ERC-165 reports ERC-5115 and not Pendle while independent ERC-20/SE support remains.
2. **False deposit:** actual caller token debit and vault credit/minted receiver shares match the ordinary path; no pretransfer flag is silently enabled; minimum failure rolls back.
3. **True deposit:** funded credit is consumed through the current token path with no in-call transferFrom. Include a code-less caller with sufficient credit as a positive control for the owner-selected absence of a new gate. Insufficient credit expects the current precise credit error, not `EOAPretransferNotAllowed`. Preserve the current excess/no-refund semantics without claiming to close the stored-reserve residual.
4. **Redemption gates:** retain the code-less internal-balance rejection and allowed contract-caller vault-held redemption, separately from ordinary caller redemption. The deposit exception must not weaken redemption/share-delivery checks.
5. **Nonpayable ABI:** a native-value call to the new deposit is rejected; use an explicit nonpayable/empty-revert expectation rather than a bare any-revert expectation. Do not require the removed payable entry's custom native-payment error. WETH-face deposit remains an ERC-20 operation.
6. **Events/queries:** exact Deposit and Redeem event fields and unchanged retained query results. ClaimRewards and assetInfo are not resurrected to satisfy old tests.

Do not edit shared Pendle selector/behavior helpers to accommodate the legacy vault. `Behavior_NativeStandardYieldExecution.sol` is interface-neutral and remains unchanged. Tests may import Pendle solely to identify removed selectors or its old interface ID in negative assertions; that does not authorize a production Pendle dependency.

## 4. Artifact refresh, size gate, then tests

These commands are for the later authorized session only. No command below was run in this pass. Use the repository's default hermetic profile, existing compiler settings, and retained `out/` and `cache_forge/`.

```bash
V4=contracts/protocols/dexes/uniswap/v4
T4=test/foundry/spec/protocol/dexes/uniswap/v4
SOURCES=(
  "$V4/UniswapV4StandardYieldExecutionTarget.sol"
  "$V4/UniswapV4StandardExchangeInFacet.sol"
  "$V4/UniswapV4StandardExchangeOutMultiQueryTarget.sol"
  "$V4/UniswapV4StandardExchangeOutMultiQueryFacet.sol"
  "$V4/UniswapV4StandardExchangeDFPkg.sol"
)

git diff --check
python3 scripts/forge-artifacts.py plan "${SOURCES[@]}" --test-root "$T4"
python3 scripts/forge-artifacts.py build "${SOURCES[@]}" \
  "$V4/UniswapV4StandardExchangeOutFacet.sol" \
  --consumer "$T4/**/*.t.sol"
```

OutFacet is passed as an explicit measurement dependency, not as an edited file or permission to edit it. Read the newly built IN and OUT deployed-runtime lengths, including metadata. Use this exact measurement command; it does not modify artifacts or historical reports:

```bash
python3 - <<'PY'
import json
from pathlib import Path

oversized = False
for name in ("UniswapV4StandardExchangeInFacet", "UniswapV4StandardExchangeOutFacet"):
    path = Path("out") / (name + ".sol") / (name + ".json")
    artifact = json.loads(path.read_text())
    obj = artifact["deployedBytecode"]["object"]
    if obj.startswith("0x"):
        obj = obj[2:]
    if not obj or len(obj) % 2:
        raise SystemExit("Invalid or missing deployed bytecode: " + str(path))
    size = len(obj) // 2
    print(f"{name}: {size} runtime bytes; limit 24576; artifact {path}")
    oversized = oversized or size > 24576
raise SystemExit(1 if oversized else 0)
PY
```

The measurement is artifact byte length, not successful onchain deployment. Preserve its output and command exit. Missing/invalid artifacts or a failed build are errors, not size results. If either facet remains above **24,576 bytes**, **stop and report both sizes and the unrun tests**. Do not split, restore a hop, enable `via_ir`, change optimizer policy, or remove additional behavior. Do not reuse the prior redesign size numbers as new measurements.

Only if the size gate passes, run:

```bash
python3 scripts/forge-artifacts.py test "${SOURCES[@]}" --test-root "$T4" -- -vv
git diff --check
```

The full family root includes the declaration, architecture, ERC-5115, vault-held redemption, book, buffer, adversarial, and decimals suites. Report commands, actual toolchain, build results, both sizes, and every test result. A present test or saved earlier pass is not execution of this interface change. Any non-legacy caller found to depend on this legacy ABI must be identified precisely; do not convert another vault family to repair it.

## 5. Stop conditions and non-goals

- Keep the owner-selected no-new-gate mapping for true token deposits. Do not substitute my earlier dissent, generic recommendations, or another family's behavior.
- Keep the internal-balance redeem and share-delivery caller gates; do not remove them for symmetry.
- No shared-SY implementation/selector changes, vendored interface edits, parallel target class, new facet, selector relocation, credit ledger, stored-reserve fix, or new economic model.
- No old payable deposit alias, reward stubs, assetInfo, public validity wrappers, alternate ERC-5115 text, or inherited Pendle surface on the two legacy targets.
- No Standard Exchange signature changes, self-call, delegate restoration, live deployment, or instance migration.
- Do not add methods to a money facet merely to satisfy inheritance of an interface implemented across multiple facets. Preserve the composite ABI with exact declarations and proxy tests.
- If a compile/test failure would require breaking one of these boundaries, stop and report it rather than choosing a replacement architecture.

## Done when

The existing legacy targets implement the selected local ERC-5115 surface; the IN and OUT multi-query arrays are exactly three and seven selectors; the two existing Pendle interface-ID sites are replaced in place; nine removed selector identities are absent; deposit modes follow the explicitly preserved token paths without a new caller gate; redemption safeguards remain; other families retain Pendle; and the post-change IN/OUT size results and applicable test results are recorded honestly.

**No implementer choice remains in this draft.** “Redeem keeps its current body” is implemented as preservation of its effective validation/holder/settlement behavior after removing the shared parent, not as a dangling `super.redeem` call. All source reads requested by the user succeeded. Only this assigned Markdown was written; no implementation or controlling document was changed.

I did not run Forge.
