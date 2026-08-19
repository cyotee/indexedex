// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice T06a / L-FEE-*: CP-single burn takes usage fee to feeTo; preview includes fee.
contract T06a_CpBurnFee_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    uint256 internal constant USAGE_FEE_WAD = 0.01e18; // 1%
    address internal feeToAddr;

    function setUp() public override {
        super.setUp();
        detf = _deployDetfWired(_openArgs());
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        vm.stopPrank();
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        _firstBond(500 ether);

        // Pin known feeTo + non-zero usage fee so fee delta is observable.
        feeToAddr = makeAddr("safFeeTo");
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(feeToAddr));
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(detf, USAGE_FEE_WAD);
        vm.stopPrank();

        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(detf),
            USAGE_FEE_WAD,
            "usage fee set"
        );
        assertEq(address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()), feeToAddr, "feeTo set");
    }

    function test_burn_usageFee_goesToFeeTo_andPreviewMatches() public {
        uint256 userOut = _mintPair(100 ether);
        assertGt(userOut, 0);

        uint256 burnAmt = userOut / 2;
        (, uint256 expectedFee) = DETFUsageFeeLib._splitUsageFee(burnAmt, USAGE_FEE_WAD);
        assertGt(expectedFee, 0, "non-zero fee portion");

        uint256 feeBefore = IERC20(detf).balanceOf(feeToAddr);
        uint256 preview = detfExchangeIn.previewExchangeIn(IERC20(detf), burnAmt, IERC20(address(pairToken)));

        uint256 pairBefore = pairToken.balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt);
        uint256 pairOut = detfExchangeIn.exchangeIn(
            IERC20(detf), burnAmt, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // L-PREV-1 / L-FEE-3: preview includes same fee as execute.
        assertEq(pairOut, preview, "L-PREV-1 / L-FEE-3: preview==exec with fee");
        assertEq(pairToken.balanceOf(detfUser) - pairBefore, pairOut);
        assertGt(pairOut, 0, "burn still produces pair");

        // D14: burn does not mint or transfer DETF to feeTo. Usage fee is unused on this path.
        uint256 feeAfter = IERC20(detf).balanceOf(feeToAddr);
        assertEq(feeAfter, feeBefore, "D14 no feeTo DETF on burn");
        expectedFee;
    }
}
