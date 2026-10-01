# Astra — NN-05 weights/fees combined cross-review

2026-09-27. Read COMPLETE Grok (105 lines), MiniMax M3 (152), Kimi K3 (58) ORIGINALS together as untrusted evidence. No peer cross-review read; originals unchanged. Routing `openai/gpt-6-astra`, not provider attestation. Grok's reported routing mismatch/read limitations remain its attributed process caveats; this does not certify the roster.

## Accepted choices and decisive correction

Record **NET-DETF/NET/sNET/USDG = 50/20/10/20%**, explicit NET numeraire, existing usage-fee oracle mechanism and DETF seigniorage calculation. No new fee/default/model vote is required.

**Reject Grok's `creation[NET]=1000e18` recommendation** (§§2/Amendment), which contradicts both its own selected-peg summary and the PRD. Preserve the source's creation division with **creation=1e18; opening=1000e18**. Normalizing by 1,000 would reinterpret the selected absolute 1-NET peg as a launch-relative ratio. Astra/Kimi agree on the correct mapping.

Grok's opening example must also use the pair's native units: for a nine-decimal NET face, 1,000 NET is `1000e9`, not `1000e18` fed into `nativeToWad`. Its ownership pseudocode must read **HLP balances**, not DETF-token balances.

## Synthetic formula: retain exact operations

Sources: `UniswapV4DetfCommon.sol:92–101,175–211,258–263` under `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`; weighted `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–140`.

Let r be the NET rated-WAD coordinate. Exclude the self-leg; include NET itself plus each other **positive** nonself coordinate's marginal weighted mark:

```text
M = r + sum(floor(r * w_i / w_NET))
V = floor(M * ownedHlp / projectedHlpSupply)
mid = floor(V * WAD / detfSupplyWad)
synthetic = floor(mid * WAD / creationNET)
```

With sNET/USDG positive and selected weights, **M=2r+floor(r/2)**. “2.5r” is only the unrounded shorthand; no equilibrium assumption is necessary for this reference algebra. Preserve positivity/live checks, floor ordering and checked-arithmetic limits. No simple NET-only/supply formula.

Supply is native nine-decimal DETF multiplied by `1e9` **once**. Preview expansion enters that supply once; the reference passes separate pending expansion as zero. Use the custom DETF's **directly owned HLP**, not external LP holdings or an imported Universal NFT custody location. HLP denominator includes projected protocol-fee dilution.

## Fees: source order and exact denominator

Rechecked weighted `...HookMath.sol:165–179` and `...HookTarget.sol:387–452`:

```text
a = floor(usageWad * 100000 / WAD)
delta = K - Klast
protocolHlp = floor(H * delta / (floor(K * 100000 / a) + delta))
```

Apply only under reference fee-on/nonzero/growth/mode guards. K is native-inventory Weighted V (or interim invariant), **not sqrt(K)** and not the rated swap book. Do not replace the plus-delta denominator with another familiar AMM formula.

Join paths settle pending protocol HLP before user-share pricing; commit updates the invariant baseline (`...HookJoinCore.sol:191–215,312–323,573–610`). There is **no additional flat usage-per-deposit haircut**. Swap/imbalance fees and underlying-SE fees remain distinct where the selected route incurs them; “no double fee” must not mean no other legitimate fee exists.

`DETFMintSplitLib.sol:19–26,45–52` floors each term. **MiniMax's dust bounds are inaccurate:** live split totals U or U−1 native DETF unit. For bonds:

`G + principal + pot = G + U + floor(G*p/WAD) − epsilon`, where `epsilon` is 0 or 1 for valid `0<=p<=WAD`.

Use native DETF units, not ambiguous ETH “wei.” Preserve normal bond-side bonus/splits; do not stack ordinary mint's input uplift onto bond U.

## Failure behavior is not “oracle fallback to zero”

`VaultFeeOracleQueryFacet.sol:105–116,224–233` resolves **vault→type→global** on stored zero. An effective zero is possible; a stored vault zero is not a guaranteed exemption. MiniMax conflates these lookups with unrelated zero-return guards.

Weighted `...HookClaimLib.sol:30–52`, inspected this continuation, requires the buffered rate provider and reverts on failed calls, wrong return length or zero rate. Such failure is **not missing TWAP**. A no-live/invalid-context synthetic zero is not a measured one-hour below-peg observation. Unknown-numeraire handling returns zero, not MiniMax's “revert(0).” These reads and floors do not make pricing oracle-free.

## Amendment / remaining evidence

Use the equations above and selected identities in the PRD. NET valuation remains PLP/YT-derived; sNET rates the SY book; USDG rates SE shares. Ordinary NET/sNET cash still comes from shared SY. Native HLP custody/subshare inputs and rated pricing inputs need faithful custom mapping; reference fee capability does not prove that mapping already works.

Reject Kimi's categorical “no gap/no double fee” as an implementation certification. No new oracle, numerical fee default, liquid issuance or Universal expansion policy follows. Custom expansion and synthetic-TWAP branch rules remain selected. No owner fee choice is reopened.

High confidence in source mechanics; no live configuration, gas, deployment or parity proof. Local-only checks; no external API claim, shell/RPC/tests/browser/code/config/delegation. Only this cross-review written; return to moderator.
