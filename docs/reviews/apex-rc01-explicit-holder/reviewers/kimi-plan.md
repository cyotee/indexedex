# Plan draft — RC-01 explicit-holder share redemption (input, not final)

- **Date:** 2026-10-11. **Author:** Kimi K3, as review input. The coordinator owns the final `REMEDIATION_PRD.plan.md`; this draft is input to it, not the final file.
- **Controlling document:** `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` (DRAFT, 2026-10-11), including its 2026-10-11 owner decision applying the repair to Uniswap V3 FullSpread and the project-law ban on calls to self.
- **Authorization:** Writing this draft does not authorize implementation. The PRD itself does not authorize editing code. A later session must be explicitly asked to implement, and that session reports the commands it actually ran.
- **Blocking questions:** none. The earlier V3 citation conflict is resolved by the owner ruling ("Owner ruling on the V3 citation"): the V3 settlement is the exact-input `_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228`, and `executeZapOutWithdrawal` in the OUT execution delegate is expressly out of scope.

## 1. What the repair is

Both vaults stop discovering the redemption holder through a call to self. The single existing pool-exit settlement function on each vault gains a holder parameter, and both of its burn sites burn that holder. The yield facet on each vault already inherits that function (`UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:16` inherits the V3 InBase; `UniswapV4StandardExchangeOutBase.sol:22-23` inherits the legacy V4 InBase), so the yield facet calls the inherited internal function directly and passes the holder. It does not call `address(this)` — by external call or by `delegatecall` — and it does not call `exchangeIn` on either path.

- Vault-held redemption passes `address(this)` and the requested amount.
- Ordinary redemption passes the original caller and burns that caller's shares. It does not move the caller's shares onto the vault and does not touch the pretransfer flag.
- The pretransfer bytecode gate stays exactly where it authenticates a real external pretransfer or the internal-balance SY entry. It is not applied to ordinary redemption.

## 2. Edit sequence

Order the legacy V4 and V3 FullSpread edits independently; either may land first. Within each vault: settlement signature first, then callers, then the yield facet, then comments, then tests.

### Step 1 — legacy V4 settlement gains the holder

In `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol`, `_executeZapOutExactIn` (:121-155) and its free-path continuation `_executeFreeZapOutExactIn` (:157-199) receive a holder parameter. Both existing burns (:147 and :195) burn that holder instead of the hardcoded `address(this)`. The function is not copied, duplicated, or split; the pool-exit math stays one function. The locked-branch pricing preview at :137-139 is a view read, not holder discovery, and is left alone per the PRD's instruction not to invent a self-call from a view `previewExchangeIn`.

### Step 2 — legacy V4 callers pass the holder

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol:20`: the public `exchangeIn` wrapper passes `address(this)`, because that entry has already pulled or credited the shares onto the vault (`UniswapV4StandardExchangeInTarget.sol:70-71` delivers through `_secureShareDelivery` before delegating at :101). This wrapper is not named in the PRD's V4 in-scope list; updating it is a mandatory mechanical consequence of the signature change, authorized in substance by repair 8 (a public `exchangeIn` that has already pulled shares calls the same settlement with holder `address(this)`). Leaving it unchanged would leave a caller compiling against the old shape.
- No other caller of `_executeZapOutExactIn` or `_executeFreeZapOutExactIn` exists in the legacy V4 tree (bounded re-read: only the InBase definition/chained call and the delegate wrapper).

### Step 3 — legacy V4 yield facet

`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`:

- `_redeemVaultHeld` (:17-25) is rewritten to call the inherited internal settlement directly with holder `address(this)`. The external `IStandardExchangeIn(address(this)).exchangeIn(...)` call is removed.
- The ordinary `_standardRoute` override (:27-35) is rewritten: for share input with the ordinary flag it calls the same inherited settlement with the original caller as holder. It no longer stages `ERC20Repo._transfer(msg.sender, address(this), amount_)` and no longer converts the call into the internal-balance path.
- The comment at :20-24 that presents the self-call as the supported reuse path is replaced with one stating that the holder is an argument and that a call to self is not the reuse path.

### Step 4 — legacy V4 share-delivery branch

Delete the `msg.sender == address(this) && !pretransferred` acceptance branch in `_secureShareDelivery` (`UniswapV4StandardExchangeCommon.sol:1299-1305`, branch at :1302-1305). Preserve the two real branches exactly as the PRD requires: a false-flag delivery still pulls from the original caller with exact-delta enforcement (:1306-1309), and a true-flag delivery still authenticates the caller through `LocalCreditLib.requirePretransferCaller` and credits only unbooked value (:1310-1316). No other line of that helper changes.

### Step 5 — V3 FullSpread settlement gains the holder

In `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, `_executeZapOutExactIn` (:183-228 region; locked-branch burn at :204) and its free-path continuation `_executeFreeZapOutExactIn` (:213 onward; burn at :224) receive the holder parameter, threaded from the outer function into the continuation (chained call at :210). Both burns use the passed holder. This is the function the owner ruling names; `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.executeZapOutWithdrawal` is not edited in this item.

