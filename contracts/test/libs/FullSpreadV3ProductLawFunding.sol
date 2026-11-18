// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/// @dev Generic test setup through existing payment inputs. Raw-payment witnesses bypass preparation.
library FullSpreadV3ProductLawFunding {
    Vm private constant vm = Vm(VM_ADDRESS);

    /// @dev Prepare once before quoting: keep the original native budget, acquire real bundle shares
    ///      only when the payment leg has fewer decimals than its SE counterasset.
    function preparePayment(address instance, address inputPair, uint256 budget, address payer)
        internal returns (IERC20 token, uint256 amount)
    {
        token = IERC20(inputPair);
        amount = budget;
        if (budget == 0) return (token, amount);
        address vault = IUniswapV4SeBufferHook(IUniswapV4Detf(instance).hook()).standardExchangeOf(inputPair);
        // Already prepared shares and other payment kinds keep the common fixture's identity behavior.
        if (vault == address(0)) return (token, amount);
        _fundPair(inputPair, payer, budget);
        address[] memory tokens = IBasicVault(vault).vaultTokens();
        require(tokens.length == 2 && (tokens[0] == inputPair || tokens[1] == inputPair), "position payment leg");
        address other = tokens[0] == inputPair ? tokens[1] : tokens[0];
        if (IERC20Metadata(inputPair).decimals() < IERC20Metadata(other).decimals()) {
            token = IERC20(vault);
            uint256 beforeShares = token.balanceOf(payer);
            amount = SeLib.acquirePositionShares(vault, inputPair, budget, payer);
            require(amount > 0 && token.balanceOf(payer) == beforeShares + amount, "real shares fund payment");
        }
    }

    function tryBond(address instance, address inputPair, uint256 inputAmount, address payer, uint256 duration)
        internal returns (bool handled, uint256 tokenId, uint256 liquidity)
    {
        if (inputAmount == 0) return (false, 0, 0);
        IUniswapV4Detf detf = IUniswapV4Detf(instance);
        if (!detf.isReserveLive()) {
            (tokenId, liquidity,) = SeLib.bondFirstPositionBasket(detf, inputPair, inputAmount, payer, duration);
            return (true, tokenId, liquidity);
        }
        address pair = inputPair;
        address vault = IUniswapV4SeBufferHook(detf.hook()).standardExchangeOf(pair);
        address[] memory tokens = IBasicVault(vault).vaultTokens();
        require(tokens.length == 2 && (tokens[0] == pair || tokens[1] == pair), "position payment leg");
        address other = tokens[0] == pair ? tokens[1] : tokens[0];
        if (IERC20Metadata(pair).decimals() >= IERC20Metadata(other).decimals()) return (false, 0, 0);
        uint256 budget = inputAmount;
        _fundPair(pair, payer, budget);
        uint256 acquired = SeLib.acquirePositionShares(vault, pair, budget, payer);
        uint256 beforeShares = IERC20(vault).balanceOf(payer);
        vm.startPrank(payer);
        IERC20(vault).approve(instance, acquired);
        (tokenId, liquidity) = detf.bond(
            IERC20(vault), acquired, duration, payer, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(IERC20(vault).balanceOf(payer) == beforeShares - acquired, "real shares fund bond");
        require(liquidity > 0 && detf.isReserveLive(), "funded reserve live");
        return (true, tokenId, liquidity);
    }

    function _fundPair(address token, address payer, uint256 amount) private {
        uint256 balance = IERC20(token).balanceOf(payer);
        if (balance < amount) MintableERC20Decimals(token).mint(payer, amount - balance);
    }
}
