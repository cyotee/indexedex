// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {TokenStaking_Component_FactoryService} from
    "contracts/protocols/staking/token/TokenStaking_Component_FactoryService.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

abstract contract TestBase_TokenStaking is IndexedexTest {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using TokenStaking_Component_FactoryService for ICreate3FactoryProxy;

    IFacet tokenStakingFacet;
    IFacet rebasingAwareErc4626Facet;
    IFacet rebasingAwareSeFacet;
    IFacet rebasingAwareSyFacet;
    IFacet rebasingAwareMetadataFacet;
    IFacet rebasingAwareQuoteFacet;
    IFacet erc20Facet;
    IRebasingAwareERC4626DFPkg claimVaultPkg;
    ITokenStakingDFPkg tokenStakingPkg;
    ITokenStaking staking;
    ERC20PermitMintableStub stakeToken;
    IPermit2 permit2;

    address stakerA;
    address stakerB;

    function setUp() public virtual override {
        super.setUp();
        stakerA = makeAddr("stakerA");
        stakerB = makeAddr("stakerB");

        erc20Facet = create3Factory.deployERC20Facet();
        tokenStakingFacet = create3Factory.deployTokenStakingFacet();
        rebasingAwareErc4626Facet =
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626Facet(create3Factory);
        rebasingAwareSeFacet = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareStandardExchangeFacet(create3Factory);
        rebasingAwareSyFacet = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareStandardYieldFacet(create3Factory);
        rebasingAwareMetadataFacet = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareVaultMetadataFacet(create3Factory);
        rebasingAwareQuoteFacet = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareStandardExchangeQuoteFacet(create3Factory);
        permit2 = IPermit2(address(new BetterPermit2()));

        vm.prank(owner);
        claimVaultPkg = TokenStaking_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: rebasingAwareErc4626Facet,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: rebasingAwareSeFacet,
                standardYieldFacet: rebasingAwareSyFacet,
                vaultMetadataFacet: rebasingAwareMetadataFacet,
                transitionQuoteFacet: rebasingAwareQuoteFacet,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );

        tokenStakingPkg = TokenStaking_Component_FactoryService.deployTokenStakingDFPkg(
            create3Factory,
            ITokenStakingDFPkg.PkgInit({
                tokenStakingFacet: tokenStakingFacet,
                multiStepOwnableFacet: multiStepOwnableFacet,
                claimVaultPkg: claimVaultPkg,
                permit2: permit2
            })
        );

        stakeToken = new ERC20PermitMintableStub("Stake", "STK", 18, address(this), 0);
        stakeToken.mint(stakerA, 1_000e18);
        stakeToken.mint(stakerB, 1_000e18);
        stakeToken.mint(owner, 10_000e18);

        staking = tokenStakingPkg.deployStaking(
            diamondPackageFactory,
            ITokenStakingDFPkg.PkgArgs({
                stakingToken: IERC20(address(stakeToken)),
                rewardsDuration: 7 days,
                owner: owner,
                ownershipBufferPeriod: 2 days,
                optionalSalt: bytes32(0)
            })
        );
        vm.label(address(staking), "TokenStaking");
    }
}
