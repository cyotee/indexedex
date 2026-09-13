// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DETFFundedBondMetadataFacet} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadataFacet.sol";
import {DETFSYDFPkg} from "contracts/vaults/detf/common/sy/DETFSYDFPkg.sol";
import {DETFSYFacet} from "contracts/vaults/detf/common/sy/DETFSYFacet.sol";
import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import {ERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";
import {ERC4626StandardExchangeDFPkg} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol";
import {ERC4626StandardExchangeInFacet} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol";
import {ERC4626StandardExchangeMarkerFacet} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeMarkerFacet.sol";
import {ERC4626StandardExchangeOutFacet} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutFacet.sol";
import {FeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {IndexedexManagerDFPkg} from "contracts/manager/IndexedexManagerDFPkg.sol";
import {RebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {RebasingClaimTokenFacet} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol";
import {UniswapV4DetfBondFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondFacet.sol";
import {UniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {UniswapV4DetfBondNFTVaultFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultFacet.sol";
import {UniswapV4DetfClaimFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfClaimFacet.sol";
import {UniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";
import {UniswapV4DetfExchangeFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeFacet.sol";
import {UniswapV4DetfMaintenanceFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfMaintenanceFacet.sol";
import {UniswapV4DetfQueryFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryFacet.sol";
import {UniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookFlagsFacet} from "contracts/hooks/uniswap/v4/factory/facets/UniswapV4HookFlagsFacet.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";

import {BalancerV3StandardExchangeRouterExactInQueryFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryFacet.sol";
import {BalancerV3StandardExchangeRouterExactInSwapFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapFacet.sol";
import {BalancerV3StandardExchangeRouterExactOutQueryFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryFacet.sol";
import {BalancerV3StandardExchangeRouterExactOutSwapFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapFacet.sol";
import {BalancerV3StandardExchangeBatchRouterExactInFacet} from "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInFacet.sol";
import {BalancerV3StandardExchangeBatchRouterExactOutFacet} from "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutFacet.sol";
import {BalancerV3StandardExchangeRouterPrepayFacet} from "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayFacet.sol";
import {BalancerV3StandardExchangeRouterPrepayHooksFacet} from "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksFacet.sol";
import {BalancerV3StandardExchangeRouterPermit2WitnessFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPermit2WitnessFacet.sol";
import {BalancerV3StandardExchangeRouterDFPkg} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {AerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

import {UniswapV4StandardExchangeWeightedBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";

/// @notice Standalone compile seed for factory-loaded funded-staking components.
/// @dev Build this source before focused tests; TestBases must not import or inherit it.
abstract contract DETFFundedStakingArtifacts {}

import {BalancerV3VaultAwareFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareFacet.sol";
import {BalancerV3PoolTokenFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BetterBalancerV3PoolTokenFacet.sol";
import {BalancerV3AuthenticationFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3AuthenticationFacet.sol";

import { ComposedStableCommonDetfDFPkg } from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol";
import { ComposedStableCommonDetfExchangeIn } from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol";
import { ComposedStableCommonDetfExchangeOutQueryFacet } from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol";
import { ComposedStableCommonDetfBondingFacet } from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondingFacet.sol";
import { RebasingDETFTokenPricingFacet } from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenPricingFacet.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet.sol";

import {BalancerV3ConstantProductPoolFacet} from "@crane/contracts/protocols/dexes/balancer/v3/pool-constProd/BalancerV3ConstantProductPoolFacet.sol";

import {BalancerV3ConstantProductPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

import {CommonBufferMultiVaultStablePoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolFacet.sol";

import {CommonBufferMultiVaultStablePoolHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookFacet.sol";

import {CommonBufferMultiVaultStablePoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolLiquidityFacet.sol";

import {CommonBufferMultiVaultStablePoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol";

import {CommonBufferMultiVaultWeightedPoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolFacet.sol";

import {CommonBufferMultiVaultWeightedPoolHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookFacet.sol";

import {CommonBufferMultiVaultWeightedPoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolLiquidityFacet.sol";

import {CommonBufferMultiVaultWeightedPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol";

import {MixedBufferMultiVaultStablePoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolFacet.sol";

import {MixedBufferMultiVaultStablePoolHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookFacet.sol";

import {MixedBufferMultiVaultStablePoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolLiquidityFacet.sol";

import {MixedBufferMultiVaultStablePoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";

import {MixedLegWeightedBufferPoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolFacet.sol";

import {MixedLegWeightedBufferPoolHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolHookFacet.sol";

import {MixedLegWeightedBufferPoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolLiquidityFacet.sol";

import {MixedLegWeightedBufferPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";

import {MultiPairStandardExchangeBufferPoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolFacet.sol";

import {MultiPairStandardExchangeBufferPoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolLiquidityFacet.sol";

import {MultiPairStandardExchangeBufferPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolStandardVaultPkg.sol";

import {MultiPairStandardExchangeHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeHookFacet.sol";

import {StandardExchangeBufferPoolFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolFacet.sol";

import {StandardExchangeBufferPoolLiquidityFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityFacet.sol";

import {StandardExchangeBufferPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";

import {StandardExchangeHookFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeHookFacet.sol";
