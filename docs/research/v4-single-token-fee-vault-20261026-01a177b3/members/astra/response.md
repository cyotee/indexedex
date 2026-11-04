# Identity

- Member: Astra, independent initial research response; not the coordinator or a council verdict.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Exposed runtime labels: `PI_MODEL=gpt-6-astra`, `PI_REASONING_LEVEL=high`. These labels do not independently establish the billing/account route.
- Date: October 26, 2026.
- Run: `v4-single-token-fee-vault-20261026-01a177b3`.
- Authority: research and this response only. No implementation authority.

# Question

What can IndexedEx adapt so holders earn the underlying pool's swap fees, deposit and exit in one token, and expose a meaningful rate to another reserve-holding hook, when that token might trade only in the underlying pool and that pool's TWAP is the only reference?

I recommend a **fully T-backed vault with an assigned right to the T-denominated LP fees of separately funded pool positions**. This is a new composition of existing primitives, not a claim that a reviewed public vault already implements it.

The important cost is explicit: **the vault's deposited T does not fund the volatile LP principal**. A treasury or another consenting capital provider supplies that principal and assigns its T fee revenue. The vault earns real underlying-pool swap fees, but it is a fee-right vault, not a conventional pooled LP investment. If the intended requirement is that the same deposited capital must become active two-token LP capital, this recommendation fails that additional requirement. I have not established a design satisfying that stronger requirement together with dependable, linearly consumable, immediately redeemable T backing.

I accept the brief's interpretation of "use this liquidity": another hook can hold the share as a reserve, rate it in T, and redeem it into T. I do not assume an independent price, guaranteed trading volume, or an existing sponsor.

# Sources

## Local evidence actually read

1. `docs/research/v4-single-token-fee-vault-20261026-01a177b3/brief.md`: assignment, constraints and interpretation of downstream use.
2. `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md`: supplied prior research, especially "Quote manipulation", "Executed-price allocation", "Vault self-fill", and "Price-free per-component join". I read the report, not the other members' files, and did not reproduce its calculations.
3. `docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md`: supplied source-check note. I did not independently read the underlying oracle contracts.
4. `docs/agent/INDEXEDEX_AGENT_LAW.md:233-243`: locked held-reserve valuation law, read directly.
5. `CLAUDE.md`, `docs/agent/RESEARCH_COUNCIL.md`, and the installed native-council skill and its research/workflow/evidence references: task boundaries, not economic evidence.

## Public pages opened

All accesses were on October 26, 2026. These are fetched text, not rendered screenshots. Live `main` sources are not pinned deployment evidence.

