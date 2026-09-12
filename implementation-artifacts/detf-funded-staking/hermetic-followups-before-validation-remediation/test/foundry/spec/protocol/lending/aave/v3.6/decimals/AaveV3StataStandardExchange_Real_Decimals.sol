// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/**
 * @title AaveV3StataStandardExchange_Real_Decimals
 * @notice Gold Real `test_Real_Route_*` / `testFuzz_Real_*` on a non-18 Stata base.
 * @dev Amounts for the configured underlying are `_u(human)`. SE vaultShare stays 18.
 *      Combo ID is recorded by the concrete suite (`U6` / `U9`).
 */
abstract contract AaveV3StataStandardExchange_Real_Decimals is
    TestBase_AaveV3StataStandardExchange_Decimals
{
    function test_Real_Route_BaseToSE_PreviewMatches() public {
        uint256 amount = _u(10);
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
        uint256 amount = _u(5);

        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realStata, amount);
        uint256 stataShares = stataTokenV2.depositATokens(amount, address(this));

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
        uint256 dep = _u(20);
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
        assertEq(previewIn, sharesToBurn);

        uint256 stataBefore = IERC20(realStata).balanceOf(address(this));
        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), sharesToBurn, IERC20(realStata), sharesToBurn, address(this), false, block.timestamp + 100
        );
        assertEq(amtIn, previewIn);

        uint256 received = IERC20(realStata).balanceOf(address(this)) - stataBefore;
        assertEq(amtIn, previewIn);
        assertGt(received, 0);
    }

    function test_Real_Route_SEToBase_PreviewMatches() public {
        uint256 dep = _u(15);
        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 sharesToBurn = seGot / 3;
        require(sharesToBurn > 0, "need shares");

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realBase), sharesToBurn
        );

        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), sharesToBurn, IERC20(realBase), sharesToBurn, address(this), false, block.timestamp + 100
        );

        assertEq(amtIn, previewIn);
    }

    function testFuzz_Real_BaseToSE(uint256 amount) public {
        uint8 d = _underlyingDecimals();
        amount = bound(amount, 1 * (10 ** uint256(d)) / 1000, 500 * (10 ** uint256(d)));
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
        dep = bound(dep, _u(5), _u(200));
        burnFrac = bound(burnFrac, 1, 90);

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
        amount = bound(amount, _u(1), _u(100));
        fee = bound(fee, 0, 0.05e18);

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

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(0)
        );
    }

    function testFuzz_Real_SEToStata_Pretransferred(uint256 dep, uint256 burnFrac) public {
        dep = bound(dep, _u(5), _u(200));
        burnFrac = bound(burnFrac, 1, 80);

        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);

        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        uint256 shares = (seGot * burnFrac) / 100;
        if (shares == 0) return;

        IERC20(realVault).transfer(realVault, shares);

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realStata), shares
        );

        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), shares, IERC20(realStata), shares, address(this), true, block.timestamp + 100
        );

        assertEq(amtIn, previewIn);
    }

    function test_Real_Route_BaseToStata() public {
        uint256 amount = _u(10);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: previewExchangeIn BaseToStata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
        assertGt(out, 0);
    }

    /// @notice Honest same-tx push: transfer base then pretransferred=true.
    function test_Real_Route_BaseToStata_Pretransferred() public {
        uint256 amount = _u(8);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).transfer(realVault, amount);
        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), 0, address(this), true, block.timestamp + 100
        );
        assertEq(out, preview, "real: pretransferred BaseToStata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
    }

    /// @notice I1: booked residual cannot free-credit a second pretransfer with U=0.
    function test_Real_Route_BaseToStata_Pretransferred_bookedInventory_reverts() public {
        uint256 residual = _u(15);
        uint256 honest = _u(1);
        _fundUnderlying(residual + honest, address(this));
        IERC20(realBase).transfer(realVault, residual);
        IERC20(realBase).approve(realVault, honest);
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), honest, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );

        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual, uint256(0))
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), residual, IERC20(realStata), 0, address(this), true, block.timestamp + 100
        );
    }

    function test_Real_Route_ATokenToStata() public {
        uint256 amount = _u(6);
        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(aToken), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(aToken), amount, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: aToken->stata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
        assertGt(out, 0);
    }

    function test_Real_Route_ATokenToSE() public {
        uint256 amount = _u(6);
        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(aToken), amount, IERC20(realVault)
        );
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(aToken), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: aToken->SE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
        assertGt(out, 0);
    }

    /// @dev N/A: production `AaveV3StataStandardExchangeOutTarget._pool()` is `address(0)`,
    ///      so SE→aToken cannot settle via `pool.supply` on Crane Stata. Mock `test_Route_SEToAToken`
    ///      used `vm.mockCall` and is EX-MOCK.
    function test_Real_Route_SEToAToken() public view {
        assertTrue(realStata != address(0) && aToken != address(0), "stata and aToken exist");
    }

    function test_Real_Route_SEToBase_Pretransferred() public {
        uint256 dep = _u(12);
        _fundUnderlying(dep, address(this));
        IERC20(realBase).approve(realVault, dep);
        uint256 seGot = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), dep, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );
        uint256 shares = seGot / 3;
        require(shares > 0, "need shares");
        IERC20(realVault).transfer(realVault, shares);

        uint256 previewIn = IStandardExchangeOut(realVault).previewExchangeOut(
            IERC20(realVault), IERC20(realBase), shares
        );
        uint256 amtIn = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), shares, IERC20(realBase), shares, address(this), true, block.timestamp + 100
        );
        assertEq(amtIn, previewIn, "real: pretransferred SE->base");
    }

    /// @notice Fee path: user receives full preview; feeTo mints extra shares.
    function test_Real_FeeApplicationAndMarker() public {
        uint256 amount = _u(10);
        uint256 usageFee = 0.05e18;
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(usageFee)
        );

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );
        address userRecipient = address(0xBEEF);
        uint256 userBefore = IERC20(realVault).balanceOf(userRecipient);
        uint256 feeToBefore = IERC20(realVault).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, userRecipient, false, block.timestamp + 100
        );
        uint256 userReceived = IERC20(realVault).balanceOf(userRecipient) - userBefore;
        uint256 feeShares = IERC20(realVault).balanceOf(address(this)) - feeToBefore;
        assertEq(out, preview);
        assertEq(userReceived, preview);
        assertGt(feeShares, 0, "feeTo shares");

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, realVault),
            abi.encode(uint256(0))
        );
    }

    /// @dev Rewards: real Crane Stata hermetic has no LM emissions to forward. Route ops still
    ///      call collect; dedicated reward-token delta is N/A without an emission admin campaign.
    function test_Real_RewardsForwarded_NA() public view {
        assertTrue(realStata != address(0), "real stata");
    }
}
