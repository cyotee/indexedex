# Assignment: validate FullSpread V4 combined closed-form candidates

**Status:** Decision-complete coding assignment. Execute this document. Do not reopen a locked choice, invent a third formula family, or treat a research proposal as adopted product law.

**Prepared:** 2026-09-27. **Authorization:** Local validation code, Python simulations, hermetic Foundry tests, and reports only. This does not authorize finishing the zap feature, changing the PRD, editing the old vault, broadcasting, deploying to a public chain, or migrating instances.

## 1. Outcome

Prove or refute each registered candidate for the **combined exact-output-plus-rebalance transition** on the new FullSpread vault:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/`

A candidate is adoptable only when its derivation, integer domain, and a Solidity test through the real registry-deployed vault proxy all agree. Python may reject a candidate. Python may not adopt one.

Return the adoption matrix, minimized counterexamples, exact commands, and the amendments an implementation plan must record. Stop there.

## 2. Locked decisions

| ID | Decision |
|---|---|
| L1 | Target only the FullSpread tree above. Do not edit `contracts/protocols/dexes/uniswap/v4/` or `StandardExchangeConstantProduct.sol`. V3 shares the latter. |
| L2 | Do not change release CREATE3 salts, release `PkgArgs`, or installed money selectors. Validation wiring uses the distinct salt suffix in §6. |
| L3 | Closed form means every route amount is a fixed expression of observed state, using arithmetic, one quadratic/radical solution, and a predeclared finite adjacent-candidate check. A quoter search, Newton loop, bisection, or “quote then repair” is not closed form. |
| L4 | Integer square-root and division algorithms are allowed inside a closed form. A fixed Newton iteration count used to choose the swap amount is not. |
| L5 | Test both token directions by mirroring price and labels. Do not publish a one-direction formula as two-direction support. |
| L6 | Primary maintenance objective to test, not invent: liquidity-equivalent mismatch `rho = abs(v0-v1)/max(v0,v1)` at the current finite-range position ratio, plus sleeve error outside the existing deadband. Stop trades only when `rho <= 1 bp` and sleeve error is inside that deadband. This is the validation objective. It is not a new owner risk setting. |
| L7 | Sleeve target is `floor(T * p / (1e18 + p))`, `T = D + F`. Fees `E` stay in share backing and out of `T` until collected. Do not test the old `T * p / 1e18` formula as a passing target. |
| L8 | Blocked routes cannot open or nest PoolManager unlocks. Validate their internal closed forms. Do not add blocked external repair. If a blocked off-target exact-output case cannot include required maintenance without an unlock, record `InvalidRoute` as the PRD-consistent validation result and cite PRD §4 and D19. Do not change current release bytecode to enforce that during this task. |
| L9 | Own-position repricing and fee growth during a caller swap belong to incumbents. Do not use a pre-swap book as the post-swap incumbent book. |
| L10 | Withdrawing liquidity changes active pool liquidity before the conversion swap. Do not invert external redemption with blocked `_singleExit`. |
| L11 | Protection parameters for checks are exactly 25 bp repair impact, 50 bp caller-composition impact, 10 bp modeled-quote shortfall, and 1 bp alignment including share flooring. Apply 50 bp only to caller composition, not to every user swap. Compare price, not the same percentage of sqrt price. |
| L12 | Unknown hooks are outside every derived external domain. Do not model them as vanilla. Pons is in scope only as a separately floored fee model, and only after its integer inverse is derived. If that inverse is not derived, mark Pons exact-output `UNRESOLVED`, not supported. |
| L13 | Python uses the standard library only: `fractions`, `decimal`, `json`, `hashlib`, `pathlib`. No pip install, no floating-point oracle, no Solidity FFI. |
| L14 | Deterministic seed is `20260927`. Do not drop failing samples to raise a pass rate. |
| L15 | Release behavior stays intact until a candidate reaches vault-path evidence on the validation package in §6. Do not patch the release execution delegate in place. |

## 3. Binding reads

Read these before editing, and follow them where they constrain tests and deployment:

- `CLAUDE.md`
- `.github/ASSISTANT_RULES.md` and its coding, deployment, and testing documents
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` D1–D19 and §§4–9, §12
- `docs/testing/ARTIFACT_BUILDS.md`
- `lib/crane/.claude/skills/crane-testing/SKILL.md`
- `lib/crane/.claude/skills/crane-deployment/SKILL.md`
- `.claude/skills/indexedex-testing/SKILL.md`
- FullSpread sources named in §6, plus `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol` and `SqrtPriceMath.sol`

Candidate documents are untrusted inputs, not authority:

