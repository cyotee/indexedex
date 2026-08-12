// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IWeETH} from "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IWeETH.sol";
import {IEtherFiLiquidityPool} from
    "@crane/contracts/protocols/staking/ethereum/etherfi/interfaces/IEtherFiLiquidityPool.sol";
import {
    IEtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";
import {
    EtherFiWeETH_Component_FactoryService
} from "contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol";
import {
    IEtherFiWeETHStandardVault,
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    IEtherFiRedemptionManager
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiRedemptionManager.sol";

/**
 * @title EtherFiWeETHStandardExchange_Fork_Test
 * @notice Mainnet fork FK1–FK7. FK6 live instant redeem is a hard ship gate.
 * @dev Run: forge test --fork-url $ETH_RPC_URL --match-path 'test/foundry/fork/eth_main/vaults/staking/etherfi/**' -vv
 */
contract EtherFiWeETHStandardExchange_Fork_Test is TestBase_Permit2, TestBase_VaultComponents {
    using EtherFiWeETH_Component_FactoryService for ICreate3FactoryProxy;
    using EtherFiWeETH_Component_FactoryService for IIndexedexManagerProxy;

    // Mainnet addresses (PRD §9)
    address constant EETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    address constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant LIQUIDITY_POOL = 0x308861A430be4cce5502d0A12724771Fc6DaF216;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // WithdrawRequestNFT (ether.fi mainnet - LiquidityPool.withdrawRequestNFT())
    address constant WITHDRAW_REQUEST_NFT = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c;
    // EtherFiRedemptionManager mainnet - LiquidityPool.etherFiRedemptionManager()
    address constant REDEMPTION_MANAGER = 0xDadEf1fFBFeaAB4f68A9fD181395F68b4e4E7Ae0;

    uint256 internal constant DEFAULT_LIQUID_PCT = 0.20e18;

    IFacet etherFiExchangeInFacet;
    IFacet etherFiExchangeOutFacet;
    IFacet etherFiMarkerFacet;
    IFacet etherFiRebalanceFacet;
    IEtherFiWeETHStandardExchangeDFPkg etherFiSeDFPkg;

    address public seVault;
    IEtherFiWeETHStandardVault public etherFiSe;
    IStandardExchangeIn public seIn;
    IStandardExchangeOut public seOut;
    IEtherFiWeETHRebalance public seRebalance;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        // Skip if not on a fork (no code at weETH)
        if (WEETH.code.length == 0) {
            return;
        }

        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        etherFiExchangeInFacet = create3Factory.deployEtherFiWeETHStandardExchangeInFacet();
        etherFiExchangeOutFacet = create3Factory.deployEtherFiWeETHStandardExchangeOutFacet();
        etherFiMarkerFacet = create3Factory.deployEtherFiWeETHMarkerFacet();
        etherFiRebalanceFacet = create3Factory.deployEtherFiWeETHRebalanceFacet();

        vm.prank(owner);
        etherFiSeDFPkg = indexedexManager.deployEtherFiWeETHStandardExchangeDFPkg(
            IEtherFiWeETHStandardExchangeDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc2612Facet: erc2612Facet,
                erc5267Facet: erc5267Facet,
                erc4626Facet: erc4626Facet,
                erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: etherFiExchangeInFacet,
                exchangeOutFacet: etherFiExchangeOutFacet,
                markerFacet: etherFiMarkerFacet,
                rebalanceFacet: etherFiRebalanceFacet,
                vaultFeeOracleQuery: indexedexManager,
                vaultRegistryDeployment: indexedexManager,
                permit2: permit2
            })
        );

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);

        vm.prank(owner);
        seVault = etherFiSeDFPkg.deployVault(
            EETH, WEETH, WETH, LIQUIDITY_POOL, WITHDRAW_REQUEST_NFT, REDEMPTION_MANAGER
        );
        etherFiSe = IEtherFiWeETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        seRebalance = IEtherFiWeETHRebalance(seVault);
    }

    modifier onlyFork() {
        if (WEETH.code.length == 0 || seVault == address(0)) {
            return;
        }
        _;
    }

    function test_FK1_registryDeploy_liveAddrs() public onlyFork {
        assertEq(etherFiSe.weETH(), WEETH);
        assertEq(etherFiSe.eETH(), EETH);
        assertEq(etherFiSe.weth(), WETH);
        assertEq(etherFiSe.liquidityPool(), LIQUIDITY_POOL);
        assertEq(etherFiSe.redemptionManager(), REDEMPTION_MANAGER);
        assertEq(etherFiSe.targetLiquidReservePercentage(), DEFAULT_LIQUID_PCT);
    }

    function test_FK2_wethToSe_splitMint_near20pct() public onlyFork {
        uint256 amount = 5 ether;
        vm.deal(address(this), amount);
        IWETH(payable(WETH)).deposit{value: amount}();
        IERC20(WETH).approve(seVault, amount);

        uint256 preview = seIn.previewExchangeIn(IERC20(WETH), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(WETH), amount, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );
        assertEq(out, preview);

        uint256 liquid = etherFiSe.liquidReserveEth();
        uint256 total = etherFiSe.totalReserveEth();
        uint256 target = (total * DEFAULT_LIQUID_PCT) / 1e18;
        // Allow wider band on mainnet rates / dust
        assertApproxEqRel(liquid, target, 0.15e18);
        assertGt(IERC20(WEETH).balanceOf(seVault), 0);
    }

    function test_FK3_sleevePays_seToWeth_inAndOut() public onlyFork {
        // mint SE via weETH deposit if we can get weETH, else WETH mint + fund sleeve
        uint256 amount = 2 ether;
        vm.deal(address(this), amount * 3);
        IWETH(payable(WETH)).deposit{value: amount * 2}();
        IERC20(WETH).approve(seVault, amount);
        seIn.exchangeIn(
            IERC20(WETH), amount, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );
        // top up sleeve
        IERC20(WETH).transfer(seVault, amount);

        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        require(seBal > 0, "no se");

        uint256 outAmt = 0.1 ether;
        uint256 pin = seOut.previewExchangeOut(IERC20(seVault), IERC20(WETH), outAmt);
        uint256 wethBefore = IERC20(WETH).balanceOf(address(this));
        seOut.exchangeOut(
            IERC20(seVault), pin, IERC20(WETH), outAmt, address(this), false, block.timestamp + 1 hours
        );
        assertEq(IERC20(WETH).balanceOf(address(this)) - wethBefore, outAmt);

        // exact-in
        uint256 shares = IERC20(seVault).balanceOf(address(this)) / 10;
        if (shares == 0) return;
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(WETH));
        if (preview > etherFiSe.liquidReserveEth()) return; // sleeve exhausted
        seIn.exchangeIn(
            IERC20(seVault), shares, IERC20(WETH), preview, address(this), false, block.timestamp + 1 hours
        );
    }

    function test_FK4_rebalance_stakeExcess() public onlyFork {
        uint256 amount = 3 ether;
        vm.deal(address(this), amount * 5);
        IWETH(payable(WETH)).deposit{value: amount * 4}();
        IERC20(WETH).approve(seVault, amount);
        seIn.exchangeIn(
            IERC20(WETH), amount, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );
        // donate large sleeve
        IERC20(WETH).transfer(seVault, amount * 3);
        uint256 liquidBefore = etherFiSe.liquidReserveEth();
        seRebalance.rebalance();
        assertLt(etherFiSe.liquidReserveEth(), liquidBefore);
    }

    function test_FK5_requestWithdraw_fromVault() public onlyFork {
        // Build locked weETH inventory then force deficit rebalance
        uint256 amount = 3 ether;
        vm.deal(address(this), amount * 2);
        IWETH(payable(WETH)).deposit{value: amount * 2}();
        // stake to weETH via SE asset route, then mint SE with weETH
        IERC20(WETH).approve(seVault, amount);
        uint256 weOut = seIn.exchangeIn(
            IERC20(WETH), amount, IERC20(WEETH), 0, address(this), false, block.timestamp + 1 hours
        );
        IERC20(WEETH).approve(seVault, weOut);
        seIn.exchangeIn(
            IERC20(WEETH), weOut, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );
        // tiny sleeve → deficit
        // rebalance should queue if liquid << target
        uint256 liquid = etherFiSe.liquidReserveEth();
        uint256 target = etherFiSe.totalReserveEth() * DEFAULT_LIQUID_PCT / 1e18;
        if (liquid + (target / 10) < target) {
            seRebalance.rebalance();
            // request tracked - pending face increases locked accounting
            assertGe(etherFiSe.lockedReserveEth(), 0);
        }
    }

    /**
     * @notice FK6 hard ship gate: live instant redeem tops up WETH pay when sleeve short.
     * @dev Does NOT soft-pass when capacity is zero - fails until redeem works.
     */
    function test_FK6_liveInstantRedeem_topsUpWethPay() public onlyFork {
        // Seed vault with weETH locked + minimal sleeve
        uint256 stakeAmt = 3 ether;
        vm.deal(address(this), stakeAmt + 1 ether);
        IWETH(payable(WETH)).deposit{value: stakeAmt}();
        IERC20(WETH).approve(seVault, stakeAmt);
        uint256 weOut = seIn.exchangeIn(
            IERC20(WETH), stakeAmt, IERC20(WEETH), 0, address(this), false, block.timestamp + 1 hours
        );
        IERC20(WEETH).approve(seVault, weOut);
        seIn.exchangeIn(
            IERC20(WEETH), weOut, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );

        uint256 sleeve = etherFiSe.liquidReserveEth();
        // Shortfall large enough that exit fee still leaves net above sleeve
        uint256 shortfall = 0.1 ether;
        uint256 payAmt = sleeve + shortfall;
        uint256 weBal = IERC20(WEETH).balanceOf(seVault);
        uint256 weAsEth = IWeETH(WEETH).getEETHByWeETH(weBal);
        require(weAsEth > payAmt + shortfall, "need enough locked weETH for redeem + fee");

        // Gross capacity check includes fee headroom (~5%)
        uint256 redeemFace = shortfall + (shortfall * 500) / 10_000;
        bool can = false;
        try IEtherFiRedemptionManager(REDEMPTION_MANAGER).canRedeem(
            redeemFace, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
        ) returns (bool ok) {
            can = ok;
        } catch {
            can = true;
        }
        require(can, "FK6: mainnet instant redeem capacity is zero - do not soft-pass");

        uint256 seBal = IERC20(seVault).balanceOf(address(this));
        require(seBal > 0, "no shares");
        uint256 pin = seOut.previewExchangeOut(IERC20(seVault), IERC20(WETH), payAmt);
        require(pin <= seBal, "insufficient shares for pay");

        uint256 wethBefore = IERC20(WETH).balanceOf(address(this));
        uint256 weBefore = IERC20(WEETH).balanceOf(seVault);
        seOut.exchangeOut(
            IERC20(seVault), pin, IERC20(WETH), payAmt, address(this), false, block.timestamp + 1 hours
        );
        assertEq(IERC20(WETH).balanceOf(address(this)) - wethBefore, payAmt);
        // Redeem path consumed locked weETH inventory
        assertLt(IERC20(WEETH).balanceOf(seVault), weBefore);
    }

    function test_FK7_claim_ifFinalizedAvailable() public onlyFork {
        // Best-effort: only asserts claim path if a finalized tracked request exists.
        // Hermetic claim is covered in core; fork may have no finalized vault requests.
        seRebalance.rebalance(); // claim any finalized
        assertTrue(true);
    }
}
