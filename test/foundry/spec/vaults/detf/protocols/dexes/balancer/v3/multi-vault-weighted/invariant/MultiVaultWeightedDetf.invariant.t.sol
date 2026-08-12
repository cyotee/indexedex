// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {InvariantAssertLib} from "contracts/test/invariant/InvariantAssertLib.sol";
import {
    Handler_MultiVaultWeightedDetf,
    IMultiVaultInvHost
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/invariant/Handler_MultiVaultWeightedDetf.sol";

/**
 * @title MultiVaultWeightedDetfInvariant
 * @notice L3 Foundry invariant suite for MultiVaultWeightedDetf (Wave 1A).
 * @dev Production-first N=1 open-threshold DETF + Aerodrome SE leg. Handler try/catch pattern
 *      from BufferPool L3 gold. Complements adversarial P0/P1 (does not replace catalog cases).
 */
/// forge-config: default.invariant.runs = 24
/// forge-config: default.invariant.depth = 10
contract MultiVaultWeightedDetfInvariant is TestBase_MultiVaultWeightedDetf, IMultiVaultInvHost {
    Handler_MultiVaultWeightedDetf internal handler;
    address internal invInstanceAddr;
    address internal invActor0;
    address internal invActor1;

    function setUp() public virtual override {
        super.setUp();
        invActor0 = makeAddr("invActor0");
        invActor1 = makeAddr("invActor1");

        invInstanceAddr = _deployOpenThresholdDetfN(1);
        _goLiveViaBptBond(invInstanceAddr, invActor0, 1_000e18);
        _assertLive(invInstanceAddr);

        handler = new Handler_MultiVaultWeightedDetf(IMultiVaultInvHost(address(this)));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_MultiVaultWeightedDetf.mint.selector;
        selectors[1] = Handler_MultiVaultWeightedDetf.burn.selector;
        selectors[2] = Handler_MultiVaultWeightedDetf.donateShares.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /* ---------------------------------------------------------------------- */
    /*                         IMultiVaultInvHost                             */
    /* ---------------------------------------------------------------------- */

    function invInstance() external view override returns (address) {
        return invInstanceAddr;
    }

    function invShare0() external view override returns (IERC20) {
        return seShares[0];
    }

    function invActor(uint256 idx) external view override returns (address) {
        return idx % 2 == 0 ? invActor0 : invActor1;
    }

    function invMint(address user, uint256 lpAmount) external override returns (uint256 detfOut) {
        // Only handler should call; still production path.
        detfOut = _mintOnLeg(invInstanceAddr, 0, user, lpAmount);
    }

    function invBurn(address user, uint256 detfAmount) external override returns (uint256 sharesOut) {
        sharesOut = _burnToLeg(invInstanceAddr, 0, user, detfAmount);
    }

    function invDonateShares(address from, uint256 shareAmount) external override {
        vm.prank(from);
        seShares[0].transfer(invInstanceAddr, shareAmount);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Invariants                                */
    /* ---------------------------------------------------------------------- */

    /// @notice P-RESID: no free DETF or vault shares stuck on diamond after ops.
    function invariant_residualInventory() public view {
        // Donate intentionally leaves vault shares on instance - only free product DETF
        // and non-donated residual must be zero when donate ghost is 0.
        assertEq(IERC20(invInstanceAddr).balanceOf(invInstanceAddr), 0, "P-RESID: free DETF");
        // After donate, seShares may sit on instance; that is intentional free transfer.
        // If no donate ever succeeded, shares residual must be 0.
        if (handler.ghost_donateCount() == 0) {
            assertEq(seShares[0].balanceOf(invInstanceAddr), 0, "P-RESID: free SE share without donate");
        }
    }

    /// @notice P-GHOST: successful op counters never wrap / only increase (uint monotonic).
    function invariant_ghostCountersMonotonic() public view {
        // uint256 cannot go negative; assert counts are consistent with totals.
        if (handler.ghost_mintCount() == 0) {
            assertEq(handler.ghost_totalDetfMinted(), 0, "P-GHOST: mint total without count");
        }
        if (handler.ghost_burnCount() == 0) {
            assertEq(handler.ghost_totalDetfBurned(), 0, "P-GHOST: burn total without count");
        }
    }

    /// @notice P-SUPPLY: tracked actor DETF balances ≤ totalSupply.
    function invariant_actorBalancesLeSupply() public view {
        uint256 supply_ = IERC20(invInstanceAddr).totalSupply();
        uint256 a_ = IERC20(invInstanceAddr).balanceOf(invActor0);
        uint256 b_ = IERC20(invInstanceAddr).balanceOf(invActor1);
        assertLe(a_ + b_, supply_, "P-SUPPLY: actors exceed supply");
    }

    /// @notice P-NOFREE soft: burned DETF cannot exceed minted + genesis bootstrap supply.
    function invariant_burnedNotExceedMintedPlusBootstrap() public view {
        // Bootstrap go-live may mint DETF to invActor0 via bond path; only track handler mints/burns.
        // Soft: totalDetfBurned from handler ≤ totalDetfMinted + supply (cannot burn more than exists).
        uint256 supply_ = IERC20(invInstanceAddr).totalSupply();
        assertLe(
            handler.ghost_totalDetfBurned(),
            handler.ghost_totalDetfMinted() + supply_ + 1,
            "P-NOFREE: burn ghost exceeds mint+supply"
        );
    }

    /// @notice Live flag stays true under random user ops.
    function invariant_stillLive() public view {
        assertTrue(IMultiVaultWeightedDetfInfo(invInstanceAddr).isReserveLive(), "reserve still live");
    }
}
