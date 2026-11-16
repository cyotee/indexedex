// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {Behavior_UniswapV4PairTokenStandardExchangeVaultPackage as PackageBehavior} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/behaviors/Behavior_UniswapV4PairTokenStandardExchangeVaultPackage.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC2612} from "@crane/contracts/interfaces/IERC2612.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultProxySurfaceTest[]
/// @notice Typed Target -> declaration -> package -> live proxy closure and canonical token behavior.
/// @dev Engine smoke is deliberately not the full route/economic acceptance matrix.
contract UniswapV4PairTokenStandardExchangeVaultProxySurfaceTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct PermitSignature {
        address signer;
        address spender;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice S1-A06/A56: exact independent declarations and all twelve package lifecycle declarations.
    function test_PairToken_SUR_TargetFacetCutProxyMatrix() public {
        IFacet[] memory facets_ = PackageBehavior.components(pkgInit);
        uint256 total_;
        uint256 reused_;
        for (uint256 i_; i_ < facets_.length; ++i_) {
            bytes4[] memory funcs_ = PackageBehavior.selectors(i_);
            bytes4[] memory ids_ = PackageBehavior.interfaces(i_);
            assertEq(facets_[i_].facetFuncs().length, funcs_.length);
            assertEq(facets_[i_].facetInterfaces().length, ids_.length);
            assertTrue(Behavior_IFacet.areValid_IFacet_facetName(
                facets_[i_], PackageBehavior.facetName(i_), facets_[i_].facetName()
            ));
            assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facets_[i_], funcs_, facets_[i_].facetFuncs()));
            assertTrue(Behavior_IFacet.areValid_IFacet_facetInterfaces(facets_[i_], ids_, facets_[i_].facetInterfaces()));
            assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(facets_[i_]));
            assertTrue(PackageBehavior.sameSet(funcs_, facets_[i_].facetFuncs()), "duplicate facet selector");
            assertTrue(PackageBehavior.sameSet(ids_, facets_[i_].facetInterfaces()), "duplicate facet interface");
            assertTrue(PackageBehavior.sameSet(
                funcs_, IDiamondLoupe(address(vault)).facetFunctionSelectors(address(facets_[i_]))
            ), "live facet selector set");
            for (uint256 j_; j_ < funcs_.length; ++j_) {
                assertEq(IDiamondLoupe(address(vault)).facetAddress(funcs_[j_]), address(facets_[i_]));
            }
            if (i_ < 5) reused_ += funcs_.length;
            total_ += funcs_.length;
        }
        assertEq(reused_, 20);
        assertEq(total_, 60);
        assertTrue(PackageBehavior.hasValidDeclaration(pairTokenPackage, pkgInit));
    }

    /// @notice S1-A06/A57/A68: the final 66 selectors are exactly 60 product plus six persistent factory selectors.
    function test_PairToken_SUR_FactoryPersistentClosure() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        IERC8109Introspection.FunctionFacetPair[] memory pairs_ = IERC8109Introspection(address(vault)).functionFacetPairs();
        assertEq(pairs_.length, 66);
        address[] memory addresses_ = loupe_.facetAddresses();
        assertEq(addresses_.length, 15);
        IDiamondLoupe.Facet[] memory live_ = loupe_.facets();
        assertEq(live_.length, 15);
        uint256 count_;
        for (uint256 i_; i_ < live_.length; ++i_) {
            assertEq(loupe_.facetFunctionSelectors(live_[i_].facetAddress).length, live_[i_].functionSelectors.length);
            count_ += live_[i_].functionSelectors.length;
        }
        assertEq(count_, 66);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            assertEq(loupe_.facetAddress(pairs_[i_].selector), pairs_[i_].facet);
            assertTrue(_knownSelector(pairs_[i_].selector), "unexpected persistent selector");
            for (uint256 j_; j_ < i_; ++j_) assertNotEq(pairs_[j_].selector, pairs_[i_].selector);
        }
        assertEq(loupe_.facetAddress(IERC165.supportsInterface.selector), address(diamondPackageFactory.ERC165_FACET()));
        assertEq(loupe_.facetAddress(IDiamondLoupe.facets.selector), address(diamondPackageFactory.DIAMOND_LOUPE_FACET()));
        assertNotEq(loupe_.facetAddress(IERC8109Introspection.functionFacetPairs.selector), address(0));
        assertEq(loupe_.facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
        assertEq(loupe_.facetAddress(IDiamondFactoryPackage.initAccount.selector), address(0));
        assertEq(loupe_.facetAddress(IDiamondCut.diamondCut.selector), address(0));
        assertEq(loupe_.facetAddress(IMultiStepOwnable.owner.selector), address(0));
        assertEq(loupe_.facetAddress(IERC4626.asset.selector), address(0));
        // Full closure above also excludes rescue, excluded integrations and every undeclared selector.
        IERC165 erc165_ = IERC165(address(vault));
        assertTrue(erc165_.supportsInterface(type(IERC165).interfaceId));
        assertTrue(erc165_.supportsInterface(type(IDiamondLoupe).interfaceId));
        assertTrue(erc165_.supportsInterface(type(IERC8109Introspection).interfaceId));
        assertFalse(erc165_.supportsInterface(type(IERC4626).interfaceId));
        assertFalse(erc165_.supportsInterface(type(IDiamondCut).interfaceId));
        assertFalse(erc165_.supportsInterface(bytes4(0xffffffff)));
        bytes4[] memory packageIds_ = PackageBehavior.packageInterfaces();
        for (uint256 i_; i_ < packageIds_.length; ++i_) {
            assertTrue(erc165_.supportsInterface(packageIds_[i_]));
            assertNotEq(packageIds_[i_], type(IERC165).interfaceId);
            assertNotEq(packageIds_[i_], type(IDiamondLoupe).interfaceId);
            assertNotEq(packageIds_[i_], type(IERC8109Introspection).interfaceId);
            assertNotEq(packageIds_[i_], bytes4(0)); // No inheritance-only combined marker.
        }
    }

    /// @notice S1-A05/A57: metadata, proxy/chain domain, permit, replay and two-instance isolation.
    function test_PairToken_SUR_TokenDomainPermit() public {
        IERC20Metadata token_ = IERC20Metadata(address(vault));
        assertEq(token_.name(), "PairToken shares");
        assertEq(token_.symbol(), "PTSE");
        assertEq(token_.decimals(), 18);
        assertEq(token_.totalSupply(), 0);
        assertEq(token_.balanceOf(address(this)), 0);
        assertEq(token_.allowance(address(this), address(123)), 0);
        _assertDomain(address(vault), "PairToken shares");
        IVault other_ = _deployVault(_defaultArgs(key, address(token0), "same facets other instance"));
        _assertDomain(address(other_), "same facets other instance");
        assertNotEq(IERC20Permit(address(other_)).DOMAIN_SEPARATOR(), IERC20Permit(address(vault)).DOMAIN_SEPARATOR());
        PermitSignature memory permit_;
        permit_.signer = vm.addr(0x123456);
        permit_.spender = address(123);
        permit_.deadline = block.timestamp + 100;
        bytes32 structHash_ = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            permit_.signer, permit_.spender, uint256(77), uint256(0), permit_.deadline
        ));
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(address(vault)).DOMAIN_SEPARATOR(), structHash_));
        (permit_.v, permit_.r, permit_.s) = vm.sign(0x123456, digest_);
        assertEq(IERC20Permit(address(vault)).nonces(permit_.signer), 0);
        IERC20Permit(address(vault)).permit(
            permit_.signer, permit_.spender, 77, permit_.deadline, permit_.v, permit_.r, permit_.s
        );
        assertEq(IERC20Permit(address(vault)).nonces(permit_.signer), 1);
        assertEq(token_.allowance(permit_.signer, permit_.spender), 77);
        assertEq(IERC20Permit(address(other_)).nonces(permit_.signer), 0);
        assertEq(IERC20(address(other_)).allowance(permit_.signer, permit_.spender), 0);
        _expectBadPermit(address(other_), permit_, structHash_);
        bytes32 replayStruct_ = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            permit_.signer, permit_.spender, uint256(77), uint256(1), permit_.deadline
        ));
        _expectBadPermit(address(vault), permit_, replayStruct_);
        assertEq(IERC20Permit(address(vault)).nonces(permit_.signer), 1);
        assertEq(token_.allowance(permit_.signer, permit_.spender), 77);
        // The same typed signature is invalid after a chain-ID change; discovery follows that chain.
        vm.chainId(block.chainid + 1);
        _assertDomain(address(vault), "PairToken shares");
        _expectBadPermit(address(vault), permit_, replayStruct_);
    }

    /// @notice S1-A07/A69: shared discovery is initialized, ordered and separates local book from pool principal.
    function test_PairToken_SUR_BookAndDiscovery() public {
        assertEq(address(vault.poolManager()), address(pool));
        assertEq(abi.encode(vault.poolKey()), abi.encode(key));
        assertEq(vault.wrappedNative(), address(wrappedNative));
        assertEq(vault.rateAsset(), address(token0));
        assertEq(vault.tickLower(), TickMath.minUsableTick(key.tickSpacing));
        assertEq(vault.tickUpper(), TickMath.maxUsableTick(key.tickSpacing));
        assertEq(vault.maxZapBps(), 1000);
        assertEq(vault.maxZapTickMove(), 600);
        assertEq(vault.positionLiquidity(), 0);
        _assertBook(0, 0);
        address[] memory expected_ = new address[](2);
        expected_[0] = address(token0);
        expected_[1] = address(token1);
        assertEq(IBasicVault(address(vault)).vaultTokens(), expected_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(123)), 0);
        IStandardVault.VaultConfig memory config_ = IStandardVault(address(vault)).vaultConfig();
        assertEq(config_.tokens, expected_);
        assertEq(config_.vaultFeeTypeIds, bytes32(0));
        assertEq(config_.contentsId, keccak256(abi.encode(expected_)));
        assertEq(IStandardVault(address(vault)).contentsId(), config_.contentsId);
        assertTrue(PackageBehavior.sameSet(PackageBehavior.packageInterfaces(), config_.vaultTypes));
        assertTrue(PackageBehavior.sameSet(config_.vaultTypes, IStandardVault(address(vault)).vaultTypes()));
        assertEq(IStandardizedYield(address(vault)).exchangeRate(), 0);
        _bootstrap(1e18, 1e18, address(this));
        (uint256 principal0_, uint256 principal1_) = vault.basket();
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        _assertBook(book0_, book1_);
        assertGt(principal0_, book0_);
        assertGt(principal1_, book1_);
        // Unsolicited funds never enter the committed book.
        token0.mint(address(vault), 999);
        _assertBook(book0_, book1_);
    }

    /// @notice S1-A26: both Out methods reject unconditionally before funding or manager changes.
    function test_PairToken_SUR_ExactOutputUnavailable() public {
        _fund(address(this), 1e18, 1e18);
        _approveVault(address(vault));
        (uint160 price_, int24 tick_, uint24 protocolFee_, uint24 fee_) = pool.getSlot0(key.toId());
        for (uint256 i_; i_ < 4; ++i_) {
            IERC20 in_ = IERC20(i_ < 2 ? address(token0) : address(vault));
            IERC20 out_ = IERC20(i_ < 2 ? address(vault) : address(token1));
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            IStandardExchangeOut(address(vault)).previewExchangeOut(in_, out_, 1);
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            IStandardExchangeOut(address(vault)).exchangeOut(in_, 1e18, out_, 1, address(this), i_ % 2 == 1, block.timestamp);
        }
        (uint160 afterPrice_, int24 afterTick_, uint24 afterProtocolFee_, uint24 afterFee_) = pool.getSlot0(key.toId());
        assertEq(afterPrice_, price_);
        assertEq(afterTick_, tick_);
        assertEq(afterProtocolFee_, protocolFee_);
        assertEq(afterFee_, fee_);
        assertEq(pool.getLiquidity(key.toId()), 0);
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(token0.balanceOf(address(this)), 1e18);
        assertEq(token1.balanceOf(address(this)), 1e18);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        assertEq(token0.allowance(address(this), address(vault)), type(uint256).max);
        _assertBook(0, 0);
    }

    /// @notice S1-A06/A29/A31: successful public calls exercise installed money/quote/SY selectors.
    /// @dev This is a surface smoke, not full economic, native, callback-security or parity coverage.
    function test_PairToken_SUR_PublicEngineSurfaceSmoke() public {
        (uint256 genesis_, uint256 used0_, uint256 used1_) = vault.previewDepositPair(1e18, 1e18);
        assertEq(genesis_, 1e18);
        assertEq(used0_, 1e18);
        assertEq(used1_, 1e18);
        assertEq(_bootstrap(1e18, 1e18, address(this)), genesis_);
        assertEq(IERC20(address(vault)).totalSupply(), 1e18);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), 1e18);
        // Canonical transfer/allowance selectors operate on the public share supply.
        IERC20(address(vault)).approve(address(this), 9);
        IERC20(address(vault)).transfer(address(123), 7);
        IERC20(address(vault)).transferFrom(address(this), address(123), 9);
        assertEq(IERC20(address(vault)).balanceOf(address(123)), 16);
        assertEq(IERC20(address(vault)).allowance(address(this), address(this)), 0);
        _fund(address(this), 1e16, 1e16);
        vault.donate(address(token0), 1);
        (uint256 fees0_, uint256 fees1_) = vault.compound();
        assertEq(fees0_, 0);
        assertEq(fees1_, 0);
        _smokeQuotesAndEntry();
        _smokeSY();
        uint256 redeem_ = IERC20(address(vault)).balanceOf(address(this)) / 10;
        (uint256 expected0_, uint256 expected1_) = vault.previewRedeemPair(redeem_);
        (IVault.WithdrawalMode mode_, IVault.MaintenanceReason reason_) = vault.previewWithdrawalMode(redeem_, true, address(0));
        assertEq(uint256(mode_), uint256(IVault.WithdrawalMode.FullCompound));
        assertEq(uint256(reason_), uint256(IVault.MaintenanceReason.None));
        uint256 before0_ = token0.balanceOf(address(this));
        uint256 before1_ = token1.balanceOf(address(this));
        (uint256 paid0_, uint256 paid1_) = vault.redeemPair(redeem_, expected0_, expected1_, address(this), block.timestamp);
        assertEq(paid0_, expected0_);
        assertEq(paid1_, expected1_);
        assertEq(token0.balanceOf(address(this)) - before0_, paid0_);
        assertEq(token1.balanceOf(address(this)) - before1_, paid1_);
    }

    function _smokeQuotesAndEntry() private {
        (uint256 creditShares_,,,,) = vault.previewZapCredit(address(token0), 1e12);(uint256 expected_,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(token0)), 1e12, IERC20(address(vault)));
        assertEq(creditShares_, expected_);
        uint256 before_ = IERC20(address(vault)).balanceOf(address(this));(uint256 minted_,) = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(token0)), 1e12, IERC20(address(vault)), expected_, address(this), false, block.timestamp
        );
        assertEq(minted_, expected_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)) - before_, minted_);
    }

    function _smokeSY() private {
        IStandardizedYield sy_ = IStandardizedYield(address(vault));
        address[] memory tokens_ = IBasicVault(address(vault)).vaultTokens();
        assertEq(sy_.getTokensIn(), tokens_);
        assertEq(sy_.getTokensOut(), tokens_);
        assertEq(sy_.yieldToken(), address(vault));
        assertTrue(sy_.isValidTokenIn(address(token0)));
        assertTrue(sy_.isValidTokenOut(address(token1)));
        assertFalse(sy_.isValidTokenIn(address(0)));
        assertFalse(sy_.isValidTokenOut(address(123)));
        assertEq(sy_.previewDeposit(address(123), 1), 0);
        assertEq(sy_.previewRedeem(address(123), 1), 0);
        assertEq(sy_.getRewardTokens().length, 0);
        assertEq(sy_.accruedRewards(address(this)).length, 0);
        assertEq(sy_.rewardIndexesStored().length, 0);
        assertEq(sy_.rewardIndexesCurrent().length, 0);
        vm.expectEmit(true, false, false, true, address(vault));
        emit IStandardizedYield.ClaimRewards(address(this), new address[](0), new uint256[](0));
        assertEq(sy_.claimRewards(address(this)).length, 0);
        (IStandardizedYield.AssetType kind_, address asset_, uint8 decimals_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, address(token0));
        assertEq(decimals_, 18);
        assertGt(sy_.exchangeRate(), 0);
        uint256 expected_ = sy_.previewDeposit(address(token1), 1e12);
        uint256 beforeShares_ = IERC20(address(vault)).balanceOf(address(this));
        uint256 minted_ = sy_.deposit(address(this), address(token1), 1e12, expected_);
        assertEq(minted_, expected_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)) - beforeShares_, minted_);
        uint256 payout_ = sy_.previewRedeem(address(token0), minted_);
        uint256 beforeToken_ = token0.balanceOf(address(this));
        assertEq(sy_.redeem(address(this), minted_, address(token0), payout_, false), payout_);
        assertEq(token0.balanceOf(address(this)) - beforeToken_, payout_);
    }

    function _assertDomain(address instance_, string memory expectedName_) private view {
        (bytes1 fields_, string memory name_, string memory version_, uint256 chainId_, address verifying_, bytes32 salt_, uint256[] memory extensions_) =
            IERC5267(instance_).eip712Domain();
        assertEq(fields_, bytes1(0x0f));
        assertEq(name_, expectedName_);
        assertEq(version_, "1");
        assertEq(chainId_, block.chainid);
        assertEq(verifying_, instance_);
        assertEq(salt_, bytes32(0));
        assertEq(extensions_.length, 0);
        bytes32 expected_ = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(expectedName_)), keccak256("1"), block.chainid, instance_
        ));
        assertEq(IERC20Permit(instance_).DOMAIN_SEPARATOR(), expected_);
    }

    function _expectBadPermit(address instance_, PermitSignature memory permit_, bytes32 structHash_) private {
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(instance_).DOMAIN_SEPARATOR(), structHash_));
        address recovered_ = ecrecover(digest_, permit_.v, permit_.r, permit_.s);
        assertNotEq(recovered_, permit_.signer);
        vm.expectRevert(abi.encodeWithSelector(IERC2612.ERC2612InvalidSigner.selector, recovered_, permit_.signer));
        IERC20Permit(instance_).permit(
            permit_.signer, permit_.spender, 77, permit_.deadline, permit_.v, permit_.r, permit_.s
        );
    }

    function _assertBook(uint256 expected0_, uint256 expected1_) private view {
        uint256[] memory reserves_ = IBasicVault(address(vault)).reserves();
        assertEq(reserves_.length, 2);
        assertEq(reserves_[0], expected0_);
        assertEq(reserves_[1], expected1_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), expected0_);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), expected1_);
        (uint256 actual0_, uint256 actual1_) = vault.localReserves();
        assertEq(actual0_, expected0_);
        assertEq(actual1_, expected1_);
    }

    function _knownSelector(bytes4 selector_) private pure returns (bool) {
        if (
            selector_ == IERC165.supportsInterface.selector || selector_ == IDiamondLoupe.facets.selector
                || selector_ == IDiamondLoupe.facetFunctionSelectors.selector || selector_ == IDiamondLoupe.facetAddresses.selector
                || selector_ == IDiamondLoupe.facetAddress.selector || selector_ == IERC8109Introspection.functionFacetPairs.selector
        ) return true;
        for (uint256 i_; i_ < 12; ++i_) {
            bytes4[] memory controls_ = PackageBehavior.selectors(i_);
            for (uint256 j_; j_ < controls_.length; ++j_) if (selector_ == controls_[j_]) return true;
        }
        return false;
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultProxySurfaceTest[]
