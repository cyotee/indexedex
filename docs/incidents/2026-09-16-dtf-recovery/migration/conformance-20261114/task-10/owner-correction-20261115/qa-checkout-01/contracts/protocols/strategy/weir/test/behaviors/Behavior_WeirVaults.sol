// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol";
import {WeirVaults} from "../../WeirVaults.sol";

library Behavior_WeirVaults {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    function assertPosition(WeirVaults weir, IPoolManager manager, PoolId id, address positionOwner) internal view {
        WeirVaults.Vault memory vault = weir.vault(id);
        (uint128 liquidity,,) = manager.getPositionInfo(id, positionOwner, vault.tickLower, vault.tickUpper, bytes32(0));
        require(liquidity == vault.liquidity, "position liquidity");
    }

    function assertNoSubtreeEffects(
        uint256 sharesBefore,
        uint256 sharesAfter,
        uint128 liquidityBefore,
        uint128 liquidityAfter,
        uint256 idle0Before,
        uint256 idle0After,
        uint64 timestampBefore,
        uint64 timestampAfter
    ) internal pure {
        require(sharesBefore == sharesAfter, "shares changed");
        require(liquidityBefore == liquidityAfter, "liquidity changed");
        require(idle0Before == idle0After, "idle changed");
        require(timestampBefore == timestampAfter, "timestamp changed");
    }

    function balanceOf(Currency currency, address holder) internal view returns (uint256) {
        if (currency.isAddressZero()) return holder.balance;
        return IERC20(Currency.unwrap(currency)).balanceOf(holder);
    }
}
