// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IMorpho, Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
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

contract MorphoBlueStandardExchange_EthereumFork is TestBase_MorphoBlueStandardExchangeFork {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function _rpcAlias() internal pure override returns (string memory) {
        return "ethereum_mainnet_alchemy";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return ETHEREUM_MAIN.DEFAULT_FORK_BLOCK;
    }

    function _liveMorphoAddress() internal pure override returns (address) {
        return ETHEREUM_MAIN.MORPHO;
    }

    function _candidateIds() internal pure override returns (bytes32[] memory ids) {
        ids = new bytes32[](3);
        ids[0] = 0x94b823e6bd8ea533b4e33fbc307faea0b307301bc48763acc4d4aa4def7636cd;
        ids[1] = 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758;
        ids[2] = 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc;
    }

    function test_FK0_morphoCode_andMarketExists() public view {
        assertGt(address(liveMorpho).code.length, 0, "FK0 morpho code");
        assertTrue(liveParams.loanToken != address(0), "FK0 bound market");
        assertTrue(liveMorpho.market(liveId).lastUpdate != 0, "FK0 lastUpdate");
    }

    function test_FK1_registryDeployVault() public view {
        assertTrue(se != address(0), "FK1 vault");
        assertEq(se4626.asset(), liveParams.loanToken, "FK1 asset");
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
        assertEq(address(mbse.morpho()), ETHEREUM_MAIN.MORPHO, "FK5 Blue singleton");
        assertTrue(mbse.loanToken() != ETHEREUM_MAIN.MORPHO_VAULT_V2_FACTORY);
    }
}
