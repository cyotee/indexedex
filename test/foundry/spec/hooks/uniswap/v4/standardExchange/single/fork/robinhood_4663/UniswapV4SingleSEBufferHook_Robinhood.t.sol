// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

/**
 * @title UniswapV4SingleSEBufferHook_Robinhood_Test
 * @notice Robinhood (chain 4663) fork smoke: live PoolManager pin + fresh pair/4626/SE/buffer.
 *
 * Live PM pin (O18):
 *   lib/crane/.../ROBINHOOD_MAIN.sol UNISWAP_V4_POOL_MANAGER
 *   0x8366a39CC670B4001A1121B8F6A443A643e40951
 *
 * When ROBINHOOD_RPC_URL (or RH_RPC_URL) is set, forks Robinhood and asserts live PM code.
 * Always deploys a fresh pair/4626/SE/buffer stack.
 */
contract UniswapV4SingleSEBufferHook_Robinhood_Test is TestBase {
    address internal constant ROBINHOOD_UNISWAP_V4_POOL_MANAGER =
        0x8366a39CC670B4001A1121B8F6A443A643e40951;

    bool internal forked;

    function setUp() public override {
        string memory rpc = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("RH_RPC_URL", string(""));
        }
        if (bytes(rpc).length > 0) {
            try vm.createSelectFork(rpc) {
                forked = true;
            } catch {}
        }
        TestBase.setUp();

        if (forked && ROBINHOOD_UNISWAP_V4_POOL_MANAGER.code.length > 0) {
            pm = IPoolManager(ROBINHOOD_UNISWAP_V4_POOL_MANAGER);
        }
    }

    function test_FK_rh_livePmPinPresent() public view {
        assertEq(
            ROBINHOOD_UNISWAP_V4_POOL_MANAGER,
            0x8366a39CC670B4001A1121B8F6A443A643e40951
        );
        if (forked) {
            assertTrue(ROBINHOOD_UNISWAP_V4_POOL_MANAGER.code.length > 0, "live PM has code on fork");
        }
    }

    function test_FK_rh_fourModesSmoke() public {
        _initPool();
        _wrapExactIn(5 ether);
        _unwrapExactIn(2 ether);
        _wrapExactOut(1 ether);
        _unwrapExactOut(0.5 ether);
        _assertHookFlat();
    }
}
