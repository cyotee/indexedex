// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";

import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/**
 * @title UniswapV4SingleStandardExchangeDETF_ForkTest
 * @notice Phase 6.1: Base mainnet fork lifecycle smoke.
 * @dev Peer pattern (hook Base / DualLiquidity): `createSelectFork` then production DFPkg path
 *      (CREATE3 + manager registry + real hook package + SE wrapper) on that fork context.
 *
 * Run:
 *   FOUNDRY_PROFILE=uv4_single_se_cp_detf_fork forge test \
 *     --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/*' -vv
 *
 * RPC: `base_mainnet_alchemy` (ALCHEMY_KEY) or BASE_RPC_URL / FOUNDRY_ETH_RPC_URL.
 * Optional pin: BASE_FORK_BLOCK (default BASE_MAIN.DEFAULT_FORK_BLOCK).
 */
contract UniswapV4SingleStandardExchangeDETF_ForkTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    uint256 internal baseForkId;
    uint256 internal forkBlock;
    bool internal forked;

    function setUp() public override {
        forked = _trySelectBaseFork();
        TestBase_UniswapV4SingleStandardExchangeDETF.setUp();
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
        // Named endpoint from foundry.toml [rpc_endpoints]
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

    /// @notice inert deploy → first bond → live → closed-form primary mint (preview == exec).
    /// @dev Open mode so post-first-bond seigniorage dilution does not Policy-gate mint.
    function test_FK1_fork_lifecycle_inert_firstBond_mint() public {
        assertTrue(forked, "Base fork required (ALCHEMY_KEY / BASE_RPC_URL; plan Phase 6.1)");
        assertEq(block.chainid, BASE_MAIN.CHAIN_ID, "expected Base mainnet fork");

        address d = _deployDetfInstance(_openArgs());
        pairToken.mint(detfUser, 5_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        vm.stopPrank();

        detf = d;
        detfInfo = IUniswapV4SingleStandardExchangeDETF(d);
        detfExchangeIn = IStandardExchangeIn(d);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        assertFalse(detfInfo.isReserveLive(), "expected inert after deploy");

        (uint256 tokenId, uint256 shares) = _firstBond(200 ether);
        assertTrue(detfInfo.isReserveLive(), "first bond must go live");
        assertGt(tokenId, 0, "bond nft");
        assertGt(shares, 0, "lp principal");
        assertGt(detfInfo.userBondedLp(), 0, "user bonded lp");

        uint256 pairIn = 40 ether;
        uint256 preview =
            detfExchangeIn.previewExchangeIn(IERC20(address(pairToken)), pairIn, IERC20(d));
        assertGt(preview, 0, "preview mint");

        uint256 balBefore = IERC20(d).balanceOf(detfUser);
        uint256 userOut = _mintPair(pairIn);

        assertEq(userOut, preview, "preview==exec mint on fork");
        assertEq(IERC20(d).balanceOf(detfUser) - balBefore, userOut, "user free DETF");
        assertGt(detfInfo.protocolLp(), 0, "protocol LP after mint");
    }
}
