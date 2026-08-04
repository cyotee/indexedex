// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as OrbitalFactoryService
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";
import {
    IUniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookFactory.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract UniswapV4OrbitalSwapHook_Factory_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_F1_hookHasRequiredFlags() public view {
        uint160 flags = uint160(hook) & Hooks.ALL_HOOK_MASK;
        assertEq(flags, factory.HOOK_FLAGS());
        assertEq(flags, OrbitalFactoryService.requiredFlags());
    }

    function test_F2_threePoolsInitialized() public view {
        assertTrue(address(poolKey01.hooks) == hook);
        assertTrue(address(poolKey12.hooks) == hook);
        assertTrue(address(poolKey02.hooks) == hook);
        assertEq(poolKey01.fee, poolKey12.fee);
        assertEq(poolKey12.fee, poolKey02.fee);
    }

    function test_F3_isDeployedByFactory() public view {
        assertTrue(factory.isDeployedByFactory(hook));
    }

    function test_F4_predictMatchesDeploy() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 b = new SimpleMintableERC20("B", "B");
        SimpleMintableERC20 c = new SimpleMintableERC20("C", "C");
        (bytes32 s2, address pred2) =
            OrbitalFactoryService.mineSalt(address(factory), address(this));
        assertEq(factory.predictHookAddress(s2, address(this)), pred2);
        (address h,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s2,
            0,
            0
        );
        assertEq(h, pred2);
    }

    function test_F5_idempotentSameCallerSalt() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("X", "X");
        SimpleMintableERC20 b = new SimpleMintableERC20("Y", "Y");
        SimpleMintableERC20 c = new SimpleMintableERC20("Z", "Z");
        (bytes32 s,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        (address h1,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s,
            0,
            0
        );
        (address h2,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s,
            0,
            0
        );
        assertEq(h1, h2);
    }

    function test_F6_differentCallersSameUserSaltDifferentHooks() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        (bytes32 shared,) = OrbitalFactoryService.mineSalt(address(factory), alice);
        address pAlice = factory.predictHookAddress(shared, alice);
        address pBob = factory.predictHookAddress(shared, bob);
        assertTrue(pAlice != pBob, "salt scoped to deployer");

        SimpleMintableERC20 a = new SimpleMintableERC20("P", "P");
        SimpleMintableERC20 b = new SimpleMintableERC20("Q", "Q");
        SimpleMintableERC20 c = new SimpleMintableERC20("R", "R");

        vm.prank(alice);
        (address hA,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            shared,
            0,
            0
        );
        assertEq(hA, pAlice);
        assertTrue(factory.predictHookAddress(shared, bob) != hA);

        (bytes32 bobSalt,) = OrbitalFactoryService.mineSalt(address(factory), bob);
        vm.prank(bob);
        (address hB,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            bobSalt,
            0,
            0
        );
        assertTrue(hA != hB);
    }

    function test_F7_hooksOfBinding_exactOrder() public view {
        address[] memory hooks = factory.hooksOfBinding(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(token0),
            address(token1),
            address(token2)
        );
        assertEq(hooks.length, 1);
        assertEq(hooks[0], hook);
        assertEq(
            factory.hooksOfBindingCount(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token0),
                address(token1),
                address(token2)
            ),
            1
        );
        assertEq(
            factory.hooksOfBindingAt(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token0),
                address(token1),
                address(token2),
                0
            ),
            hook
        );
    }

    function test_F8_invalidHookSaltReverts() public {
        bytes32 badSalt = bytes32(uint256(1));
        address pred = factory.predictHookAddress(badSalt, address(this));
        if (uint160(pred) & Hooks.ALL_HOOK_MASK == factory.HOOK_FLAGS()) {
            badSalt = bytes32(uint256(2));
            pred = factory.predictHookAddress(badSalt, address(this));
        }
        if (uint160(pred) & Hooks.ALL_HOOK_MASK != factory.HOOK_FLAGS()) {
            vm.expectRevert(IUniswapV4OrbitalSwapHookFactory.InvalidHookSalt.selector);
            factory.deploy(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token0),
                address(token1),
                address(token2),
                badSalt,
                0,
                0
            );
        }
    }

    /// @dev F9: code present at salt with wrong binding → SaltOccupied
    function test_F9_saltOccupied_wrongBinding() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("S0", "S0");
        SimpleMintableERC20 b = new SimpleMintableERC20("S1", "S1");
        SimpleMintableERC20 c = new SimpleMintableERC20("S2", "S2");
        SimpleMintableERC20 d = new SimpleMintableERC20("S3", "S3");

        (bytes32 s,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s,
            0,
            0
        );

        // Same salt + deployer, different binding → code present, isExpectedHook fails
        vm.expectRevert(IUniswapV4OrbitalSwapHookFactory.SaltOccupied.selector);
        factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(d),
            s,
            0,
            0
        );
    }

    /// @dev F11: second hook same binding under different salt
    function test_F11_secondHookSameBinding() public {
        (bytes32 s2,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        // Ensure different from setUp salt by mining until predicted != hook
        address pred = factory.predictHookAddress(s2, address(this));
        uint256 i;
        while (pred == hook || pred.code.length != 0) {
            s2 = bytes32(++i);
            pred = factory.predictHookAddress(s2, address(this));
            if (uint160(pred) & Hooks.ALL_HOOK_MASK != factory.HOOK_FLAGS()) continue;
            if (pred.code.length == 0 && pred != hook) break;
            require(i < 50_000, "mine");
        }

        (address h2,,,) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(token0),
            address(token1),
            address(token2),
            s2,
            0,
            0
        );
        assertTrue(h2 != hook);
        assertEq(
            factory.hooksOfBindingCount(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token0),
                address(token1),
                address(token2)
            ),
            2
        );
    }

    /// @dev F12: binding map key is exact deploy order, not sorted
    function test_F12_bindingOrderKey_permutationEmpty() public view {
        // Deployed as (token0, token1, token2) — permuted order is a different key
        assertEq(
            factory.hooksOfBindingCount(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token1),
                address(token0),
                address(token2)
            ),
            0
        );
        assertEq(
            factory.hooksOfBindingCount(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(token0),
                address(token1),
                address(token2)
            ),
            1
        );
    }

    /// @dev F14: AddressSet idempotent — double deploy same salt does not double-add
    function test_F14_addressSet_idempotentOnRedeploy() public {
        uint256 before = factory.hooksOfBindingCount(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(token0),
            address(token1),
            address(token2)
        );
        // Redeploy setUp salt path is already used; use F5-style redeploy on new binding
        SimpleMintableERC20 a = new SimpleMintableERC20("I0", "I0");
        SimpleMintableERC20 b = new SimpleMintableERC20("I1", "I1");
        SimpleMintableERC20 c = new SimpleMintableERC20("I2", "I2");
        (bytes32 s,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s,
            0,
            0
        );
        factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(a),
            address(b),
            address(c),
            s,
            0,
            0
        );
        assertEq(
            factory.hooksOfBindingCount(
                IVaultFeeOracleQuery(address(indexedexManager)),
                address(a),
                address(b),
                address(c)
            ),
            1
        );
        before; // silence
    }
}
