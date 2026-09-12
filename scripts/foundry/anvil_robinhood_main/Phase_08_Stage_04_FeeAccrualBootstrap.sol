// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

library Phase_08_Stage_04_FeeAccrualBootstrap {
    struct Config {
        address actor;
        address recipient;
        address dtf;
        address weth;
        uint256 wethInput;
        uint256 maxDtfInput;
        uint256 lockDuration;
        uint256 minBondShares;
        uint256 deadline;
    }

    function payments(IUniswapV4Detf detf, Config memory c)
        internal view returns (address[] memory tokens, uint256[] memory amounts)
    {
        require(!detf.isReserveLive(), "Bootstrap: already live; verify receipt instead");
        require(c.actor != address(0) && c.recipient != address(0), "Bootstrap: missing actor");
        require(c.wethInput > 0 && c.maxDtfInput > 0 && c.minBondShares > 0, "Bootstrap: explicit positive limits required");
        require(c.deadline > block.timestamp, "Bootstrap: expired deadline");
        (tokens, amounts) = detf.previewFirstBondPayments(IERC20(c.weth), c.wethInput);
        require(tokens.length == 2 && amounts.length == 2, "Bootstrap: two capital payments required");
        uint256 found;
        for (uint256 i; i < 2; ++i) {
            require(amounts[i] > 0, "Bootstrap: empty capital leg");
            if (tokens[i] == c.weth) {
                require(amounts[i] == c.wethInput, "Bootstrap: WETH budget");
                found |= 1;
            } else if (tokens[i] == c.dtf) {
                require(amounts[i] <= c.maxDtfInput, "Bootstrap: DTF budget");
                found |= 2;
            }
            require(IERC20(tokens[i]).balanceOf(c.actor) >= amounts[i], "Bootstrap: actor lacks payment");
        }
        require(found == 3, "Bootstrap: unexpected capital token");
    }

    function execute(IUniswapV4Detf detf, Config memory c) internal returns (uint256 tokenId, uint256 shares) {
        (address[] memory tokens, uint256[] memory amounts) = payments(detf, c);
        for (uint256 i; i < tokens.length; ++i) {
            require(IERC20(tokens[i]).approve(address(detf), 0), "Bootstrap: reset approval");
            require(IERC20(tokens[i]).approve(address(detf), amounts[i]), "Bootstrap: approval");
        }
        (tokenId, shares) = detf.bond(IERC20(c.weth), c.wethInput, c.lockDuration, c.recipient, false, c.deadline);
        for (uint256 i; i < tokens.length; ++i) require(IERC20(tokens[i]).approve(address(detf), 0), "Bootstrap: clear approval");
        require(detf.isReserveLive() && shares >= c.minBondShares, "Bootstrap: short/not live");
        require(IERC721(detf.bondNftVault()).ownerOf(tokenId) == c.recipient, "Bootstrap: wrong bond recipient");
    }
}
