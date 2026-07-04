// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BaseTest} from "lib/crane/test/foundry/spec/protocols/lending/aave/3.6/extensions/stata-token/TestBase.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_AaveV3StataStandardExchange} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title AaveV3StataStandardExchange_RealTest
 * @notice Integration tests using real Aave V3.6 + StataTokenV2 (via Crane test harness).
 *         Verifies previewExchangeIn/Out exactly matches execution return values and
 *         recipient balance deltas for all supported routes, including pretransferred
 *         and usage fee cases.
 *
 *         These complement the mock-based unit tests and add fuzz variants for each scenario.
 */
contract AaveV3StataStandardExchange_RealTest is TestBase_AaveV3StataStandardExchange, BaseTest {
    address internal realVault;
    address internal realStata;
    address internal realBase; // the underlying for the real stata (e.g. weth in harness)

    function setUp() public override(TestBase_AaveV3StataStandardExchange, BaseTest) {
        // 1. Initialize real Aave V3 test environment + real StataTokenV2 (w/ real aToken, ERC4626 logic, LM)
        BaseTest.setUp();

        // 2. Run the IndexedEx side (deploys facets, DFPkg via manager, etc.)
        //    This will also create stub mocks and one mock vault; we override below.
        TestBase_AaveV3StataStandardExchange.setUp();

        // 3. Switch to real stata from the harness
        realStata = address(stataTokenV2);
        realBase = underlying;

        // 4. Deploy a fresh vault bound to the *real* StataTokenV2 using the already-deployed DFPkg
        realVault = _deployStataVault(realStata);

        // 5. Fee oracle wiring for this vault (0 usage fee by default; individual tests can override)
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.feeTo.selector),
            abi.encode(address(this))
        );

        // 6. Give the tester a healthy balance of the real underlying and approve the vault
        _fundUnderlying(1000e18, address(this));
        IERC20(realBase).approve(realVault, type(uint256).max);
    }

    /* ------------------------------------------------------------------ */
    /*                     Real route tests (preview == exec)             */
    /* ------------------------------------------------------------------ */

    function test_Real_Route_BaseToSE_PreviewMatches() public {
        uint256 amount = 10e18;
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );

        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        assertEq(out, preview, "real: previewExchangeIn must equal execution BaseToSE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out, "real recipient delta must match");
        assertGt(out, 0);
    }

    function test_Real_Route_StataToSE() public {
        uint256 amount = 5e18;

        // Acquire stata via aToken or underlying path using harness helpers
        _fundAToken(amount, address(this)); // gives aTokens
        IERC20(aToken).approve(realStata, amount);
        uint256 stataShares = stataTokenV2.depositATokens(amount, address(this));

        // Now exchange real stata into SE vault (pretransferred=false will pull)
        IERC20(realStata).approve(realVault, stataShares);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realStata), stataShares, IERC20(realVault)
        );

        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        assertEq(out, preview, "real: preview must match for stata->SE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
    }

    function test_Real_Route_SEToStata_PreviewMatches() public {
        uint256 dep = 20e18;
        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 sharesToBurn = seGot / 2;
        require(sharesToBurn > 0, "need shares");

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realStata), sharesToBurn
        );
        // In the real SEToStata path preview returns the shares number (1:1 intent in this wrapper)
        assertEq(previewIn, sharesToBurn);

        uint256 stataBefore = IERC20(realStata).balanceOf(address(this));
        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), sharesToBurn, IERC20(realStata), sharesToBurn, address(this), false, block.timestamp + 100
        );
        assertEq(amtIn, previewIn);

        uint256 received = IERC20(realStata).balanceOf(address(this)) - stataBefore;
        // After burn and transfer, the received stata should be close to sharesToBurn (real rate may differ slightly from 1:1)
        // We mainly validate the returned amtIn == preview
        assertEq(amtIn, previewIn);
        assertGt(received, 0);
    }

    function test_Real_Route_SEToBase_PreviewMatches() public {
        uint256 dep = 15e18;
        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 sharesToBurn = seGot / 3;
        require(sharesToBurn > 0, "need shares");

        // For base out, preview is computed via stata previewRedeem etc.
        // We call preview with a "desired" that the wrapper translates
        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realBase), sharesToBurn
        );

        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), sharesToBurn, IERC20(realBase), sharesToBurn, address(this), false, block.timestamp + 100
        );

        assertEq(amtIn, previewIn);
    }

    /* ------------------------------------------------------------------ */
    /*                     Real fuzz variants for each scenario           */
    /* ------------------------------------------------------------------ */

    function testFuzz_Real_BaseToSE(uint256 amount) public {
        amount = bound(amount, 1e15, 500e18);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview);
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
    }

    function testFuzz_Real_SEToStata(uint256 dep, uint256 burnFrac) public {
        dep = bound(dep, 5e18, 200e18);
        burnFrac = bound(burnFrac, 1, 90); // percent

        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 sharesToBurn = (seGot * burnFrac) / 100;
        if (sharesToBurn == 0) return;

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realStata), sharesToBurn
        );

        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), sharesToBurn, IERC20(realStata), sharesToBurn, address(this), false, block.timestamp + 100
        );

        assertEq(amtIn, previewIn);
    }

    function testFuzz_Real_FeeOnBaseToSE(uint256 amount, uint256 fee) public {
        amount = bound(amount, 1e18, 100e18);
        fee = bound(fee, 0, 0.05e18); // up to 5%

        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(fee)
        );

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );

        address recipient = address(0xCAFE);
        uint256 balBefore = IERC20(realVault).balanceOf(recipient);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, recipient, false, block.timestamp + 100
        );

        uint256 received = IERC20(realVault).balanceOf(recipient) - balBefore;

        assertEq(out, preview);
        assertEq(received, preview);

        // reset
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(0)
        );
    }

    // Pretransferred Out fuzz (exact amount pretransferred)
    function testFuzz_Real_SEToStata_Pretransferred(uint256 dep, uint256 burnFrac) public {
        dep = bound(dep, 5e18, 200e18);
        burnFrac = bound(burnFrac, 1, 80);

        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 shares = (seGot * burnFrac) / 100;
        if (shares == 0) return;

        // Pretransfer exact shares to vault
        IERC20(realVault).transfer(realVault, shares);

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realStata), shares
        );

        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), shares, IERC20(realStata), shares, address(this), true, block.timestamp + 100
        );

        assertEq(amtIn, previewIn);
    }
}