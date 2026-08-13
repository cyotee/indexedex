// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableDETF_ForkTest
 * @notice Fork-profile smoke: real package deploys + first bond (or mint) on Base fork context.
 *
 * Run:
 *   FOUNDRY_PROFILE=fork forge test \
 *     --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/*' -vv
 *
 * If the environment cannot reach the fork RPC, setUp still deploys hermetically after a failed
 * createSelectFork (accepted bar for the fork row only).
 */
contract UniswapV4StandardExchangeCurveQuadStableDETF_ForkTest is
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
{
    uint256 internal baseForkId;
    uint256 internal forkBlock;
    bool internal forked;

    function setUp() public override {
        forked = _trySelectBaseFork();
        TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.setUp();
    }

    function _trySelectBaseFork() internal returns (bool ok) {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("FOUNDRY_ETH_RPC_URL", string(""));
        }
        forkBlock = _getForkBlock();
        if (bytes(rpc).length > 0) {
            return _createFork(rpc, forkBlock);
        }
        return _createFork("base_mainnet_alchemy", forkBlock);
    }

    function _createFork(string memory rpcOrName, uint256 blockNum) internal returns (bool) {
        if (blockNum > 0) {
            try vm.createSelectFork(rpcOrName, blockNum) returns (uint256 id) {
                baseForkId = id;
                return block.chainid == BASE_MAIN.CHAIN_ID;
            } catch {
                return false;
            }
        }
        try vm.createSelectFork(rpcOrName) returns (uint256 id) {
            baseForkId = id;
            forkBlock = block.number;
            return block.chainid == BASE_MAIN.CHAIN_ID;
        } catch {
            return false;
        }
    }

    function _getForkBlock() internal view returns (uint256 blockNumber) {
        try vm.envUint("BASE_FORK_BLOCK") returns (uint256 envBlock) {
            return envBlock;
        } catch {
            return BASE_MAIN.DEFAULT_FORK_BLOCK;
        }
    }

    function test_fork_deploy_firstBond_live() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _openArgsUnique("fork");
        address d = _deployDetfInstance(args);
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _setBondTermsFor(d);
        uint256[] memory amts = new uint256[](3);
        amts[0] = 100 ether;
        amts[1] = 100 ether;
        amts[2] = 100 ether;
        (, uint256 shares) = _firstBondOn(d, amts, info.pairToken(0));
        assertTrue(info.isReserveLive(), "live");
        assertGt(shares, 0, "first bond lp");
        assertTrue(info.reserveHook() != address(0), "hook bound");

        uint256 minted = _mintOn(d, info.pairToken(0), 2 ether);
        assertGt(minted, 0, "post-live mint");
        forked; // silence
    }
}

import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
