// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {IRebasingClaimTokenDFPkg, RebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";

contract RebasingClaimTokenDFPkg_Deploy_Test is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;

    IRebasingClaimTokenDFPkg internal pkg;
    ERC20PermitDFPkg internal erc20PermitPkg;

    function setUp() public override {
        super.setUp();

        IFacet rebasingClaimTokenFacet = create3Factory.deployRebasingClaimTokenFacet();

        IRebasingClaimTokenDFPkg.PkgInit memory pkgInit = IRebasingClaimTokenDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            rebasingClaimTokenFacet: rebasingClaimTokenFacet,
            diamondFactory: diamondPackageFactory
        });

        // NOTE: RebasingClaimTokenDFPkg is NOT an IStandardVaultPkg, so it must NOT be deployed via VaultRegistryDeployment.
        pkg = IRebasingClaimTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingClaimTokenDFPkg).creationCode, abi.encode(pkgInit), abi.encode(type(RebasingClaimTokenDFPkg).name)._hash()
                )
            )
        );

        erc20PermitPkg = _deployTestTokenPkg();

        assertGt(address(pkg).code.length, 0, "RebasingClaimTokenDFPkg not deployed");
    }

    function test_mintFromNFTSale_emptyVault_thenFewerSharesAfterProtocolBpt() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth4626")));
        address nft_ = address(0xCAFE);
        _stubNftViews(nft_, 1, 0);
        IRebasingClaimToken token = IRebasingClaimToken(
            pkg.deployToken(IDetf(address(0xBEEF)), IDETFNFTVault(nft_), IERC20(mockWeth), 1, owner)
        );

        address alice_ = makeAddr("alice4626");
        address bob_ = makeAddr("bob4626");

        vm.startPrank(owner);
        uint256 first_ = token.mintFromNFTSale(100e18, 0, alice_);
        uint256 second_ = token.mintFromNFTSale(100e18, 200e18, bob_);
        vm.stopPrank();

        assertGt(first_, 0, "empty-vault mint");
        assertLt(second_, first_, "second mint fewer shares per BPT after protocol BPT up");
        assertEq(token.sharesOf(alice_), 100e18, "empty vault sharesOut = assets");
        assertEq(token.sharesOf(bob_), 50e18, "4626 floor vs totalAssetsBefore=200");
    }

    function test_mintFromNFTSale_liveReadWrapper_emptyWhenProtocolZero() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth4626b")));
        address nft_ = address(0xCAFE);
        _stubNftViews(nft_, 2, 0);
        IRebasingClaimToken token = IRebasingClaimToken(
            pkg.deployToken(IDetf(address(0xBEEF)), IDETFNFTVault(nft_), IERC20(mockWeth), 2, owner)
        );
        vm.prank(owner);
        uint256 minted_ = token.mintFromNFTSale(10e18, 0, owner);
        assertEq(token.sharesOf(owner), 10e18, "explicit empty totalAssets");
        assertGt(minted_, 0, "rebasing units");
    }

    function _stubNftViews(address nft_, uint256 tokenId_, uint256 originalShares_) internal {
        IDETFNFTVault.Position memory position = IDETFNFTVault.Position({
            originalShares: originalShares_,
            effectiveShares: originalShares_,
            bonusMultiplier: 1e18,
            unlockTime: 0,
            rewardDebt: 0
        });
        vm.mockCall(nft_, abi.encodeWithSelector(IDETFNFTVault.getPosition.selector, tokenId_), abi.encode(position));
        vm.mockCall(
            nft_, abi.encodeWithSelector(IDETFNFTVault.originalSharesOf.selector, tokenId_), abi.encode(originalShares_)
        );
    }

    function test_deployToken_success() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth")));

        address tokenAddr = pkg.deployToken(
            IDetf(address(0xBEEF)), IDETFNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        assertGt(tokenAddr.code.length, 0, "RICHIR proxy not deployed");
        assertEq(IRebasingClaimToken(tokenAddr).detf(), address(0xBEEF), "detf mismatch");
    }

    function test_deployToken_returnsExisting_onDuplicateSalt() public {
        address mockWeth = address(_deployTestToken("Mock WETH", "mWETH", keccak256("RICHIR_MockWeth2")));

        address tokenAddr1 = pkg.deployToken(
            IDetf(address(0xBEEF)), IDETFNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        // Same detf => same optionalSalt => deterministic address collision.
        // The factory returns the existing deployment instead of reverting.
        address tokenAddr2 = pkg.deployToken(
            IDetf(address(0xBEEF)), IDETFNFTVault(address(0xCAFE)), IERC20(mockWeth), 1, owner
        );

        assertEq(tokenAddr2, tokenAddr1, "expected existing deployment");
        assertGt(tokenAddr2.code.length, 0, "RICHIR proxy not deployed");
    }

    function _deployTestTokenPkg() internal returns (ERC20PermitDFPkg pkg_) {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        pkg_ = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "RICHIRDeploy"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: 0,
            recipient: address(0),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }
}
