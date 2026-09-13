// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {HermeticWETH, HermeticStETH, HermeticWstETH, HermeticWithdrawalQueue} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {LidoWstETHStandardExchangeInFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeInFacet.sol";
import {LidoWstETHStandardExchangeOutFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutFacet.sol";
import {LidoWstETHMarkerFacet} from "contracts/protocols/staking/lido/LidoWstETHMarkerFacet.sol";
import {LidoWstETHRebalanceFacet} from "contracts/protocols/staking/lido/LidoWstETHRebalanceFacet.sol";
import {LidoWstETHStandardExchangeDFPkg} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IStETH.sol";
import {IWstETH} from "@crane/contracts/protocols/staking/ethereum/lido/interfaces/IWstETH.sol";
import {LidoService} from "@crane/contracts/protocols/staking/ethereum/lido/services/LidoService.sol";
import {WstETHRateProvider} from "@crane/contracts/protocols/staking/ethereum/lido/rate/WstETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

contract LidoServiceHarness {
    function wrap(IWstETH wst, uint256 amount) external returns (uint256) {
        return LidoService._wrap(wst, amount);
    }

    function unwrap(IWstETH wst, uint256 amount) external returns (uint256) {
        return LidoService._unwrap(wst, amount);
    }

    function submit(IStETH steth, address referral) external payable returns (uint256) {
        return LidoService._submit(steth, referral);
    }
}

contract LidoServiceFork is TestBase_EthereumStakingFork {
    LidoServiceHarness internal harness;
    IStETH internal steth;
    IWstETH internal wsteth;
    WstETHRateProvider internal rateProvider;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new LidoServiceHarness();
        steth = IStETH(EthereumStakingAddresses.ST_ETH);
        wsteth = IWstETH(EthereumStakingAddresses.WST_ETH);
        rateProvider = new WstETHRateProvider(wsteth);
        _dealETH(address(this), 50 ether);
    }

    function test_Fork_RateProvider_MatchesStEthPerToken() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "rate > 0");
        assertEq(rate, wsteth.stEthPerToken(), "rate == stEthPerToken");
    }

    function test_Fork_WrapUnwrap_InverseWithinOneShare() public {
        // Acquire stETH via submit on harness, transfer to harness for wrap
        uint256 stOut = harness.submit{value: 2 ether}(steth, address(0));
        assertGt(stOut, 0, "stETH minted");

        // Pull stETH into harness for wrap (submit credited harness)
        // submit mints to harness (msg.sender = harness)
        uint256 stBal = IERC20(address(steth)).balanceOf(address(harness));
        assertGt(stBal, 0);

        uint256 wstOut = harness.wrap(wsteth, stBal);
        assertGt(wstOut, 0, "wst minted");

        uint256 stBack = harness.unwrap(wsteth, wstOut);
        // Inverse within 1 wei/share tolerance for rounding
        assertApproxEqAbs(stBack, stBal, 2, "wrap/unwrap inverse within 2 wei");
    }
}

/// @notice Actual registry-deployed SE against Ethereum's fractional Lido receipt.
/// The inherited hermetic components are replaced with live protocol contracts
/// before deploying the subject SE; no transaction is broadcast to Ethereum.
contract LidoStandardExchangeProjectionFork is TestBase_LidoWstETHStandardExchange, TransitionQuoteAssertions {
    function setUp() public override {
        vm.createSelectFork("ethereum_mainnet_alchemy", 24_000_000);
        super.setUp();
        hermeticWeth = HermeticWETH(payable(EthereumStakingAddresses.WETH));
        hermeticStEth = HermeticStETH(EthereumStakingAddresses.ST_ETH);
        hermeticWstEth = HermeticWstETH(EthereumStakingAddresses.WST_ETH);
        // Queue operations are not involved in the standard liquid/receipt routes.
        // Zero is the existing package's optional queue configuration.
        hermeticQueue = HermeticWithdrawalQueue(payable(address(0)));
        seVault = _deployLidoSe();
        lidoSe = ILidoWstETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.07e18);
        vm.deal(address(this), 1_000 ether);
        IStETH(EthereumStakingAddresses.ST_ETH).submit{value: 500 ether}(address(0));
        uint256 stAmount = hermeticStEth.balanceOf(address(this));
        hermeticStEth.approve(address(hermeticWstEth), stAmount);
        IWstETH(address(hermeticWstEth)).wrap(stAmount);
        hermeticWeth.deposit{value: 500 ether}();
        hermeticWeth.approve(seVault, 200 ether);
        seIn.exchangeIn(IERC20(address(hermeticWeth)), 200 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        hermeticWstEth.approve(seVault, 200 ether);
        seIn.exchangeIn(IERC20(address(hermeticWstEth)), 200 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        assertGt(IWstETH(address(hermeticWstEth)).stEthPerToken(), 1e18, "live non-unit receipt ratio");
    }

    function test_lidoLiveLiquidAndWrappedSequentialQuotes() public {
        _assertQuoteSequence(seVault, IERC20(address(hermeticWeth)), address(this), 1 ether);
        _assertQuoteSequence(seVault, IERC20(address(hermeticWstEth)), address(this), 1 ether);
    }

    function test_lidoLiveExternalMintFeeAttribution() public {
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 7 ether + 19, address(this));
        address beneficiary = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 3 ether + 11, beneficiary);
    }

    function test_lidoLiveExternalStakeChangesReceiptRatio() public {
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 3 ether + 17);
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 7 ether + 29);
    }

    function test_lidoLiveStETHConversionsProjectRounding() public {
        vm.deal(address(this), 5 ether);
        IStETH(address(hermeticStEth)).submit{value: 5 ether}(address(0));
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticStEth)), IERC20(address(hermeticWeth)), hermeticStEth.balanceOf(address(this)) / 2, address(this));
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticStEth)), IERC20(address(hermeticWeth)), hermeticStEth.balanceOf(address(this)) / 2);
    }
}
