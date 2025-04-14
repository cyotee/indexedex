// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/ProtocolDETF_IntegrationBase.t.sol";

contract ProtocolDETFSyntheticPriceDebugTest is ProtocolDETFIntegrationBase {
    function test_debug_synthetic_price() public view {
        uint256 syntheticPrice = detf.syntheticPrice();
        console.log("Synthetic price (raw):", syntheticPrice);
        console.log("Synthetic price (WAD):", syntheticPrice / 1e18);
    }

    function test_mint_chir_with_weth() public {
        vm.skip(true);

        uint256 amountIn = 10e18;
        uint256 syntheticPrice = detf.syntheticPrice();
        console.log("Synthetic price before mint:", syntheticPrice);

        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(weth9)),
            amountIn,
            IERC20(address(detf))
        );
        console.log("Preview CHIR out:", previewOut);

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), amountIn);
        uint256 chirOut = IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(weth9)),
            amountIn,
            IERC20(address(detf)),
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        console.log("Actual CHIR out:", chirOut);
        console.log("Alice CHIR balance:", IERC20(address(detf)).balanceOf(detfAlice));
        assertGt(chirOut, 0, "Should mint some CHIR");
    }

    function test_log_pool_state() public view {
        console.log("=== Protocol DETF State ===");
        console.log("CHIR address:", address(detf));
        console.log("WETH address:", address(weth9));
        console.log("RICH address:", address(rich));
        console.log("RICHIR address:", address(richir));
        console.log("Reserve pool:", address(reservePool));
        console.log("CHIR totalSupply (e18):", IERC20(address(detf)).totalSupply() / 1e18);
        console.log("Reserve pool totalSupply (e18):", IERC20(address(reservePool)).totalSupply() / 1e18);
        console.log("DETF reserve BPT balance (e18):", IERC20(address(reservePool)).balanceOf(address(detf)) / 1e18);
        console.log("DETF chirWethVault shares (e18):", IERC20(address(chirWethVault)).balanceOf(address(detf)) / 1e18);
        console.log("DETF richChirVault shares (e18):", IERC20(address(richChirVault)).balanceOf(address(detf)) / 1e18);
    }
}
