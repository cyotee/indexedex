# Member response

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: astra
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/astra/response.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the published vault specification, and any implementation it has, meet these four needs: a reserve exposed to trading fees; a deposit of either token; a withdrawal into one token; a quote of one vault share into one token?
- Required targets: [Published specification](../../../../research/v4-own-vault-spec-20261027-01a177b3/REPORT.md), repository path `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md`.
- Optional context: the specification's coordinator resolution was offered but not opened or used.
- Admitted read scope: [Council brief](../../brief.md), required specification, cited repository source needed for the assessment, and repository implementation discovery. Excluded third-party source and peer artifacts were not opened.

## Evidence

`REPORT.md` below means the required specification, not a peer report.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Product and reserve | `REPORT.md:42-44`, sections 2 and 3 | source observation | One diamond owns one pool position. Deposited capital funds that position; trading fees accrue into separate escrow. |
| Fee entitlement | `REPORT.md:94-127` | source observation | Collect fees before balance changes, index them to existing supply, crystallize account earnings, and pay them in kind through `claimFees`. Claims remain with the earning account after transfer or exit. |
| Entry | `REPORT.md:131-141` | source observation | Entry pulls both currencies, permits a zero side only when that side is unused, and expressly excludes a vault swap or an implemented zap route. |
| Exit | `REPORT.md:143-159`, section 8 | source observation | Convert burned shares into liquidity units, remove that slice, sell its opposing principal, and pay only target currency; insufficient output or incomplete execution reverts atomically. |
| Quote | `REPORT.md`, section 7, especially `184-196` | source observation | Quote one whole share by simulating its liquidity removal before selling its opposing principal. Normalize actual target output to 18 decimals. Unsupported or incomplete quotes revert. |
| PoolManager boundary | `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-65,94-135` | static analysis | `unlock` calls the caller's callback and checks settlement. `modifyLiquidity` uses `msg.sender` as position owner and returns a separately identified fee amount. Its returned `callerDelta` includes principal plus fees before hook adjustment; it is not a principal-only return value. |
| Implementation discovery | Scoped first-party Solidity searches and production filename inventory, described below | source observation | No contract implementing this specification was identified. Exact specification markers had no matches in 4,676 searched Solidity files. |
| Implementation status stated by the source | `REPORT.md:38,42`; brief, Review contract | source observation | The report describes a new diamond that a later agent implements; the brief explicitly says there is no Solidity implementation. Repository discovery is consistent with that statement. |

Implementation discovery used these read-only searches:

- In `contracts/`, searched Solidity for `redeemTarget`, `feePerShare`, `uReceived`, `claimFees(address`, `OwnVault`, own-vault wording, and homogeneous-position wording. The broad wording produced unrelated filenames, not this vault.
- Widened to first-party repository Solidity, searching `redeemTarget|feePerShare|uReceived|v4-own-vault|OwnVault`: no matches, with 4,676 files searched. Dependencies, generated output/cache, frontend, documentation, excluded source names, and the unrelated existing vault subtree were excluded from this content search.
- Inspected V4-named production filenames and the complete standard-exchange V4 subtree listing. The initial filename limit was expanded from 300 to 600; the expanded result contained 507 paths without a truncation notice. No new own-vault package was identified. Wings is not the reviewed target and was not reviewed as an implementation of this specification.

These searches support a scoped absence finding, not a claim to have audited every contract or searched other branches or machines. Public queries: not used.

## Assumptions

- "Deposit of either token" means a caller can supply token 0 alone or token 1 alone to a defined product route, not merely supply both tokens or happen to supply the sole token required by an out-of-range position.
- "One token" on exit means the configured target currency. The question does not require choosing either output currency on each call.
- A share quote refers to the property redeemable by that share. The question does not expressly require selling an account's separately owned historical fee claims in the same transaction.
- The needs do not promise successful execution without liquidity, irrespective of slippage, or on every possible hook. Ordinary execution limits and the specification's explicit quote domain are therefore disclosed rather than treated as invented universal guarantees.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md` | required | examined | Read all 320 lines, including product rules, sequences, exclusions, invariants, and limitations. |
| Implementation of that specification | required discovery | absent | No matching implementation found in the searched first-party repository scope. The brief and specification agree that implementation is future work. |
| Cited `PoolManager.sol` | optional dependency context | partially examined | Read lines 1-155, including callback, ownership, liquidity accounting, and the beginning of swap execution. Did not review the full dependency or its libraries. |
| Specification coordinator resolution | optional context | not examined | Not used; conclusions rely on the published target itself. |

## Conclusions

**The specification does not meet all four needs: it explicitly fails either-token deposits. No implementation of this vault was found, so none of the four needs is established as working software.**

The following verdicts grade the specification's requirements, not implemented behavior. As a delivered product, the result is partial: a specification exists, one required feature is excluded, and executable implementation is absent.

