// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";

/// @notice N=3 multi-vault deploy + swap smoke (plan P7.3).
contract CommonBufferMultiVault_N3 is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 3;
    }

    function test_deploy_N3_and_swap() public {
        assertEq(cbmv().vaultCount(), 3);
        assertEq(cbmv().tokenCount(), 4);
        dai.mint(alice, 20e18);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault2)), 20e18);
        assertGt(out, 0);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }
}

/// @notice T=8 smoke: U=5 N=2 with fifth unpaired as mintable ERC20.
contract CommonBufferMultiVault_T8 is TestBase_CommonBufferMultiVaultWeightedPool {
    ERC20TestToken internal extraUnpaired;

    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 5;
    }

    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function _deployBufferPool() internal virtual override {
        extraUnpaired = new ERC20TestToken("Extra", "EXT", 18);
        TestBase_CommonBufferMultiVaultWeightedPool._deployBufferPool();
        for (uint256 i = 0; i < users.length; ++i) {
            vm.startPrank(users[i]);
            extraUnpaired.approve(address(permit2), type(uint256).max);
            permit2.approve(address(extraUnpaired), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
    }

    function _unpairedTokenAt(uint8 i) internal view override returns (IERC20) {
        if (i == 0) return IERC20(address(usdc));
        if (i == 1) return IERC20(address(weth));
        if (i == 2) return IERC20(address(usdt));
        if (i == 3) return IERC20(address(wsteth));
        return IERC20(address(extraUnpaired));
    }

    function test_deploy_T8_U5_N2() public {
        assertEq(cbmv().tokenCount(), 8);
        assertEq(cbmv().unpairedCount(), 5);
        assertEq(cbmv().vaultCount(), 2);
        dai.mint(alice, 15e18);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 15e18);
        assertGt(out, 0);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }
}
