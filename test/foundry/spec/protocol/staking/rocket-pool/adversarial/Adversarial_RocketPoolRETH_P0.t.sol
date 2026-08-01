// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault
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
}
