// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    UniswapV4HookDiamondCreate2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    UniswapV4DetfHookPremineLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

library UniswapV4SeDetfDeployMineNonceLib {
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function firstNonMatchingNonce(
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory,
        IUniswapV4HookDiamondPackage hookPkg,
        bytes32 packageSalt,
        uint256 good
    ) internal view returns (uint256 bad) {
        bad = good + 1;
        while (
            UniswapV4HookDiamondCreate2Lib.flagsMatch(
                UniswapV4HookDiamondCreate2Lib.predictAddress(
                    address(hookFactory), hookFactory.PROXY_INIT_HASH(), packageSalt, bad
                ),
                hookPkg.requiredHookFlags()
            )
        ) {
            unchecked {
                ++bad;
            }
        }
    }

    function cpHookSalt(
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage hookPkg,
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args,
        address predicted,
        address poolManager,
        address feeOracle
    ) internal view returns (bytes32) {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                standardExchange: address(args.standardExchangeVault),
                pairToken: address(args.pairToken),
                rawToken: predicted
            });
        return hookPkg.calcSalt(abi.encode(hArgs));
    }

    function orbitalHookSalt(
        IUniswapV4StandardExchangeOrbitalBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args,
        address predicted,
        address poolManager,
        address feeOracle
    ) internal view returns (bytes32) {
        uint8 detfIdx = args.detfBindingIndex;
        uint8[2] memory rem;
        uint256 k;
        for (uint8 i; i < 3; ++i) {
            if (i != detfIdx) rem[k++] = i;
        }
        address[3] memory tokens;
        address[3] memory ses;
        address[3] memory rps;
        tokens[detfIdx] = predicted;
        tokens[rem[0]] = address(args.pairToken0);
        tokens[rem[1]] = address(args.pairToken1);
        ses[rem[0]] = address(args.standardExchange0);
        ses[rem[1]] = address(args.standardExchange1);
        rps[rem[0]] = args.rateProvider0;
        rps[rem[1]] = args.rateProvider1;
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
                sqrtPriceX96: SQRT_PRICE_1_1
            });
        return hookPkg.calcSalt(abi.encode(hArgs));
    }

    function weightedHookSalt(
        IUniswapV4StandardExchangeWeightedBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args,
        address predicted,
        address poolManager,
        address feeOracle
    ) internal view returns (bytes32) {
        uint8 m = uint8(args.pairTokens.length);
        uint8 n = m + 1;
        address[] memory sorted = new address[](n);
        sorted[0] = predicted;
        for (uint8 i; i < m; ++i) {
            sorted[i + 1] = address(args.pairTokens[i]);
        }
        for (uint8 i = 1; i < n; ++i) {
            address key = sorted[i];
            uint8 j = i;
            while (j > 0 && sorted[j - 1] > key) {
                sorted[j] = sorted[j - 1];
                unchecked {
                    --j;
                }
            }
            sorted[j] = key;
        }
        uint8 detfIdx;
        uint8[] memory pairIdx = new uint8[](m);
        for (uint8 b; b < n; ++b) {
            if (sorted[b] == predicted) detfIdx = b;
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
        tokens[detfIdx] = predicted;
        weights[detfIdx] = args.detfWeight;
        for (uint8 i; i < m; ++i) {
            uint8 b = pairIdx[i];
            tokens[b] = address(args.pairTokens[i]);
            ses[b] = address(args.standardExchanges[i]);
            rps[b] = args.rateProviders[i];
            weights[b] = args.pairWeights[i];
        }
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                n: n,
                tokens: tokens,
                weights: weights,
                standardExchanges: ses,
                rateProviders: rps
            });
        return hookPkg.calcSalt(abi.encode(hArgs));
    }

    function quadHookSalt(
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage hookPkg,
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args,
        address predicted,
        address poolManager,
        address feeOracle
    ) internal view returns (bytes32) {
        uint8 m = 3;
        uint8 n = 4;
        address[] memory sorted = new address[](n);
        sorted[0] = predicted;
        for (uint8 i; i < m; ++i) {
            sorted[i + 1] = address(args.pairTokens[i]);
        }
        for (uint8 i = 1; i < n; ++i) {
            address key = sorted[i];
            uint8 j = i;
            while (j > 0 && sorted[j - 1] > key) {
                sorted[j] = sorted[j - 1];
                unchecked {
                    --j;
                }
            }
            sorted[j] = key;
        }
        uint8 detfIdx;
        uint8[3] memory pairIdx;
        for (uint8 b; b < n; ++b) {
            if (sorted[b] == predicted) detfIdx = b;
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
        tokens[detfIdx] = predicted;
        for (uint8 i; i < m; ++i) {
            uint8 b = pairIdx[i];
            tokens[b] = address(args.pairTokens[i]);
            ses[b] = address(args.standardExchanges[i]);
            rps[b] = args.rateProviders[i];
        }
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
                poolManager: poolManager,
                feeOracle: feeOracle,
                tokens: tokens,
                standardExchanges: ses,
                rateProviders: rps,
                baseAmp: args.baseAmp
            });
        return hookPkg.calcSalt(abi.encode(hArgs));
    }
}