| ID | Opened public source | Observation used |
| --- | --- | --- |
| P1 | [Uniswap: Fees](https://developers.uniswap.org/docs/get-started/concepts/fees), "Swap Fees" and "In-Range Liquidity and Fee Accrual" | Active LP positions earn swap fees; v3/v4 fees are separately claimable rather than automatically part of principal. |
| P2 | [Uniswap: Collect Fees](https://developers.uniswap.org/docs/protocols/v4/guides/managing-liquidity/collect-fees), "Guide" and "Additional Notes" | A zero-liquidity-change operation collects fees; settlement transfers the currencies; received amounts can be measured from balances. |
| P3 | [Uniswap v4 `IPoolManager.sol`](https://raw.githubusercontent.com/Uniswap/v4-core/main/src/interfaces/IPoolManager.sol), `modifyLiquidity`, `donate`, `unlock`, and `take` | Principal/fee/hook deltas are distinct; `feesAccrued` alone is not trustworthy evidence of organic revenue because donations can inflate it. |
| P4 | [Uniswap v4 `PoolManager.sol`](https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol), `unlock` and `modifyLiquidity` | The manager checks settlement at unlock completion; fee and principal deltas are accounted separately before hook effects. |
| P5 | [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626), specification and security considerations | Single-asset vault shares and withdrawal previews are public interface ideas. The standard itself warns that executable previews need not be safe price oracles. |
| P6 | [ICHI: How ICHI Works](https://docs.ichi.org/home/how-ichi-works.md) | Describes single-token deposits, LP shares and pool trading fees; describes withdrawals as the corresponding assets in the vault. This page does not establish an invariant T-only redemption value. |
| P7 | [Arrakis Pro, returned from the brief's introduction URL](https://docs.arrakis.finance/text/arrakisModular/guides/quickstart/introduction.html) | The retrieved page describes issuer-owned actively managed liquidity, not the particular T-backed fee-right composition proposed below. |
| P8 | [Bunni v2 repository](https://github.com/Bunniapp/bunni-v2), README | The opened README states the repository has unaddressed exploit issues and should not be used as-is in production. I did not audit its implementation. |
| P9 | [Uniswap v4 Hooks](https://developers.uniswap.org/docs/protocols/v4/concepts/hooks) | Hooks are pool-specific and fixed in the pool key. The proposed fee assignment can instead live in an LP-position-owning escrow; it does not require attaching a new hook to an existing pool. |
| P10 | [Uniswap: Calculate LP Fees](https://developers.uniswap.org/docs/protocols/v4/guides/managing-liquidity/calculate-fees) | Uncollected fees are tracked separately for each currency using position liquidity and fee growth. |
| P11 | [ICHI: Vault Build](https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build) | Retrieved technical prose describes distributing collected trading fees, price-dependent share valuation, spot/TWAP checks and owner-driven rebalancing. Embedded equation images were not decoded. |

Additional pages opened but not used as evidence for the recommendation: the Uniswap Arrakis article at `https://blog.uniswap.org/arrakis-uniswap-protocol-v3` and OpenZeppelin's fee-hook overview at `https://docs.openzeppelin.com/uniswap-hooks/fee`.

Exact public search queries were:

- `site.openzeppelin.com uniswap v4 hook fee taking liquidity provider fees`
- `site.docs.uniswap.org v4 modifyLiquidity feesAccrued callerDelta`
- `site.eips.ethereum.org EIPS eip-4626 previewRedeem totalAssets`

No private source was sent in those queries. Source claims above are grounded in direct page fetches, not search summaries. The optional Bunni pool-creation page, Coinspect Bunni case, Olympix Arrakis-loss article and v4 whitepaper PDF from the brief were not examined; I make no claims about their contents.

# Observations

## Why an ordinary single-sided LP vault is not enough

The prior report establishes that actual entry and exit swaps do not, by themselves, repair issuance against a manipulable whole-book quote or an executed price extrapolated into ownership allocation. It also distinguishes a price-free proportional acceptance identity from protection against subsequent trading against the remaining vault liquidity. Those are supplied research conclusions, not experiments repeated here. [Local 2]

A general LP's one-share liquidation proceeds can depend on the state and liquidity remaining after that share is removed. Multiplying that small executable quote by a large held balance need not equal the proceeds of liquidating that entire balance. This is an inference about nonlinear execution, not a new proof of a production exploit. ERC-4626's own preview warning is consistent with the distinction. [P5]

The locked law does not permit replacing the consumer's rate multiplication with a reserve-size-specific liquidation quote. Therefore changing the wrapper interface alone does not solve the composition problem. Likewise, "single-token deposit" in the fetched ICHI page is insufficient evidence of a safe, linear T redemption rate. [Local 4; P6]

ICHI's technical page is more specific: it describes token-ratio-based valuation and spot/TWAP restrictions. It does not establish the required guarantee for the particular poke-record TWAP described in the supplied evidence. I have not transplanted that page's safety claims into this setting. The ICHI overview and technical page also describe different rebalance privileges, so they are not treated as one version-pinned deployed specification. [P6, P11; Local 3]

The recommendation avoids needing an O/T mark by separating LP principal ownership from entitlement to a particular currency's fee receipts. Uniswap already separates fee accrual and collection from liquidity principal; the proposed assignment of those fees and the T-backed share accounting are the new design. [P1-P4; proposal]

## Recommended economic structure

Let `T` be exactly the token in which users deposit, the rate is quoted, and users redeem. Let `O` be the underlying pool's other token.

Use two separately accounted onchain claims, even if implemented within one package:

1. **LP principal claim.** A sponsor funds T/O positions in the underlying pool through an escrow. The sponsor bears inventory changes, adverse trading, range risk and principal losses. It retains the LP principal and O-denominated fees.
2. **T-backed vault share.** Users deposit T into a segregated, non-lent cash reserve. The escrow assigns all T-denominated LP fees from the designated positions to this vault. The share owns that reserve and its accrued T fee entitlement, but has no claim against O or LP principal.

These are proposed ownership rules, not descriptions of current IndexedEx code. Assignment must be enforceable: the sponsor cannot collect assigned T fees through another path, count them as principal, or pledge the vault's T reserve to cover an LP loss. Every position removal or rebalance must crystallize and separate fees before principal is released. The designated positions and assignment term must be explicit. The sponsor can stop future yield by ending the agreed program or failing to maintain active liquidity, but cannot take already accrued fees or deposited T.

The concrete fee path is:

`underlying-pool swap -> designated active LP position's T fee accrual -> escrow collects the actual T -> T vault backing increases -> existing shares redeem more T`.

O fees stay with the sponsor. There is no O-to-T swap, no exit fee substituted for swap income, and no mark of anticipated future fees. Only the T fee component is captured. A pool producing no such fees produces no yield for this share. Public fee collection primitives support the first stages of this path; fee assignment and segregation require new design work. [P1-P4; proposal]

The sponsor supplies real economic value by giving up fee revenue. A protocol treasury might choose to do that to support a useful reserve asset, but the existence or willingness of such a treasury is not established here. The new depositor's capital is cash backing, not a hidden source of replacement LP capital.

## Mint equation and fee synchronization

All quantities below are native token/share integers:

- `S`: existing share supply.
- `B`: accounted T already in the vault.
- `C`: net accrued T fees that the escrow owes exclusively to the vault and can collect without selling or removing LP principal.
- `A = B + C`: actual redeemable T claims, not the market value of the fee right.
- `D`: T actually received from the entrant, excluding the old book.

Before changing supply, collect and settle `C`, with the collection counted exactly once. The pre-deposit backing remains `A`; collection merely moves the T entitlement into cash. Mint:

```text
m = floor(D * S / A)
```

Then the cash backing becomes `A + D` and the supply becomes `S + m`. This equation uses a T-per-share accounting ratio, but **no O/T price, spot quote, TWAP, liquidation quote, or trade execution price**.

Ignoring integer rounding, incumbents retain the same T entitlement:

```text
S / (S + D*S/A) * (A + D) = A.
```

Rounding down minted shares favors the existing backing. Reject zero-share deposits and require the caller's minimum share output. Initialize with real T and real, permanently retained seed shares, not an unbacked synthetic rate. Keep at least one whole share outstanding so the defined one-whole-share preview is meaningful. Direct unsolicited token transfers do not alter accounted backing or mint ratios.

Pending fees must be included in both previews and the pre-mint collection. Otherwise a depositor can enter just before harvest and take part of fees already earned for incumbents. A fee-growth number is not enough: execution must reconcile it to the net T the permitted escrow path can actually deliver. Pool donations are explicitly possible in v4; if they pass through that path, they are real backing but must not be reported as organic swap income. [P2-P4, P10; accounting rules are proposed]

Future fee rights have no discounted present value in this mint equation. New deposits participate in future fees and dilute the future income per share from a fixed sponsor portfolio. This is an explicit open reward-pool policy, not a fair-market sale of a fixed-income security or a promise to preserve the market value of incumbents' future income.

## Exit execution

For `s` shares, calculate the pre-burn entitlement after synchronizing the same pending T fee claim:

```text
x = floor(s * A / S)
```

Burn `s`, reduce accounted backing by `x`, and transfer `x` T. No pool trade and no LP principal withdrawal occurs.

If the vault's on-address T balance is below `x` because some backing remains as accrued T fees, collect those fees from the escrow first. This is collection of T that already exists as a fee entitlement, not selling O. Once collection is settled, cash equals the redeemable book and suffices for all valid redemptions.

If the escrow cannot deliver the T that the preview included, execution fails closed; it does not borrow from another holder, sell all opposing inventory, or substitute a stale NAV payout. Such failure is a violated backing/collectibility assumption, not an ordinary slippage mode. This proposal does not claim the assumption is already satisfied by every possible underlying hook.

The escrow adapter must support both a standalone manager unlock and collection invoked from an already-unlocked consumer path without nesting `unlock`. Intermediate collection/accounting states must not expose a usable inconsistent rate. These are requirements for the future implementation, not verified compatibility with the current buffer-hook call graph. The relevant public manager distinction is visible in `unlock`, its settlement check, and the unlocked liquidity-modification path. [P3-P4]

## Exact meaning of getRate

**`getRate` returns the WAD-normalized T amount the actual redemption path would deliver for one whole share at the current state, including the same collectible T fees and rounding; its withdrawal-and-sale preview has an empty sale leg because no O belongs to the share.**

For share decimals `dS` and token decimals `dT`:

```text
u = 10^dS
q = previewRedeemT(u) = floor(u * A / S)
getRate = floor(q * 10^18 / 10^dT)
```

This retains the mandated executable semantics. The fact that direct-cash redemption and a T balance ratio coincide is a consequence of this portfolio, not a redefinition of `getRate` as general NAV. The mint calculation remains separately specified. Failure to produce a valid executable rate, or a result rounding to zero, must fail closed for the rate provider. [Local 4; proposal]

**Can a caller move it in one transaction? Yes.** A trade can generate actual assigned T fees, increasing `A/S`; a paid donation through the eligible fee path can do so as well. Rounding can also make small changes. A spot push or the recorded TWAP cannot multiply the value of pre-existing O because the share owns none.

Thus I do not promise an immutable or universally non-manipulable rate. I claim a narrower property: absent an accounting or settlement failure, an increase represents extra redeemable T, not an unbacked revaluation of mixed inventory. Paying fees to raise a rate is not by itself evidence of a profitable attack. It also is not proof that every downstream contract handles changing rates safely.

## Another hook holding the share

Under the proposed invariants, **yes, under the locked law's rate-provider branch**. Configure the correct T/share provider for the buffered T leg. The hook still values held shares by `held * rate`, with decimal normalization; it does not derive a rate from an SE quote. The ordinary SE deposit/exit adapter supplies buffering execution. [Local 4; proposal]

In exact arithmetic, all sizes redeem at the same cash ratio, so `h * A/S` is backed for every valid held share quantity `h`. Using the rounded one-whole-share preview as a rate is conservative: `q/u <= A/S`. With downward rounding and correct unit conversion, multiplying held shares by that rate does not invent a large-position liquidation premium.

This is why the recommendation is materially different from giving another hook a rate computed by selling one LP slice through a nonlinear pool. Here increasing the redeemed quantity does not exhaust an O-to-T market; it consumes segregated T backing.

The raw-balance identity-leg option also exists under the law, but measures shares, not T, and is not my proposed solution. A fresh provider read and consistency between rate reads and buffering execution remain necessary. Locked-law conformance alone does not prove the consumer is safe against reentrancy, stale rates, rounding mistakes, or a trade interleaved with fee collection.

# Conclusions

## One recommendation, with its trade-off

Build no conventional LP wrapper on the evidence of this response. The recommended research direction is the **T-backed vault plus irrevocably assigned T LP-fee receipts**, borrowing Uniswap's separated LP fee collection and the single-asset vault/share interface idea. It needs a funded fee-right supplier and new escrow/accounting integration. [P1-P5; proposal]

It can satisfy the brief's literal functional contract:

- Holders earn an identified part of the underlying pool's actual swap fees.
- They deposit T, receive a T-denominated executable quote, and redeem T.
- Neither issuance nor exit needs an independent price or the same-pool TWAP.
- The exact one-share preview can be linearly consumed because backing is T rather than a nonlinear LP liquidation.

Its cost is not hidden in a swap, oracle or mint equation. **Someone else must fund and bear the LP principal risk.** The deposited T stays reserved. If "use this liquidity" additionally demands using that very T as the underlying AMM's principal while continuing to promise the same backing behavior, this is the closest design I recommend, and that same-capital-reuse constraint is the one it breaks.

I do not assert a universal impossibility theorem covering all asynchronous, auction, insurance or bespoke-AMM designs. I found no opened source establishing the stronger combination under this brief.

## Prior mechanisms, separately

| Prior mechanism | Status in this recommendation | What remains |
| --- | --- | --- |
| Quote manipulation | The reported mixed-book mint/exit channel is removed by construction: neither mint nor redemption converts O inventory using a movable quote. | A rate can rise with paid T inflows. Incorrect fee receivable accounting, accepting an informational `feesAccrued` value without settlement, or stale downstream reads would be separate vulnerabilities. |
| Executed-price allocation | Absent from share allocation: no entry swap, no credited execution price, and no scalar mark of an untraded O book. | New depositors share future fees. Transaction ordering can capture subsequently generated fee income; the design is not JIT-reward resistant. Pre-existing accrued fees must be synchronized to prevent harvest dilution. |
| Vault self-fill | Absent from holder exits: the fee vault never sells O, and its T backing is never used to fill that sale. | The sponsor's separate LP principal can still trade adversely against outside callers, including share owners. That is sponsor LP risk, not guaranteed harmless trading and not a gain magically eliminated for the combined system. |

These conclusions are design deductions relative to the mechanisms in the prior report, not production tests. In particular, relocating principal risk to the sponsor is an economic allocation, not a claim that LP trading losses have disappeared. [Local 2]

# Coverage

| Required target | Status | Answer location |
| --- | --- | --- |
| One recommended design | Answered, conditional on separately supplied LP capital and enforceable fee assignment | Question; recommended structure |
| Actual underlying-pool swap fees, not exit fees | Answered | Concrete fee path; T component only |
| Single deposit, quote and exit token | Answered | T throughout |
| Mint equation and price use | Answered | `floor(D*S/A)`; no token-pair price |
| Exit when on-address T is insufficient | Answered | Collect owed T fees; no sale; fail closed on a broken entitlement |
| Normalized one-share actual preview | Answered | Exact `getRate` definition and decimals |
| Same-transaction rate movement | Answered | Yes, via real receipts; not via repricing O |
| Locked-law consumer | Conceptually answered; integration not executed | Linear T backing and provider branch |
| Three prior mechanisms | Answered individually | Conclusions table |
| Same-pool TWAP premise | Accepted; not used for accounting | Prior report and coordinator source-check note read |
| Current Wings production source | Not independently examined | Current behavior is taken only from the supplied prior report |
| Named public alternatives | Partially examined | ICHI overview and technical prose, returned Arrakis page and Bunni README opened; not audits |
| Optional unopened pages and image equations | Disclosed | Sources section |

# Uncertainty

- No sponsor, assignment terms, designated positions, token choice, fee volume or economic participation incentive has been established. Without the LP-fee assignment this is merely an idle T vault and does not satisfy the fee-earning requirement.
- The proposed escrow must separate actual principal from actual net fees through every position lifecycle operation. Arbitrary underlying hooks can change deltas or reject collection. I have not proven compatibility with them, nor with the current IndexedEx nested callback surface.
- Pending T fee calculation and actual collection must agree, including fee-growth rounding, donations, hook effects and exactly-once accounting. The cited interface warns against treating reported fee growth as organic revenue.
- Fully T-backed does not mean stable in another currency. No claim is made about T's external purchasing power, saleability elsewhere, or resistance to token pause/blacklist behavior.
- Seed sizing, dust bounds, direct-donation treatment, transaction ordering and consumer rate-read sequencing need their own implementation specification and adversarial verification. This response supplies no test or deployed assurance.
- Public pages and `main` source can change. They were not tied to a specific onchain deployment. The ICHI technical page's embedded equation images were not decoded; its prose was read.

# Limits

This design does not provide LP principal exposure to the T-share holder, compound the share's cash into active pool liquidity, collect both currencies' fees into T, price future fee rights, guarantee yield, or make its rate constant within a transaction.

It does not prove every alternative impossible. It does not resolve a stronger requirement to use the same capital simultaneously as volatile LP inventory and fully liquid T backing. It makes the additional capital and transferred fee rights explicit instead of asking the same-pool TWAP or a swap to supply missing backing.

No project tests, simulations, installations, wallet operations, deployments, Git operations, peer-response reads or sub-agent launches were performed. The only authored artifact is this response. The proposal is not implementation authority.
