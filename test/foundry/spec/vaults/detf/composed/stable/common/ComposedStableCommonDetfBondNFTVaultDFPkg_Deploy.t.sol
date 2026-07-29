// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    ComposedStableCommonDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol";
import {
    IComposedStableCommonDetfBondNFTVaultDFPkg
} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol";
import {
    ComposedStableCommonDetfBondNFTVault_Facet_FactoryService
} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol";
import {
    ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService
} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol";

contract MockBondVaultDeployERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ComposedStableCommonDetfBondNFTVaultDFPkg_Deploy_Test is TestBase_VaultComponents {
    using ComposedStableCommonDetfBondNFTVault_Facet_FactoryService for ICreate3FactoryProxy;
    using ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService for IVaultRegistryDeployment;

    IComposedStableCommonDetfBondNFTVaultDFPkg internal pkg;
    IFacet internal erc721Facet;
    IFacet internal bondNFTVaultFacet;

    function setUp() public override {
        super.setUp();

        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("ComposedStableCommonDetfBondNFTVault_ERC721Facet")
            )
        );
        bondNFTVaultFacet = create3Factory.deployComposedStableCommonDetfBondNFTVaultFacet();

        vm.startPrank(owner);
        pkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfBondNFTVaultDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildBondNFTVaultPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.BondNFTVaultFacets({
                    erc721Facet: erc721Facet,
                    erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                    erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                    bondNFTVaultFacet: bondNFTVaultFacet,
                    multiStepOwnableFacet: multiStepOwnableFacet
                }),
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfInfra({
                    vaultRegistryDeployment: indexedexManager
                })
            )
        );
        vm.stopPrank();
    }

    function test_deployVault_initializesBondVaultReferences() public {
        IERC20 lpToken = IERC20(address(new MockBondVaultDeployERC20("Reserve BPT", "rBPT", 18)));
        IERC20 detfToken = IERC20(address(new MockBondVaultDeployERC20("DETF Token", "DETF", 18)));
        IDetf detf = IDetf(makeAddr("detf"));

        vm.startPrank(owner);
        address vault = pkg.deployVault(
            "Composed Stable Bond NFT Vault",
            "csBOND",
            detf,
            lpToken,
            detfToken,
            9,
            owner
        );
        vm.stopPrank();

        assertEq(address(IDETFNFTVault(vault).lpToken()), address(lpToken), "lp token initialized");
        assertEq(address(IDETFNFTVault(vault).rewardToken()), address(detfToken), "reward token initialized to detf");
        assertEq(address(IDETFNFTVault(vault).detf()), address(detf), "protocol detf initialized");

        IComposedStableCommonDetfBondNFTVault bondVault = IComposedStableCommonDetfBondNFTVault(vault);
        uint256 protocolTokenId = bondVault.detfNFTId();
        uint256 feeRecipientTokenId = bondVault.feeRecipientNFTId();

        assertEq(IDETFNFTVault(vault).ownerOf(protocolTokenId), vault, "protocol nft owner");
        assertEq(
            IDETFNFTVault(vault).ownerOf(feeRecipientTokenId),
            address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()),
            "fee recipient nft owner"
        );
        assertGt(feeRecipientTokenId, protocolTokenId, "special nft mint order");
        assertEq(bondVault.deploymentTimestamp(), IDETFNFTVault(vault).unlockTimeOf(feeRecipientTokenId), "fee recipient unlock time");
    }

    function test_packageMetadata_matchesExpectedFacets() public view {
        (string memory name_, bytes4[] memory interfaces_, address[] memory facets_) = pkg.packageMetadata();

        assertEq(name_, "ComposedStableCommonDetfBondNFTVaultDFPkg", "package name");
        assertEq(interfaces_.length, 6, "interface count");
        assertEq(facets_.length, 5, "facet count");
        assertEq(facets_[0], address(erc721Facet), "erc721 facet");
        assertEq(facets_[1], address(erc4626BasicVaultFacet), "erc4626 basic facet");
        assertEq(facets_[2], address(erc4626StandardVaultFacet), "erc4626 standard facet");
        assertEq(facets_[3], address(bondNFTVaultFacet), "bond facet");
        assertEq(facets_[4], address(multiStepOwnableFacet), "ownable facet");
    }
}