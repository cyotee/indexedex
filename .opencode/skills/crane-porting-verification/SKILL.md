---
name: crane-porting-verification
description: This skill should be used when the user asks to "verify a protocol port", "port tests", "fork test the port", "Behavior for ported protocol", "TestBase for ported protocol", "parity with mainnet", "port verification", "definition of done for port", or needs to write/run tests that prove Crane-vendored protocol code matches upstream behavior.
license: MIT
---

# Crane Protocol Port Verification

Mandatory testing and acceptance gates for any protocol ported into Crane. Complements `crane-porting` (how to vendor) and `crane-testing` (how Crane tests are structured).

## Production-first (same ladder as crane-testing)

1. **Real production / ported contracts** — deploy protocol ports (stubs) or use factories for Crane wrappers.
2. **Existing `TestBase_*` chains** — extend, do not reinvent.
3. **Hermetic ports** under `protocols/.../stubs/` **or** fork bases with live addresses.
4. **Harness doubles** only outside the SUT (mintable ERC20, reentrancy token).
5. **`vm.mockCall`** only for non-SUT isolation.

**Forbidden:** mocking the ported protocol SUT, mocking Crane facets/DFPkgs under test, shipping a port with only compile success.

## Required verification layers

Every port must implement the layers that apply. Core ports need **all of 1–5**. Thin interface wrappers may skip 4 if documented.

| # | Layer | Purpose | Location |
|---|-------|---------|----------|
| 1 | **Compile** | `@crane/` imports resolve; no private dep trees required | `forge build` |
| 2 | **Hermetic unit / integration** | Deploy ported contracts locally; exercise core flows | `test/foundry/spec/protocols/...` + `TestBase_*` |
| 3 | **Behavior libraries** | Interface compliance for consumer-facing APIs | `Behavior_I*` next to protocol or under test infra |
| 4 | **Fork parity** | Same inputs → same outputs vs live deployment | `TestBase_*Fork` + RPC |
| 5 | **Wrapper / Service tests** | Crane Service, AwareRepo, DFPkg paths work end-to-end | CraneTest + factories |
| 6 | **Upstream suite (when portable)** | Bring high-value upstream Foundry/Hardhat cases | Adapted under `test/foundry/spec/...` |
| 7 | **Adversarial (if value-bearing wrappers)** | Donation, reentrancy, auth matrix | `crane-adversarial-testing` |
| 8 | **Gas snapshots (optional but preferred)** | Regressions on hot paths | `snapshots/` + gas tests |

## Directory conventions

```
contracts/protocols/{category}/{protocol}/{version}/
├── stubs/                      # Protocol-faithful deployables for hermetic tests
├── test/bases/
│   ├── TestBase_<Protocol>.sol           # Deploys stubs / wires addresses
│   └── TestBase_<Protocol>Fork.sol       # Optional: fork setup + live addresses
└── services/…                  # Covered by wrapper tests

test/foundry/spec/protocols/{category}/{protocol}/{version}/
├── unit/…                      # Pure unit + hermetic integration
├── fork/…                      # Live-chain parity
├── gas/…                       # Optional gas
└── contracts/…                 # Deeper module suites (Aave-style)
```

Mirror the protocol tree under `test/foundry/spec/` the same way existing Aave/Uniswap/CCA suites do.

## TestBase patterns for ports

### Hermetic protocol setup

```solidity
// contracts/protocols/dexes/example/v1/test/bases/TestBase_ExampleV1.sol
abstract contract TestBase_ExampleV1 is TestBase_Weth9 {
    IExampleFactory internal exampleFactory;
    IExampleRouter internal exampleRouter;

    function setUp() public virtual override {
        TestBase_Weth9.setUp(); // CraneTest factories first via parent chain
        if (address(exampleFactory) == address(0)) {
            // Protocol PORT (stubs/), not a mock
            exampleFactory = IExampleFactory(address(new ExampleFactory(feeToSetter)));
        }
        if (address(exampleRouter) == address(0)) {
            exampleRouter = IExampleRouter(
                address(new ExampleRouter(address(exampleFactory), address(weth)))
            );
        }
    }
}
```

Rules:

- Call parent `setUp()` first (`Super.setUp()` / explicit parent).
- Idempotent guards: only deploy if zero address.
- `new` is allowed **only** for protocol ports/stubs, never for Crane production facets/DFPkgs.
- Prefer `vm.label` on deployed addresses.

### Fork setup

```solidity
abstract contract TestBase_ExampleV1_Fork is CraneTest {
    uint256 internal forkId;
    address constant LIVE_FACTORY = 0x…; // from VENDOR / official docs

    function setUp() public virtual override {
        CraneTest.setUp();
        forkId = vm.createSelectFork(vm.envString("ETH_RPC_URL")); // or BASE_RPC_URL
        // Bind interfaces to live addresses; do not redeploy core protocol
    }
}
```

- Record RPC env var and chain id in the test NatSpec / PR description.
- Prefer pinned block numbers for reproducibility when assertions are brittle:
  `vm.createSelectFork(url, blockNumber)`.
- Compare **exact** values where deterministic (balances, reserves, preview outputs). Document any timestamp/block-dependent drift.

### Behavior libraries

For every interface Crane consumers will call:

- Add `Behavior_I{Name}` with `expect_*` / `isValid_*` / `areValid_*` / `hasValid_*`.
- Declaration tests via `TestBase_I{Name}` style where applicable.
- Reuse existing `Behavior_IERC20`, `Behavior_ERC4626`, `Behavior_IFacet` when the surface matches.