| Need | Verdict | Evidence and qualification |
| --- | --- | --- |
| A reserve exposed to trading fees | **met** | Sections Product, 2, and 3 place deposited capital in the diamond-owned pool position and prescribe collection and attribution of its trading fees. This is fee exposure, not a promise of continuous earnings, automatic compounding, or fees increasing `U`. The fee-claim implementation and its solvency are unverified. |
| A deposit of either token | **failed** | Section 4 requires the currencies needed to add liquidity and forbids the vault from converting a single input. A zero side is allowed only when the position does not need it. No defined single-token route covers both input choices. Finding ASTRA-01. |
| A withdrawal into one token | **met** | Sections 5 and 8 define removal of the redeemed share's liquidity slice followed by sale of only its opposing principal and payment in the configured target currency. This is conditional on a complete sale and `minTargetOut`; failure reverts, not an in-kind payout. Historical fee credits are a separate in-kind claim. |
| A quote of one vault share into one token | **met** | Section 7 defines `uOut = floor(10^18 * (U + 1) / (S + 10^9))`, removal first, exact-in sale against the post-removal state, then `floor(q * 10^18 / 10^dT)`. This is a normalized single-share target exit preview, not NAV issuance accounting or total liquidation divided by supply. |

The quote verdict is limited to its explicit domain: enough outstanding supply for a whole share, a nonzero redeemable slice, a complete sale, and hook/fee behavior the preview can reproduce. It can revert for unsupported hooks, unquotable dynamic fees, insufficient fill, or zero rounded output. The text does not establish actual preview/execution parity; only a later implementation review can do so.

The separate fee ledger is a material product boundary: a user who redeems all shares can still have two-currency fee credits to claim. Likewise, `getRate` does not value that user's historical earnings. Those are explicit exclusions, not concealed omissions. The four stated needs alone do not require an all-wealth single-token exit or transfer of historical fees with the share, so I do not reopen the receipt choice or classify those stronger requirements as defects.

There is no council-consensus claim in this independent response.

## Review findings

### ASTRA-01 - High: the entry specification excludes the required either-token deposit

- Location: `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md:133-139`; reinforced by section 8's deposit step 3 and the Recommendations instruction not to add a vault zap.
- Invariant or requirement: the vault product must accept a deposit funded by either pool token alone.
- Impact: a caller holding only token 0 cannot fund an entry that needs positive amounts of both currencies; the same applies to token 1. The existing zero-amount exception is conditional on the position not needing that currency, so it does not supply the general feature. The report itself directs an external contract to perform the missing swap while explicitly saying that contract and route are not this vault. An implementer following this specification faithfully will omit the requested behavior.
- Static failure case: choose an entry state in which both currencies are required. The caller offers `(amount0 > 0, amount1 = 0)`. The specified path has no way to obtain the missing currency, and zero received liquidity must revert. Exchanging the input sides has the same problem. This is reasoning from the stated entry contract, not a transaction result.
- Fix direction: revise the requirements, under separate authorization, to include a concrete single-token route for both pool currencies. It may be a vault entry or an explicitly specified product router, but its swap, custody, refunds, minimum-share protection, and integration must be part of the deliverable. Mint from the liquidity actually received using the existing liquidity-unit equation. Merely saying an unspecified external contract may swap is not completion. Adding this route should not be represented as proof of manipulation resistance.
- Evidence class: source observation and static analysis. No implementation or reproduction test exists in this review.

### ASTRA-02 - Coverage gap: there is no implementation to establish any of the four operational capabilities

- Location: `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md:38-44`, section 6's deployment description, and the repository discovery results recorded under Evidence.
- Invariant or requirement: an assessment of working reserve exposure, entry, exit, and quoting requires the implementation of this specified vault, not a different vault or prose alone.
- Impact: there is no identified contract surface on which to verify position ownership, either-token entry, target-only redemption, fee accounting, or one-share quote parity. The specification-level passes above must not become implementation approvals. This is an absence/coverage finding, not a discovered defect in hypothetical Solidity.
- Fix direction: after resolving ASTRA-01 and obtaining separate implementation authorization, implement the specified vault and identify its production paths and acceptance evidence for a later review. Do not substitute an unrelated existing product or claim this consultation authorizes that work.
- Evidence class: source observation and inference from scoped repository search, corroborated by the brief. No deployment or runtime evidence was supplied.

## Limits

- Runtime or extraction proof: static Markdown/source reading and repository searches only. No project tests, builds, deployments, wallets, or transactions were run.
- Not examined: peer responses, council draft/final, optional specification resolution, excluded StonkBrokers/PairToken/Clutch/Sourcify source, unrelated vault implementation, full PoolManager internals, live deployments, other branches, and ignored/generated artifacts.
- The dependency read does not establish the correctness of a future vault's fee accounting, quote simulation, callback guards, or bootstrap lifecycle. Search results reflect the live workspace, not an atomic repository snapshot.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
