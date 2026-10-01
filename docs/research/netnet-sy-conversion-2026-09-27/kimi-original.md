# Kimi K3 — ORIGINAL: L3 — actual PendleStakedNetSY conversion source trace (chain 4663)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date / access | 2026-09-27 (all fetches this date) |
| Scope | L3 only: actual configured SY conversion source. Research only; no execution/delegation; no current-round peers. |

## 1. Verification chain (full source evidence, not metadata-only)

- **Proxy** `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` (SY-sNET) → **implementation** `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` (prior read-only Sourcify proxyResolution, as supplied).
- Sourcify v2 for the implementation, fetched fresh: **`creationMatch` = `runtimeMatch` = `exact_match`, `verifiedAt 2026-09-04T08:05:04Z`, matchId 47105638**, contract `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`; compiler `0.8.30+commit.73712a01`, viaIR true, optimizer 1,000,000 runs, cancun, remappings `@pendle/sy/=lib/pendle-sy/`. The deployed bytecode is byte-exact to this compilation — full-source evidence class, not proxy-only or metadata-only.
- Full source bundle retrieved via v2 `?fields=sources` (saved ~230 KB single-line JSON, chain output `tool_0ea57687f00112L3bJt2R10J1B`). The implementation file is the **first** source entry; its opening section is verbatim-readable below. Per-file retrieval of the remaining body was blocked by tooling (§7 — exact misses recorded).

## 2. Implementation skeleton (verbatim from the verified source, opening ~60 lines)

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "../../v2/SYBaseUpgV2.sol";
import "../../../../interfaces/IPDecimalsWrapperFactory.sol";
import "../../../misc/TokenWithSupplyCapUpg.sol";
import "../../../../interfaces/NetNet/IStakedNet.sol";
import "../../../../interfaces/NetNet/IStakedNetStaking.sol";

