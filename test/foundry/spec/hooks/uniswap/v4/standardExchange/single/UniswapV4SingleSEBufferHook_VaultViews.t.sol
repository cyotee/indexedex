// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_VaultViews_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_vaultTokens_addressSorted() public view {
        address[] memory tokens = IBasicVault(hook).vaultTokens();
        assertEq(tokens.length, 2);
        assertTrue(tokens[0] < tokens[1], "address-sorted");
        assertTrue(
            (tokens[0] == address(pairToken) && tokens[1] == se)
                || (tokens[0] == se && tokens[1] == address(pairToken))
        );
    }

    function test_reserves_zero_beforeAndAfterSwap() public {
        address[] memory tokens = IBasicVault(hook).vaultTokens();
        assertEq(IBasicVault(hook).reserveOfToken(tokens[0]), 0);
        assertEq(IBasicVault(hook).reserveOfToken(tokens[1]), 0);

        _wrapExactIn(5 ether);

        assertEq(IBasicVault(hook).reserveOfToken(tokens[0]), 0, "reserves stay 0 after wrap");
        assertEq(IBasicVault(hook).reserveOfToken(tokens[1]), 0, "reserves stay 0 after wrap");
        uint256[] memory r = IBasicVault(hook).reserves();
        assertEq(r[0], 0);
        assertEq(r[1], 0);
    }

    function test_vaultConfig_O12() public view {
        IStandardVault.VaultConfig memory cfg = IStandardVault(hook).vaultConfig();
        bytes4 hookType = bytes4(keccak256("UniswapV4SingleStandardExchangeBufferHook"));
        assertEq(cfg.vaultFeeTypeIds, bytes32(hookType), "feeTypeIds O12");
        assertEq(
            cfg.contentsId,
            keccak256(
                abi.encode(keccak256("uv4-single-se-buffer-hook"), se, address(pairToken))
            ),
            "contentsId O12"
        );
        assertEq(cfg.tokens.length, 2);
        assertTrue(cfg.vaultTypes.length >= 4);
    }

    function test_vaultFeeTypeIds_contentsId_matchPkg() public view {
        assertEq(
            IStandardVault(hook).vaultFeeTypeIds(),
            UniswapV4SingleStandardExchangeBufferHookDFPkg(address(hookPkg)).vaultFeeTypeIds()
        );
        assertEq(
            IStandardVault(hook).contentsId(),
            keccak256(abi.encode(keccak256("uv4-single-se-buffer-hook"), se, address(pairToken)))
        );
    }
}
