// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC721Facet} from '@crane/contracts/tokens/ERC721/ERC721Facet.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IComposedStableCommonDetfBondNFTVault} from 'contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol';
import {IDetf} from 'contracts/interfaces/detf/IDetf.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {TestBase_VaultComponents} from 'contracts/vaults/TestBase_VaultComponents.sol';
import {
    ComposedStableCommonDetf_Component_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol';
import {
    IComposedStableCommonDetfBondNFTVaultDFPkg
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol';
import {
    ComposedStableCommonDetfBondNFTVault_Facet_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol';
import {
    ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol';
import {
    IRebasingDETFTokenDFPkg
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol';
import {
    RebasingDETFToken_Facet_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Facet_FactoryService.sol';
import {
    RebasingDETFToken_Pkg_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Pkg_FactoryService.sol';

contract MockComposedStableCommonERC20 is IERC20 {
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

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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

abstract contract TestBase_ComposedStableCommonDetf is TestBase_VaultComponents {
    using ComposedStableCommonDetfBondNFTVault_Facet_FactoryService for ICreate3FactoryProxy;
    using ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService for IVaultRegistryDeployment;
    using RebasingDETFToken_Facet_FactoryService for ICreate3FactoryProxy;
    using RebasingDETFToken_Pkg_FactoryService for ICreate3FactoryProxy;

    MockComposedStableCommonERC20 internal lpToken;
    MockComposedStableCommonERC20 internal detfToken;
    MockComposedStableCommonERC20 internal rateAsset;

    IFacet internal erc721Facet;
    IFacet internal bondNFTVaultFacet;
    IFacet internal rebasingDetfTokenFacet;

    IComposedStableCommonDetfBondNFTVaultDFPkg internal bondNFTVaultPkg;
    IRebasingDETFTokenDFPkg internal rebasingDetfTokenPkg;

    IDETFNFTVault internal bondNFTVault;
    IRebasingClaimToken internal rebasingDetfToken;

    address internal detfOwner;
    IDetf internal detf;

    function _warpPastUnlock(uint256 tokenId_) internal {
        uint256 unlock_ = bondNFTVault.unlockTimeOf(tokenId_);
        if (block.timestamp <= unlock_) {
            vm.warp(unlock_ + 1);
        }
    }

    function setUp() public virtual override {
        super.setUp();

        detfOwner = makeAddr('detfOwner');
        detf = IDetf(makeAddr('detf'));

        lpToken = new MockComposedStableCommonERC20('Reserve BPT', 'rBPT', 18);
        detfToken = new MockComposedStableCommonERC20('DETF Token', 'DETF', 18);
        rateAsset = new MockComposedStableCommonERC20('Wrapped Ether', 'WETH', 18);

        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256('ComposedStableCommonDetf_TestBase_ERC721Facet')
            )
        );
        bondNFTVaultFacet = create3Factory.deployComposedStableCommonDetfBondNFTVaultFacet();
        rebasingDetfTokenFacet = create3Factory.deployRebasingDETFTokenFacet();

        vm.startPrank(owner);
        bondNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfBondNFTVaultDFPkg(
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

        rebasingDetfTokenPkg = create3Factory.deployRebasingDETFTokenDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildRebasingDetfTokenPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.RebasingDetfTokenFacets({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet,
                    multiStepOwnableFacet: multiStepOwnableFacet,
                    rebasingDetfTokenFacet: rebasingDetfTokenFacet
                }),
                diamondPackageFactory
            )
        );

        vm.startPrank(owner);
        bondNFTVault = IDETFNFTVault(
            bondNFTVaultPkg.deployVault(
                'Composed Stable Bond NFT Vault',
                'csBOND',
                detf,
                IERC20(address(lpToken)),
                IERC20(address(detfToken)),
                0,
                owner
            )
        );
        vm.stopPrank();

        assertEq(bondNFTVault.detfNFTId(), 0, 'protocol nft initialized first at deploy');
        assertEq(address(bondNFTVault.rewardToken()), address(detfToken), 'bond vault reward token initialized to detf');
        assertGt(IComposedStableCommonDetfBondNFTVault(address(bondNFTVault)).feeRecipientNFTId(), 0, 'fee recipient nft initialized at deploy');

        vm.startPrank(owner);
        rebasingDetfToken = IRebasingClaimToken(
            rebasingDetfTokenPkg.deployToken(
                IDETF(address(detf)), bondNFTVault, IERC20(address(rateAsset)), bondNFTVault.detfNFTId(), owner
            )
        );
        vm.stopPrank();
    }
}