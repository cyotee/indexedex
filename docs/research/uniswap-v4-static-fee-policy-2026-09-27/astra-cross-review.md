# Astra — Single combined static-fee cross-review

**Date:** 2026-09-27. Read the complete unchanged Grok, MiniMax M3 and Kimi K3 originals together as untrusted evidence. Read no peer cross-review. Rechecked disputed source paths directly. My original remains unchanged. No shell, tests, code/config changes or delegation. Static-only admission is still a **proposal**, not an approved PRD change.

**Path shorthand:** **C/** = `lib/crane/contracts/protocols/dexes/uniswap/v4/`; **F/** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/`; **Z** = `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.

## Minimum safe answer

**Yes: a static-only PoolKey admission rule is technically straightforward and consistent with leaving behavioral hook compatibility to the deployer.** Reject the exact dynamic sentinel, then validate the remaining fee encoding. Use the static LP fee **plus the live directional protocol fee**, and separately model any relevant hook effects. Neither an initialized-pool requirement, a no-return-delta-hook rule, a Pons-only restriction nor a below-100% fee ceiling follows automatically from that proposal.

Admission, quote capability and execution safety are distinct. Deployer assurance cannot turn an unsupported vanilla calculation into an exact fee-inclusive quote or waive the approved protections. No static-fee exception revives the release-disabled combined exact-output route (Z:175–189).

## Verified corrections and disagreements

### 1. Existing quoting already includes protocol fees — reject MiniMax's omission finding

FullSpread `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:96–135` calls Crane `quoteExactInput`/`quoteExactOutput` before hook adjustment. `C/utils/UniswapV4Quoter.sol:196–211` loads live slot0, selects the direction's packed protocol fee, and calls `ProtocolFeeLibrary.calculateSwapFee`. Lines 214–225 also subtract protocol fees when projecting LP fee growth.

Therefore MiniMax's statements that protocol fees are invisible/ignored, previews are unaffected, and new omission handling is needed are false. Its own §2.3 provides the contradictory correct evidence. Discarding fields in one Common destructuring does not establish an omission in an invoked library. No package-level duplicate `MAX_PROTOCOL_FEE` constant is necessary to prove the executing canonical PoolManager validates its settings.

API precision: `getSlot0` here is a **StateLibrary extension over PoolManager storage reads**, not a native external PoolManager getter. The quoter's `p.manager.getSlot0(...)` syntax does not change that (`C/libraries/StateLibrary.sol:44–66`).

### 2. Same-transaction protocol-fee changes are possible — correct Kimi

Kimi's “constant within a tx” inference is too strong. `C/ProtocolFees.sol:34–39` restricts `setProtocolFee` to the controller but has no lock/session prohibition. `PoolManager.sol:151–155` invokes `beforeSwap` **before** `Pool.swap` snapshots slot0 (`libraries/Pool.sol:288–312`). An authorized controller callable in that callback, or an authorized change between actions in a transaction, can change the rate before the affected swap.

The narrower correct statement is: **the core swap computation uses its own start snapshot**. Other transactions cannot interleave during a transaction, and arbitrary hooks do not gain controller privileges. Nevertheless transaction-wide constancy is not a protocol invariant.

My original already noted the unrestricted setter and per-action issue. I sharpen its recommendation: refreshing/rechecking snapshots helps but is not a proof against all callback behavior. Actual-fill/protection checks and a truthful hook model remain necessary; post-call equality alone cannot prove an intervening change never occurred. This is a supported capability observation, not a demonstrated exploit.

### 3. Static hooks can charge additional deltas; return deltas can be modeled

Consensus is correct that static fee mode removes the **LP-fee override**, not hook effects. `C/libraries/Hooks.sol:263–277` gates only the LP override on dynamic mode and separately processes specified deltas. Lines 299–317 account after-swap deltas; :210–245 account liquidity-hook deltas.

Disagree with Grok's suggestion that exact quoting requires rejecting all return-delta flags. A known deterministic delta can be modeled exactly; banning it is a distinct product restriction and does not prove the remaining callbacks are harmless. Disagree with MiniMax that any nonzero modeled Pons delta necessarily creates preview disagreement. Current hook adjustment exists precisely to predict that charge.

### 4. Pons is the concrete exclusion counterexample

Direct verification:

- `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol:66–71` uses **static LP fee zero** and `AFTER_SWAP_RETURNS_DELTA_FLAG`.
- That fixture inherits the **preserved** SE base (:46–58). It proves a static Pons pool configuration, not successful current FullSpread integration.
- The real hook is `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:480–524`: it computes two independently floored charges on the unspecified swap leg, takes them and returns their sum as its delta.
- F/QuoteService:21–57 reads launch terms and predicts those two floors: subtract from output for exact input; add to input for exact output. Its operation shape matches the inspected hook's unspecified-leg charge under the matching model. This is not a full integration proof.

A blanket return-delta ban excludes this static configuration and the explicit FullSpread quote model. **Static-only admission itself does not exclude it.** Conversely a Pons-only constructor decode gate would exclude other compatible static hooks. MiniMax's proposal simultaneously says to revert constructor initialization and allow the same vault to deploy; those cannot both describe one gate.

MiniMax's conjecture that the inspected Pons setter changes existing launch fee rates is unsupported: `_registerPoolWithArgs` snapshots fee terms (:355–403); `_afterSwap` reads those terms (:490–504). `setHookFeeBps` (:251–254) changes global policy, not the stored launch record. Inspected per-pool mutations alter recipients/buyback enablement (:415–437), not these trade-fee rates. A spoofed matching ABI/flag set remains possible in general: decoding metadata is not behavioral authentication.

### 5. Initialization and fee bounds are separate requirements

Static/dynamic key classification needs **no external pool-state read**. F/DFPkg:257–298 currently imposes no initialized-pool requirement in its inspected process/init path. Requiring initialization at deployment, as Grok/Kimi recommend, changes the allowed deployment lifecycle and is not necessary to reject dynamic keys. Preserve that lifecycle unless separately approved. Require initialized state before pricing/activation/trading; only then compare observed LP fee with the accepted static key. An uninitialized zero slot is not an initialized zero-fee pool.

MiniMax is also wrong that deploy-time protocol-fee inspection is impossible: the bound PoolManager and computed PoolId permit reading current protocol fees. What is impossible to infer from that read is **future immutability**. Validate packed fees per direction, not by testing the whole packed uint24 `<=1000`.

`MAX_LP_FEE=1_000_000` is **100%**, not MiniMax's 1.0% (`C/libraries/LPFeeLibrary.sol:25–39`). It is valid static encoding. `Pool.sol:315–320` rejects core exact-output swapping at 100%; productive vanilla exact-input composition also cannot assume positive net input. Hook custom accounting makes “no operation can ever work” too broad.

**Refinement of my original:** my recommended separate 100% deployment exclusion was a product recommendation, not part of the minimal static-only check. Do not bundle it into approval of rejecting dynamic fees. Retain valid encoding and truthfully reject infeasible protected operations unless a separate 100% incompatibility restriction is adopted.

## Final proposed policy

1. On every new FullSpread instance-creation path, reject `key.fee == 0x800000`, then require `key.fee <= 1_000_000`. Reject malformed mixed flags; never mask flags into an accepted static value. Use centralized package validation, not only the deploy convenience wrapper.
2. Preserve native PoolKey ordering, tick-spacing and hook-address structural checks. Do not add a Pons-only or no-return-delta admission condition. Keep initialization-at-deployment and the 100% boundary as separately disclosed policy choices, not implied changes.
3. Preserve the existing quoter's directional live fee computation: `h + f - floor(h*f/1_000_000)`. Never add protocol/LP fees a second time in the hook adjustment. Read live state for each plan/action; do not promise a transaction-wide constant effective rate.
4. Treat hook compatibility assurance as deployer responsibility where it is not determinable on-chain. Separately require truthful modeled quotes and actual net settlement checks for protected routes. An ordinary vanilla fallback and `_supportsProjectedHook` are different current code paths, not a universal safety gate.
5. Keep existing price-impact, shortfall, alignment, attribution and complete-booking protections. Static-only admission neither authorizes observe-only enforcement nor restores Z's disabled combined exact-output-plus-rebalance route.

The only immediate owner decision sought is whether to adopt **static-LP-only admission**. Do not present this cross-review as its approval or expand it into new hook/lifecycle/fee-cap restrictions.

## Evidence limits and confidence

High confidence in local fee composition, callback ordering, bounds and Pons charge mechanics. No production bytecode pin, same-transaction demonstration or current FullSpread/Pons execution test was performed. A broad Crane source glob reported unrelated missing LayerZero directories; the Pons path was then resolved from the fixture's explicit import, not by bypassing a restriction. No peer cross-review was read.

First-pass Context7 `/uniswap/v4-core` and primary upstream LPFeeLibrary, ProtocolFeeLibrary and Hooks URLs remain the API evidence, accessed 2026-09-27. This verification used current local implementations. Solidity configuration remains the observed 0.8.35, optimizer runs 1, via-IR false; port compatibility comments and moving upstream main are not commit/deployment pins. Claims of byte-faithful imports or model/execution equivalence by shared-library construction are stronger than this evidence establishes. Agreement proves neither security nor economic soundness.
