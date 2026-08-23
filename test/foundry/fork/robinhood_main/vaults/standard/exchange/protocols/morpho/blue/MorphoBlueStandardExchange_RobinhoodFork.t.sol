// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    TestBase_MorphoBlueStandardExchangeFork
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchangeFork.sol";

contract MorphoBlueStandardExchange_RobinhoodFork is TestBase_MorphoBlueStandardExchangeFork {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function _rpcAlias() internal pure override returns (string memory) {
        return "robinhood_mainnet";
    }

    function _forkBlock() internal pure override returns (uint256) {
        // Public Robinhood RPC is not archive at DEFAULT_FORK_BLOCK (metadata missing).
        // 0 => fork latest in TestBase_MorphoBlueStandardExchangeFork.
        return 0;
    }

    function _liveMorphoAddress() internal pure override returns (address) {
        return ROBINHOOD_MAIN.MORPHO;
    }

    function _candidateIds() internal pure override returns (bytes32[] memory ids) {
        ids = new bytes32[](4);
        // USDG / SGOV 86% (free cash at research time)
        ids[0] = 0xf6f3dbe0a19e948147e79e66502c6b05709d8dfde977fec7db1528fc8f0ebdfa;
        // USDG / CRCL 62.5%
        ids[1] = 0xf0959f62e748938cf260ca6fe7cb21a412e0a6643913460f4a6770c3f4b90af6;
        // USDG / ORCL 62.5%
        ids[2] = 0xee04847a312224d551d2267bb5c2c2695777af5fd1f05347bdcca397e8f54336;
        // USDG / NBIS 62.5%
        ids[3] = 0xf049167e6bf18a1b41b8e2acefcf7bc9b13ea013d8d65c7fbc7cbaeb3fe9b4e2;
    }

    function test_FK0_morphoCode_andMarketExists() public view {
        assertGt(address(liveMorpho).code.length, 0, "FK0 morpho code");
        assertTrue(liveParams.loanToken != address(0), "FK0 bound market");
        assertTrue(liveMorpho.market(liveId).lastUpdate != 0, "FK0 lastUpdate");
    }

    function test_FK1_registryDeployVault() public view {
        assertTrue(se != address(0), "FK1 vault");
        assertEq(se4626.asset(), liveParams.loanToken);
        assertEq(address(mbse.morpho()), address(liveMorpho));
    }

    function test_FK2_wrapIncreasesExpectedSupply() public {
        uint256 amt = 10 ** IERC20Metadata(liveParams.loanToken).decimals();
        deal(liveParams.loanToken, user, amt * 2);
        vm.startPrank(user);
        IERC20(liveParams.loanToken).approve(se, type(uint256).max);
        uint256 before = liveMorpho.expectedSupplyAssets(liveParams, se);
        seIn.exchangeIn(
            IERC20(liveParams.loanToken), amt, IERC20(se), 0, user, false, _deadline()
        );
        vm.stopPrank();
        assertGt(liveMorpho.expectedSupplyAssets(liveParams, se), before, "FK2 supply up");
    }

    function test_FK3_unwrapWhileFreeCash() public {
        assertGt(_freeCash(), 0, "FK3 free cash at pin");
        uint256 amt = 10 ** IERC20Metadata(liveParams.loanToken).decimals();
        deal(liveParams.loanToken, user, amt * 2);
        vm.startPrank(user);
        IERC20(liveParams.loanToken).approve(se, type(uint256).max);
        uint256 shares = seIn.exchangeIn(
            IERC20(liveParams.loanToken), amt, IERC20(se), 0, user, false, _deadline()
        );
        uint256 out = seIn.exchangeIn(IERC20(se), shares, IERC20(liveParams.loanToken), 0, user, false, _deadline());
        vm.stopPrank();
        assertGt(out, 0, "FK3 unwrap");
    }

    function test_FK4_missingMarket_reverts() public {
        ERC20Mock missingLoan = new ERC20Mock();
        ERC20Mock missingColl = new ERC20Mock();
        address oracle_ = liveParams.oracle != address(0) ? liveParams.oracle : ROBINHOOD_MAIN.MORPHO_CHAINLINK_ORACLE_V2_FACTORY;
        address irm_ = liveParams.irm != address(0) ? liveParams.irm : ROBINHOOD_MAIN.MORPHO_ADAPTIVE_CURVE_IRM;
        uint256 lltv_ = liveParams.lltv != 0 ? liveParams.lltv : 0.86e18;
        MarketParams memory missing = MarketParams({
            loanToken: address(missingLoan),
            collateralToken: address(missingColl),
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IMorphoBlueStandardExchange.MarketNotCreated.selector, missing.id())
        );
        morphoBlueStandardExchangeDFPkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: liveMorpho, marketParams: missing})
        );
    }

    function test_FK5_notVaultV2() public view {
        assertEq(address(liveMorpho), ROBINHOOD_MAIN.MORPHO, "FK5 Blue singleton");
        assertTrue(ROBINHOOD_MAIN.MORPHO != ROBINHOOD_MAIN.MORPHO_VAULT_V2_FACTORY);
    }
}
