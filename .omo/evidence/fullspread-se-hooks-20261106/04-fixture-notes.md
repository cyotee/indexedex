# Task 4 - genuine FullSpread matrix fixtures

Date: 2026-11-06.

Status: source handoff for parent-owned serialized validation. No build, test,
install, deployment command, commit, or delegation was run by this task.
The reported 152 green tests are the parent's tasks 1-3 baseline, not task 4
evidence. New Hook LP genesis/accounting cases remain expected red until the
family adapters implement FS-HOOK-05 through FS-HOOK-10.

## Parent validation receipt

The parent built runtime artifacts and selected all nine migrated matrix roots
with Solar. `04-fixtures.log` records exit 0 and four executed fixture sanity
tests, all passing. The trailing-dollar nonmember filter did not match the
signature, so it is not counted in that run. `04-fixture-negative.log` records
the corrected prefix filter, exit 0, one executed nonmember-binding test passing.
No tests were skipped. The compiler completed successfully with existing
warnings. These five tests establish task 4's deployment/funding gate, not
green hook component/genesis accounting. The latter remains tasks 5-12.

## Owned edits

Paths below are relative to
`test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `SeMatrix_FullSpreadV4Fixture.sol`.
- `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol`.
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol`.
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`: only make `_seed` virtual.
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`: only make `_seed` virtual.

The FullSpread TestBase did not need changes. Production hooks, packages,
shared arithmetic, `HookLiquidityInvariantHandler`,
`HookComponentAccountingBehavior`, VT regressions, and unrelated dirty changes
were not edited. The existing shared checkout was inventoried before editing;
the owned fixture and nine row files were already dirty, and their prior
changes were retained.

## Deployment, membership and address ordering

The sibling now deploys from the exact same FullSpread package as the primary
vault, through its registry deployment route, on the same real PoolManager.
Each vault has an independently initialized hookless backing key, external
full-range liquidity, and its own public bundle bootstrap. No PairToken
implementation, import, depositPair route, mocked SE, or raw-leg fallback
remains in these rows.

The fixture deploys twelve non-SUT mintable funding tokens once, sorts them,
and assigns records: two central primary members, two sibling members on each
side, and three raw controls on each side. Selecting already-deployed records
places either primary member below or above every companion. There is no
token-address or vault-address salt search. Hook permission-bit mining still
uses the ordinary production hook factory; it is unrelated to token placement.

The hook's pair field is a member token, while its SE field is the real vault
share address. Both primary members retain their external providers. The
sibling also exposes separate external providers for both members. Own-share
membership is explicitly absent and supported public mint/redemption remains
positive coverage. Whole token/SE/provider/weight records stay together when
multi-leg rows sort their product tokens.

## Fixture APIs

`SeMatrix_FullSpreadV4Fixture`:

```solidity
fixtureVault(address vault) external view returns (bool);
rawToken(bool abovePrimaryMembers, uint256 index) external view returns (address);
deploySibling(address placementFace, bool faceAtProductIndexZero)
    external returns (Sibling memory);
acquireShares(address vault, address member, address recipient, uint256 inputBudget)
    external returns (uint256 actualShares);
```

`rawToken` has indices 0 through 2. `Sibling` contains `share`, `provider`,
`otherProvider`, `face0`, `face1`, and `poolKey`; `provider` targets `face0`,
`otherProvider` targets `face1`. `acquireShares` accepts only fixture-deployed
vaults and real member tokens. It funds a non-SUT token, invokes the real
public exact-input mint, and checks the actual recipient share delta. It
runs before the Hook LP call, never inside hook execution.

The dual row file retains `FullSpreadV4MatrixSibling`, with `share()`, `p0()`,
`p1()`, `provider()`, `otherProvider()`, `backingKey()`, and `sideMatched()`.
`p0()` is now a genuine member paired token, not `share()`.

`FullSpreadV4MatrixChecks` in that same owned row provides:

```solidity
membership(address se, address pair) internal view;
raw(SeMatrix_FullSpreadV4Fixture fixture, bool above, uint256 index)
    internal view returns (address);
prepareSeed(SeMatrix_FullSpreadV4Fixture fixture, address[] memory tokens,
    address[] memory ses, address hook, address caller, uint256 inputBudget)
    internal returns (Seed memory);
assertSeed(Seed memory seed, address[] memory tokens, address[] memory ses,
    address hook, address caller, uint256 netLp) internal;
```

`Seed` carries actual `amounts`, per-leg `isShare`, pre-hook share supplies,
hook share/pair balances, caller share balances, and caller LP balance.
Zero SE addresses denote raw legs. `prepareSeed` requires zero Hook LP supply,
acquires SE shares publicly, and approves them for the real installed selector.
`assertSeed` requires full supplied-share intake, exact floor(A/20) share burn,
retained A-floor(A/20) shares, positive actual local proceeds, raw-token
receipts, locked floor, and the returned net LP receipt.
`FixtureSeedLp(hook, lockedFloor, grossLp, feeLp, netLp)` records the actual
initial allocation; task 5/family fee tests still supply the independent
configured-fee oracle, rather than treating that observation as a fee proof.

## Seed routes

| Row | Installed seed selector | Inputs |
| --- | --- | --- |
| single | No Hook LP product | Existing supported wrap/unwrap conversion paths remain. |
| CP single | `depositWithSeShares` | Pre-acquired FullSpread shares plus raw token. |
| dual | `depositFlexible` | Pre-acquired shares for both genuine FullSpread legs. |
| orbital | `depositFlexible` | Two SE-share inputs plus one raw input. |
| weighted two/N3 | `joinProportionalFlexible` | Runtime-length share flags; raw legs remain raw. |
| Curve four | `joinProportionalFlexible` | Two share inputs plus two raw inputs. |
| Balancer two/five | `IUniswapV4BalancerStableLiquidityUnits.joinProportionalFlexible` | Installed units selector, runtime-length share flags and raw controls. |