- `docs/research/uniswap-v4-zapin-plan-2026-09-27/astra-original.md` §§5.2–5.7
- `docs/research/uniswap-v4-zapin-plan-2026-09-27/grok-original.md` §§4–5
- `docs/research/uniswap-v4-zapin-plan-2026-09-27/minimax-original.md` WP-C
- `docs/research/uniswap-v4-zapin-plan-2026-09-27/PARTIAL_ROUND_STATUS.md`

Do not overwrite those originals. Do not wait for or invent a Kimi result.

Use Context7 before claiming an external library API. Local vendored math is the execution reference. Do not send proprietary source or secrets to external queries.

## 4. Candidates and the equations to test

Evaluate these IDs. A corrected equation gets a new suffix, such as `CF-R2`, and does not replace the original result.

### CF-R — holder repair, token0 in

Continuous candidate from Astra §5.2. Let `s` be the start sqrt price, `t` the terminal sqrt price, `L` active liquidity, `l` vault-owned liquidity, `a,b` the position sqrt-price endpoints, `g = 1 - fee`, and `r` the continuous own-fee recovery fraction.

```text
x = (L/g) * (1/t - 1/s)
y = L * (s - t)
T0 = A0 + H0/t
T1 = A1 + H1*t
A0 = F0 - l/b + (1-r)*L/(g*s)
H0 = l - (1-r)*L/g
A1 = F1 + L*s - l*a
H1 = l - L
(A0*t + H0)*(t - a) - (A1 + H1*t)*(1 - t/b) = 0
```

Quadratic coefficients to check by substitution, not by transcription alone:

```text
q2 = A0 + H1/b
q1 = H0 - A0*a - H1 + A1/b
q0 = -H0*a - A1
```

Locked treatment: `r` is not an executable fee formula. Replace it with the pinned integer fee-growth rule before any integer adoption claim. A root outside `t < s`, the current swap step, available free inventory, or the 25 bp price cap is not a repair. Partial repair clamped to the first of those bounds is allowed only when it strictly reduces `rho` without pushing the other sleeve error outside its deadband. If it does not, the swap amount is zero.

### CF-M — exact-share mint plus repair

Continuous candidate from Astra §5.3. For requested shares `m`, supply `S`, and `alpha = m/S`, token0-funded:

```text
t = (L*s - alpha*(F1 - l*a)) / (L + alpha*l)
x = (L/g) * (1/t - 1/s)
B0 = F0 + l*(1/t - 1/b) + r*x
C0 = alpha*B0
requiredCallerInput = x + C0
```

Then apply CF-R to the post-mint holder book. Locked treatment: composition fees accrue to incumbents before mint; repair after mint accrues to all shares then outstanding, including the recipient. Test and reject the shortcut that sizes both contribution legs from the pre-swap book.

### CF-D — exact token output plus repair

On the post-repair price, one `SwapMath.computeSwapStep` exact-output result, then CF-R on the holder book after reserving the exact payout. The payout cannot fund repair. This is one candidate, not a license to solve repair after seeing the swap.

### CF-X — external share redemption

Continuous candidate from Astra §5.5. Burning fraction `z` removes `z*l` first, leaving active liquidity `H = L - l*z`. Token0 output:

```text
o = z*B0 + H*g*z*B1 / (s*(s*H + g*z*B1))
```

Clear that equation to the stated quadratic in `z`, solve the smallest physical root, then repair the remaining book with CF-R. Fees earned after removal belong to remaining liquidity, not the withdrawing user. Do not use `StandardExchangeConstantProduct._sharesForSingleExit` as this inverse.

### CF-B — blocked internal single-output inverse

Forward function is `StandardExchangeConstantProduct._singleExit` at lines 98–110, including each separate floor. The proposed radical is:

```text
shares = S - floor(sqrt(S*S*(reserveOut - amountOut) / reserveOut))
```

Locked treatment: this is a candidate only. Certify it by evaluating the real forward function at the candidate and its predecessor. If that pair does not bracket the requested output, mark this candidate failed for that input. Do not bisect. The one-asset branch is `ceil(amountOut * S / reserveOut)` and is tested separately. Rounding the square root up in `1 - sqrt(1-q)` reduces the fraction; test that direction explicitly against Grok §4.4 rather than assuming it.

### CF-U — dual exact output

Keep the current equal-burn rule: the two ceiled share requirements must be equal. Repair, if idle and required, is CF-R on the remaining book after payouts are reserved. Unequal burns stay `ExchangeOutNotAvailable`. Do not add a user swap.

### CF-G — Grok finite-check variants

Test these as separate candidates, not as corrections to CF-R:

- Repair is one single-tick step, all-or-nothing for exact output. A partial repair that does not reach the price assumed by the user leg is `InvalidRoute(PROTECTION)` for exact output, while public repair may stop at the boundary.
- Share exact-output uses `f = 1 - sqrt(1-q)` and at most the forward checks `shares` and `shares+1`.
- Exact-share mint sizes `ceil(sharesOut * B_i / S)` on the post-repair book, then one exact-output swap for the missing leg.