/// @notice Unit A/B/C: DETF salt ignores nonce; bad nonce reverts; missing nonce reverts.
contract UniswapV4SeDetfDeployMineNonce_Cp is TestBase_UniswapV4SingleStandardExchangeDETF {
    function test_saltIgnoresNonce() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        address a0 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        address a1 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(1))
        );
        assertEq(a0, a1);
        address deployed = _deployDetfInstance(args);
        assertEq(deployed, a0);
    }

    function test_badNonceReverts() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CpBadNonce";
        args.symbol = "cpBN";
        (, uint256 good) = UniswapV4DetfHookPremineLib.premineCp(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        address predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        bytes32 packageSalt = UniswapV4SeDetfDeployMineNonceLib.cpHookSalt(
            hookPkg, args, predicted, address(pm), address(indexedexManager)
        );
        uint256 bad = UniswapV4SeDetfDeployMineNonceLib.firstNonMatchingNonce(
            hookFactory, hookPkg, packageSalt, good
        );
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, bad);
    }

    function test_missingNonceReverts() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CpMissingNonce";
        args.symbol = "cpMN";
        vm.prank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
    }
}

contract UniswapV4SeDetfDeployMineNonce_Orbital is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function test_saltIgnoresNonce() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        address a0 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        address a1 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(1))
        );
        assertEq(a0, a1);
        address deployed = _deployDetfInstance(args);
        assertEq(deployed, a0);
    }

    function test_badNonceReverts() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "OrbBadNonce";
        args.symbol = "orbBN";
        (, uint256 good) = UniswapV4DetfHookPremineLib.premineOrbital(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        address predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        bytes32 packageSalt = UniswapV4SeDetfDeployMineNonceLib.orbitalHookSalt(
            hookPkg, args, predicted, address(pm), address(indexedexManager)
        );
        uint256 bad = UniswapV4SeDetfDeployMineNonceLib.firstNonMatchingNonce(
            hookFactory, hookPkg, packageSalt, good
        );
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, bad);
    }

    function test_missingNonceReverts() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "OrbMissingNonce";
        args.symbol = "orbMN";
        vm.prank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
    }
}

contract UniswapV4SeDetfDeployMineNonce_Weighted is TestBase_UniswapV4StandardExchangeWeightedDETF {
    function test_saltIgnoresNonce() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        address a0 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        address a1 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(1))
        );
        assertEq(a0, a1);
        address deployed = _deployDetfInstance(args);
        assertEq(deployed, a0);
    }

    function test_badNonceReverts() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "WgtBadNonce";
        args.symbol = "wgtBN";
        (, uint256 good) = UniswapV4DetfHookPremineLib.premineWeighted(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        address predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        bytes32 packageSalt = UniswapV4SeDetfDeployMineNonceLib.weightedHookSalt(
            hookPkg, args, predicted, address(pm), address(indexedexManager)
        );
        uint256 bad = UniswapV4SeDetfDeployMineNonceLib.firstNonMatchingNonce(
            hookFactory, hookPkg, packageSalt, good
        );
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, bad);
    }

    function test_missingNonceReverts() public {
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "WgtMissingNonce";
        args.symbol = "wgtMN";
        vm.prank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
    }
}

contract UniswapV4SeDetfDeployMineNonce_Quad is TestBase_UniswapV4StandardExchangeCurveQuadStableDETF {
    function test_saltIgnoresNonce() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        address a0 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        address a1 = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(1))
        );
        assertEq(a0, a1);
        address deployed = _deployDetfInstance(args);
        assertEq(deployed, a0);
    }

    function test_badNonceReverts() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "QuadBadNonce";
        args.symbol = "qBN";
        (, uint256 good) = UniswapV4DetfHookPremineLib.premineQuad(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        address predicted = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(args, uint256(0))
        );
        bytes32 packageSalt = UniswapV4SeDetfDeployMineNonceLib.quadHookSalt(
            hookPkg, args, predicted, address(pm), address(indexedexManager)
        );
        uint256 bad = UniswapV4SeDetfDeployMineNonceLib.firstNonMatchingNonce(
            hookFactory, hookPkg, packageSalt, good
        );
        vm.prank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args, bad);
    }

    function test_missingNonceReverts() public {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.name = "QuadMissingNonce";
        args.symbol = "qMN";
        vm.prank(owner);
        vm.expectRevert();
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
    }
}
