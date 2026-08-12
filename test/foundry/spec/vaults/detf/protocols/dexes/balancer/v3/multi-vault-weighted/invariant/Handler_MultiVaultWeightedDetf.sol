// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/// @dev Callback surface exposed by the invariant suite (public wrappers over TestBase helpers).
interface IMultiVaultInvHost {
    function invInstance() external view returns (address);
    function invShare0() external view returns (IERC20);
    function invActor(uint256 idx) external view returns (address);
    function invMint(address user, uint256 lpAmount) external returns (uint256 detfOut);
    function invBurn(address user, uint256 detfAmount) external returns (uint256 sharesOut);
    function invDonateShares(address from, uint256 shareAmount) external;
}

/**
 * @title Handler_MultiVaultWeightedDetf
 * @notice Foundry invariant handler for MultiVaultWeightedDetf (Wave 1A L3).
 * @dev Pattern mirrors Handler_StandardExchangeBufferPool: try/catch, ghosts on success,
 *      fund-before-act via host.mint path. Actors alice/bob via invActor.
 */
contract Handler_MultiVaultWeightedDetf is Test {
    IMultiVaultInvHost public immutable HOST;

    uint256 public ghost_mintCount;
    uint256 public ghost_burnCount;
    uint256 public ghost_donateCount;
    uint256 public ghost_totalDetfMinted;
    uint256 public ghost_totalDetfBurned;
    uint256 public ghost_totalSharesDonated;

    constructor(IMultiVaultInvHost host_) {
        HOST = host_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return HOST.invActor(seed % 2);
    }

    /// @notice Mint DETF with SE shares funded from lp seed.
    function mint(uint256 lpSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        uint256 lpAmount = bound(lpSeed, 20e18, 150e18);
        try HOST.invMint(actor, lpAmount) returns (uint256 out) {
            if (out > 0) {
                unchecked {
                    ++ghost_mintCount;
                    ghost_totalDetfMinted += out;
                }
            }
        } catch {}
    }

    /// @notice Burn up to actor's DETF balance for leg-0 shares.
    function burn(uint256 burnSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        address instance_ = HOST.invInstance();
        uint256 bal = IERC20(instance_).balanceOf(actor);
        if (bal < 1e6) return;
        uint256 amount = bound(burnSeed, 1e6, bal);
        try HOST.invBurn(actor, amount) returns (uint256 out) {
            if (out > 0 || amount > 0) {
                unchecked {
                    ++ghost_burnCount;
                    ghost_totalDetfBurned += amount;
                }
            }
        } catch {}
    }

    /// @notice Donate SE shares to the diamond without mint credit (A-class ghost support).
    function donateShares(uint256 shareSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        // Ensure actor has shares via a mint attempt first when empty.
        IERC20 share = HOST.invShare0();
        if (share.balanceOf(actor) < 1e12) {
            try HOST.invMint(actor, 40e18) {} catch {}
        }
        uint256 bal = share.balanceOf(actor);
        if (bal < 1e12) return;
        uint256 amount = bound(shareSeed, 1e12, bal / 4 + 1e12);
        if (amount > bal) amount = bal;
        try HOST.invDonateShares(actor, amount) {
            unchecked {
                ++ghost_donateCount;
                ghost_totalSharesDonated += amount;
            }
        } catch {}
    }
}
