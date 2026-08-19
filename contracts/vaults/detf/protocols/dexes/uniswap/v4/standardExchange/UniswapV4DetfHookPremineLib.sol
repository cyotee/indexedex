// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    UniswapV4HookDiamondCreate2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/// @title UniswapV4DetfHookPremineLib
/// @notice Predict DETF address (dummy nonce 0), build hook PkgArgs, mine CREATE2 nonce.
/// @dev View only — callers pass the nonce into `I*DETDFPkg.deployVault(args, mineNonce)`.
library UniswapV4DetfHookPremineLib {
    uint160 private constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function premineCp(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4SingleStandardExchangeDETDFPkg detfPkg,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg,
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args,
        address poolManager,
        address feeOracle
    ) internal view returns (address predictedDetf, uint256 mineNonce) {
        predictedDetf = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                standardExchange: address(args.standardExchangeVault),
                pairToken: address(args.pairToken),
                rawToken: predictedDetf,
                ownerOnlyLiquidity: true,
                owner: predictedDetf
            });
        mineNonce = _mine(hookFactory, hookPkg, abi.encode(hArgs));
    }

    function premineOrbital(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4StandardExchangeOrbitalDETDFPkg detfPkg,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args,
        address poolManager,
        address feeOracle
    ) internal view returns (address predictedDetf, uint256 mineNonce) {
        predictedDetf = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        uint8 detfIdx = args.detfBindingIndex;
        (uint8 p0Idx, uint8 p1Idx) = _orbitalPairIdx(detfIdx);
        address[3] memory tokens;
        address[3] memory ses;
        address[3] memory rps;
        tokens[detfIdx] = predictedDetf;
        tokens[p0Idx] = address(args.pairToken0);
        tokens[p1Idx] = address(args.pairToken1);
        ses[p0Idx] = address(args.standardExchange0);
        ses[p1Idx] = address(args.standardExchange1);
        rps[p0Idx] = args.rateProvider0;
        rps[p1Idx] = args.rateProvider1;
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                token0: tokens[0],
                token1: tokens[1],
                token2: tokens[2],
                se0: ses[0],
                se1: ses[1],
                se2: ses[2],
                rp0: rps[0],
                rp1: rps[1],
                rp2: rps[2],
                tickSpacing: 60,
                sqrtPriceX96: SQRT_PRICE_1_1,
                ownerOnlyLiquidity: true,
                owner: predictedDetf
            });
        mineNonce = _mine(hookFactory, hookPkg, abi.encode(hArgs));
    }

    function premineWeighted(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4StandardExchangeWeightedDETDFPkg detfPkg,
        IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args,
        address poolManager,
        address feeOracle
    ) internal view returns (address predictedDetf, uint256 mineNonce) {
        predictedDetf = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        mineNonce = _mine(hookFactory, hookPkg, _weightedHookArgs(args, predictedDetf, poolManager, feeOracle));
    }

    function premineQuad(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg detfPkg,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args,
        address poolManager,
        address feeOracle
    ) internal view returns (address predictedDetf, uint256 mineNonce) {
        predictedDetf = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        mineNonce = _mine(hookFactory, hookPkg, _quadHookArgs(args, predictedDetf, poolManager, feeOracle));
    }

    function _weightedHookArgs(
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args,
        address predictedDetf,
        address poolManager,
        address feeOracle
    ) private pure returns (bytes memory) {
        uint8 m = uint8(args.pairTokens.length);
        uint8 n = m + 1;
        address[] memory sorted = new address[](n);
        sorted[0] = predictedDetf;
        for (uint8 i; i < m; ++i) {
            sorted[i + 1] = address(args.pairTokens[i]);
        }
        _sort(sorted);
        uint8 detfIdx;
        uint8[] memory pairIdx = new uint8[](m);
        for (uint8 b; b < n; ++b) {
            if (sorted[b] == predictedDetf) detfIdx = b;
        }
        for (uint8 i; i < m; ++i) {
            address p = address(args.pairTokens[i]);
            for (uint8 b; b < n; ++b) {
                if (sorted[b] == p) {
                    pairIdx[i] = b;
                    break;
                }
            }
        }
        address[] memory tokens = new address[](n);
        address[] memory ses = new address[](n);
        address[] memory rps = new address[](n);
        uint256[] memory weights = new uint256[](n);
        tokens[detfIdx] = predictedDetf;
        weights[detfIdx] = args.detfWeight;
        for (uint8 i; i < m; ++i) {
            uint8 b = pairIdx[i];
            tokens[b] = address(args.pairTokens[i]);
            ses[b] = address(args.standardExchanges[i]);
            rps[b] = args.rateProviders[i];
            weights[b] = args.pairWeights[i];
        }
        return abi.encode(
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                n: n,
                tokens: tokens,
                weights: weights,
                standardExchanges: ses,
                rateProviders: rps,
                ownerOnlyLiquidity: true,
                owner: predictedDetf
            })
        );
    }

    function _quadHookArgs(
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args,
        address predictedDetf,
        address poolManager,
        address feeOracle
    ) private pure returns (bytes memory) {
        uint8 m = 3;
        uint8 n = 4;
        address[] memory sorted = new address[](n);
        sorted[0] = predictedDetf;
        for (uint8 i; i < m; ++i) {
            sorted[i + 1] = address(args.pairTokens[i]);
        }
        _sort(sorted);
        uint8 detfIdx;
        uint8[3] memory pairIdx;
        for (uint8 b; b < n; ++b) {
            if (sorted[b] == predictedDetf) detfIdx = b;
        }
        for (uint8 i; i < m; ++i) {
            address p = address(args.pairTokens[i]);
            for (uint8 b; b < n; ++b) {
                if (sorted[b] == p) {
                    pairIdx[i] = b;
                    break;
                }
            }
        }
        address[4] memory tokens;
        address[4] memory ses;
        address[4] memory rps;
        tokens[detfIdx] = predictedDetf;
        for (uint8 i; i < m; ++i) {
            uint8 b = pairIdx[i];
            tokens[b] = address(args.pairTokens[i]);
            ses[b] = address(args.standardExchanges[i]);
            rps[b] = args.rateProviders[i];
        }
        return abi.encode(
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                tokens: tokens,
                standardExchanges: ses,
                rateProviders: rps,
                baseAmp: args.baseAmp,
                ownerOnlyLiquidity: true,
                owner: predictedDetf
            })
        );
    }

    function _mine(
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4HookDiamondPackage hookPkg,
        bytes memory hookArgs
    ) private view returns (uint256) {
        bytes32 packageSalt = hookPkg.calcSalt(hookArgs);
        return UniswapV4HookDiamondCreate2Lib.findMineNonce(
            address(hookFactory),
            hookFactory.PROXY_INIT_HASH(),
            packageSalt,
            hookPkg.requiredHookFlags(),
            UniswapV4HookDiamondCreate2Lib.MAX_LOOP
        );
    }

    function _orbitalPairIdx(uint8 detfIdx) private pure returns (uint8 p0, uint8 p1) {
        uint8[2] memory rem;
        uint256 k;
        for (uint8 i; i < 3; ++i) {
            if (i != detfIdx) rem[k++] = i;
        }
        return (rem[0], rem[1]);
    }

    function _sort(address[] memory a) private pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            address key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }
}
