# Task 10 - weighted component accounting

Date: 2026-11-06.

Status: implementation and test sources are frozen for parent-owned serialized validation. No Forge build, test, install, deployment or commit was run by this task. No runtime pass, code-size pass or deployed-bytecode linkage pass is claimed.

## Verification receipt

- Native LSP diagnostics were requested for all 34 changed Solidity files (13 production, 21 test files). Final responses: No diagnostics found for every file. A preceding pass detected missing IERC20/IStandardExchangeIn imports in the decimal TestBase; those imports were added, and a later successful fresh response cleared that file after intervening diagnostic timeouts.
- git diff --check restricted to the two assigned weighted directories returned exit code 0 and no output.
- Read-back inspection compared every owned changed source against this task's recorded text. No unexpected concurrent changes were found in those files.
- All pre-existing dirty work was retained. The initial inventory included prior DFPkg membership corrections, FullSpread row migrations and the untracked component adapter. Git's total diff includes those earlier changes; the manifest below identifies this task's resulting frontier, not authorship of every dirty line.

## Implemented contract

The existing weighted storage slot is retained. seReserves is appended as the attributed SE-share book; rawReserves is the independent local/raw book, no longer overwritten from physical balances. vaultRegistry is appended and initialized from the package's existing trusted registry dependency. Unknown/foreign registrations and overlapping pair/share roles are rejected instead of assuming an enabled SE. No package argument or migration was added.

ClaimLib reconciles exact input/output balance deltas with both exchange tuple words. Caller conversions do not book assets. Pool conversions book actual shares and input refunds once. Enabled partial/all input refunds remain local; disabled pool input never calls the prohibited SE mint. Swap pricing includes local pair tokens plus provider-rated booked shares. Output consumes local inventory first and spends rounded SE shares only for a deficit. Local-only exact output bypasses the SE's unavailable exchangeOut; a deficit retains its existing inverse-route limitation. No ambient cleanup deposit remains.

LiquidityLib now owns the weighted family's acceptance operation, rather than a universal cross-family engine. Existing-supply joins snapshot independent components, convert only caller assets, calculate one common native-unit mint limit, accept ceil quantities, and return excess caller assets. Entirely empty legs may be funded during the existing partial-book progression only alongside a mint backed by every incumbent positive component; they never independently justify LP issuance. An existing leg's zero component requires zero and its unused caller inventory is returned. All-zero incumbent books cannot mint.

Single-asset and missing-leg entries first execute the family's weighted trades, then apply quantity-based acceptance to the post-trade/pre-mint book. Preowned source shares are retained while only the portion needed for missing legs is redeemed. This allows permitted disabled share-input aliases without forcing a prohibited source-vault remint. The existing weighted curve is used for those internal liquidity trades; public swaps keep their 30% input/output limits, and liquidity entries keep the 3x invariant-growth bound and owner-only uncapped policy. Weights never replace the final component constraints.

Genesis accepts incoming shares on each funded SE leg, redeems floor(A/20) through exact-input redemption, verifies complete share consumption and positive actual pair receipt, and seeds the existing full/partial weighted function from normalized retained shares and raw quantities. The 1,000-LP floor is allocated once. The active usageFeeOfVault/feeTo configuration splits only backed gross LP, including genesis after the floor. Retired growth minting and growth supply projections are removed; reserved kLast fields are not repurposed.

Proportional exits allocate floor(b*C/T) independently, including local pair claims, with no extra dust haircut. Share-requested output converts only the exiting caller's local claim and fails atomically if that requested conversion is unavailable. Cross-leg exits withdraw the caller basket before trading it against the remaining book. Exact-output surplus remains local instead of triggering a cleanup mint.

Installed direct, flexible, address-array, allowance/Permit2, SE and Native SY paths use these cores. The old aggregate LiquidityTarget now composes the installed targets rather than retaining duplicate economics. The Standard Exchange facade reports actual same-input refunds. Exact-net quotes are forward-verified funding budgets, not a promise of globally minimal conversion input: execution caps funding by the caller maximum, mints the minimal fee-grossed LP quantity and returns actual input debit after component refunds. Tests preserve exact caller-debit and LP/fee receipts while replacing the superseded assumption that every quoted budget unit must be spent.