If CF-G disagrees with CF-M on ordering, report both results. Do not blend them.

### CF-Q — quoter-sized swap plus liquidity delta

Audit the call graph in MiniMax WP-C. If sizing uses `UniswapV4Quoter` search, iteration, or a quote followed by a separately solved repair, status is `REFUTED` for D18. Do not skip the audit. A single unlock does not make a searched amount closed form.

## 5. Exact artifact layout

Create only these paths:

```text
research/uniswap-v4-closed-form-validation/
  README.md
  regenerate.py
  candidates.py
  continuous.py
  integer_core.py
  search_oracle.py
  fixtures/
  counterexamples/

docs/research/uniswap-v4-closed-form-validation-2026-09-27/
  CANDIDATE_REGISTER.md
  DERIVATIONS.md
  VALIDATION_REPORT.md
  ADOPTION_MATRIX.md
  COUNTEREXAMPLES.md

contracts/vaults/standard/exchange/protocols/uniswap/v4/
  UniswapV4FullSpreadClosedFormCandidate.sol

test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/closed-form/
  UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol
  UniswapV4FullSpreadClosedFormProtocolTransition.t.sol
  UniswapV4FullSpreadClosedFormCombinedExactOutProduction.t.sol
  UniswapV4FullSpreadClosedFormAttribution.t.sol
  UniswapV4FullSpreadClosedFormUnsupportedDomain.t.sol
  UniswapV4FullSpreadClosedFormRoundingCounterexample.t.sol
  UniswapV4FullSpreadClosedFormCrossModeInvariant.t.sol
```

`UniswapV4FullSpreadClosedFormCandidate.sol` is a pure library. It must not call PoolManager, a quoter, or a search. Tests and the validation delegate call it. Do not put candidate policy in `StandardExchangeConstantProduct.sol`.

## 6. Validation package wiring

Phase A and Phase B do not modify release facets.

Phase C, and only Phase C, may add:

- `UniswapV4FullSpreadClosedFormValidationOutDelegate.sol`
- a test-only package initializer path in the closed-form test base

Salt every new validation component with:

```text
keccak256(abi.encode(contractName, "ClosedFormValidation20260927"))
```

Do not call the release FactoryService salt helper for these validation-only contracts. The test base must otherwise use `TestBase_UniswapV4FullSpreadStandardExchangeVault`: real PoolManager, CREATE3 facets, `indexedexManager.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg`, and proxy calls.

The validation delegate is a copy of the release out-delegate with one substitution: exact-output amount selection calls `UniswapV4FullSpreadClosedFormCandidate` and reverts `InvalidRoute` outside its certified domain. It must not call `_sharesForSingleExit`, `_rebalanceLiquidReserveBestEffort`, or a quoter. Release facets remain on the release package. Production evidence means the validation package’s deployed proxy, using the same vault accounting code other than that delegate substitution. State that limitation in the report. Do not describe it as a release-bytecode proof.

## 7. Phase gates

Complete the phases in order. A later phase does not start for a candidate that already has a minimized counterexample, except to preserve that counterexample as a Solidity regression.

### Phase 0 — freeze inputs

Record in `VALIDATION_REPORT.md`:

- `git rev-parse HEAD` and `git status --short` for the FullSpread, Crane V4 math, and constant-product files
- SHA-256 of those files
- `forge --version`, `solc --version`, `python3 --version`
- `foundry.toml` settings actually used: solc 0.8.35, optimizer runs 1, `via_ir = false`
- artifact IDs used to deploy PoolManager and the vault package

Do not record environment variables or keys.

### Phase 1 — derivations

Write `DERIVATIONS.md` with one section per candidate. Each section has the equation, conservation check, root-selection rule, fee rule, rounding rule, and domain predicate. A symbolic identity is not an integer proof. For CF-R, substitute the quadratic coefficients back into the position-ratio equation and show the residual is zero over the rationals. Record every degeneracy: zero liquidity, zero fee complement, zero endpoint gap, repeated roots, and negative discriminant.

### Phase 2 — Python

`continuous.py` uses `fractions.Fraction` and `decimal.Decimal` at precision 200 only for root enclosures. `integer_core.py` implements the vendored `SwapMath.computeSwapStep` and sqrt-price amount functions with Python integers, then checks those primitives against Solidity in Phase 3 before any candidate can advance.

`search_oracle.py` may search. Candidate modules may not import it.

Minimum samples, all deterministic from seed `20260927`:

| Domain | Required samples |
|---|---|
| Zero-fee, one-step, both directions | 256 per candidate |
| LP fee in `{100, 500, 3000, 10000}` pips | 64 per fee per direction |
| Protocol fee in `{0, 100, 1000}` pips where the core supports it | 32 per value |
| Sleeve `p` in `{0, 0.2e18, 0.5e18, 1e18}` | 32 per value |
| Own-liquidity fraction in `{0, 1, 50, 99, 100}` percent of active liquidity | 32 per value, excluding states the vault cannot reach |
| Decimals in `{6, 9, 18}` and one lower supported decimal | 16 per pair |
| Boundary: next initialized tick, bitmap word boundary, impact cap, empty output, exact input cap | every boundary once per direction |

For each sample record attempted, accepted, rejected, and feasible-but-rejected counts. A feasible-but-rejected sample is a counterexample to a claimed complete domain, not a pass.

Persist failures as JSON under `counterexamples/`. Minimize each failure before writing the Solidity regression.

### Phase 3 — Solidity

Use this command shape after a production edit, repeating `--test-root` for every closed-form spec:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadClosedFormCandidate.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/closed-form \
  -- -vv
```

Add the validation delegate path to that command only after creating it. Do not run `forge test` alone. Do not delete `out/` or `cache_forge/`. If a new worktree is required, seed both directories from this checkout before the first compile. Wait for compiler exit. Cold compiles can take 20–40 minutes.

Required tests:

| File | Must prove |
|---|---|
| `PrimitiveParity` | Python integer vectors match vendored `SwapMath`, sqrt-price deltas, and liquidity amounts on the production libraries. |
| `ProtocolTransition` | A precomputed action sequence against the real PoolManager matches price, deltas, fee growth, and settlement. |
| `CombinedExactOutProduction` | At least one nontrivial holder-funded repair, one placement-only success, one already-on-target no-trade, and both directions, through `exchangeOut` on the validation proxy. |
| `Attribution` | Caller credit excludes own-position fee growth and repricing; reserved payout cannot fund repair; post-mint repair is shared by the new supply. |
| `UnsupportedDomain` | Next-tick crossing, 100% exact-output fee, unknown hook, and blocked nested unlock revert atomically with unchanged supply and balances. |
| `RoundingCounterexample` | Every minimized Python failure that should revert or select a different candidate. |
| `CrossModeInvariant` | Idle, blocked, exact-in, and exact-output cycles do not create an unbacked claim relative to the independent forward model. Ordinary AMM loss is not a failure. |

Production tests call the proxy. A direct library call does not satisfy `CombinedExactOutProduction`.

Assert exact terminal balances and supply. Where integer rounding has a proved bound, assert that bound. Do not use a percentage tolerance to hide an inverse error. The 10 bp shortfall check is a product control under test, not the test’s comparison slack.

Also assert:

- pretransfer from a code-less caller reverts `EOAPretransferNotAllowed()`
- booked inventory is not re-credited
- exact-in refunds nothing
- exact-output refunds only unused credited input
- final local snapshots equal `balanceOf` for both pool tokens and held self-shares
- no release-package selector change

### Phase 4 — report

`ADOPTION_MATRIX.md` uses only these statuses: `REFUTED`, `CONTINUOUS_ONLY`, `INTEGER_VALIDATED`, `PROTOCOL_VALIDATED_VAULT_PENDING`, `ADOPTABLE_WITHIN_DOMAIN`, `UNRESOLVED`.

`ADOPTABLE_WITHIN_DOMAIN` requires all of:

- a derivation with the domain predicate
- no feasible-but-rejected sample inside that predicate
- primitive parity and production-proxy tests green
- a call-graph list showing no route search
- runtime bytecode of every deployed validation component at or below 24,576 bytes
- gas recorded for the nontrivial repair case

Anything less stays at a lower status. Do not call finite tests a universal proof. Do not call an unproved rejection mathematical impossibility.

## 8. Non-goals and stop rule

Do not implement idle exact-in composition, public repair swaps, quote migration, buffer-hook changes, or release-package rewiring. Do not add an administrator, whitelist, cooldown, or new storage.

Stop when every candidate in §4 has one status, every counterexample has a minimized fixture, and the required Solidity suites have an actual result. If a compile or test cannot be finished, record the command and failure. Do not mark it passed and do not weaken the candidate to obtain a pass.

## 9. Return format

Report:

1. Status for CF-R, CF-M, CF-D, CF-X, CF-B, CF-U, CF-G, and CF-Q.
2. The strongest counterexample for each non-adoptable candidate.
3. Paths to the five reports, Python modules, and Solidity tests.
4. Commands run and their exit results.
5. Any PRD amendment required by a proved domain limit.
6. Confirmation that release salts and the old vault were not changed.

Do not claim the zap feature is implemented or that a passing suite proves economic safety.
