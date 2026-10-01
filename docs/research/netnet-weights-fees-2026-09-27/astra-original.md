# Astra — NN-05 weights, synthetic price and fee source verification ORIGINAL

2026-09-27. PRD v0.28; current human selections control this amendment. No current-round peers read. Routing `openai/gpt-6-astra`, not provider attestation. Local-source research only; no execution or PRD/code edits.

## Selected—not new owner questions

Weights are **NET-DETF 50%, NET 20%, sNET 10%, USDG 20%**, WAD `[5e17,2e17,1e17,2e17]` in that stated order. Bind by leg identity, not an accidental array order. Synthetic follows the Universal DETF/Weighted reference **using NET as numeraire**. Existing oracle usage-fee and seigniorage mechanisms are selected; do not invent percentages or ask the owner to select another formula.

PRD `104,120,583,709` distinguishes **1 NET peg** from **1,000 NET opening**. Its `356–363` retains PLP/YT-derived NET valuation and shared-SY ordinary NET/sNET output funding. The synthetic mark is not a cash-deliverability promise.

## 1. Exact synthetic reference

Abbreviations: **D** = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`; **W** = `contracts/hooks/uniswap/v4/standardExchange/weighted/`, with filenames below prefixed `UniswapV4StandardExchangeWeightedBufferHook`.

`D/UniswapV4DetfCommon.sol:175–211` supplies total DETF supply, owned LP and **creation** price to `previewSynthetic`. Native nine-decimal DETF supply is multiplied by **1e9 once**, becoming WAD. Preview adds pending expansion before conversion and passes `pendingExpansion=0`; do not add it twice. `_syntheticPrice()` picks the first configured pair; custom routing must explicitly ensure **NET**, not accidentally sNET/USDG, is the selected numeraire.

`W/*ExitQueryTarget.sol:89–140` gives this ordered calculation. Let `R[i]` be rated-WAD pricing balances, j=NET, L=owned HLP, H=projected HLP supply after pending protocol-fee dilution, S=DETF WAD supply including the specified projected settlement, C=NET creation-price WAD:

```text
M = R[j]
for each other non-DETF leg i with R[i]>0 and weight[i]>0:
    M += floor(R[j] * weight[i] / weight[j])
V = floor(M * L / H)
mid = floor(V * 1e18 / S)
synthetic = floor(mid * 1e18 / C)
```

The self-leg is **excluded**. Other nonself legs are **included at marginal weighted spot marks into NET**; their amounts cancel in the marginal conversion algebra but their nonzero/domain checks remain. With all three external coordinates positive and selected weights, `M = 2*R_NET + floor(R_NET/2)`—approximately **2.5×R_NET**, not R_NET alone. This is not independent external fair-value pricing or a finite liquidation quote.

`Common:92–101` counts actual protocol LP in DETF plus its reference bond holder; the custom family uses its selected direct DETF HLP custody, not unrelated holders. Apply `L/H`; do not treat the shared hook's whole inventory as protocol-owned. **Synthetic marginal marking is distinct from the separately ownership-limited nonlinear burn quotation.**

For the selected peg use `C=1e18`; opening is separately `1000e18`. `Common:258–263` uses opening (falling back to creation only if zero) for first-bond quote. Never normalize synthetic by 1,000. Keep source floor stages, zero/live/numeraire guards and checked arithmetic; source expressions are not an unlimited-range proof.

## 2. Hook usage fee is protocol HLP issuance, not a flat deposit haircut

`W/*Target.sol:387–452` resolves `usageFeeOfVault(address(this))` and current `feeTo()` in **hook proxy context**. With WAD usage u and F=100,000 (`*Repo.sol:24`, `*Math.sol:38`):

```text
a = floor(u * F / 1e18)
feeOn = feeTo != 0 AND 0 < u < 1e18 AND a != 0
delta = K - Klast
protocolHlp = floor(Hactual * delta / (floor(K * F / a) + delta))
```

`*Math.sol:165–179` returns zero for zero supply/Klast/a or nonpositive growth. Target additionally requires matching invariant modes. K is **Weighted invariant V**, or its partial-book interim invariant—not a square root despite `rootK` naming. It is measured from normalized **native inventory**, not the rated swap vector (`Target:334–346,400–412`). Invalid/quantized-off fee states disable this reference fee path; do not describe them as a second percentage charge.

`*JoinCore.sol:191–215,552–611` mints pending protocol HLP **before** calculating user join shares; previews include the corresponding supply dilution. `:312–323` then pulls/buffers assets, mints user/minimum liquidity, snapshots Klast, refunds and synchronizes. The contribution's invariant increase is not separately charged as a flat usage-fee haircut. Single/unbalanced joins separately use `dexSwapFeeOfVault` in their imbalance calculation (`:599–610`); no duplicate usage fee should be added. Preserve the PRD-selected actual Balancer liquidity semantics rather than silently importing known wrapper approximations.

## 3. DETF issuance split and oracle fallback

`contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:105–116,224–233`: vault override → registered fee-type default → global default; stored zero means fallback, not necessarily fee exemption. Hook uses its identity; `D/Common:112–133` resolves seigniorage p under the **DETF proxy** identity. No live u/p values were read.

`contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19–26,45–52`:

```text
live: user=floor(U*(1e18-p)/1e18); pot=floor(U*p/1e18)
bond: principal=floor(U*(1e18-p)/1e18)
      pot=floor(U*p/1e18)+floor(G*p/1e18); reserve self-leg=G
```

Preserve separate floors; user+pot can differ from U by dust. Arithmetic requires p<=1e18. Do not use the unrelated half-seigniorage helper. Actual callers: `D/UniswapV4DetfTarget.sol:283–301` live split/mint/reward funding; `:581–599` bond quote→join G→fund principal→fund rewards. `Common:252–289` distinguishes ordinary mint input uplift from duration-adjusted bond U: do not stack them.

Reference live mint is **not permission to restore custom liquid issuance**: NetNet liquid purchases remain swaps, fresh issuance remains bonded, and expansion retains its separate selected formula without recursive seigniorage charging.

## Amendment handoff / limits

Record fixed weights, explicit NET numeraire, the source-ordered marginal mark/owned-HLP/dilution formula, 1-NET creation normalization, and the two distinct fee mechanisms. Retire generic owner questions on those selections. Remaining work is mapping custom SY/PLP-YT custody units into reference native/rated books and proving preview/settlement parity—not choosing new economics.

Current CLAUDE and canonical Crane architecture/local hook-package guidance read directly. No missing-path or guard failures. Source snapshot, not pinned build/deployment evidence; no tests/gas/live configuration claims. No external library documentation claim required lookup. Only this report saved.
