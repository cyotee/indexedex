// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IUniswapV4StandardExchangeLiquidReserve} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol";
import {IUniswapV4StandardExchangePositionImport} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {UniswapV4StandardExchangeInBase} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {UniswapV4StandardExchangeCommon} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {UniswapV4_Component_FactoryService} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/// @dev Hostile PM. Copied from gold. Not a mock of the SE vault.
contract HostileUniswapV4PositionManagerDecimals {
    PoolKey public key;
    uint128 public liq;
    address public nftOwner;

    function configure(PoolKey memory key_, uint128 liq_, address nftOwner_) external {
        key = key_;
        liq = liq_;
        nftOwner = nftOwner_;
    }

    function getPoolAndPositionInfo(uint256) external view returns (PoolKey memory, PositionInfo) {
        return (key, PositionInfo.wrap(0));
    }

    function getPositionLiquidity(uint256) external view returns (uint128) {
        return liq;
    }

    function ownerOf(uint256) external view returns (address) {
        return nftOwner;
    }

    function transferFrom(address, address, uint256) external {}
}

/**
 * @title Adversarial_UniswapV4SE_E6ImpA0_Decimals
 * @notice E6 / IMP / A0 on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract Adversarial_UniswapV4SE_E6ImpA0_Decimals is UniswapV4SeDecimalsHelpers {
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    address internal attacker;
    address internal victim;
    address internal donator;

    address internal constant DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD);

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uOf(_token1(), human);
    }

    function _testAmt0() internal view returns (uint256) {
        return _u0(2);
    }

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        donator = makeAddr("donator");

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 sqrtP = _oneToOneHumanSqrtPrice(_token0(), _token1());
        poolManager.initialize(poolKey, sqrtP);

        UniswapV4LiquiditySeeder_ProDexUniV4 seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        (int24 tickLower, int24 tickUpper) = _seedTicksAround(sqrtP, poolKey.tickSpacing);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            _u0(100_000),
            _u1(100_000)
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _mintSeShares(address to_, uint256 amountIn_) internal returns (uint256 shares_) {
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(to_, amountIn_);
        vm.startPrank(to_);
        IERC20(token0_).approve(address(vault), amountIn_);
        if (vault.totalSupply() == 0) {
            uint256 amount1_ = amountIn_ * _u1(1) / _u0(1);
            MintableERC20Decimals(_token1()).mint(to_, amount1_);
            IERC20(_token1()).approve(address(vault), amount1_);
            address[] memory tokens = new address[](2);
            tokens[0] = token0_;
            tokens[1] = _token1();
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amountIn_;
            amounts[1] = amount1_;
            shares_ = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
                tokens, amounts, IERC20(address(vault)), 0, to_, false, _deadline()
            );
        } else {
            shares_ = vault.exchangeIn(IERC20(token0_), amountIn_, IERC20(address(vault)), 0, to_, false, _deadline());
        }
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    function _syncShareReserve() internal {
        address token0_ = _token0();
        uint256 dust_ = _milliOf(token0_);
        MintableERC20Decimals(token0_).mint(address(this), dust_);
        IERC20(token0_).approve(address(vault), dust_);
        vault.exchangeIn(IERC20(token0_), dust_, IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function test_E6_exchangeOut_zap_doesNotSweepOtherUsersShares() public {
        uint256 leftover_ = _mintSeShares(victim, _testAmt0());
        uint256 attackerShares_ = _mintSeShares(attacker, _testAmt0());
        uint256 used_ = attackerShares_ / 2;
        if (used_ == 0) used_ = attackerShares_;

        vm.prank(victim);
        vault.transfer(address(vault), leftover_);
        _syncShareReserve();

        uint256 booked_ = IBasicVault(address(vault)).reserveOfToken(address(vault));
        assertEq(booked_, leftover_, "E6: leftover booked as R");

        vm.prank(attacker);
        vault.transfer(address(vault), used_);

        uint256 fatMax_ = used_ + leftover_;
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 leftoverBefore_ = vault.balanceOf(address(vault));
        uint256 attackerTokenBefore_ = IERC20(_token0()).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, fatMax_, used_)
        );
        vault.exchangeOut(IERC20(address(vault)), fatMax_, IERC20(_token0()), 1, attacker, true, _deadline());

        assertEq(vault.balanceOf(address(vault)), leftoverBefore_, "E6: leftover self-shares unmoved");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "E6: attacker shares unmoved");
        assertEq(IERC20(_token0()).balanceOf(attacker), attackerTokenBefore_, "E6: no tokenOut skim");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(vault)), leftover_, "E6: R unskimmed");
    }

    function test_E6_exchangeOut_zap_exactUsed_doesNotRefundBookedLeftover() public {
        uint256 leftover_ = _mintSeShares(victim, _testAmt0());
        uint256 attackerShares_ = _mintSeShares(attacker, _testAmt0());

        vm.prank(victim);
        vault.transfer(address(vault), leftover_);
        _syncShareReserve();

        vm.prank(attacker);
        vault.transfer(address(vault), attackerShares_);

        uint256 amountOut_ = _tinyOf(_token0());
        uint256 preview_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(_token0()), amountOut_);
        require(preview_ > 0 && preview_ <= attackerShares_, "preview in range");

        vm.prank(attacker);
        uint256 burned_ = vault.exchangeOut(
            IERC20(address(vault)), preview_, IERC20(_token0()), amountOut_, attacker, true, _deadline()
        );

        assertEq(burned_, preview_, "burned preview");
        assertEq(vault.balanceOf(address(vault)), leftover_ + (attackerShares_ - preview_), "leftover stays");
        assertEq(vault.balanceOf(attacker), 0, "attacker pushed all used");
    }

    function test_E6_exchangeIn_zapOut_fatClaim_doesNotSkimBookedShares() public {
        uint256 leftover_ = _mintSeShares(victim, _testAmt0());
        uint256 attackerShares_ = _mintSeShares(attacker, _u0(1));
        if (attackerShares_ == 0) attackerShares_ = _mintSeShares(attacker, _testAmt0());

        vm.prank(victim);
        vault.transfer(address(vault), leftover_);
        _syncShareReserve();

        vm.prank(attacker);
        vault.transfer(address(vault), attackerShares_);

        uint256 fat_ = leftover_ + attackerShares_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, fat_, attackerShares_)
        );
        vault.exchangeIn(IERC20(address(vault)), fat_, IERC20(_token0()), 0, attacker, true, _deadline());

        assertEq(vault.balanceOf(address(vault)), leftover_ + attackerShares_, "E6 in: inventory unmoved");
    }

    function test_IMP_importPosition_untrustedPositionManager_reverts() public {
        HostileUniswapV4PositionManagerDecimals hostile_ = new HostileUniswapV4PositionManagerDecimals();
        hostile_.configure(poolKey, type(uint128).max, attacker);

        uint256 supplyBefore_ = vault.totalSupply();
        vm.prank(attacker);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_UntrustedPositionManager.selector);
        IUniswapV4StandardExchangePositionImport(address(vault)).importPosition(
            IPositionManager(address(hostile_)), 1, 0, attacker, attacker, _deadline()
        );
        assertEq(vault.totalSupply(), supplyBefore_, "IMP: no fake mint");
        assertEq(vault.balanceOf(attacker), 0, "IMP: attacker got no shares");
    }

    function test_IMP_importPosition_unboundPositionManager_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_UntrustedPositionManager.selector);
        IUniswapV4StandardExchangePositionImport(address(vault)).importPosition(
            IPositionManager(address(1)), 1, 0, attacker, attacker, _deadline()
        );
    }

    function test_IMP_importPosition_untrustedOwner_reverts() public {
        HostileUniswapV4PositionManagerDecimals official_ = new HostileUniswapV4PositionManagerDecimals();
        official_.configure(poolKey, 1_000_000, victim);
        IStandardExchangeProxy boundVault_ = _deployVaultBoundToPm(IPositionManager(address(official_)));

        vm.prank(attacker);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_UntrustedImportOwner.selector);
        IUniswapV4StandardExchangePositionImport(address(boundVault_)).importPosition(
            IPositionManager(address(official_)), 1, 0, victim, attacker, _deadline()
        );
        assertEq(boundVault_.totalSupply(), 0, "IMP: no mint to attacker");
    }

    function _boundPmPkgInit(IPositionManager positionManager_)
        internal
        view
        returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit_)
    {
        pkgInit_ = UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(_univ4SePkgInitCore());
        pkgInit_ = UniswapV4_Component_FactoryService.attachTwapOracle(pkgInit_, twapOracle);
        pkgInit_ = UniswapV4_Component_FactoryService.attachUniswapV4StandardExchangeMultiFacets(
            pkgInit_,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        pkgInit_.positionManager = positionManager_;
    }

    function _deployVaultBoundToPm(IPositionManager positionManager_) internal returns (IStandardExchangeProxy) {
        vm.startPrank(owner);
        IUniswapV4StandardExchangeDFPkg boundPkg_ = IUniswapV4StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    ArtifactCreationCode.creationCode(create3Factory, "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol:UniswapV4StandardExchangeDFPkg"),
                    abi.encode(_boundPmPkgInit(positionManager_)),
                    keccak256("UniswapV4StandardExchangeDFPkg.boundPM.secFix.decimals")
                )
            )
        );
        vm.stopPrank();
        return IStandardExchangeProxy(boundPkg_.deployVault(poolKey));
    }

    function test_A0_donateThenFirstMint_cannotRedeemDonation() public {
        uint256 donation_ = _u0(10);
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(donator, donation_);
        vm.prank(donator);
        IERC20(token0_).transfer(address(vault), donation_);
        assertEq(vault.totalSupply(), 0, "A0: empty supply");

        uint256 mintIn_ = _u0(1);
        uint256 attackerTokBefore_ = IERC20(token0_).balanceOf(attacker);
        uint256 shares_ = _mintSeShares(attacker, mintIn_);

        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares for residual");
        assertEq(vault.balanceOf(attacker), shares_, "A0: attacker user shares");
        assertLt(shares_, vault.totalSupply(), "A0: attacker is not 100% supply");
        // Activation paid both assets. Independently bound ownership of each leg.
        IUniswapV4StandardExchangeLiquidReserve book = IUniswapV4StandardExchangeLiquidReserve(address(vault));
        (uint256 total0, uint256 total1) = book.deployedReserve();
        total0 += book.localReserve(token0_);
        total1 += book.localReserve(_token1());
        assertLe(shares_ * total0, mintIn_ * vault.totalSupply(), "A0: token0 claim excludes donation");
        assertLe(shares_ * total1, _u1(1) * vault.totalSupply(), "A0: token1 claim limited to payment");

        vm.startPrank(attacker);
        vault.approve(address(vault), shares_);
        vault.exchangeIn(IERC20(address(vault)), shares_, IERC20(token0_), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 attackerTokAfter_ = IERC20(token0_).balanceOf(attacker);
        assertLe(attackerTokAfter_, attackerTokBefore_ + 2 * mintIn_, "A0: recovery limited to both paid assets");
        assertEq(vault.balanceOf(attacker), 0, "A0: all attacker shares redeemed");
        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares remain after redeem");
        assertLt(attackerTokAfter_ - attackerTokBefore_, donation_, "A0: did not absorb donation");
    }

    function test_A0_dustShare_donation_victimDeposit_noZeroShareAbsorb() public {
        uint256 dustIn_ = _u0(1);
        _mintSeShares(attacker, dustIn_);

        uint256 donation_ = _u0(100);
        address token0_ = _token0();
        MintableERC20Decimals(token0_).mint(donator, donation_);
        vm.prank(donator);
        IERC20(token0_).transfer(address(vault), donation_);

        uint256 victimIn_ = 1;
        MintableERC20Decimals(token0_).mint(victim, victimIn_);
        uint256 victimTokBefore_ = IERC20(token0_).balanceOf(victim);
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.startPrank(victim);
        IERC20(token0_).approve(address(vault), victimIn_);
        uint256 quoted = vault.previewExchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)));
        if (quoted == 0) {
            vm.expectRevert(UniswapV4StandardExchangeCommon.UniswapV4Exchange_ZeroAmount.selector);
            vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), 0, victim, false, _deadline());
            assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_, "A0: zero-share payment returned");
        } else {
            uint256 received = vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), quoted, victim, false, _deadline());
            assertEq(received, quoted, "A0: positive quote funds actual shares");
            assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_ - victimIn_, "A0: exact funded payment");
        }
        vm.stopPrank();

        assertEq(vault.balanceOf(victim), quoted, "A0: no payment without positive shares");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A0: attacker shares unchanged");
        assertEq(vault.totalSupply(), supplyBefore_ + quoted, "A0: only victim shares issued");
    }
}
