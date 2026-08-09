// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice T06b: supported routes preview ≡ execute (CP-single pair mint/burn as in-scope sample).
contract T06b_PreviewParity_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        detf = _deployDetfInstance(_openArgs());
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        vm.stopPrank();
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        _firstBond(500 ether);
    }

    function test_mint_previewEqExecute() public {
        uint256 pairIn = 40 ether;
        uint256 preview = detfExchangeIn.previewExchangeIn(
            IERC20(address(pairToken)), pairIn, IERC20(detf)
        );
        uint256 out = _mintPair(pairIn);
        assertEq(out, preview, "mint preview==exec");
    }

    function test_burn_previewEqExecute() public {
        uint256 userOut = _mintPair(80 ether);
        uint256 burnAmt = userOut / 2;
        uint256 preview = detfExchangeIn.previewExchangeIn(IERC20(detf), burnAmt, IERC20(address(pairToken)));
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt);
        uint256 pairOut = detfExchangeIn.exchangeIn(
            IERC20(detf), burnAmt, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(pairOut, preview, "burn preview==exec");
    }
}
