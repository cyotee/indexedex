// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault,
    IRocketPoolRETHRebalance
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    RocketPoolRETH_Component_FactoryService
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    HermeticRETH,
    HermeticDepositPool
} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";
import {HostileWETH} from "contracts/protocols/staking/rocket-pool/test/hermetic/HostileWETH.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title Adversarial_RocketPoolRETH_P0
 * @notice P0 adversarial: deposit integrity, donation, reentrancy, capacity duality, residual inventory.
 *
 * Attack catalog:
 * - A0 pretransferred no delta
 * - A1/A2 donation
 * - C1/C2 reentrancy IsLocked
 * - E1/E2 round-trip conservation
 * - E5 zero/deadline
 * - H1 liquid shortfall
 * - S3/S4 capacity duality
 * - R-route native ETH
 */
contract Adversarial_RocketPoolRETH_P0 is TestBase_RocketPoolRETHStandardExchange {
    using RocketPoolRETH_Component_FactoryService for ICreate3FactoryProxy;
    using RocketPoolRETH_Component_FactoryService for IIndexedexManagerProxy;

    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    /// @dev A0: pretransferred=true with no balance delta → InsufficientDeposit; no mint.
    function test_A0_pretransferred_noDelta() public {
        uint256 amount = 1 ether;
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientDeposit.selector, amount, 0)
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            true, // pretransferred without credit
            block.timestamp + 1 hours
        );
        assertEq(IERC20(seVault).totalSupply(), supplyBefore);
    }

    /// @dev A1: donate WETH does not free-mint SE.
    function test_A1_donateWeth_noFreeMint() public {
        _seedVaultInventory(0, 10 ether);
        uint256 seBefore = IERC20(seVault).balanceOf(address(this));
        _fundSleeve(5 ether);
        assertEq(IERC20(seVault).balanceOf(address(this)), seBefore);
        // Victim still gets fair redeem of their shares
        uint256 shares = seBefore / 2;
        _fundSleeve(20 ether); // ensure sleeve for pay
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticReth)));
        assertGt(preview, 0);
    }

    /// @dev A2: donate rETH does not free-mint SE.
    function test_A2_donateReth_noFreeMint() public {
        _seedVaultInventory(5 ether, 0);
        uint256 seBefore = IERC20(seVault).balanceOf(address(this));
        hermeticReth.mint(address(this), 3 ether);
        hermeticReth.transfer(seVault, 3 ether);
        assertEq(IERC20(seVault).balanceOf(address(this)), seBefore);
    }

    /// @dev C1: reenter exchangeIn during WETH transferFrom → IsLocked (nested fails, outer succeeds).
    function test_C1_reentrancyIn_IsLocked() public {
        (HostileWETH hostile, address hostileVault) = _deployHostileVault();
        IStandardExchangeIn vin = IStandardExchangeIn(hostileVault);

        uint256 amount = 1 ether;
        vm.deal(address(this), amount * 2);
        hostile.deposit{value: amount * 2}();

        // Nested call uses pretransferred=true so it does not re-pull (arm only fires once on outer transferFrom).
        hostile.arm(
            hostileVault,
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(address(hostile)),
                amount,
                IERC20(hostileVault),
                uint256(0),
                address(this),
                true,
                block.timestamp + 1 hours
            )
        );

        hostile.approve(hostileVault, amount);
        uint256 shares = vin.exchangeIn(
            IERC20(address(hostile)),
            amount,
            IERC20(hostileVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        assertGt(shares, 0);
        assertEq(hostile.reentryAttempts(), 1, "nested reentry must fire once");
        assertFalse(hostile.nestedCallSucceeded(), "nested must not succeed");
        assertEq(
            hostile.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested must revert IsLocked"
        );
        hostile.disarm();
    }

    /// @dev C2: reenter exchangeOut during WETH transfer out → IsLocked.
    function test_C2_reentrancyOut_IsLocked() public {
        (HostileWETH hostile, address hostileVault) = _deployHostileVault();
        IStandardExchangeIn vin = IStandardExchangeIn(hostileVault);
        IStandardExchangeOut vout = IStandardExchangeOut(hostileVault);

        uint256 seed = 5 ether;
        vm.deal(address(this), seed + 2 ether);
        hostile.deposit{value: seed + 2 ether}();
        hostile.approve(hostileVault, seed);
        uint256 shares = vin.exchangeIn(
            IERC20(address(hostile)),
            seed,
            IERC20(hostileVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        // Ensure sleeve can pay 0.5 ETH (capacity may have staked overage).
        if (IRocketPoolRETHStandardVault(hostileVault).liquidReserveEth() < 0.5 ether) {
            hostile.transfer(hostileVault, 2 ether);
        }
        uint256 outAmt = 0.5 ether;

        hostile.arm(
            hostileVault,
            abi.encodeWithSelector(
                IStandardExchangeOut.exchangeOut.selector,
                IERC20(hostileVault),
                shares,
                IERC20(address(hostile)),
                outAmt,
                address(this),
                false,
                block.timestamp + 1 hours
            )
        );

        assertGt(
            vout.exchangeOut(
                IERC20(hostileVault),
                shares,
                IERC20(address(hostile)),
                outAmt,
                address(this),
                false,
                block.timestamp + 1 hours
            ),
            0
        );
        assertEq(hostile.reentryAttempts(), 1);
        assertFalse(hostile.nestedCallSucceeded());
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
        hostile.disarm();
    }

    function _deployHostileVault() internal returns (HostileWETH hostile, address vault) {
        hostile = new HostileWETH();
        HermeticRETH reth2 = new HermeticRETH();
        HermeticDepositPool pool2 = new HermeticDepositPool(reth2);
        pool2.setMaxDepositAmount(type(uint256).max);
        vm.prank(owner);
        vault = rocketPoolSeDFPkg.deployVault(address(reth2), address(hostile), address(pool2));
    }

    /// @dev E1: round-trip W↔S - preview==exec both legs; no extractable profit; residual free inventory ok on sleeve.
    function test_E1_roundTrip_wethSe() public {
        // Capacity 0 keeps full eth face liquid so SE→WETH can close without burn.
        hermeticPool.setMaxDepositAmount(0);
        _seedVaultInventory(1 ether, 0);

        uint256 amount = 20 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 previewMint = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            previewMint,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, previewMint);

        uint256 previewRedeem = seIn.previewExchangeIn(IERC20(seVault), out, IERC20(address(hermeticWeth)));
        uint256 wethBefore = hermeticWeth.balanceOf(address(this));
        uint256 recovered = seIn.exchangeIn(
            IERC20(seVault),
            out,
            IERC20(address(hermeticWeth)),
            previewRedeem,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(recovered, previewRedeem);
        assertEq(hermeticWeth.balanceOf(address(this)) - wethBefore, recovered);
        // No free profit: recovered <= amount (virtual offset / floor share math)
        assertLe(recovered, amount);
        // Meaningful recovery (not drained)
        assertGt(recovered, amount * 99 / 100);
    }

    /// @dev E5: zero amount / deadline.
    function test_E5_zeroAndDeadline() public {
        vm.expectRevert(abi.encodeWithSelector(IRocketPoolRETHStandardVault.ZeroAmount.selector));
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            0,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        _dealWeth(address(this), 1 ether);
        hermeticWeth.approve(seVault, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IRocketPoolRETHStandardVault.DeadlineExpired.selector));
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            1 ether,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp - 1
        );
    }

    /// @dev H1: empty sleeve + no burn collateral → InsufficientLiquidReserve exact args.
    function test_H1_emptySleeve_noBurn() public {
        _seedVaultInventory(0, 15 ether);
        uint256 requested = 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientLiquidReserve.selector, requested, 0)
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            requested,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    /// @dev S3: capacity 0 W→S does not hard-fail mint.
    function test_S3_capacity0_wethToSe_mints() public {
        hermeticPool.setMaxDepositAmount(0);
        _dealWeth(address(this), 5 ether);
        hermeticWeth.approve(seVault, 5 ether);
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            5 ether,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertGt(out, 0);
    }

    /// @dev S4: capacity 0 W→R hard-fails; no partial rETH.
    function test_S4_capacity0_wethToReth_hardFail() public {
        hermeticPool.setMaxDepositAmount(0);
        _dealWeth(address(this), 2 ether);
        hermeticWeth.approve(seVault, 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientDepositCapacity.selector, 0, 2 ether)
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            2 ether,
            IERC20(address(hermeticReth)),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(hermeticReth.balanceOf(address(this)), 0);
    }

    /// @dev R-route: native ETH InvalidRoute.
    function test_R_nativeEth_invalidRoute() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(0), seVault)
        );
        seIn.previewExchangeIn(IERC20(address(0)), 1 ether, IERC20(seVault));
    }

    /* ---------------------------------------------------------------------- */
    /*  I1–I3: same-tx inbound-delta (WP-SEC-I-LST-001)                       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: inventory sitting, pretransferred=true, no in-call transfer → delta=0 revert.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _seedVaultInventory(10 ether, 10 ether);
        uint256 claimed = 1 ether;
        uint256 invBefore = hermeticWeth.balanceOf(seVault);
        assertGe(invBefore, claimed, "absolute inventory present");
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        uint256 attackerSharesBefore = IERC20(seVault).balanceOf(attacker);
        assertEq(hermeticWeth.balanceOf(attacker), 0, "attacker drained");
        assertEq(hermeticWeth.allowance(attacker, seVault), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientDeposit.selector, claimed, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            claimed,
            IERC20(seVault),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(seVault).totalSupply(), supplyBefore, "I1: no free vaultShare");
        assertEq(IERC20(seVault).balanceOf(attacker), attackerSharesBefore, "I1: attacker shares unchanged");
        assertEq(hermeticWeth.balanceOf(seVault), invBefore, "I1: inventory unchanged");
    }

    /// @notice I2: short prior push then claim more with pretransferred=true.
    ///         Same-tx snapshot is after the push, so observed delta=0 → InsufficientDeposit(claimed, 0).
    function test_I2_shortPush_pretransferred_claimedGtDelta_reverts() public {
        _seedVaultInventory(5 ether, 5 ether);
        uint256 claimed = 1 ether;
        uint256 shortPush = 0.4 ether;
        require(shortPush > 0 && shortPush < claimed, "need short < claimed");

        _dealWeth(attacker, shortPush);
        vm.prank(attacker);
        hermeticWeth.transfer(seVault, shortPush);

        uint256 invAfterPush = hermeticWeth.balanceOf(seVault);
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        assertEq(hermeticWeth.allowance(attacker, seVault), 0, "I2: no in-call allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientDeposit.selector, claimed, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            claimed,
            IERC20(seVault),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(seVault).totalSupply(), supplyBefore, "I2: no mint on short");
        assertEq(IERC20(seVault).balanceOf(attacker), 0, "I2: attacker no vaultShare");
        assertEq(hermeticWeth.balanceOf(seVault), invAfterPush, "I2: short push not consumed");
    }

    /// @notice I3: residual after an honest pull cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        _seedVaultInventory(5 ether, 5 ether);

        uint256 victimIn = 2 ether;
        _dealWeth(victim, victimIn);
        vm.startPrank(victim);
        hermeticWeth.approve(seVault, victimIn);
        uint256 minted = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            victimIn,
            IERC20(seVault),
            0,
            victim,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted, 0, "honest first pull");

        uint256 residual = hermeticWeth.balanceOf(seVault);
        assertGt(residual, 0, "residual inventory remains");
        uint256 claim = residual > 1 ether ? 1 ether : residual;
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        assertEq(hermeticWeth.balanceOf(attacker), 0, "I3: attacker drained");
        assertEq(hermeticWeth.allowance(attacker, seVault), 0, "I3: no allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IRocketPoolRETHStandardVault.InsufficientDeposit.selector, claim, uint256(0))
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            claim,
            IERC20(seVault),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(seVault).totalSupply(), supplyBefore, "I3: no second free mint");
        assertEq(hermeticWeth.balanceOf(seVault), residual, "I3: residual unmoved");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: Target ⊆ facetFuncs ⊆ loupe ⊆ proxy (WP-SEC-J-LST-001)         */
    /* ---------------------------------------------------------------------- */

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _rocketMoneySelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](5);
        sels_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[1] = IStandardExchangeIn.exchangeIn.selector;
        sels_[2] = IStandardExchangeOut.previewExchangeOut.selector;
        sels_[3] = IStandardExchangeOut.exchangeOut.selector;
        sels_[4] = IRocketPoolRETHRebalance.rebalance.selector;
    }

    /// @notice J1: Target/product money selectors ⊆ CREATE3 facetFuncs (not an incomplete Facet copy).
    function test_J1_facetFuncs_coversTargetApi() public view {
        bytes4[] memory inFuncs_ = IFacet(address(rocketPoolExchangeInFacet)).facetFuncs();
        assertTrue(_facetFuncsContains(inFuncs_, IStandardExchangeIn.previewExchangeIn.selector), "J1 previewIn");
        assertTrue(_facetFuncsContains(inFuncs_, IStandardExchangeIn.exchangeIn.selector), "J1 exchangeIn");

        bytes4[] memory outFuncs_ = IFacet(address(rocketPoolExchangeOutFacet)).facetFuncs();
        assertTrue(
            _facetFuncsContains(outFuncs_, IStandardExchangeOut.previewExchangeOut.selector), "J1 previewOut"
        );
        assertTrue(_facetFuncsContains(outFuncs_, IStandardExchangeOut.exchangeOut.selector), "J1 exchangeOut");

        bytes4[] memory rebFuncs_ = IFacet(address(rocketPoolRebalanceFacet)).facetFuncs();
        assertTrue(_facetFuncsContains(rebFuncs_, IRocketPoolRETHRebalance.rebalance.selector), "J1 rebalance");
    }

    /// @notice J2: loupe facetAddress(sel) != 0 and != proxy after registry deploy.
    function test_J2_proxyLoupe_allProductSelectors() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(seVault);
        bytes4[] memory controls_ = _rocketMoneySelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != seVault, "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on the **proxy**, never the facet impl.
    function test_J3_proxyCallable_smoke_eachSelector() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(seVault);
        address inFacet_ = loupe_.facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address outFacet_ = loupe_.facetAddress(IStandardExchangeOut.exchangeOut.selector);
        address rebFacet_ = loupe_.facetAddress(IRocketPoolRETHRebalance.rebalance.selector);
        assertTrue(inFacet_ != address(0) && inFacet_ != seVault, "J3 proxy cut in");
        assertTrue(outFacet_ != address(0) && outFacet_ != seVault, "J3 proxy cut out");
        assertTrue(rebFacet_ != address(0) && rebFacet_ != seVault, "J3 proxy cut rebalance");

        _seedVaultInventory(3 ether, 3 ether);

        uint256 previewIn_ =
            IStandardExchangeIn(seVault).previewExchangeIn(IERC20(address(hermeticWeth)), 1 ether, IERC20(seVault));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        uint256 previewOut_ =
            IStandardExchangeOut(seVault).previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1e17);
        assertGt(previewOut_, 0, "J3 previewExchangeOut live on proxy");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRocketPoolRETHStandardVault.InsufficientDeposit.selector, uint256(1 ether), uint256(0)
            )
        );
        IStandardExchangeIn(seVault).exchangeIn(
            IERC20(address(hermeticWeth)), 1 ether, IERC20(seVault), 0, attacker, true, block.timestamp + 1 hours
        );

        seRebalance.rebalance();
    }
}
