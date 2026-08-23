// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
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

contract MorphoBlueStandardExchange_BaseFork is TestBase_MorphoBlueStandardExchangeFork {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function _rpcAlias() internal pure override returns (string memory) {
        return "base_mainnet_alchemy";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return BASE_MAIN.DEFAULT_FORK_BLOCK;
    }

    function _liveMorphoAddress() internal pure override returns (address) {
        return BASE_MAIN.MORPHO;
    }

    function _candidateIds() internal pure override returns (bytes32[] memory ids) {
        ids = new bytes32[](3);
        // WETH/USDC 86% (Morpho app)
        ids[0] = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
        // msETH / wstETH with free cash at research time
        ids[1] = 0xffd35206a772174c04f599e4034a2f132fc3f7a462ca732affcea92136716573;
        ids[2] = 0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49;
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
        MarketParams memory missing = MarketParams({
            loanToken: address(missingLoan),
            collateralToken: address(missingColl),
            oracle: liveParams.oracle,
            irm: liveParams.irm,
            lltv: liveParams.lltv
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
        assertEq(address(mbse.morpho()), BASE_MAIN.MORPHO, "FK5 Blue singleton");
    }
}
