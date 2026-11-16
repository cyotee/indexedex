// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IUniswapV4ProtocolAware} from "@crane/contracts/interfaces/IUniswapV4ProtocolAware.sol";
import {IUniswapV4SinglePositionAware} from "@crane/contracts/interfaces/IUniswapV4SinglePositionAware.sol";
import {IERC8109Introspection} from "@crane/contracts/introspection/ERC8109/IERC8109Introspection.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {MissingReturnToken} from "@crane/contracts/external/solmate/test/utils/weird-tokens/MissingReturnToken.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {Bytecode} from "@crane/contracts/utils/Bytecode.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadPackage {
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function vaultTokens() external view returns (address[] memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function positionLiquidity() external view returns (uint128);
    function poolKey() external view returns (bytes32, address, address, uint24, int24, address);
}

contract UniswapV4FullSpreadStandardExchangeVault_Package_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    function test_bootstrapBundleDepositMintsShares() public {
        _fund(address(this), 1_000_000 ether, 1_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 1_000 ether;
        IFullSpreadPackage money_ = IFullSpreadPackage(address(vault));
        (uint256 shares_, uint256[] memory refunds_) = money_.exchangeBundleInForSingleOut(
            amounts_, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(shares_, 0);
        assertEq(money_.balanceOf(address(this)), shares_);
        assertGt(money_.totalSupply(), shares_, "floor or fee shares exist beside the depositor");
        assertEq(refunds_.length, 2);
        assertGt(money_.positionLiquidity(), 1000);
        address[] memory tokens_ = money_.vaultTokens();
        assertEq(tokens_.length, 2);
        assertEq(tokens_[0], address(token0));
        assertEq(tokens_[1], address(token1));
    }

    function test_permitDomainUsesPackageName() public {
        (bytes1 fields_, string memory name_, string memory version_, uint256 chainId_, address verifying_, bytes32 salt_, uint256[] memory extensions_) =
            IERC5267(address(vault)).eip712Domain();
        assertEq(fields_, hex"0f");
        assertEq(name_, string.concat("UniV4 Vault of (", token0.symbol(), " / ", token1.symbol(), " 0.3%)"));
        assertEq(IERC20Metadata(address(vault)).name(), name_);
        assertEq(IERC20Metadata(address(vault)).symbol(), "UV4X");
        assertEq(IERC20Metadata(address(vault)).decimals(), 18);
        assertEq(version_, "1");
        assertEq(chainId_, block.chainid);
        assertEq(verifying_, address(vault));
        assertEq(salt_, bytes32(0));
        assertEq(extensions_.length, 0);
        assertEq(
            IERC20Permit(address(vault)).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name_)), keccak256(bytes("1")), block.chainid, address(vault)
            ))
        );
    }

    /// @notice K03: a real EIP-2612 signature changes the proxy allowance and nonce.
    function test_permitAuthorizesSpenderAndConsumesNonce() public {
        uint256 signingKey_ = 0xA11CE;
        address signer_ = vm.addr(signingKey_);
        address spender_ = address(0xB0B);
        IERC20Permit permit_ = IERC20Permit(address(vault));
        uint256 nonce_ = permit_.nonces(signer_);
        uint256 deadline_ = block.timestamp + 1;
        bytes32 digest_ = keccak256(abi.encodePacked(
            hex"1901",
            permit_.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer_, spender_, uint256(123), nonce_, deadline_
            ))
        ));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(signingKey_, digest_);
        permit_.permit(signer_, spender_, 123, deadline_, v_, r_, s_);
        assertEq(IERC20(address(vault)).allowance(signer_, spender_), 123);
        assertEq(permit_.nonces(signer_), nonce_ + 1);
    }

    /// @notice K02: paired previews and the remaining SY entry points are not cut.
    /// @dev The withdrawn exchange-rate route is deliberately not tested.
    function test_pairedPreviewsAndRemainingSySelectorsAreAbsent() public view {
        bytes4[12] memory absent_ = [
            bytes4(keccak256("previewDepositPair(uint256,uint256)")),
            bytes4(keccak256("previewRedeemPair(uint256)")),
            bytes4(keccak256("deposit(address,address,uint256,uint256)")),
            bytes4(keccak256("redeem(address,uint256,address,uint256,bool)")),
            bytes4(keccak256("claimRewards(address)")),
            bytes4(keccak256("accruedRewards(address)")),
            bytes4(keccak256("rewardIndexesCurrent()")),
            bytes4(keccak256("rewardIndexesStored()")),
            bytes4(keccak256("getRewardTokens()")),
            bytes4(keccak256("isValidTokenIn(address)")),
            bytes4(keccak256("isValidTokenOut(address)")),
            bytes4(keccak256("assetInfo()"))
        ];
        for (uint256 i_; i_ < absent_.length; ++i_) {
            assertFalse(_cutHas(absent_[i_]));
            assertEq(IERC8109Introspection(address(vault)).facetAddress(absent_[i_]), address(0));
            assertFalse(_selectorOk(absent_[i_]));
        }
    }

    function test_getRateAndAssetAreAbsent() public {
        (bool rate_,) = address(vault).staticcall(abi.encodeWithSignature("getRate()"));
        (bool asset_,) = address(vault).staticcall(abi.encodeWithSignature("asset()"));
        assertFalse(rate_);
        assertFalse(asset_);
    }

    function test_directTransferDoesNotMintShares() public {
        _fund(address(this), 10 ether, 10 ether);
        uint256 supply_ = IFullSpreadPackage(address(vault)).totalSupply();
        token0.transfer(address(vault), 10 ether);
        token1.transfer(address(vault), 10 ether);
        assertEq(IFullSpreadPackage(address(vault)).totalSupply(), supply_);
        assertEq(IFullSpreadPackage(address(vault)).balanceOf(address(this)), 0);
    }

    /// @notice K03: assets present at the predicted address are not genesis issuance.
    function test_preExistingBalanceDoesNotMintSharesOnDeployment() public {
        PoolKey memory fresh_ = key;
        fresh_.fee = 500;
        pool.initialize(fresh_, uint160(1) << 96);
        address predicted_ = diamondFactory.calcAddress(
            IDiamondFactoryPackage(address(package)), abi.encode(IPackage.PkgArgs(fresh_))
        );
        assertEq(predicted_.code.length, 0);
        _fund(address(this), 10 ether, 10 ether);
        token0.transfer(predicted_, 10 ether);
        token1.transfer(predicted_, 10 ether);
        address deployed_ = package.deployVault(IPackage.PkgArgs(fresh_));
        assertEq(deployed_, predicted_);
        assertEq(IFullSpreadPackage(deployed_).totalSupply(), 0);
        assertEq(IFullSpreadPackage(deployed_).balanceOf(address(this)), 0);
        assertEq(IFullSpreadPackage(deployed_).balanceOf(address(0)), 0);
        assertEq(IFullSpreadPackage(deployed_).positionLiquidity(), 0);
        assertEq(token0.balanceOf(deployed_), 10 ether);
        assertEq(token1.balanceOf(deployed_), 10 ether);
    }

    /// @notice K03: the production package accepts an underlying with no bool returns.
    function test_noReturnApproveTokenCanDepositThroughPackage() public {
        MissingReturnToken missing_ = new MissingReturnToken();
        address first_ = address(missing_);
        address second_ = address(token1);
        if (first_ > second_) (first_, second_) = (second_, first_);
        PoolKey memory fresh_ = PoolKey(
            Currency.wrap(first_), Currency.wrap(second_), 3000, 60, IHooks(address(0))
        );
        pool.initialize(fresh_, uint160(1) << 96);
        address deployed_ = package.deployVault(IPackage.PkgArgs(fresh_));
        (bool approved_, bytes memory result_) =
            address(missing_).call(abi.encodeWithSelector(IERC20.approve.selector, deployed_, type(uint256).max));
        assertTrue(approved_);
        assertEq(result_.length, 0, "approve must actually omit its bool");
        token1.mint(address(this), 1_000 ether);
        token1.approve(deployed_, type(uint256).max);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 1_000 ether;
        (uint256 shares_,) = IFullSpreadPackage(deployed_).exchangeBundleInForSingleOut(
            amounts_, deployed_, 0, address(this), false, block.timestamp
        );
        assertGt(shares_, 0);
        assertEq(IFullSpreadPackage(deployed_).balanceOf(address(this)), shares_);
        assertGt(IFullSpreadPackage(deployed_).positionLiquidity(), 1_000);
    }

    /// @notice FS-A01: all package cuts resolve exactly once to their declared facet.
    function test_everyPackageSelectorIsInstalledOnItsDeclaredFacet() public view {
        IDiamond.FacetCut[] memory cuts_ = package.facetCuts();
        address[] memory addresses_ = package.facetAddresses();
        assertEq(cuts_.length, 12);
        assertEq(addresses_.length, cuts_.length);
        uint256 selectorCount_;
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            assertEq(cuts_[i_].facetAddress, addresses_[i_]);
            assertEq(uint256(cuts_[i_].action), uint256(IDiamond.FacetCutAction.Add));
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                ++selectorCount_;
                bytes4 selector_ = cuts_[i_].functionSelectors[j_];
                assertEq(IERC8109Introspection(address(vault)).facetAddress(selector_), addresses_[i_]);
                _assertOnce(selector_);
            }
        }
        assertEq(selectorCount_, 45);
        assertEq(
            IERC8109Introspection(address(vault)).facetAddress(IFullSpreadPackage.vaultTokens.selector),
            address(packageInit.basicVaultFacet)
        );
        assertEq(cuts_[3].functionSelectors.length, 1, "basic facet installs vaultTokens only");
        assertEq(cuts_[3].functionSelectors[0], IFullSpreadPackage.vaultTokens.selector);
        assertEq(
            IERC8109Introspection(address(vault)).facetAddress(bytes4(keccak256("reserves()"))),
            address(packageInit.queryFacet)
        );
        assertEq(
            IERC8109Introspection(address(vault)).facetAddress(bytes4(keccak256("reserveOfToken(address)"))),
            address(packageInit.queryFacet)
        );
    }

    /// @notice FS-A01: controls enumerate the public interfaces, not facetFuncs().
    function test_reviewedSelectorManifestIsComplete() public view {
        bytes4[45] memory selectors_ = [
            IERC20Metadata.name.selector,
            IERC20Metadata.symbol.selector,
            IERC20Metadata.decimals.selector,
            IERC20.totalSupply.selector,
            IERC20.balanceOf.selector,
            IERC20.allowance.selector,
            IERC20.approve.selector,
            IERC20.transfer.selector,
            IERC20.transferFrom.selector,
            IERC20Permit.permit.selector,
            IERC20Permit.nonces.selector,
            IERC20Permit.DOMAIN_SEPARATOR.selector,
            IERC5267.eip712Domain.selector,
            IFullSpreadPackage.vaultTokens.selector,
            bytes4(keccak256("vaultFeeTypeIds()")),
            bytes4(keccak256("contentsId()")),
            bytes4(keccak256("vaultTypes()")),
            bytes4(keccak256("vaultConfig()")),
            bytes4(keccak256("exchangeIn(address,uint256,address,uint256,address,bool,uint256)")),
            bytes4(keccak256("exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)")),
            bytes4(keccak256("exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)")),
            bytes4(keccak256("donate(address,uint256,bool)")),
            bytes4(keccak256("compound()")),
            bytes4(keccak256("setOperator(address,bool)")),
            bytes4(keccak256("setOperatorFor(bytes4,address,bool)")),
            bytes4(keccak256("previewExchangeIn(address,uint256,address)")),
            bytes4(keccak256("previewExchangeBundleInForSingleOut(uint256[],address)")),
            bytes4(keccak256("previewExchangeBundleOut(address,uint256,address[])")),
            IStandardExchangeOut.previewExchangeOut.selector,
            IStandardExchangeOut.exchangeOut.selector,
            bytes4(keccak256("reserveOfToken(address)")),
            bytes4(keccak256("reserves()")),
            bytes4(keccak256("unlockCallback(bytes)")),
            IUniswapV4ProtocolAware.poolManager.selector,
            IUniswapV4ProtocolAware.positionDescriptor.selector,
            IUniswapV4ProtocolAware.positionManager.selector,
            IUniswapV4ProtocolAware.quoter.selector,
            IUniswapV4ProtocolAware.stateView.selector,
            IUniswapV4ProtocolAware.reservesLens.selector,
            IUniswapV4ProtocolAware.universalRouter.selector,
            IUniswapV4SinglePositionAware.poolKey.selector,
            IUniswapV4SinglePositionAware.tickLower.selector,
            IUniswapV4SinglePositionAware.tickUpper.selector,
            IUniswapV4SinglePositionAware.positionSalt.selector,
            IUniswapV4SinglePositionAware.positionLiquidity.selector
        ];
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertTrue(_cutHas(selectors_[i_]));
            _assertOnce(selectors_[i_]);
        }
    }

    /// @notice FS-A01: package declarations agree with the configuration used by the factory.
    function test_packageMetadataConfigAndSaltMatchBindings() public view {
        (string memory name_, bytes4[] memory interfaces_, address[] memory facets_) = package.packageMetadata();
        assertEq(name_, "UniswapV4FullSpreadStandardExchangeVaultDFPkg");
        assertEq(name_, package.packageName());
        assertEq(abi.encode(interfaces_), abi.encode(package.facetInterfaces()));
        assertEq(abi.encode(facets_), abi.encode(package.facetAddresses()));
        IDiamondFactoryPackage.DiamondConfig memory config_ = package.diamondConfig();
        assertEq(abi.encode(config_.facetCuts), abi.encode(package.facetCuts()));
        assertEq(abi.encode(config_.interfaces), abi.encode(interfaces_));
        assertEq(
            package.calcSalt(abi.encode(IPackage.PkgArgs(key))),
            keccak256(abi.encode(package.bindingHash(), IPackage.PkgArgs(key)))
        );
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(address(vault)));
        assertEq(address(diamondFactory.pkgOfAccount(address(vault))), address(package));
        assertEq(diamondFactory.pkgArgsOfAccount(address(vault)), abi.encode(IPackage.PkgArgs(key)));
    }

    /// @notice Crane protocol and position state are initialized on the real proxy.
    function test_craneAwareGettersMatchPackageAndPositionBindings() public view {
        IUniswapV4ProtocolAware protocol_ = IUniswapV4ProtocolAware(address(vault));
        assertEq(address(protocol_.poolManager()), address(packageInit.poolManager));
        assertEq(protocol_.positionDescriptor(), packageInit.positionDescriptor);
        assertEq(protocol_.positionManager(), packageInit.positionManager);
        assertEq(protocol_.quoter(), packageInit.quoter);
        assertEq(protocol_.stateView(), packageInit.stateView);
        assertEq(protocol_.reservesLens(), packageInit.reservesLens);
        assertEq(protocol_.universalRouter(), packageInit.universalRouter);
        IUniswapV4SinglePositionAware position_ = IUniswapV4SinglePositionAware(address(vault));
        assertEq(abi.encode(position_.poolKey()), abi.encode(key));
        assertEq(position_.tickLower(), TickMath.minUsableTick(key.tickSpacing));
        assertEq(position_.tickUpper(), TickMath.maxUsableTick(key.tickSpacing));
        assertEq(position_.positionSalt(), bytes32(0));
        assertEq(position_.positionLiquidity(), 0);
    }

    /// @notice Crane declarations use interface-derived controls and Behavior_IFacet.
    function test_craneAwareFacetDeclarations() public {
        bytes4[] memory protocol_ = new bytes4[](7);
        protocol_[0] = IUniswapV4ProtocolAware.poolManager.selector;
        protocol_[1] = IUniswapV4ProtocolAware.positionDescriptor.selector;
        protocol_[2] = IUniswapV4ProtocolAware.positionManager.selector;
        protocol_[3] = IUniswapV4ProtocolAware.quoter.selector;
        protocol_[4] = IUniswapV4ProtocolAware.stateView.selector;
        protocol_[5] = IUniswapV4ProtocolAware.reservesLens.selector;
        protocol_[6] = IUniswapV4ProtocolAware.universalRouter.selector;
        _assertAwareFacet(
            packageInit.uniswapV4ProtocolAwareFacet, "UniswapV4ProtocolAwareFacet",
            type(IUniswapV4ProtocolAware).interfaceId, protocol_
        );
        bytes4[] memory position_ = new bytes4[](5);
        position_[0] = IUniswapV4SinglePositionAware.poolKey.selector;
        position_[1] = IUniswapV4SinglePositionAware.tickLower.selector;
        position_[2] = IUniswapV4SinglePositionAware.tickUpper.selector;
        position_[3] = IUniswapV4SinglePositionAware.positionSalt.selector;
        position_[4] = IUniswapV4SinglePositionAware.positionLiquidity.selector;
        _assertAwareFacet(
            packageInit.uniswapV4SinglePositionAwareFacet, "UniswapV4SinglePositionAwareFacet",
            type(IUniswapV4SinglePositionAware).interfaceId, position_
        );
    }

    /// @notice K03: package lifecycle entry points cannot be invoked after deployment.
    function test_noUnprivilegedPostDeployInitializationSurface() public {
        bytes memory args_ = abi.encode(IPackage.PkgArgs(key));
        bytes32 before_ = keccak256(abi.encode(
            IFullSpreadPackage(address(vault)).totalSupply(),
            IUniswapV4SinglePositionAware(address(vault)).poolKey(),
            IERC20Metadata(address(vault)).name()
        ));
        (bool initialized_,) = address(vault).call(abi.encodeWithSelector(package.initAccount.selector, args_));
        assertFalse(initialized_);
        (bool post_,) = address(vault).call(abi.encodeWithSignature("postDeploy()"));
        assertFalse(post_);
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        package.initAccount(args_);
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        package.postDeploy(address(vault));
        vm.expectRevert(IPackage.InvalidInitializationContext.selector);
        package.updatePkg(address(vault), args_);
        assertEq(keccak256(abi.encode(
            IFullSpreadPackage(address(vault)).totalSupply(),
            IUniswapV4SinglePositionAware(address(vault)).poolKey(),
            IERC20Metadata(address(vault)).name()
        )), before_);
    }

    function test_selectorCutAndCraneGetters() public {
        bytes4[8] memory absent_ = [
            bytes4(keccak256("getRate()")),
            bytes4(keccak256("rateAsset()")),
            bytes4(keccak256("asset()")),
            bytes4(keccak256("depositPair(uint256,uint256,uint256,address,uint256)")),
            bytes4(keccak256("redeemPair(uint256,uint256,uint256,address,uint256)")),
            bytes4(keccak256("previewZapCredit(address,uint256)")),
            bytes4(keccak256("previewWithdrawalMode(uint256,bool,address)")),
            bytes4(keccak256("localReserves()"))
        ];
        for (uint256 i_; i_ < absent_.length; ++i_) {
            assertFalse(_cutHas(absent_[i_]));
            assertFalse(_selectorOk(absent_[i_]));
        }
        assertFalse(_cutHas(bytes4(keccak256("basket()"))));
        assertFalse(_cutHas(bytes4(keccak256("wrappedNative()"))));
        assertFalse(_selectorOk(bytes4(keccak256("basket()"))));
        assertFalse(_selectorOk(bytes4(keccak256("wrappedNative()"))));
        bytes4[7] memory sy_ = [
            bytes4(keccak256("deposit(address,address,uint256,uint256,bool)")),
            bytes4(keccak256("redeem(address,uint256,address,uint256,bool)")),
            bytes4(keccak256("getTokensIn()")),
            bytes4(keccak256("getTokensOut()")),
            bytes4(keccak256("yieldToken()")),
            bytes4(keccak256("previewDeposit(address,uint256)")),
            bytes4(keccak256("previewRedeem(address,uint256)"))
        ];
        for (uint256 i_; i_ < sy_.length; ++i_) {
            assertFalse(_cutHas(sy_[i_]));
            assertFalse(_selectorOk(sy_[i_]));
        }
        assertFalse(_cutHas(bytes4(keccak256("supportsInterface(bytes4)"))));
        assertFalse(_cutHas(bytes4(keccak256("facets()"))));
        assertFalse(_cutHas(IERC8109Introspection.facetAddress.selector));
        assertFalse(_cutHas(IERC8109Introspection.functionFacetPairs.selector));
        assertFalse(_cutHas(bytes4(keccak256("postDeploy()"))));
        assertFalse(_staticOk("postDeploy()"));
        (bool erc165_,) = address(vault).staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x01ffc9a7)));
        assertTrue(erc165_, "factory ERC165 stays callable");
        (bool loupe_,) = address(vault).staticcall(abi.encodeWithSignature("facets()"));
        assertTrue(loupe_, "factory loupe stays callable");
        (bool facetAddr_,) = address(vault).staticcall(abi.encodeWithSignature("facetAddress(bytes4)", bytes4(keccak256("poolManager()"))));
        assertTrue(facetAddr_, "ERC-8109 facetAddress stays callable");
        (bool pairs_,) = address(vault).staticcall(abi.encodeWithSignature("functionFacetPairs()"));
        assertTrue(pairs_, "ERC-8109 functionFacetPairs stays callable");
        assertEq(
            IERC8109Introspection(address(vault)).facetAddress(IUniswapV4ProtocolAware.poolManager.selector),
            address(packageInit.uniswapV4ProtocolAwareFacet)
        );
        assertEq(
            IERC8109Introspection(address(vault)).facetAddress(IUniswapV4SinglePositionAware.poolKey.selector),
            address(packageInit.uniswapV4SinglePositionAwareFacet)
        );
        _assertOnce(IUniswapV4ProtocolAware.poolManager.selector);
        _assertOnce(IUniswapV4SinglePositionAware.poolKey.selector);
        assertGt(uint160(address(IUniswapV4ProtocolAware(address(vault)).poolManager())), 0);
        IUniswapV4SinglePositionAware(address(vault)).poolKey();
        IUniswapV4SinglePositionAware(address(vault)).positionLiquidity();
        IUniswapV4SinglePositionAware(address(vault)).tickLower();
        IUniswapV4SinglePositionAware(address(vault)).tickUpper();
        IUniswapV4SinglePositionAware(address(vault)).positionSalt();
        IFullSpreadPackage(address(vault)).vaultTokens();
        (bool reserve_,) = address(vault).staticcall(abi.encodeWithSignature("reserveOfToken(address)", address(token0)));
        assertTrue(reserve_);
        (bool reserves_,) = address(vault).staticcall(abi.encodeWithSignature("reserves()"));
        assertTrue(reserves_);
        (bool previewIn_,) = address(vault).staticcall(abi.encodeWithSignature("previewExchangeIn(address,uint256,address)", address(token0), 1, address(vault)));
        assertTrue(previewIn_);
        (bool previewBundle_,) = address(vault).staticcall(abi.encodeWithSignature("previewExchangeBundleInForSingleOut(uint256[],address)", new uint256[](2), address(vault)));
        assertTrue(previewBundle_);
        (bool previewOut_,) = address(vault).staticcall(abi.encodeWithSignature("previewExchangeBundleOut(address,uint256,address[])", address(vault), 1, new address[](2)));
        assertTrue(previewOut_);
        assertTrue(_cutHas(bytes4(keccak256("exchangeIn(address,uint256,address,uint256,address,bool,uint256)"))));
        assertTrue(_cutHas(bytes4(keccak256("donate(address,uint256,bool)"))));
        assertTrue(_cutHas(bytes4(keccak256("compound()"))));
        (bool factorySel_,) = address(packageInit.diamondFactory).staticcall(abi.encodeWithSignature("ERC165_FACET()"));
        (bool vaultSel_,) = address(vault).staticcall(abi.encodeWithSignature("ERC165_FACET()"));
        assertTrue(factorySel_, "factory selector lives on the factory");
        assertFalse(vaultSel_, "factory selector is not on the vault");
    }

    function test_bindingHashChangesWithAnyBinding() public {
        bytes32 hash_ = package.bindingHash();
        assertEq(hash_, keccak256(abi.encode(packageInit)));
        IPackage.PkgInit memory init_ = packageInit;
        init_.erc20Facet = _facet(init_.erc20Facet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.erc2612Facet = _facet(init_.erc2612Facet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.erc5267Facet = _facet(init_.erc5267Facet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.basicVaultFacet = _facet(init_.basicVaultFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.standardVaultFacet = _facet(init_.standardVaultFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.moneyFacet = _facet(init_.moneyFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.quoteFacet = _facet(init_.quoteFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.outFacet = _facet(init_.outFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.queryFacet = _facet(init_.queryFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.callbackFacet = _facet(init_.callbackFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.uniswapV4ProtocolAwareFacet = _facet(init_.uniswapV4ProtocolAwareFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.uniswapV4SinglePositionAwareFacet = _facet(init_.uniswapV4SinglePositionAwareFacet);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.poolManager = IPoolManager(address(this));
        _changed(hash_, init_);
        init_ = packageInit;
        init_.positionDescriptor = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.positionManager = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.quoter = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.stateView = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.reservesLens = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.universalRouter = address(this);
        _changed(hash_, init_);
        init_ = packageInit;
        init_.registry = IVaultRegistryDeployment(address(this));
        _changed(hash_, init_);
        init_ = packageInit;
        init_.oracle = IVaultFeeOracleQuery(address(this));
        _changed(hash_, init_);
        init_ = packageInit;
        init_.weth = IWETH(address(this));
        _changed(hash_, init_);
        init_ = packageInit;
        init_.diamondFactory = IDiamondPackageCallBackFactory(address(this));
        _changed(hash_, init_);
        for (uint256 i_; i_ < 6; ++i_) {
            init_ = packageInit;
            string[6] memory names_ = [
                "UniswapV4FullSpreadStandardExchangeVaultMath",
                "UniswapV4FullSpreadStandardExchangeVaultProjection",
                "UniswapV4FullSpreadStandardExchangeVaultSwapProjection",
                "UniswapV4FullSpreadStandardExchangeVaultPlanner",
                "UniswapV4FullSpreadStandardExchangeVaultExecution",
                "UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation"
            ];
            init_.linkedLibraries[i_] = create3Factory.create3(
                ArtifactCreationCode.creationCode(create3Factory, string.concat(names_[i_], ".sol:", names_[i_])),
                keccak256(abi.encode("FullSpread.Package.Binding.Library", i_))
            );
            // The five family facets declare all six links. Relink their actual
            // artifact references so the constructor sees a coherent binding set.
            init_.moneyFacet = _relinkedFacet(init_.moneyFacet, names_[i_], init_.linkedLibraries[i_]);
            init_.quoteFacet = _relinkedFacet(init_.quoteFacet, names_[i_], init_.linkedLibraries[i_]);
            init_.outFacet = _relinkedFacet(init_.outFacet, names_[i_], init_.linkedLibraries[i_]);
            init_.queryFacet = _relinkedFacet(init_.queryFacet, names_[i_], init_.linkedLibraries[i_]);
            init_.callbackFacet = _relinkedFacet(init_.callbackFacet, names_[i_], init_.linkedLibraries[i_]);
            _changed(hash_, init_);
        }
    }

    function test_invalidComponentRevertsBeforeDiamond() public {
        assertEq(address(0xBEEF).code.length, 0, "invalid infrastructure must be code-empty");
        IPackage.PkgInit memory init_ = packageInit;
        init_.positionDescriptor = address(0xBEEF);
        _expectComponent(init_);
        init_ = packageInit;
        init_.positionManager = address(0xBEEF);
        _expectComponent(init_);
        init_ = packageInit;
        init_.quoter = address(0xBEEF);
        _expectComponent(init_);
        init_ = packageInit;
        init_.stateView = address(0xBEEF);
        _expectComponent(init_);
        init_ = packageInit;
        init_.reservesLens = address(0xBEEF);
        _expectComponent(init_);
        init_ = packageInit;
        init_.universalRouter = address(0xBEEF);
        _expectComponent(init_);
    }

    /// @notice K01: every required infrastructure binding also rejects address zero.
    function test_missingComponentsRevertBeforeDiamond() public {
        IPackage.PkgInit memory init_ = packageInit;
        init_.positionDescriptor = address(0);
        _expectComponent(init_);
        init_ = packageInit;
        init_.positionManager = address(0);
        _expectComponent(init_);
        init_ = packageInit;
        init_.quoter = address(0);
        _expectComponent(init_);
        init_ = packageInit;
        init_.stateView = address(0);
        _expectComponent(init_);
        init_ = packageInit;
        init_.reservesLens = address(0);
        _expectComponent(init_);
        init_ = packageInit;
        init_.universalRouter = address(0);
        _expectComponent(init_);
    }

    /// @notice FS-A03: code at a library address does not waive the facet-link binding.
    function test_mismatchedLinkedComponentsRevertBeforeDiamond() public {
        for (uint256 i_; i_ < packageInit.linkedLibraries.length; ++i_) {
            IPackage.PkgInit memory init_ = packageInit;
            init_.linkedLibraries[i_] = address(this);
            _expectComponent(init_);
        }
    }

    /// @dev The repeated deploy is an idempotence check, not AlreadyInitialized coverage.
    function test_badPoolWrongCallerAndSecondInitRevert() public {
        PoolKey memory hooked_ = key;
        hooked_.hooks = IHooks(address(0xBEEF));
        _assertDeployReverts(IPackage.PkgArgs(hooked_), IPackage.InvalidPoolKey.selector);
        PoolKey memory fresh_ = key;
        fresh_.fee = 100;
        _assertDeployReverts(IPackage.PkgArgs(fresh_), IPackage.InvalidPoolKey.selector);
        vm.expectRevert(IPackage.NotCalledByRegistry.selector);
        package.processArgs(abi.encode(IPackage.PkgArgs(key)));
        vm.prank(address(indexedexManager));
        vm.expectRevert(IPackage.NotCalledByRegistry.selector);
        package.processArgs(abi.encode(IPackage.PkgArgs(key)));
        assertEq(package.deployVault(IPackage.PkgArgs(key)), address(vault));
        assertGt(address(vault).code.length, 0);
    }

    function _assertDeployReverts(IPackage.PkgArgs memory args_, bytes4 selector_) internal {
        address predicted_ = diamondFactory.calcAddress(IDiamondFactoryPackage(address(package)), abi.encode(args_));
        assertEq(predicted_.code.length, 0);
        bytes32 registered_ = keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults()));
        try package.deployVault(args_) returns (address) {
            assertTrue(false, "deploy returned a vault");
        } catch (bytes memory err_) {
            assertGe(err_.length, 4);
            assertEq(bytes4(err_), selector_);
        }
        assertEq(predicted_.code.length, 0, "reject left no usable diamond");
        assertEq(address(diamondFactory.pkgOfAccount(predicted_)), address(0));
        assertEq(keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults())), registered_);
    }

    function test_storageSlotIsNotPairTokenOrWings() public pure {
        bytes32 full_ = bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1);
        bytes32 pair_ = bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken"))) - 1);
        bytes32 wings_ = keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings");
        assertTrue(full_ != pair_);
        assertTrue(full_ != wings_);
        assertEq(full_, UniswapV4FullSpreadStandardExchangeVaultRepo.STORAGE_SLOT);
        assertEq(pair_, UniswapV4PairTokenStandardExchangeVaultRepo.DEFAULT_SLOT);
        assertEq(wings_, UniswapV4UpperLowerWingsStandardExchangeVaultRepo.STORAGE_SLOT);
    }

    /// @notice FS-A04: live money and book mutations in either instance leave the other instance intact.
    function test_liveInstancesKeepSupplyBooksAndConfigurationIsolated() public {
        PoolKey memory secondKey_ = key;
        secondKey_.fee = 500;
        secondKey_.tickSpacing = 10;
        pool.initialize(secondKey_, uint160(1) << 96);
        address second_ = package.deployVault(IPackage.PkgArgs(secondKey_));
        assertNotEq(second_, address(vault));
        _fund(address(this), 10_000 ether, 10_000 ether);
        _approve(address(vault));
        _approve(second_);
        bytes32 secondBefore_ = _instanceState(second_);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 1_000 ether;
        vault.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token0), 10 ether, address(token1), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token1), 10 ether, address(token0), 0, address(this), false, block.timestamp);
        vault.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(uint256(vm.load(address(vault), UniswapV4FullSpreadStandardExchangeVaultRepo.STORAGE_SLOT)), 0);
        assertGt(uint256(vm.load(
            address(vault), bytes32(uint256(UniswapV4FullSpreadStandardExchangeVaultRepo.STORAGE_SLOT) + 1)
        )), 0, "real accrued fees are booked");
        assertEq(_instanceState(second_), secondBefore_, "first instance cannot mutate second");
        bytes32 firstBefore_ = _instanceState(address(vault));
        IFullSpreadPackage(second_).exchangeBundleInForSingleOut(
            amounts_, second_, 0, address(this), false, block.timestamp
        );
        assertGt(IFullSpreadPackage(second_).totalSupply(), 0);
        assertEq(_instanceState(address(vault)), firstBefore_, "second instance cannot mutate first");
    }

    /// @dev Read the six family slots and externally exposed immutable/position/metadata bindings.
    function _instanceState(address instance_) internal view returns (bytes32) {
        bytes32[6] memory slots_;
        for (uint256 i_; i_ < slots_.length; ++i_) {
            slots_[i_] = vm.load(
                instance_, bytes32(uint256(UniswapV4FullSpreadStandardExchangeVaultRepo.STORAGE_SLOT) + i_)
            );
        }
        IUniswapV4SinglePositionAware position_ = IUniswapV4SinglePositionAware(instance_);
        return keccak256(abi.encode(
            IERC20(instance_).totalSupply(), IERC20(instance_).balanceOf(address(this)),
            IERC20(instance_).balanceOf(address(0)), token0.balanceOf(instance_), token1.balanceOf(instance_),
            position_.poolKey(), position_.tickLower(), position_.tickUpper(), position_.positionSalt(),
            position_.positionLiquidity(), IUniswapV4ProtocolAware(instance_).poolManager(),
            IERC20Metadata(instance_).name(), IERC20Metadata(instance_).symbol(), slots_
        ));
    }

    /// @dev Check declarations and every getter's routing without copying facet controls.
    function _assertAwareFacet(IFacet facet_, string memory name_, bytes4 interface_, bytes4[] memory selectors_) internal {
        bytes4[] memory interfaces_ = new bytes4[](1);
        interfaces_[0] = interface_;
        Behavior_IFacet.expect_IFacet(facet_, name_, interfaces_, selectors_);
        assertTrue(Behavior_IFacet.hasValid_IFacet_facetName(facet_));
        assertTrue(Behavior_IFacet.hasValid_IFacet_facetInterfaces(facet_));
        assertTrue(Behavior_IFacet.hasValid_IFacet_facetFuncs(facet_));
        assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(facet_));
        assertEq(facet_.facetInterfaces().length, 1);
        assertEq(facet_.facetFuncs().length, selectors_.length);
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            assertEq(IERC8109Introspection(address(vault)).facetAddress(selectors_[i_]), address(facet_));
            _assertOnce(selectors_[i_]);
        }
    }

    /// @dev A different real facet deployment, not a code-empty address mutation.
    function _facet(IFacet facet_) internal returns (IFacet) {
        string memory name_ = facet_.facetName();
        return IFacet(create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, string.concat(name_, ".sol:", name_)),
            keccak256(abi.encode("FullSpread.Package.Binding.Facet", name_))
        ));
    }

    /// @dev Exercise the actual constructor's hash through the production registry.
    function _changed(bytes32 hash_, IPackage.PkgInit memory init_) internal {
        bytes32 expected_ = keccak256(abi.encode(init_));
        assertTrue(expected_ != hash_);
        bytes memory code_ = ArtifactCreationCode.creationCode(
            "UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"
        );
        vm.prank(owner);
        IPackage changed_ = IPackage(indexedexManager.deployPkg(
            code_, abi.encode(init_), keccak256(abi.encode("FullSpread.Package.Binding", expected_))
        ));
        assertEq(changed_.bindingHash(), expected_);
        assertTrue(changed_.bindingHash() != package.bindingHash());
    }

    /// @dev Patch only compiler-reported link offsets in real production initcode.
    function _relinkedFacet(IFacet facet_, string memory library_, address replacement_) internal returns (IFacet) {
        string memory name_ = facet_.facetName();
        bytes memory code_ =
            ArtifactCreationCode.creationCode(create3Factory, string.concat(name_, ".sol:", name_));
        string memory json_ = vm.readFile(string.concat(vm.projectRoot(), "/out/", name_, ".sol/", name_, ".json"));
        string[] memory sources_ = vm.parseJsonKeys(json_, ".bytecode.linkReferences");
        bool found_;
        for (uint256 i_; i_ < sources_.length; ++i_) {
            string memory sourceKey_ = string.concat('.bytecode.linkReferences["', sources_[i_], '"]');
            string[] memory names_ = vm.parseJsonKeys(json_, sourceKey_);
            for (uint256 j_; j_ < names_.length; ++j_) {
                if (keccak256(bytes(names_[j_])) != keccak256(bytes(library_))) continue;
                ArtifactCreationCode.LinkReference[] memory refs_ = abi.decode(
                    vm.parseJson(json_, string.concat(sourceKey_, '["', library_, '"]')),
                    (ArtifactCreationCode.LinkReference[])
                );
                for (uint256 k_; k_ < refs_.length; ++k_) {
                    assertEq(refs_[k_].length, 20);
                    for (uint256 b_; b_ < 20; ++b_) {
                        code_[refs_[k_].start + b_] = bytes20(replacement_)[b_];
                    }
                }
                found_ = true;
            }
        }
        assertTrue(found_, "family facet must declare the changed library");
        return IFacet(create3Factory.create3(
            code_, keccak256(abi.encode("FullSpread.Package.RelinkedFacet", name_, library_, replacement_))
        ));
    }

    function _selectorOk(bytes4 selector_) internal view returns (bool ok_) {
        (ok_,) = address(vault).staticcall(abi.encodeWithSelector(selector_));
    }

    function _assertOnce(bytes4 selector_) internal view {
        IERC8109Introspection.FunctionFacetPair[] memory pairs_ =
            IERC8109Introspection(address(vault)).functionFacetPairs();
        uint256 count_;
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            if (pairs_[i_].selector == selector_) ++count_;
        }
        assertEq(count_, 1);
    }

    function _expectComponent(IPackage.PkgInit memory init_) internal {
        bytes32 registered_ = keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults()));
        // The production CREATE3 wrapper replaces constructor returndata with
        // ErrorCreatingContract. Keep the production deployment boundary here.
        bytes memory code_ = ArtifactCreationCode.creationCode(
            "UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"
        );
        bytes32 salt_ = keccak256(abi.encode("FullSpread.Package.InvalidComponent", init_));
        address packageAddress_ = Creation._create3AddressFromOf(address(create3Factory), salt_);
        assertEq(packageAddress_.code.length, 0);
        vm.prank(owner);
        vm.expectRevert(Bytecode.ErrorCreatingContract.selector);
        indexedexManager.deployPkg(code_, abi.encode(init_), salt_);
        assertEq(packageAddress_.code.length, 0, "registry reject left no package");
        assertEq(keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults())), registered_);
    }

    function _cutHas(bytes4 selector_) internal view returns (bool) {
        IDiamond.FacetCut[] memory cuts_ = package.facetCuts();
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                if (cuts_[i_].functionSelectors[j_] == selector_) return true;
            }
        }
        return false;
    }

    function _staticOk(string memory sig_) internal view returns (bool ok_) {
        (ok_,) = address(vault).staticcall(abi.encodeWithSignature(sig_));
    }
}
