# Astra — ORIGINAL L3 source investigation; extraction incomplete

Continuing council-astra; `openai/gpt-6-astra` assigned routing, not provider attestation. Independent current round; no current-round peer artifacts read. Environment access date2026-09-28; the September27 directory/source-document dates are retained, not retrospectively reconciled. Read current PRD v0.33, plan v0.6, CLAUDE and canonical architecture/adversarial guidance. No shell/code execution, tests, RPC calls, browser execution, configuration changes or delegation. Only this assigned report authored.

## Disposition

**The actual implementation's verified compilation and complete public source payload have been located and downloaded. I did not successfully extract/read the complete target function bodies with the available tools.** Therefore I cannot truthfully supply the requested deployment-specific SY↔NET/sNET formulas or close L3. This is a concrete source-rendering/access limit, not proof of nonlinearity, a need for another SY, or a pricing/model question.

The failed extraction is material: a generic Pendle SYBase or wsNET formula must not be substituted for this implementation. The source prefix already shows a specialized NetNet adapter with mirrored rebase constants and an upgradeable V2 base.

## 1. Fresh primary record

Read-only lookup:

https://sourcify.dev/server/v2/contract/4663/0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5?fields=proxyResolution,compilation

Returned an EIP1967Proxy resolving to `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, named `PendleStakedNetSY`. Proxy record matchId47105658, exact creation/runtime match, verified2026-09-04T08:05:24Z.

Implementation metadata:

https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=metadata

Returned matchId47105638, exact creation/runtime match, verified2026-09-04T08:05:04Z. Compiler `0.8.30+commit.73712a01`, Cancun, optimizer1,000,000, viaIR=true. These are **external compilation facts**, not permission to enable viaIR in this repository.

Compilation target:

`lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`

Target source metadata hash:

`0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`

Target source CID: `QmXxcstnT7GawRbrX7a9TE6xWLfaH7VGYEaF44jeV1WwJ8`.

Repository view https://repo.sourcify.dev/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E also reports deployment block54108928 and transaction `0xcaa091f08ce5c61c90eaf0ea15c9a1394220e39dafef2a042146171dbf54b7e7`. Its immutable table contains canonical NET/sNET/Staking addresses and two wrapper addresses `0xba46fc84409589f369c107e869c06809df3d9727` and `0x53176cadd446700fa6b89f840357ac586d7e33db`. I did not independently verify their current getters or deployed wrapper behavior.

**Evidence boundary:** fresh third-party proxy resolution plus verified compilation is stronger than a name/ABI, but is not my independent current-block runtime/storage check. No current observation block, proxy admin/upgrade state, supply cap, pause state, tax state or index was independently observed.

## 2. Actual source prefix that was readable

The sources-only response exposes the target prefix before the read tool's per-line truncation. It establishes:

- Inherits `SYBaseUpgV2` and `TokenWithSupplyCapUpg`.
- `INDEX_BASE=1e9`, `DECIMALS_OFFSET=1e9`.
- Mirrors NetNet `INITIAL_FRAGMENTS=5_000_000_000e9`, fixed TOTAL_GONS, INDEX_GONS and uint128 MAX_SNET_SUPPLY.
- Constructor sets base `yieldToken` through `decimalsWrapperFactory.getOrCreate(_sNet,18)`.
- Discovers `staking=IStakedNet(_sNet).staking()` and `net=IStakedNetStaking(staking).net()`.
- Creates `scaledNet=decimalsWrapperFactory.getOrCreate(net,18)`.
- Initializer initializes the base, sets supply cap to uint256 max, and approves both NET and sNET to staking.

This proves that the decimal wrapper is a real constructor dependency—not merely inferred from token labels. It does **not** prove that wrapping occurs on every deposit/redemption branch, that all four denominations are accepted, or which index snapshot the conversion uses. An initial maximum supply cap does not establish the current cap.

The ABI exposes deposit/redeem/previews/exchangeRate/token lists, but their presence does not supply their bodies or exact rounding. No body for these target functions is claimed inspected here.

## 3. Public source payload and exact retrieval failure

Successful full payload requests:

- https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=compilation,sources
- https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources

Tool-generated public outputs:

- `/Users/cyotee/.local/share/opencode/tool-output/tool_0ea31fc8d0011nQs5FyfXOfDTh`
- `/Users/cyotee/.local/share/opencode/tool-output/tool_0ea41f562001ukVf9Ew26AjIlK`

They contain roughly109KB minified single-line JSON. `read` truncates that line at2000 characters. Content grep confirms a `_deposit` match but returns `[Omitted long matching line]`, not its body. I did not run a JSON parser or shell, or use a tool outside authorization.

Source metadata additionally supplies:

- `.../StandardizedYield/v2/SYBaseUpgV2.sol`: CID `QmcXuG9HeMZpUvXZXnDNiUE4gsJo1BopK9Z117XFNi2UtR`.
- `.../libraries/TokenHelper.sol`: CID `QmejAANHv2K7yVfaXaVTMr145zmoZkQ3cZCx7PfM1hMBUo`.
- `.../misc/TokenWithSupplyCapUpg.sol`: CID `Qmcm9U1h1e3igQZZNUdExwySGBoAGentiWSLrQ2ZdZtbRP`.

Attempts to fetch the target/base/helper through public IPFS gateways failed: ipfs.io429, Sourcify gateway transport errors; target dweb.link429, Pinata timeout, Lighthouse402, Filebase504. No identical failed URL was retried. A repo-domain source-file alias redirected to the disabled legacy repository endpoint and404; this did inadvertently reach the known legacy failure through a different URL. No further legacy retry was made. Guessed v2 per-file/field-selection and pretty-output requests returned404/400. Blockscout's implementation endpoint returned403; no alternate Blockscout access was attempted.

Official https://docs.sourcify.dev/docs/api/ explains that v1 was completely disabled July7,2026. Public Sourcify lookup route source exposes v2 contract lookup, not a per-file route. Thus legacy404 is not evidence that the implementation source is absent. Repository HTML returned “Loading contract data” for source bodies; no JavaScript/browser execution was attempted.

**Smallest missing evidence:** a readable extraction of the target, its exact SYBaseUpgV2/TokenHelper, and actual wrapper implementations from the already-obtained public verification payload/records. This needs neither a new economic decision nor a new pricing model. The report deliberately stops short of invented formulas.

## 4. Correct caller constraints already established

### Weighted quotation is not SY funding conversion

Directly read `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49`. Exact input removes its trading fee before WeightedMath; exact output returns a fee-grossed input. Plan v0.6 :390–419 correctly retains V4 output-scale-up → inverse → input-descale-up → native fee gross-up order. Do not add the fee again.

For requested native target amount y, quote the selected NET/sNET coordinate with the established native/WAD mapping. Separately determine the required SY debit from the verified target conversion. Substituting raw SY units as NET/sNET curve output changes the pricing equation. Exact-output stages must be solved backward and replayed forward at one projected state, but the SY stage is not derived in this report.

Keep NET/sNET input on Keep-YT. Ordinary NET/sNET output spends the shared eligible SY budget, held first and claim if short, leaving a positive raw-SY remainder. Owned-HLP burn funding is separate; its nonlinear position realization must be quoted on owned allocations before conversion, never funded by public HLP/staking backing. Preserve current origin-independent public surplus credit: do not reopen L2's former payer-provenance requirement.

### Epoch effects require target-body ordering

Local `lib/crane/contracts/protocols/pol/net/src/Staking.sol:88–125,134–150` processes at most one due epoch in each stake/unstake/rebase call. It uses queued reward, advances end/number once, checkpoints the oracle, and queues a new distributor amount. `StakedNET.sol:67–98` returns `floor(INDEX_GONS/gonsPerFragment)` and updates its divisor after supply growth/capping. Multiple calls in one composed route can therefore advance multiple overdue epochs.

These are local reference facts, not proof of this SY's call sequence. The mirrored constants suggest adapter-specific epoch projection, but that is **inference only** until its bodies are extracted. Neither a stale pre-operation index nor automatically looping all missed epochs is justified.

### NET tax must be endpoint-specific

Local `NET.sol:121–145` taxes iff enabled, neither endpoint exempt, and at least one endpoint is mapped as a taxed pair. Active deployed predicates remain unobserved. When that source applies, net(g)=`g-floor(g*t/D)` and the minimal gross for positive desired y is `floor((y-1)*D/(D-t))+1`; y0 requires0. Untaxed hops use identity. Do not apply a blanket5% to all staking/SY transfers or duplicate the SE's tax handling.

The local Staking methods use nominal amounts and boolean transfer success, not measured NET receipt deltas. Consequently their apparent1:1 return values do not prove final receiver net output under an active taxed endpoint. The target/base actual-receipt handling and minOut comparison remain essential unread evidence.

## Confidence and handoff

High confidence in fresh verification records, readable constructor/initializer prefix, local Weighted/source constraints and the extraction failure. No claim that the target is nonlinear, that its inverse is unavailable, or that generic wsNET conversion is equivalent. The full requested target-body analysis is **not complete**. The concrete reusable artifact is the publicly downloaded source payload plus precise identity/CIDs above; moderator/human can supply readable extracted files without another policy consultation.

Context7 was used first for Pendle and Sourcify documentation; primary verification/documentation followed. No secrets/private code were sent externally. The existing plan was not edited; only the assigned original report was authored.
