# Astra — RC-05 replacement-session cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my independent `astra-original.md`, preserved unchanged. I read all three supplied originals in full and treated them as untrusted evidence. No peer cross-review artifact was read.

## Decision

**Close RC-05.** Agree with the three originals' current-source closure conclusion. No unguarded second public/external exchangeOut with the reported maximum-minus-input refund remains in the single-CP family. No production fix or owner choice between deletion and delegation is needed for this current finding.

Closure is based on the absent source implementation and the inspected surviving guarded path, not merely exclusion from an installed cut. Historical source and deployed-instance behavior remain unverified.

## Fresh independent checks

A fresh search of `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/**/*.sol` for exchangeOut definitions and the prohibited `maxAmountIn - amountIn` expression returned **one definition only**, at `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`, and no prohibited refund expression.

The original independent pass additionally searched every exchangeOut reference, inspected the old HookTarget entry region and identified its remaining outbound dependency call at **349**. It found no exchangeOut definition in `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol`; that source-absence evidence remains the principal closure basis.

Freshly re-read SeTarget **870–914**:

- True-flag `_securePull` calls `requirePretransferCaller` at **885** and checks the claim against unbooked availability at **886–888**.
- `_unbookedBalance` at **894–902** uses the applicable native custody book and `LocalCreditLib.available`.
- `_pullExactOutInput` at **907–913** refunds nothing on the false flag; on the true flag it calculates `LocalCreditLib.budget(available, maxAmountIn)` and transfers only positive `credit - used`.

The original pass directly checked the complementary maximum bound at `_swapExchangeOut:775`, before this helper call at **778**. Together these establish `used <= available` and `used <= maxAmountIn`; the helper need not refund a declared maximum that was never delivered.

The existing liquidity-route dispatch at SeTarget **759** was also traced in the independent pass to `UniswapV4BufferHookLiquidityRouteLib.sol:87–102`: it rejects prepaid liquidity routing after the caller check and does not provide a second maximum-minus-used refund. Closure does not overlook that branch.

## Peer assessment

### Grok — agree; distinguish dispatch from helper

Agree with `grok-original.md:7–9` on absence and the surviving guarded refund. More precisely, exchangeOut dispatches first; the **swap branch** reaches `_pullExactOutInput`, and its caller check is delegated through `_securePull`. This is a call-chain clarification, not a gap.

### MiniMax replacement — agree on source absence; narrow unsupported side claims

Agree with `minimax-original.md:25–65,71–81` that the historical duplicate is absent and the surviving swap route is guarded.

- **22:** calling the old HookTarget's exchangeIn the “installed exact-in route” is not established by the stated definition search. RC-05 does not require that assertion; do not use it as installation evidence.
- **83:** line 760 is a dispatch call, not the refund helper definition. The refund helper is at **907–914**, with the caller check in `_securePull` at **885**. Names and comments alone are not substitutes for those bodies, which Astra directly read.
- **67–69:** a literal-pattern search is not proof of all refund semantics across the entire repository. The out-of-family batch-router match is irrelevant to this closed single-CP finding and was not audited here. I do not adopt a repository-wide safety conclusion from it.

These qualifications do not change the scoped closure result.

### Kimi replacement — agree on implementation; mark history/cut preservation unverified

Agree with `kimi-original.md:14–24,28,30` on source absence and the bounded surviving refund.

- **29:** current facet exposure is consistent with the guarded route, but historical installed-selector/cut identity was not independently diffed in this review. Do not claim its preservation solely because the unused function is absent today.
- **34:** the controlling PRD describes the historical defect; today's source does not independently establish the exact code at filing or when it changed. Mark that history unverified rather than relying on it for closure.

No inference about all deployed instances follows from current-source removal.

## Attribution, findings and limits

No evidence changes Astra's original conclusion. There is no unresolved dissent requiring a source repair. No current RC-05 production defect was found, so no fix selection is proposed.

**Facts:** no second exchangeOut definition in the scoped family; the cited old target lacks the reported implementation; the remaining swap path uses bytecode validation, availability checks and budgeted refunds.

**Inference:** the current source satisfies RC-05's removal/guarded-helper criterion. It is unnecessary and incorrect to keep the alert open solely because the original function was once described as unused.

**Unverified:** historical cut preservation, historical source at filing, deployed bytecode, runtime test results and unrelated operations. Source absence is not an independent test run or a comprehensive family audit.

Files freshly examined without a scoped defect: SeTarget **870–914**, the family-wide definition/refund-pattern search results, and the three original reports. The preserved independent report contains the wider HookTarget, facet, LocalCreditLib and liquidity-route evidence. All supplied originals were present; the assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, original report, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-05
I did not run Forge.
