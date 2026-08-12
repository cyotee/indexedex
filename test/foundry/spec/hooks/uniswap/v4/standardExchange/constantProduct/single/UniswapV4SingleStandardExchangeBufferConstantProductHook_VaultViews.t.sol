// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Vault/SE surface: shared facets + product reserve semantics.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_VaultViews_Test is TestBase {
    function setUp() public override {
        TestBase.setUp();
        _seedLiveLiquidity();
    }

    function test_BV1_vaultTokensPoolOrder() public view {
        address[] memory tokens = IBasicVault(hook).vaultTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], single.currency0());
        assertEq(tokens[1], single.currency1());
        assertTrue(tokens[0] < tokens[1]);
        uint256[] memory r = IBasicVault(hook).reserves();
        assertEq(r.length, 2);
        assertEq(r[0], single.reserveCurrency0());
        assertEq(r[1], single.reserveCurrency1());
    }

    function test_BV2_reserveOfPairIsVirtualClaim() public view {
        assertEq(IBasicVault(hook).reserveOfToken(address(pairToken)), single.seClaimSupply());
        assertEq(IBasicVault(hook).reserveOfToken(address(rawToken)), single.rawReserve());
        assertTrue(
            single.seClaimSupply() > pairToken.balanceOf(hook) || pairToken.balanceOf(hook) <= DUST
        );
    }

    function test_SV1_vaultTypesAndConfig() public view {
        bytes4[] memory types = IStandardVault(hook).vaultTypes();
        bool hasIn;
        bool hasOut;
        bool hasBasic;
        bool hasStd;
        for (uint256 i; i < types.length; ++i) {
            if (types[i] == type(IStandardExchangeIn).interfaceId) hasIn = true;
            if (types[i] == type(IStandardExchangeOut).interfaceId) hasOut = true;
            if (types[i] == type(IBasicVault).interfaceId) hasBasic = true;
            if (types[i] == type(IStandardVault).interfaceId) hasStd = true;
        }
        assertTrue(hasIn && hasOut && hasBasic && hasStd);
        IStandardVault.VaultConfig memory cfg = IStandardVault(hook).vaultConfig();
        assertEq(cfg.tokens.length, 2);
        assertEq(cfg.tokens[0], single.currency0());
    }

    function test_SV2_supportsInterface_erc165() public view {
        assertTrue(IERC165(hook).supportsInterface(type(IERC165).interfaceId));
    }

    function test_A1_currency0IsLowerAddress() public view {
        assertTrue(single.currency0() < single.currency1());
        assertTrue(
            (single.currency0() == address(rawToken) && single.currency1() == address(pairToken))
                || (single.currency0() == address(pairToken) && single.currency1() == address(rawToken))
        );
    }

    function test_I1_I2_poolInit_guards() public {
        PoolKey memory badFee = PoolKey({
            currency0: Currency.wrap(single.currency0()),
            currency1: Currency.wrap(single.currency1()),
            fee: 1,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        vm.expectRevert();
        pm.initialize(badFee, SQRT_PRICE_1_1);

        // already seeded live (initialized); second init reverts
        vm.expectRevert();
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }
}