Composed bond/swap views use booked components, retained input refunds and actual supply instead of retired growth supply. SY exchangeRate is an informational weighted swap-reserve mark, not an LP ownership denominator.

## Installation and metadata

No product selector, facet cut or interface ID was added or removed. Existing facet metadata continues to declare the installed selectors. No new linked library name was introduced: the already linked weighted LiquidityLib/ClaimLib/Math libraries carry the changed implementation. The artifact FactoryService resolves their current link references; the parent must rebuild dependent facets, not reuse old out/ bytecode. DFPkg internal initialization is included in the source list below.

## Test sources and scenarios

The component adapter contains 18 newly declared family scenarios in addition to the inherited shared baseline. It has concrete n=2 and n=3 coverage plus an independent n=8 adapter that avoids inheriting two-leg matrix assumptions. Source declarations are not executed test counts.

New checks include exact local equality without SE redemption; a zero-local follow-on join; permitted disabled-share genesis; atomic disabled share-requested exits followed by successful pair exits; dust and short genesis rollback with a positive recovery; inactive and zero-recipient fees; direct/flexible/address-array/SE/SY aliases; Permit2 share funding; actual refund tuples; cross-leg exit receipts; deadlines; and a real PoolManager callback that settles input, executes the hook, deliberately leaves output credit unsettled and verifies outer rollback. The n=3 case adds a missing SE leg as local-only backing, then performs a disabled pair join and local swap without an SE mint.

The independent post-trade oracle executes actual public weighted swaps separately, observes the resulting component book, and checks ceil backing/no dilution before comparing direct, flexible, SE, SY and exact-net aliases to that book. A second oracle covers preowned-share aliases with the source SE disabled. These do not compare post-trade ownership against the original pre-trade basket. The parent owns the corresponding correction to the cross-family exact-net behavior.

Family-owned seed helpers were migrated in the normal/decimal TestBases, n=8, partial, owner-only, owner-during-lock, hostile-token, Permit2, address-array and Wings consumer suites. Superseded growth-fee, ambient-donation, local-dust and blanket local-exact-output rejection assertions were updated without replacing positive calls by reverts. The family-local SeMatrixBehavior seed and component assertions were included under the assigned weighted test directory. Cross-family behaviors, shared fixtures, HookLiquidityInvariantHandler, FullSpread vault tests and configs were not edited.

## Parent validation commands

Run only after freezing this frontier and the selected shared dependency closure. The artifact helper builds affected runtime artifacts before testing and supplies Solar. No command below was executed by this task.

Targeted real FullSpread component/alias matrix:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol \
  -- --isolate -vv
```

Complete weighted family, including decimal, staged-init, metadata, recurrence and invariant suites:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  -- --isolate -vv
```

Capture actual exits/counts/traces as 10-weighted.log and 10-weighted-negative.log or cross-reference one complete run. Those logs are not asserted to exist.

## Risks and integration requirements

1. Compiler/code-size/linkage and all runtime tests remain parent-owned and unrun here. LSP is not a substitute for those gates.
2. Stateful SE conversion preview/execution parity, particularly repeated conversions, optional external-deposit projections and exact-net funding/refund rounding, needs the targeted runtime assertions. No parity receipt is claimed.
3. Foreign-registry SEs are intentionally unsupported unless a trusted authority can be established within the existing package contract; no arbitrary registry fallback was added.
4. The shared exact-net behavior correction and shared invariant handler migration remain parent-owned integration work. This task did not weaken or edit those files.
5. Conversion splits are forward-verified and budgeted, not claimed globally optimal. Exact-net gross LP is minimal for the fee rounding even when the conversion budget is not minimal.

## Changed production paths

- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol

## Changed test paths

- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Adversarial.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_B6Firm.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Liquidity.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_N8.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerOnlyLiquidity.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Partial.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_WingsRecurrence.t.sol

## Stable source frontier

Manifest digest: 1ac37ec2ab7bece5d1a12b55c7c4343b0f24f2938d7558ce66b85244bec02a26

The digest is SHA-256 of the following ordered UTF-8 lines, each formatted as sha256, two spaces, repository-relative path, newline. The evidence note itself is excluded. No source edits are planned after this handoff unless parent validation produces a coordinated failure to fix.

