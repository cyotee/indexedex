// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {TokenStakingRepo} from "contracts/protocols/staking/token/TokenStakingRepo.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

contract TokenStakingDFPkg is ITokenStakingDFPkg {
    using BetterEfficientHashLib for bytes;

    uint256 internal constant DEFAULT_REWARDS_DURATION = 7 days;
    uint256 internal constant DEFAULT_OWNERSHIP_BUFFER = 2 days;

    IFacet immutable TOKEN_STAKING_FACET;
    IFacet immutable MULTI_STEP_OWNABLE_FACET;
    IRebasingAwareERC4626DFPkg immutable CLAIM_VAULT_PKG;
    IPermit2 immutable PERMIT2;

    constructor(PkgInit memory pkgInit) {
        if (address(pkgInit.permit2) == address(0)) {
            revert NoPermit2();
        }
        TOKEN_STAKING_FACET = pkgInit.tokenStakingFacet;
        MULTI_STEP_OWNABLE_FACET = pkgInit.multiStepOwnableFacet;
        CLAIM_VAULT_PKG = pkgInit.claimVaultPkg;
        PERMIT2 = pkgInit.permit2;
    }

    function deployStaking(IDiamondPackageCallBackFactory factory, PkgArgs memory pkgArgs)
        external
        returns (ITokenStaking staking)
    {
        return ITokenStaking(factory.deploy(this, abi.encode(pkgArgs)));
    }

    function packageName() public pure returns (string memory name_) {
        return type(TokenStakingDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](2);
        facetAddresses_[0] = address(TOKEN_STAKING_FACET);
        facetAddresses_[1] = address(MULTI_STEP_OWNABLE_FACET);
    }

    function facetInterfaces() public view returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(ITokenStaking).interfaceId;
        interfaces[1] = type(IMultiStepOwnable).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](2);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(TOKEN_STAKING_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: TOKEN_STAKING_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(MULTI_STEP_OWNABLE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public view returns (bytes32 salt) {
        return processArgs(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        PkgArgs memory decodedArgs = abi.decode(pkgArgs, (PkgArgs));
        if (address(decodedArgs.stakingToken) == address(0)) {
            revert NoStakingToken();
        }
        if (decodedArgs.owner == address(0)) {
            revert NoOwner();
        }
        if (decodedArgs.rewardsDuration == 0) {
            decodedArgs.rewardsDuration = DEFAULT_REWARDS_DURATION;
        }
        if (decodedArgs.ownershipBufferPeriod == 0) {
            decodedArgs.ownershipBufferPeriod = DEFAULT_OWNERSHIP_BUFFER;
        }
        return abi.encode(decodedArgs, address(CLAIM_VAULT_PKG));
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        (PkgArgs memory decodedArgs, address claimVaultPkg) = abi.decode(initArgs, (PkgArgs, address));
        TokenStakingRepo._initialize(
            decodedArgs.stakingToken, decodedArgs.rewardsDuration, IDiamondFactoryPackage(claimVaultPkg)
        );
        MultiStepOwnableRepo._initialize(decodedArgs.owner, decodedArgs.ownershipBufferPeriod);
        Permit2AwareRepo._initialize(PERMIT2);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