contract PendleStakedNetSY is SYBaseUpgV2, TokenWithSupplyCapUpg {
    uint256 internal constant INDEX_BASE = 1e9;
    uint256 internal constant DECIMALS_OFFSET = 1e9;
    uint256 internal constant INITIAL_FRAGMENTS = 5_000_000_000e9;
    uint256 internal constant TOTAL_GONS = type(uint256).max - (type(uint256).max % INITIAL_FRAGMENTS);
    uint256 internal constant INDEX_GONS = INDEX_BASE * (TOTAL_GONS / INITIAL_FRAGMENTS);
    uint256 internal constant MAX_SNET_SUPPLY = type(uint128).max;
    address public immutable net;
    address public immutable sNet;
    address public immutable staking;
    address public immutable scaledNet;

    constructor(address _sNet, address _decimalsWrapperFactory)
        SYBaseUpgV2(IPDecimalsWrapperFactory(_decimalsWrapperFactory).getOrCreate(_sNet, 18))
    {
        sNet = _sNet;
        staking = IStakedNet(_sNet).staking();
        net = IStakedNetStaking(staking).net();
        scaledNet = IPDecimalsWrapperFactory(_decimalsWrapperFactory).getOrCreate(net, 18);
    }

    function initialize(string memory name_, string memory symbol_, address _owner) external initializer {
        __SYBaseUpgV2_init(name_, symbol_, _owner);
        _updateSupplyCap(type(uint256).max);
        _safeApproveInf(net, staking);
        _safeApproveInf(sNet, staking);
    }
    /* DEPOSIT/REDEEM USING BAS… (body continues past readable window) */
```

**What the skeleton proves about the architecture:**
- `yieldToken` = `decimalsWrapper(sNet, 18)` = **sNET-scaled18** — matches the hosted-API underlying asset (`0x53176cadd446700fa6b89f840357ac586d7e33db`). SY shares are 18-decimal units of that wrapper.
- `scaledNet` = `decimalsWrapper(net, 18)` = **NET-scaled18** — matches the API accounting asset (`0xba46fc84409589f369c107e869c06809df3d9727`); this is the `exchangeRate` target denomination.
- Direct NetNet Staking integration: `staking = sNet.staking()`, `net = staking.net()`, and **infinite approvals of both NET and sNET to Staking** at initialize — deposit/stake and redeem/unstake run through NetNet's own Staking contract.
- **No wsNET anywhere** (probe `sNetToWs|wsToSNet|WrappedStakedNET|wsNet` = no matches in the full bundle) — the SY does not use the gOHM wrapper.
- **No NET tax-predicate queries** (`taxEnabled|isTaxExempt|isTaxedPair` = no matches) — the SY relies on NetNet's exemption whitelist for its staking-path movements (FEES.HTM: staking/bonding/claim operations are whitelisted); it does not model the 5% tax itself. Canonical-pool tax modeling stays with the custom V2 SE per PRD §8.
- Supply cap is set to `type(uint256).max` at initialization (effectively uncapped; `updateSupplyCap` exists for owner changes).
- The contract mirrors StakedNET's gon constants and declares `INDEX_BASE = 1e9`, `DECIMALS_OFFSET = 1e9` — index/decimal math is computed locally in the bodies (probes confirm `INDEX_BASE`/`DECIMALS_OFFSET`, `INDEX_GONS`, `MAX_SNET_SUPPLY`, `.index()` all present).

## 3. ABI surface (verified fresh; selected semantics)

Constructor `(_sNet, _decimalsWrapperFactory)`; `initialize(name_, symbol_, _owner)` (upgradeable, `Initialized` event). Getters: `net()`, `sNet()`, `staking()`, `scaledNet()`, `yieldToken()`, `assetInfo()`, `pricingInfo() → (refToken, refStrictlyEqual)`, `exchangeRate()`, `getTokensIn()/getTokensOut()`, `isValidTokenIn/isValidTokenOut`, `previewDeposit/previewRedeem`, `deposit(receiver, tokenIn, amount, minSharesOut) payable`, `redeem(receiver, amountShares, tokenOut, minTokenOut, burnFromInternalBalance)`, `getAbsoluteSupplyCap()/getAbsoluteTotalSupply()`, `updateSupplyCap(newSupplyCap)`, rewards: `getRewardTokens()`, `accruedRewards(user)`, `claimRewards(user)`, `rewardIndexesCurrent()/rewardIndexesStored()`, `ClaimRewards(user, rewardTokens[], rewardAmounts[])` event. Errors: `SYInsufficientSharesOut/SYInsufficientTokenOut/SYInvalidTokenIn/SYInvalidTokenOut/SYZeroDeposit/SYZeroRedeem/SupplyCapExceeded`.

The `SYBaseUpgV2` shell semantics (public `Pendle-SY-Public` `contracts/core/StandardizedYield/SYBase.sol`, same shell family, verified in the search-fetched source): `deposit` = `_transferIn(tokenIn, msg.sender, amount)` → `_deposit(...)` → enforce `minSharesOut` → `_mint(receiver, shares)`; `redeem` = burn (from internal balance or `msg.sender`) → `_redeem(receiver, tokenOut, shares)` → enforce `minTokenOut`; previews delegate to virtual `_previewDeposit/_previewRedeem` and **revert on invalid token**, with no deliverability guarantee (consistent with Pendle's documented off-chain preview warning).

## 4. Derived conversion flows (derivation — body confirmation pending per §7)

Given: shares are 18-dec units of sNET-scaled18; the scaled18 wrapper converts ×10^9 exactly (9-dec → 18-dec); Staking moves NET↔sNET 1:1 (`Staking.sol:88–126` — stake pulls `amount` NET and sends `amount` sNET; unstake the reverse); `sNET.index() = _indexGons / gonsPerFragment` (`StakedNET.sol:68–70`, stored `_indexGons` set once at wire, live `gonsPerFragment = TOTAL_GONS / supply`).

- **NET → SY:** pull NET → `staking.stake(x)` → x sNET received (1:1 exact) → wrap ×10^9 → `10^9·x` scaled units → SY shares, expected 1:1 with scaled units. Integer path is exact (no division until share issuance, which the unread body must confirm as 1:1).
- **sNET → SY:** wrap x sNET → `10^9·x` scaled units → shares.
- **SY → NET/sNET:** burn shares → unwrap `floor(scaled/10^9)` (≤1 raw 9-dec unit dust retained by the wrapper; Pendle's DecimalsWrapper pattern) → sNET out directly, or `staking.unstake` → NET out 1:1. `minTokenOut` enforced by the shell.
- **exchangeRate (SY → scaledNet):** expected `f(index)` — as the sNET index grows vs NET (rebases), one sNET-scaled unit becomes worth more NET-scaled units; the mirrored constants (`INDEX_GONS`, `MAX_SNET_SUPPLY`, `INDEX_BASE`, `DECIMALS_OFFSET`) exist to compute/track this locally; `.index()` is called (probe ✓). The exact formula is in the unread body.
- **Exact-output inverse:** if share issuance is confirmed 1:1 with scaled units, the whole NET↔SY leg is **linear** (`sy = net·10^9` forward; `net = floor(sy/10^9)` inverse, dust ≤1 raw unit) — a closed form, no sampling, no +1 fix-up, no search. **Caveat (plan v0.6 :417):** `previewRedeem`'s existence is not an exact-output API; until the body confirms the 1:1 issuance and the exchangeRate formula, treat this as the expected-not-proven shape. The SY→sNET→NET chain inside the shared-SY funding budget stays distinct from the Weighted quote (`BalancerV3WeightedPoolQuote`) and from hook funding calculations — no unit mixing: SY legs are quoted in SY units and converted at this boundary only.
- **Due-epoch mutation:** NetNet epoch processing changes `gonsPerFragment` → `index()` → `exchangeRate()` moves. Reads must occur at the operation's coherent snapshot; the funding/quote composition must not read the rate mid-transaction against a different epoch state.

## 5. Integration consequences for the plan (L3 scope only)

1. The SY is an upgradeable proxy with a working initialize + max supply cap — no custom SY is to be built (consistent with prior rounds); the family's deliverable is the provider + conversion mapping against THIS contract.
2. The provider's §4.5 sample formula applies to `previewRedeem(sNET-target)`/`exchangeRate()` with 18-dec SY units and 9-dec targets; the scaled18 layer must be accounted for exactly once (10^9 offset).
3. NET tax does not need modeling at the SY boundary (no predicates in the SY; staking paths are whitelisted). The custom V2 SE remains the only tax modeler.
4. minOut at the SY shell (`minSharesOut`/`minTokenOut`) is the caller-facing slippage control for every SY leg in Keep-YT entry, ordinary shared-SY redemption, rollover, and owned-book realization.
5. `burnFromInternalBalance` exists for redeem — the hook's custody model (SY held at the hook) uses internal-balance burns; pretransfer/origin policy (v0.32) applies to raw surplus, not to SY share minting.

## 6. Definite remaining evidence

- **Implementation function bodies** (`_deposit`, `_redeem`, `_previewDeposit`, `_previewRedeem`, `exchangeRate`, `getTokensIn/Out`, `isValidTokenIn/Out`, `assetInfo`, `pricingInfo`) — present in the saved v2 sources JSON (single-line, ~230 KB) past the first ~2,000 characters. Not extractable with available read tools (line-length cap; grep omits long lines). Obtainable in principle from the same saved JSON via a JSON-aware reader, or a Blockscout PRO endpoint (key — cannot be sent), or the original `pendle-sy` source repository if Pendle publishes it.
- Live values: `getTokensIn/Out` lists, `assetInfo`, `pricingInfo.refToken/refStrictlyEqual`, current supply cap, and the reward-token list (whether the interest token appears as an incentive — the NN-11 conditional case) — on-chain reads, NN-01 class.

## 7. Known misses (recorded once each; no identical retries)

`repo.sourcify.dev`→`/server/repository/contracts/full_match/4663/0xAdAb…/sources/lib/pendle-sy/.../PendleStakedNetSY.sol` 404; `partial_match` same path 404; `full_match` `metadata.json` 404; `partial_match` `metadata.json` 404; `/server/files/contracts/full_match/4663/0xAdAb…/sources/lib/pendle-sy/...` 404; `/server/files/any/4663/0xAdAb…` 403; proxy-address variant of the repository source URL 404; `/server/repository/4663/0xAdAb…/sources/...` 404; `/server/api-docs.json` 404; `raw.githubusercontent.com/pendle-finance/pendle-sy/main/.../NET/PendleStakedNetSY.sol` 404; `Pendle-SY-Public` implementations tree contains **no NET/ directory** (confirmed by direct tree fetch); websearch found no public copy of the implementation.

## 8. Limits

Everything in §§1–3 is directly fetched/read (URLs: `sourcify.dev/server/v2/contract/4663/0xAdAb…` fields=compilation, abi, sources; github.com `Pendle-SY-Public` tree + `SYBase.sol`; local `StakedNET.sol`/`Staking.sol`). §4 is derivation from that evidence and is labeled as such; it does not invent nonlinearity or assert the unread bodies. No execution, RPC, browser, keys or private source used; no attribution/identity/history guard failure occurred.
