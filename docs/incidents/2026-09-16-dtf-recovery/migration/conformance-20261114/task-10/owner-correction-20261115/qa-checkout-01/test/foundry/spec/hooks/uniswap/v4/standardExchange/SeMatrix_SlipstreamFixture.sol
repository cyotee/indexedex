// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ISlipstreamStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/slipstream/ISlipstreamStandardExchangeDFPkg.sol";
import {
    Slipstream_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";
import {
    SlipstreamHermeticClBook
} from "contracts/protocols/dexes/aerodrome/slipstream/test/SlipstreamHermeticClBook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/// @dev Address-only CL factory so `PkgInit.slipstreamFactory` and `pool.factory()` match without
///      Aero voter wiring (the `TestBase_SlipstreamStandardExchange` pattern).
contract SeMatrix_SlipstreamClFactoryStub {}

/**
 * @title SeMatrix_SlipstreamFixture
 * @notice Slipstream SE row fixture (PRD §5, M6). Face token = pool token0, an 18-decimal
 *         `SimpleMintableERC20` created here (tokens are address-sorted so the face is token0);
 *         `otherToken()` = token1. The hermetic CL book is initialised at price 1, seeded with a
 *         wide position and token balances exactly as `TestBase_SlipstreamStandardExchange` does,
 *         then the SE is deployed through the production `SlipstreamStandardExchangeDFPkg` on the
 *         IndexedEx manager registry with the TestBase's `DEFAULT_WIDTH_MULTIPLIER`.
 * @dev Idempotence: the package binds `slipstreamFactory` as an immutable with no getter and is
 *      CREATE3-deployed under a release salt; `initAccount` rejects a pool whose `factory()` differs.
 *      A later fixture of the same test passes the previous fixture as `existingFixture` and reuses
 *      its `pkg()` and `clFactory()`; only the tokens, the book and the SE are new.
 * @dev R14 / D33: Slipstream has no protocol capacity gate, so `limitCapacity` only records intent
 *      and `hasPartialCase()` is false (rounding-to-zero control). The unpaired zap remainder is
 *      booked on the SE and read through `seBooked()` (`reserveOfToken(face)`); D33 separation is
 *      asserted by `test_row_ammCallerFundSeparation`.
 */
contract SeMatrix_SlipstreamFixture is SeMatrixFixture {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;

    uint24 public constant FEE_LOW = 500;
    int24 public constant TICK_SPACING = 1;
    uint24 public constant DEFAULT_WIDTH_MULTIPLIER = 10;
    int24 public constant SEED_TICK_LOWER = -10_000;
    int24 public constant SEED_TICK_UPPER = 10_000;
    uint128 public constant SEED_LIQUIDITY = 1e24;
    uint256 public constant SEED_BALANCE = 1e27;

    /// @dev The test contract that created this fixture; it owns `create3Factory` (CraneTest `initEnv`).
    address internal immutable deployer;

    ICLFactory public clFactory;
    ISlipstreamStandardExchangeDFPkg public sePkg;

    SimpleMintableERC20 public token0;
    SimpleMintableERC20 public token1;
    SlipstreamHermeticClBook public book;
    address internal seVault;

    /// @dev Recorded `limitCapacity` intent; AMMs cannot honour it (see contract NatSpec).
    uint256 public capacityIntent;
    bool public capacityLimited;

    constructor(Ctx memory c, address existingFixture) SeMatrixFixture(c) {
        deployer = msg.sender;
        if (existingFixture != address(0)) {
            SeMatrix_SlipstreamFixture prev = SeMatrix_SlipstreamFixture(existingFixture);
            clFactory = prev.clFactory();
            sePkg = prev.sePkg();
        } else {
            clFactory = ICLFactory(address(new SeMatrix_SlipstreamClFactoryStub()));
            sePkg = _deployPkg(c);
        }
        token0 = new SimpleMintableERC20("SeMatrix Slip 0", "smS0");
        token1 = new SimpleMintableERC20("SeMatrix Slip 1", "smS1");
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        book = new SlipstreamHermeticClBook(address(token0), address(token1), FEE_LOW, TICK_SPACING, address(clFactory));
        book.initialize(uint160(uint256(1) << 96));
        seedLiquidity();
        vm.prank(c.owner);
        seVault = sePkg.deployVault(ICLPool(address(book)), DEFAULT_WIDTH_MULTIPLIER);
        vm.label(seVault, "SeMatrix Slipstream SE");
    }

    /// @notice Package deployed by the first fixture of a test; later fixtures reuse it.
    function pkg() public view returns (address) {
        return address(sePkg);
    }

    /// @notice Seed the book with an independent wide position and token balances so the SE can quote.
    function seedLiquidity() public {
        book.addLiquidity(SEED_TICK_LOWER, SEED_TICK_UPPER, SEED_LIQUIDITY);
        token0.mint(address(book), SEED_BALANCE);
        token1.mint(address(book), SEED_BALANCE);
    }

    function _deployPkg(Ctx memory c) internal returns (ISlipstreamStandardExchangeDFPkg pkg_) {
        ISlipstreamStandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        // Facet deployment is owner/operator-gated on the create3 factory; the test contract owns it.
        vm.startPrank(deployer);
        init.slipstreamStandardExchangeInFacet = c.create3Factory.deploySlipstreamStandardExchangeInFacet();
        init.slipstreamStandardExchangeInFacetExt = c.create3Factory.deploySlipstreamStandardExchangeInFacetExt();
        init.slipstreamStandardExchangeOutFacet = c.create3Factory.deploySlipstreamStandardExchangeOutFacet();
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        init.slipstreamFactory = clFactory;
        // Package deployment goes through the manager registry as the registry operator.
        vm.startPrank(c.owner);
        pkg_ = Slipstream_Component_FactoryService.deploySlipstreamStandardExchangeDFPkg(c.indexedexManager, init);
        vm.stopPrank();
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "SlipstreamStandardExchange";
    }

    function faceToken() public view override returns (address) {
        return address(token0);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------ funding ------------------------------ */

    function fund(address to, uint256 amount) external override {
        token0.mint(to, amount);
    }

    /* -------------------------- R14 partial case -------------------------- */

    /// @inheritdoc SeMatrixFixture
    /// @dev False: a CL book has no capacity gate, so `limitCapacity` cannot be honoured and the row
    ///      runs the rounding-to-zero control. D33 leftover handling is asserted by the AMM row.
    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    /// @dev Records intent only; AMM capacity is not gated.
    function limitCapacity(uint256 allowFace) external override {
        capacityIntent = allowFace;
        capacityLimited = true;
    }

    function openCapacity() external override {
        capacityIntent = 0;
        capacityLimited = false;
    }

    /// @notice The SE's booked face leftover (unpaired zap remainder / exact-out quote leftover, D33).
    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(token0));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @dev Zap-in ends in `pool.mint(recipient, tickLower, tickUpper, liquidity, "")` on the book
    ///      (`SlipstreamStandardExchangeInTarget._mintLiquidity`); rejecting it makes the SE's
    ///      operative investment revert after every precheck and the swap leg.
    function armOperativeRevert() external override {
        vm.mockCallRevert(
            address(book),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,int24,int24,uint128,bytes)"))),
            rejectBytes()
        );
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* ------------------------------- AMM ---------------------------------- */

    function isAmm() external pure override returns (bool) {
        return true;
    }

    function otherToken() external view override returns (address) {
        return address(token1);
    }

    function fundOther(address to, uint256 amount) external override {
        token1.mint(to, amount);
    }
}