```text
7da0464e27fe0387886e778e27f12c43da5b9fbf7903069f4f0ec5a43bf7b796  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol
77192c822bc6e55759f86c7c4587a401fe8633bfec500be3c50c38c0c161acf9  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol
dbdaf6dc5fcca655771464151b332051079edeeaa7dfaeae88e020c493dc47ee  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol
f489c68b60ebc1a06336879d439cb857b73760eb8a3d7d9511c339932775887e  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol
bf123cb433f93b0269f7043cf5542ad143db4c966ef2e10ac31ff51b6379e6c1  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol
30024b3b89bcd2cfc45920cf279f88769db95a1119259effcdd98ceafb3a78d8  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol
65fec4f5adc44fac14fca230b2f1e11cc74ac9a247591c18b3f4c072b1a613ea  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol
8ef97891e62e5c0dc08960229449398657a2d57264d389fedd37e68ae0be143a  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol
a24031eae5df21aae718a7c9fdf44b9988f1252cebbfdfb7873070641b78f713  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol
b42259eed449c914bc010ec3b14a9403ed4ed73091352b3a4a29142bf28762e9  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol
70c48d8e7f95829e79e1b855dd142679f3d2dc6c268e926f4442fb00a8496b6f  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol
24f573592e145b875c9f50fa60e73d15903729ed2f2fbfca6ea6f1011ed90ac3  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol
8d3a9a97e67c5f801106684af2fb73d7a93f00e1c1799171e73d92eb9c3cbec2  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol
669c0b514d263229188fda4cc0154860ccf877ebf08f2d7acf73825a3f806196  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals.sol
a48a1dcd1113bcb92a01342a875d3f679fb9c37861231cc8dbc864e94731ee04  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals.sol
b37e818be34a13bfc63147d29d9579b1e39bd4ba705ec46a2e412332e116f2b5  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals.sol
d7492be554f245adfc7b0e19a60d320d14387ec0fc37f0093ba18b605edd970f  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals.sol
d7cb09bf4c1d6869a8328755b2f000cc4d2cea377e348a398dddbef578a1c8c6  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol
0a5e8187e6d3ec3f71487cd7d4b77bbe804be527da73a69e4945c8c5cc10f41b  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Adversarial.t.sol
eec8122427488aa3da7f694719c06d5ba7aea8d882ed60721cd6f846950b0716  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_B6Firm.t.sol
798fa693cfccfd53dd7ac776b9cf49f6bb98957dc634209b0d202850280e71df  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol
76d1ef1dc6d0534e59d53a50c4e838c858a48e8c3279951347bc1197c124582d  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol
4fb6fc23737f51e071961ebcd9e9504bf4c234fa969469141fc4a143ab777ac7  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Liquidity.t.sol
28978739b81d22cefc2e111dac8f03f7803a7b2a525fed3d269d1b722abed315  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_N8.t.sol
4614d96088bb0570c3648747249fec2d14f34507ea2b81a81c8b506c55a70cc8  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol
925b950fe093ea411cfe6b62e7e08e406ed7dec59091bf1f72d233fd10c13bbf  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerOnlyLiquidity.t.sol
5cb2227ae266a69bdf2e2fc650421772e987a61c9348b889085303678530dda0  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Partial.t.sol
c69f932d7c12cfea0fd8c85b0d218acbb27f42b7063850965a5ec1cb0c373884  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol
71f40836b88c50e8089162f575468f2d29a68c72d377bfe270ce6a519f9b5af8  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol
aac810428fa1811d221033ec98fd451d3865a28ceba8ac22fe7c33f93fb32b0c  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol
f64126238b97bced02594984acf89103865f92361ab26a6f03fddcd7cf107296  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol
43fe077d9f19f078ddd64ad62cd1c75f3afcf751e3aea11830cc3e17b4a97795  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
420659c8e0374c415256c536be48a9c48d8df5b62c51517874036478d74bbfdc  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol
30d0ff85a2b1afd0def9574c9c44550c94d1845387dbcb6b8a46c7448a0036e9  test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_WingsRecurrence.t.sol
```
