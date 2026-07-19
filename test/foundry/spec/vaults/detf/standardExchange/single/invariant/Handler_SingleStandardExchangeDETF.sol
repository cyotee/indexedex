// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface ISingleSeDetfInvHost {
    function invInstance() external view returns (address);
    function invShare() external view returns (IERC20);
    function invActor(uint256 idx) external view returns (address);
    function invMint(address user, uint256 lpAmount) external returns (uint256);
    function invBurn(address user, uint256 detfAmount) external returns (uint256);
    function invDonateShares(address from, uint256 shareAmount) external;
}

/// @notice Handler for Single SE DETF L3 (Wave 1B).
contract Handler_SingleStandardExchangeDETF is Test {
    ISingleSeDetfInvHost public immutable HOST;

    uint256 public ghost_mintCount;
    uint256 public ghost_burnCount;
    uint256 public ghost_donateCount;
    uint256 public ghost_totalDetfMinted;
    uint256 public ghost_totalDetfBurned;

    constructor(ISingleSeDetfInvHost host_) {
        HOST = host_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return HOST.invActor(seed % 2);
    }

    function mint(uint256 lpSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        uint256 lpAmount = bound(lpSeed, 25e18, 150e18);
        try HOST.invMint(actor, lpAmount) returns (uint256 out) {
            if (out > 0) {
                unchecked {
                    ++ghost_mintCount;
                    ghost_totalDetfMinted += out;
                }
            }
        } catch {}
    }

    function burn(uint256 burnSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        address instance_ = HOST.invInstance();
        uint256 bal = IERC20(instance_).balanceOf(actor);
        if (bal < 1e6) return;
        uint256 amount = bound(burnSeed, 1e6, bal);
        try HOST.invBurn(actor, amount) returns (uint256) {
            unchecked {
                ++ghost_burnCount;
                ghost_totalDetfBurned += amount;
            }
        } catch {}
    }

    function donateShares(uint256 shareSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        IERC20 share = HOST.invShare();
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
            }
        } catch {}
    }
}