### Step 6 — V3 FullSpread callers pass the holder

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-25`: the wrapper keeps serving any non-yield caller of that delegate and passes `address(this)` into the updated internal function, per the PRD's in-scope bullet for this file. The yield facet does not call `address(this)` to reach this wrapper.
- No other caller of `_executeZapOutExactIn` or `_executeFreeZapOutExactIn` exists in the V3 FullSpread tree (bounded re-read: only the InBase definition/chained call and the delegate wrapper).

### Step 7 — V3 FullSpread yield facet

`contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` (:24-54, both functions):

- `_redeemVaultHeld` (:24-35) is rewritten to call the inherited internal settlement directly with holder `address(this)`. The facet-address lookup and the `delegatecall` into the IN execution delegate are removed from the yield path. (A `delegatecall` to a different contract is not a call to self, but the PRD bars that form here because the facet already inherits the function.)
- The ordinary `_standardRoute` override (:39-54) is rewritten: for share input with the ordinary flag it calls the inherited settlement directly with the original caller as holder. It no longer moves the caller's shares onto the vault and no longer `delegatecall`s `exchangeIn` with `pretransferred=true`. Non-share inputs and the internal flag continue to fall through to the shared base behavior as they do today; the internal-flag path resolves to the rewritten `_redeemVaultHeld`.

### Step 8 — Documentation strings

Replace the comment/NatSpec identified by the PRD that describes internal-balance redemption as a proxy self-call, including `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56`. Do not rewrite the rest of that README in this item.

## 3. Preserved public behavior (explicit)

- Public `exchangeIn` zap-out on both vaults is unchanged in shape: share delivery still pulls from the caller on the false flag or authenticates and credits unbooked value on the true flag, and settlement then burns `address(this)` via the holder parameter passed by the delegate wrapper.
- Public `exchangeOut` is untouched, including the V3 OUT execution delegate's `executeZapOutWithdrawal` and its existing flag-dependent burn selection.
- `LocalCreditLib.requirePretransferCaller` is not weakened anywhere, and remains on the internal-balance SY entry (`NativeStandardYieldTarget.sol:42`) and on genuine external pretransfer paths.
- Hookless, Pons-family, Wings, ERC-4626, and constant-product yield settlement are not edited; they are cited as already passing an explicit holder or not calling `address(this)`. `NativeStandardYieldTarget`'s ordinary `delegatecall` is not rewritten for left-alone families and is not copied into the two repaired vaults. SY deposit routing on the two repaired vaults is not part of this item; the PRD's outcome and acceptance criteria are redemption-scoped, and widening to deposits is a separate owner decision, not an implementer choice.
- Nothing is deleted or restored at the package level; no live instance is touched.

## 4. Tests (production proxies, per family)

For **legacy V4** and **V3 FullSpread** separately, on the production registry-deployed proxy with no mocked vault, and with one family's green result never counted for the other:

1. **Ordinary success with a code-less holder.** The caller is an address with no bytecode (a fresh `makeAddr`-style account, not the test contract). Ordinary redemption of that holder's own shares succeeds, the burn holder is that caller, the named receiver is paid, and the call is not rejected as `EOAPretransferNotAllowed`. This replaces the current masking pattern in which the ordinary case runs as the test contract (e.g. `UniswapV3FullSpreadVaultHeldRedeem.t.sol:96-104`).
2. **Code-less internal-balance rejection.** A code-less caller using the internal-balance flag reverts with `EOAPretransferNotAllowed` before any burn; the caller's and the vault's share balances are unchanged.
3. **Contract caller, vault-held.** A contract caller redeems only vault-held shares, in the requested amount, to the named receiver, with no refund of the vault's other shares. A zero-count call assertion on `exchangeIn` (as the current suites already use) is retained to prove no self-entry.

Existing positives for the public `exchangeIn` zap-out routes are re-run unchanged to demonstrate the preserved behavior in §3.

## 5. Execution notes for the later implementation session

- Follow repository law: production edits require `forge build` before `forge test` because FactoryServices read creation bytecode from `out/`; use the documented artifact-refresh workflow after the production edits; never `new` a facet or package; do not enable `via_ir`; do not kill long compiles.
- Signature-change completeness is covered by §2: the full caller list is the two InBase definitions and chained continuations, the two IN execution-delegate wrappers, and the two rewritten yield-facet functions per vault. A compile after Step 1/5 must show no caller still using the old four-argument shape.
- Report the commands actually run and their outcomes. A green run on one family does not close the other. Do not claim this draft or the PRD was executed by writing it.

**Stop.**
