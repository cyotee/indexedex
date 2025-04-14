// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {UNISWAPV2_FEE_PERCENT} from "@crane/contracts/constants/Constants.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {AerodromeUtils} from "@crane/contracts/utils/math/AerodromeUtils.sol";

import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {ProtocolDETFIntegrationBase} from "test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol";

contract EthereumProtocolDETFSyntheticPriceDebugTest is ProtocolDETFIntegrationBase {
    using BetterMath for uint256;

    struct SyntheticPriceDebugState {
        address chirWethPair;
        address richChirPair;
        uint256 chirWethLpTotalSupply;
        uint256 richChirLpTotalSupply;
        uint256 chirInWethPool;
        uint256 wethReserve;
        uint256 richReserve;
        uint256 chirInRichPool;
        uint256 chirTotalSupply;
        uint256 chirTotalInPools;
        uint256 chirSynthWc;
        uint256 chirSynthRc;
        uint256 syntheticWethValue;
        uint256 syntheticRichValue;
        uint256 chirWethVaultWeight;
        uint256 richChirVaultWeight;
    }

    function test_debugSyntheticPrice_afterDeployment() public {
        SyntheticPriceDebugState memory state = _loadDebugState();

        console.log("=== Ethereum Protocol DETF syntheticPrice debug ===");
        console.log("detf:", address(detf));
        console.log("chirWethVault:", address(chirWethVault));
        console.log("richChirVault:", address(richChirVault));
        console.log("chirWethPair:", state.chirWethPair);
        console.log("richChirPair:", state.richChirPair);

        emit log_named_uint("chirWethLpTotalSupply", state.chirWethLpTotalSupply);
        emit log_named_uint("richChirLpTotalSupply", state.richChirLpTotalSupply);
        emit log_named_uint("chirInWethPool", state.chirInWethPool);
        emit log_named_uint("wethReserve", state.wethReserve);
        emit log_named_uint("richReserve", state.richReserve);
        emit log_named_uint("chirInRichPool", state.chirInRichPool);
        emit log_named_uint("chirTotalSupply", state.chirTotalSupply);
        emit log_named_uint("chirTotalInPools", state.chirTotalInPools);
        emit log_named_uint("chirSynth_WC", state.chirSynthWc);
        emit log_named_uint("chirSynth_RC", state.chirSynthRc);
        emit log_named_uint("syntheticWethValue", state.syntheticWethValue);
        emit log_named_uint("syntheticRichValue", state.syntheticRichValue);
        emit log_named_uint("chirWethVaultWeight", state.chirWethVaultWeight);
        emit log_named_uint("richChirVaultWeight", state.richChirVaultWeight);

        try detf.syntheticPrice() returns (uint256 syntheticPrice_) {
            emit log_named_uint("syntheticPrice", syntheticPrice_);
            assertGt(syntheticPrice_, 0, "syntheticPrice returned zero");
        } catch (bytes memory reason) {
            bytes4 selector = _selector(reason);
            if (selector == IProtocolDETFErrors.PoolImbalanced.selector) {
                (uint256 syntheticWethValue_, uint256 syntheticRichValue_) = _decodePoolImbalanced(reason);
                emit log_named_uint("decodedSyntheticWethValue", syntheticWethValue_);
                emit log_named_uint("decodedSyntheticRichValue", syntheticRichValue_);
            }

            fail("syntheticPrice() reverted; inspect logs for reserve and synthetic quote state");
        }
    }

    function _loadDebugState() internal view returns (SyntheticPriceDebugState memory state) {
        uint256[] memory reservePoolWeights = reservePool.getNormalizedWeights();

        IUniswapV2Pair chirWethPair = IUniswapV2Pair(address(IERC4626(address(chirWethVault)).asset()));
        state.chirWethPair = address(chirWethPair);
        state.chirWethLpTotalSupply = IERC20(address(chirWethPair)).totalSupply();

        (uint256 reserve0, uint256 reserve1,) = chirWethPair.getReserves();
        if (chirWethPair.token0() == address(detf)) {
            state.chirInWethPool = reserve0;
            state.wethReserve = reserve1;
        } else {
            state.chirInWethPool = reserve1;
            state.wethReserve = reserve0;
        }

        IUniswapV2Pair richChirPair = IUniswapV2Pair(address(IERC4626(address(richChirVault)).asset()));
        state.richChirPair = address(richChirPair);
        state.richChirLpTotalSupply = IERC20(address(richChirPair)).totalSupply();

        (reserve0, reserve1,) = richChirPair.getReserves();
        if (richChirPair.token0() == address(rich)) {
            state.richReserve = reserve0;
            state.chirInRichPool = reserve1;
        } else {
            state.richReserve = reserve1;
            state.chirInRichPool = reserve0;
        }

        state.chirTotalSupply = IERC20(address(detf)).totalSupply();
        state.chirTotalInPools = state.chirInWethPool + state.chirInRichPool;
        state.chirWethVaultWeight = reservePoolWeights[chirWethVaultIndex];
        state.richChirVaultWeight = reservePoolWeights[richChirVaultIndex];

        if (state.chirTotalInPools == 0 || state.chirTotalSupply == 0) {
            return state;
        }

        state.chirSynthWc = BetterMath._mulDivDown(state.chirTotalSupply, state.chirInWethPool, state.chirTotalInPools);
        state.chirSynthRc = BetterMath._mulDivDown(state.chirTotalSupply, state.chirInRichPool, state.chirTotalInPools);

        state.syntheticWethValue = AerodromeUtils._quoteWithdrawSwapWithFee(
            state.chirWethLpTotalSupply,
            state.chirWethLpTotalSupply,
            state.wethReserve,
            state.chirSynthWc,
            UNISWAPV2_FEE_PERCENT
        );

        state.syntheticRichValue = AerodromeUtils._quoteWithdrawSwapWithFee(
            state.richChirLpTotalSupply,
            state.richChirLpTotalSupply,
            state.richReserve,
            state.chirSynthRc,
            UNISWAPV2_FEE_PERCENT
        );
    }

    function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
        if (reason.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(reason, 32))
        }
    }

    function _decodePoolImbalanced(bytes memory reason)
        internal
        pure
        returns (uint256 syntheticWethValue_, uint256 syntheticRichValue_)
    {
        if (reason.length < 68) {
            return (0, 0);
        }

        assembly {
            syntheticWethValue_ := mload(add(reason, 36))
            syntheticRichValue_ := mload(add(reason, 68))
        }
    }
}