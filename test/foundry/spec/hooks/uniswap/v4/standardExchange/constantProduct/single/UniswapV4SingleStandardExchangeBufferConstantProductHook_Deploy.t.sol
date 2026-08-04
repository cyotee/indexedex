// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy_Test
 * @notice Phase 0 + A: ERC-4626 SE preview==exec; Option B deploy/flags/registry.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy_Test is TestBase {
    function test_phase0_sePairPreviewEqualsExec() public {
        _assertSePreviewEqualsExec(100 ether);
    }

    function test_deploy_hookAddressHasRequiredFlags() public view {
        uint160 want = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        assertEq(uint160(hook) & Create2Lib.FLAG_MASK, want & Create2Lib.FLAG_MASK, "flags");
        assertEq(IUniswapV4HookFlags(hook).requiredHookFlags(), want & Create2Lib.FLAG_MASK, "flags view");
    }

    function test_deploy_bindingsAndCurrencyOrder() public view {
        assertEq(single.poolManager(), address(pm));
        assertEq(single.feeOracle(), address(indexedexManager));
        assertEq(single.standardExchange(), se);
        assertEq(single.pairToken(), address(pairToken));
        assertEq(single.rawToken(), address(rawToken));

        address c0 = single.currency0();
        address c1 = single.currency1();
        assertTrue(c0 < c1, "currency0 must be lower address");
        assertTrue(
            (c0 == address(rawToken) && c1 == address(pairToken))
                || (c0 == address(pairToken) && c1 == address(rawToken)),
            "currencies are raw/pair"
        );
    }

    function test_deploy_registeredAsVault() public view {
        assertTrue(
            IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook), "isVault"
        );
    }

    function test_deploy_initPoolAndProportionalDepositSmoke() public {
        _initPool();
        uint256 lp = _depositBoth(100 ether, 100 ether);
        assertGt(lp, 0, "lp minted");
        assertTrue(single.isLive(), "live after deposit");
        assertGt(single.rawReserve(), 0, "raw reserve");
        assertGt(single.seClaimSupply(), 0, "virtual pair reserve");
        // Free pair is not the book
        assertLe(pairToken.balanceOf(hook), DUST, "free pair dust only");
    }

    function test_D3_idempotentRedeploySameBinding() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address again = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(again, hook);
    }

    function test_D4_lpSymbolPrefixSSEBCP() public view {
        string memory sym = IERC20Metadata(hook).symbol();
        assertEq(bytes(sym)[0], bytes1("S"));
        assertEq(bytes(sym)[1], bytes1("S"));
        assertEq(bytes(sym)[2], bytes1("E"));
    }

    /// @notice LP = hook diamond: ERC20PermitDFPkg facets (ERC20 + 5267 + 2612) are live.
    function test_D5_lpHasErc20PermitSurfaces() public view {
        assertTrue(IERC20Permit(hook).DOMAIN_SEPARATOR() != bytes32(0), "DOMAIN_SEPARATOR");
        assertEq(IERC20Permit(hook).nonces(user), 0, "nonces start at 0");
        (
            bytes1 fields,
            string memory name_,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            ,
        ) = IERC5267(hook).eip712Domain();
        assertTrue(fields != 0, "eip712Domain fields");
        assertGt(bytes(name_).length, 0, "eip712 name");
        assertEq(version, "1", "eip712 version");
        assertEq(chainId, block.chainid, "eip712 chainId");
        assertEq(verifyingContract, hook, "eip712 verifyingContract is hook");
    }
}
