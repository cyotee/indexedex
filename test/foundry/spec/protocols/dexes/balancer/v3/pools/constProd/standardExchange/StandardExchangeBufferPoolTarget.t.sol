// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PoolSwapParams, SwapKind, Rounding} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferPoolTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolTarget.sol";

contract StaticRateProvider is IRateProvider {
    uint256 immutable RATE;
    constructor(uint256 r) { RATE = r; }
    function getRate() external view returns (uint256) { return RATE; }
}

contract PoolUnderTest is StandardExchangeBufferPoolTarget {
    constructor(IRateProvider rp, IERC20 shareTok) {
        StandardExchangeBufferPoolRepo._initialize(
            IERC20(address(0x1)), shareTok, IStandardExchange(address(0x3)),
            rp, 0, 1, address(0xFAC)
        );
    }
    function setVirtualTTA(uint256 v) external { StandardExchangeBufferPoolRepo._setVirtualTTA(v); }
    function setHookSharesDelta(int256 v) external { StandardExchangeBufferPoolRepo._setHookSharesDelta(v); }
}

contract StandardExchangeBufferPoolTargetTest is Test {
    PoolUnderTest pool;
    address shareTokAddr = address(0xBBBB);

    function setUp() public {
        // Stub share token to return 18 decimals when the target reads them.
        vm.mockCall(shareTokAddr, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        pool = new PoolUnderTest(new StaticRateProvider(1e18), IERC20(shareTokAddr));
        pool.setVirtualTTA(100e18);
        pool.setHookSharesDelta(0);
    }

    function _buildSwapParams(SwapKind kind, uint256 idxIn, uint256 idxOut, uint256 amount, uint256[] memory bal)
        internal pure returns (PoolSwapParams memory)
    {
        return PoolSwapParams({
            kind: kind, amountGivenScaled18: amount, balancesScaled18: bal,
            indexIn: idxIn, indexOut: idxOut, router: address(0), userData: ""
        });
    }

    function test_onSwap_TTAin_EXACT_IN_basicCP() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
        // Y = 100 * 10 / (100 + 10) = 9.0909... e18
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    function test_onSwap_SharesIn_EXACT_IN_basicCP() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 1, 0, 10e18, bal));
        assertApproxEqAbs(out, 9.090909090909090909e18, 1e9);
    }

    function test_onSwap_hookSharesDeltaShiftsDerivedY() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setHookSharesDelta(int256(20e18));
        uint256 out = pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
        // Y = 80 * 10 / (100 + 10) = 7.2727...
        assertApproxEqAbs(out, 7.272727272727272727e18, 1e9);
    }

    function test_onSwap_revertsWhenSharesSideExhausted() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setHookSharesDelta(int256(120e18));
        vm.expectRevert(IStandardExchangeBufferPool.PoolSharesSideExhausted.selector);
        pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 0, 1, 10e18, bal));
    }

    function test_onSwap_revertsWhenTTASideExhausted() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        pool.setVirtualTTA(0);
        vm.expectRevert(IStandardExchangeBufferPool.PoolTTASideExhausted.selector);
        pool.onSwap(_buildSwapParams(SwapKind.EXACT_IN, 1, 0, 10e18, bal));
    }

    function test_computeInvariant_sqrtOfXY() public {
        uint256[] memory bal = new uint256[](2); bal[0] = 0; bal[1] = 100e18;
        uint256 inv = pool.computeInvariant(bal, Rounding.ROUND_DOWN);
        // sqrt(100e18 * 100e18) = 100e18
        assertApproxEqAbs(inv, 100e18, 1e9);
    }
}