`test_row_initialPairInput_revertsWithoutFundingChanges` is an added
FS-HOOK-10 negative, expected red until the dual adapter rejects pair-funded
genesis. Existing positive bodies were not converted to expected reverts.

## Exact fixture sanity tests for the parent

All four are in
`UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault`.
They deploy/bind hooks in setup but never enter Hook LP genesis/accounting:

- `test_fixture_twoFullSpread_deploymentsAndMembership`: registered genuine
  vaults/package, same manager, distinct hookless keys, separate live
  full-range salt-zero positions, valid paired members, omitted own shares,
  all four external provider bindings, and acquired sibling bundle shares.
- `test_fixture_twoFullSpread_publicSharesAndRedemption`: public acquisition
  and exact 5% share-in/member-out redemption on both faces of both vaults;
  actual share burn, output receipt, position identity and zero own deltas.
- `test_fixture_memberOrientationsAndTargets`: both primary provider targets
  on both product sides, separate product hooks and valid paired bindings,
  without address searches or Hook LP issuance.
- `test_fixture_foreignManagerKey_reverts`: a key initialized only on a
  foreign real manager rejects on the bound FullSpread package, leaving
  neither deployed code nor a registered partial vault.

`test_row_nonmemberShareBinding_reverts` separately asserts the exact
`TokenNotInVaultTokens` binding error when a share is supplied as a fake pair.

## Original 36-instance traceability

No original public test name or inherited regression suite was removed:

| Original group | Count | Migration |
| --- | ---: | --- |
| Twelve dual names listed in task 4's parent plan, standalone and inherited DualUnwrap | 24 | Valid second FullSpread member binding; both targets/orientations and positive preview/swap bodies remain; canonical directions assert actual second-vault redemption/mint rather than transfer-only share supply. |
| `test_row_identity_pairToken` in orbital, weighted N3, Curve, Balancer five and inherited unwrap rows | 8 | Historical names now validate genuine sibling membership, share-funded genesis and positive composed directions; no raw fallback. |
| Dual `test_row_identity_thisVault`, standalone and inherited | 2 | Positive own-share processing with valid member pairing and no self-membership; separate nonmember negative added. |
| `test_dualUnwrapApprovesAndCompletesExit` | 1 | Untouched VT body inherits the real fixture and share seed. The legacy `identityAccepted` observation is set only after successful valid package deployment; no positive test is gated by it. |
| `test_disabledBufferedWithdrawalApprovesAndCompletesExit` | 1 | Untouched VT body inherits CP's new pre-acquired-share seed; positive disabled component payout remains family/VT integration work. |

Composed probes that assert a real redemption now use 10-token input, rather
than a 1-token local-only payout below the new genesis local balance. Raw
controls stay raw; the orbital pair12 historical control now distinguishes
the genuinely converting sibling from its raw companion.

## Parent validation commands

Run only after freezing the selected shared source closure and serializing
artifact writers. These are commands to run, not execution receipts:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol \
  -- --isolate \
  --match-contract '^UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault$' \
  --match-test '^test_fixture_' -vv

forge test --use solar --isolate \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*SeMatrix_UniswapV4FullSpreadStandardExchangeVault*.t.sol' \
  --match-test '^test_row_nonmemberShareBinding_reverts$' -vv

# Expected red-before until tasks 6-12 provide the family adapters:
forge test --use solar --isolate \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*SeMatrix_UniswapV4FullSpreadStandardExchangeVault*.t.sol' -vv

# After family integration, retain the inherited instances as well:
forge test --use solar --isolate \
  --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol' -vv
```

The artifact-first invocation must also include any concurrently changed
production family sources selected by the parent. Require nonzero discovery
and actual execution counts. No task 4 runtime count, gas receipt, or green
claim exists yet.

## Verification and remaining migration gaps

Final-frontier permitted LSP diagnostics returned `No diagnostics found` for
seven paths: the shared fixture, CP concrete row, dual concrete row, single
concrete row, Balancer five-leg row, and the two changed family Behavior
files. Fresh diagnostics timed out after 3000 ms for orbital, Curve,
Balancer's base row, and both weighted rows; one targeted retry returned the
same timeouts. Earlier diagnostics for those files preceded the final
address-search removal and do not certify the final frontier. No compiler
or test pass is claimed.

Static source comparison retained every pre-existing explicit `test_` name
in all nine rows and added six in the dual row: the four fixture sanity
tests, the nonmember negative, and the expected-red pair-input genesis
negative. Those are source declaration counts, not discovered or executed
test counts. Source inspection found no PairToken imports/references,
identity-revert fallback, or CREATE2 address-search code in the edited paths.

Parent tasks 5-17 still own component-book adapters, independent fee/net/floor
equations, disabled local-only versus SE-deficit routes, aliases and minima,
genesis rejection/rollback, and no growth-fee issuance. The new `assertSeed`
checks intentionally do not let the old no-redemption share seed pass.
Existing blanket exact-output rejection expectations outside fixture
funding need their family/integration owner to distinguish local-only
success from an actual unsupported SE exchangeOut call. No such production
behavior or VT body was edited here.

The nine-row gas tests still require genuine isolated parent execution.
Disjoint backing keys do not establish same-backing-pool sequential safety.
No task 4 log, negative-test log, or final all-green evidence is fabricated.
