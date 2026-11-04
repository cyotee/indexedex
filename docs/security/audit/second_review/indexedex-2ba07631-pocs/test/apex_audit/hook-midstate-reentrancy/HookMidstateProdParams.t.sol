// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// Business-logic adjudication variants for APEX-2026-017.
// Same attacker / scenario as HookMidstateReentrancy.t.sol, but:
//  (a) swap fee set to the value the package comment declares as the intended default (0.05%),
//      instead of the 5e16 (=5%) literal the fixture inherits;
//  (b) additionally, the pool initialized the way the design spec section 6.1 prescribes
//      (shares + dust TTA; virtualTTA seeded from shares), not the fixture's equal-raw seed.
// The fee is changed by the pool's real swapFeeManager (feeTo) through Vault.setStaticSwapFeePercentage,
// i.e. a legitimate admin configuration, before the attacker acts.

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolRoleAccounts} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {HookMidstateReentrancyTest} from "./HookMidstateReentrancy.t.sol";

abstract contract FeeSet is HookMidstateReentrancyTest {
    function _fee() internal pure virtual returns (uint256);

    function _setFee() internal {
        PoolRoleAccounts memory ra = bv3Vault.getPoolRoleAccounts(bufferPool);
        vm.prank(ra.swapFeeManager);
        bv3Vault.setStaticSwapFeePercentage(bufferPool, _fee());
        console2.log("static swap fee", bv3Vault.getStaticSwapFeePercentage(bufferPool));
    }

    function _initPool() internal virtual override {
        super._initPool();
        _setFee();
    }
}

/// (a) fixture init, 0.05% fee
contract HookMidstate_Fee005 is FeeSet {
    function _fee() internal pure override returns (uint256) { return 5e14; }
}

/// (a') fixture init, 1% fee
contract HookMidstate_Fee1pct is FeeSet {
    function _fee() internal pure override returns (uint256) { return 1e16; }
}

/// (b) design-spec init (shares + 1 DAI dust TTA), 0.05% fee
contract HookMidstate_DesignInit_Fee005 is FeeSet {
    function _fee() internal pure override returns (uint256) { return 5e14; }

    function _initPool() internal override {
        dai.mint(alice, INITIAL_SHARES_RAW * 2);
        usdc.mint(alice, INITIAL_SHARES_RAW * 2);
        vm.startPrank(alice);
        dai.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        usdc.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(dai), address(usdc), false, INITIAL_SHARES_RAW * 2, INITIAL_SHARES_RAW * 2, 1, 1, alice,
            block.timestamp + 1 hours
        );
        IERC20(address(aeroDaiUsdcPool)).approve(address(seVault), lpOut);
        uint256 seSharesOut = seVault.deposit(lpOut, alice);
        dai.mint(alice, 1e18);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = address(poolTokens[i]) == address(seVault) ? seSharesOut : 1e18;
        }
        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
        _setFee();
    }
}