Standards interfaces **must not** be validated only with ad-hoc `assertEq` — use Behaviors (`crane-testing` LR-7).

### Crane wrapper tests

If the port adds Service / Aware / Facet / DFPkg:

1. Inherit `CraneTest` (or gold TestBase chain).
2. Deploy facets/packages via **create3Factory / diamondPackageFactory** — full init, no `address(0)` facets.
3. Assert registry population after deploy when factories register packages.
4. Facet declaration tests: `facetName`, `facetInterfaces`, `facetFuncs`, `facetMetadata` via `Behavior_IFacet`.
5. Package declaration tests when DFPkg exists.

### Upstream tests

When the upstream repo has good Foundry tests:

1. Copy valuable cases into `test/foundry/spec/protocols/...`.
2. Rewrite imports to `@crane/...`.
3. Point fixtures at Crane TestBases / stubs.
4. Drop cases that require unavailable off-chain services; replace with fork asserts if needed.
5. Keep license headers and note origin in file header comments.

## Assertion standards (LR-7 excerpts for ports)

- **Exact** expected values / deltas — not "something changed".
- `vm.expectEmit` with full topics/data when events matter for consumers.
- `vm.expectRevert` with selector (and typed form when available).
- Preview parity for any `preview*` on wrappers/vaults: preview == execute result.
- CREATE3 salt determinism for Crane deployables: same inputs → same address.
- Access-control matrix for any Operable / Ownable / role-gated Crane surface.
- Fork parity for at least one **happy path per primary user action** (swap, supply, stake, etc.).

## Minimum scenarios per protocol type

| Category | Must-cover flows (examples) |
|----------|-----------------------------|
| DEX AMM | create pool, add/remove liquidity, swap exact in/out, fee accrual if exposed |
| CL AMM | mint/burn position, swap across ticks, observe/TWAP if ported |
| Lending | supply, borrow, repay, withdraw, liquidation edge (or fork snapshot) |
| LST / wrapper | wrap/unwrap, rate read, share/asset conversion |
| Vault ERC4626 | deposit/mint/withdraw/redeem + preview parity + inflation awareness |
| Gauge / staking | deposit, claim, withdraw, epoch/edge timing |
| Oracle adapter | quote bounds, stale feed behavior if modeled |

Document protocol-specific risks in the test module header (cooldowns, funding rates, admin roles).

## Commands agents should run

From the **Crane repo root** (`lib/crane` or standalone crane checkout):

```bash
# 1. Clean build after import remaps
rm -rf cache out
forge build

# 2. Port suite (path-scoped)
forge test --match-path 'test/foundry/spec/protocols/<category>/<protocol>/**' -vv

# 3. Named focus
forge test --match-contract <ContractName> -vvv

# 4. Fork tests (requires RPC)
ETH_RPC_URL=... forge test --match-path 'test/foundry/spec/protocols/.../fork/**' -vv

# 5. Gas (if snapshots exist)
forge test --match-path 'test/foundry/spec/protocols/.../gas/**' --gas-report
```

Do not claim the port is done if path-scoped tests were not run (or explicitly skipped with a recorded reason, e.g. missing RPC for fork-only work — hermetic suite must still pass).

## Definition of done — verification checklist

Copy into the PR / task completion note:

- [ ] `forge build` clean for touched packages
- [ ] `VENDOR.md` present with pin, license, import policy
- [ ] No new `protocols/**/dependencies/openzeppelin*` or solady clones for this port
- [ ] All new imports use `@crane/...` (no new remapping aliases)
- [ ] Hermetic `TestBase_*` deploys protocol ports successfully
- [ ] Unit/integration tests cover primary user flows with exact asserts
- [ ] `Behavior_*` for consumer interfaces (or reuse of existing Behaviors)
- [ ] Fork tests against documented live addresses (or waiver + residual risk listed)
- [ ] Crane Service / Aware / DFPkg tests if wrappers exist (factory deploy path)
- [ ] Adversarial smoke if wrappers custody assets
- [ ] Path-scoped `forge test` output captured (pass)
- [ ] CODEBASE_MAP / protocol docs / skill updated or ticketed

## Failure triage

| Symptom | Likely cause | Fix direction |
|---------|--------------|---------------|
| Import not found | Missing external file or wrong major | Expand `external/`, fix path |
| Silent behavior change | Routed OZ consumer to Crane-native | Retarget to external OZ |
| Hermetic deploy reverts | Incomplete constructor args / missing init | Match upstream deploy script |
| Fork mismatch | Wrong address, block, or fee-on-transfer | Pin block; verify address source |
| Stack too deep in Service | Too many locals | Struct-ize params (`crane-code-style`) |
| Tests pass but consumer breaks | Missing Behavior / interface surface | Add interface + Behavior + Service coverage |

## Key files

```
contracts/test/CraneTest.sol
contracts/protocols/**/test/bases/TestBase_*.sol
contracts/protocols/**/stubs/
test/foundry/spec/protocols/
DEFI_PORTING_PRD.md          # per-protocol Verification bullets
AGENTS.md                    # testing + production-first rules
docs/development/testing.md
```

## See also

- `skill:crane-porting` — vendoring layout and dependency policy
- `skill:crane-testing` — TestBase / Behavior / Handler deep dive
- `skill:crane-adversarial-testing` — abuse catalogs
- `skill:crane-deployment` — factory usage inside tests
- Agent: `crane-porter`
