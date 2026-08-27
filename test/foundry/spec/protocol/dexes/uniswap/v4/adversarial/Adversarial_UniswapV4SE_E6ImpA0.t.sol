// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {
    IUniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    IUniswapV4StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {
    UniswapV4StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/// @dev Minimal pool seeder (same shape as SecurePull).
contract AdversarialV4SeederE6 is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/// @dev Hostile PM: returns a matching PoolKey + huge liquidity. Not a mock of the SE vault.
contract HostileUniswapV4PositionManager {
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
 * @title Adversarial_UniswapV4SE_E6ImpA0
 * @notice WP-SEC-E6-U4-001 / WP-SEC-IMP-U4-001 / WP-SEC-A0-U4-001.
 * @dev Production DFPkg + proxy only. Pass = exploit blocked.
 */
contract Adversarial_UniswapV4SE_E6ImpA0 is TestBase_UniswapV4StandardExchange {
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    address internal attacker;
    address internal victim;
    address internal donator;

    uint256 internal constant TEST_AMT = 2 ether;
    address internal constant DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD);

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        donator = makeAddr("donator");

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        poolKey = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        AdversarialV4SeederE6 seeder = new AdversarialV4SeederE6(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
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

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _mintSeShares(address to_, uint256 amountIn_) internal returns (uint256 shares_) {
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(to_, amountIn_);
        vm.startPrank(to_);
        IERC20(token0_).approve(address(vault), amountIn_);
        shares_ = vault.exchangeIn(IERC20(token0_), amountIn_, IERC20(address(vault)), 0, to_, false, _deadline());
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    /// @dev Honest zap-in so `_syncVaultReserves` books sitting vaultShare as R.
    function _syncShareReserve() internal {
        address token0_ = _token0();
        uint256 dust_ = 1e15;
        ERC20PermitMintableStub(token0_).mint(address(this), dust_);
        IERC20(token0_).approve(address(vault), dust_);
        vault.exchangeIn(IERC20(token0_), dust_, IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: leftover vaultShare refund cannot skim booked R                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Seed leftover self-shares as R; fat max + this-call unused only `used` does not pay R.
    function test_E6_exchangeOut_zap_doesNotSweepOtherUsersShares() public {
        uint256 leftover_ = _mintSeShares(victim, TEST_AMT);
        uint256 attackerShares_ = _mintSeShares(attacker, TEST_AMT);
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
        vault.exchangeOut(
            IERC20(address(vault)), fatMax_, IERC20(_token0()), 1, attacker, true, _deadline()
        );

        assertEq(vault.balanceOf(address(vault)), leftoverBefore_, "E6: leftover self-shares unmoved");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "E6: attacker shares unmoved");
        assertEq(IERC20(_token0()).balanceOf(attacker), attackerTokenBefore_, "E6: no tokenOut skim");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(vault)), leftover_, "E6: R unskimmed");
    }

    /// @notice Exact used delivery after leftover is booked refunds 0 leftover shares.
    function test_E6_exchangeOut_zap_exactUsed_doesNotRefundBookedLeftover() public {
        uint256 leftover_ = _mintSeShares(victim, TEST_AMT);
        uint256 attackerShares_ = _mintSeShares(attacker, TEST_AMT);

        vm.prank(victim);
        vault.transfer(address(vault), leftover_);
        _syncShareReserve();

        vm.prank(attacker);
        vault.transfer(address(vault), attackerShares_);

        uint256 amountOut_ = 1e12;
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

    /// @notice In zap-out fat claim against booked leftover reverts (no self-balance U).
    function test_E6_exchangeIn_zapOut_fatClaim_doesNotSkimBookedShares() public {
        uint256 leftover_ = _mintSeShares(victim, TEST_AMT);
        uint256 attackerShares_ = _mintSeShares(attacker, TEST_AMT / 2);
        if (attackerShares_ == 0) attackerShares_ = _mintSeShares(attacker, TEST_AMT);

        vm.prank(victim);
        vault.transfer(address(vault), leftover_);
        _syncShareReserve();

        vm.prank(attacker);
        vault.transfer(address(vault), attackerShares_);

        uint256 fat_ = leftover_ + attackerShares_;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, fat_, attackerShares_));
        vault.exchangeIn(IERC20(address(vault)), fat_, IERC20(_token0()), 0, attacker, true, _deadline());

        assertEq(vault.balanceOf(address(vault)), leftover_ + attackerShares_, "E6 in: inventory unmoved");
    }

    /* ---------------------------------------------------------------------- */
    /*  IMP: untrusted PM / owner must revert                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Unbound / untrusted PositionManager cannot import (hostile contract, not mockCall).
    function test_IMP_importPosition_untrustedPositionManager_reverts() public {
        HostileUniswapV4PositionManager hostile_ = new HostileUniswapV4PositionManager();
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

    /// @notice Default package binds no PM — any importPosition reverts before NFT pull.
    function test_IMP_importPosition_unboundPositionManager_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_UntrustedPositionManager.selector);
        IUniswapV4StandardExchangePositionImport(address(vault)).importPosition(
            IPositionManager(address(1)), 1, 0, attacker, attacker, _deadline()
        );
    }

    /// @notice Bound official PM still requires owner == msg.sender (untrusted owner reverts).
    function test_IMP_importPosition_untrustedOwner_reverts() public {
        HostileUniswapV4PositionManager official_ = new HostileUniswapV4PositionManager();
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
        // Unique CREATE3 salt so this pkg does not collide with TestBase's unbound PM package.
        vm.startPrank(owner);
        IUniswapV4StandardExchangeDFPkg boundPkg_ = IUniswapV4StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(_boundPmPkgInit(positionManager_)),
                    keccak256("UniswapV4StandardExchangeDFPkg.boundPM.secFix")
                )
            )
        );
        vm.stopPrank();
        return IStandardExchangeProxy(boundPkg_.deployVault(poolKey));
    }

    /* ---------------------------------------------------------------------- */
    /*  A0: first mint cannot drain pre-seeded inventory                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Donate before first mint; attacker redeem cannot take the donation.
    function test_A0_donateThenFirstMint_cannotRedeemDonation() public {
        uint256 donation_ = 10 ether;
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(donator, donation_);
        vm.prank(donator);
        IERC20(token0_).transfer(address(vault), donation_);
        assertEq(vault.totalSupply(), 0, "A0: empty supply");

        uint256 mintIn_ = 1 ether;
        uint256 attackerTokBefore_ = IERC20(token0_).balanceOf(attacker);
        uint256 shares_ = _mintSeShares(attacker, mintIn_);

        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares for residual");
        assertEq(vault.balanceOf(attacker), shares_, "A0: attacker user shares");
        assertLt(shares_, vault.totalSupply(), "A0: attacker is not 100% supply");

        vm.startPrank(attacker);
        vault.approve(address(vault), shares_);
        vault.exchangeIn(IERC20(address(vault)), shares_, IERC20(token0_), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 attackerTokAfter_ = IERC20(token0_).balanceOf(attacker);
        // Spent mintIn_; redeem must not return the donation.
        assertLe(attackerTokAfter_, attackerTokBefore_ + mintIn_, "A0: no donation extract");
        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares remain after redeem");
        assertLt(attackerTokAfter_ - attackerTokBefore_, donation_, "A0: did not absorb donation");
    }

    /// @notice Dust first share + donation cannot zero-share-absorb a later victim deposit.
    function test_A0_dustShare_donation_victimDeposit_noZeroShareAbsorb() public {
        uint256 dustIn_ = 1 ether;
        _mintSeShares(attacker, dustIn_);

        uint256 donation_ = 100 ether;
        address token0_ = _token0();
        ERC20PermitMintableStub(token0_).mint(donator, donation_);
        vm.prank(donator);
        IERC20(token0_).transfer(address(vault), donation_);

        uint256 victimIn_ = 1;
        ERC20PermitMintableStub(token0_).mint(victim, victimIn_);
        uint256 victimTokBefore_ = IERC20(token0_).balanceOf(victim);
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.startPrank(victim);
        IERC20(token0_).approve(address(vault), victimIn_);
        vm.expectRevert(UniswapV4StandardExchangeCommon.UniswapV4Exchange_ZeroAmount.selector);
        vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), 0, victim, false, _deadline());
        vm.stopPrank();

        assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_, "A0: victim tokens returned");
        assertEq(vault.balanceOf(victim), 0, "A0: no zero-share credit");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A0: attacker shares unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "A0: supply unchanged");
    }
}
