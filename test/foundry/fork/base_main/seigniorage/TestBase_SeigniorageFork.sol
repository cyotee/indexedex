// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ERC20} from "@crane/contracts/tokens/ERC20/ERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter as IBalancerRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {
    TokenConfig,
    TokenType,
    PoolRoleAccounts
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ISeigniorageNFTVaultDFPkg,
    SeigniorageNFTVaultDFPkg
} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";
import {
    Seigniorage_Component_FactoryService
} from "contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                             Mock Contracts                                 */
/* -------------------------------------------------------------------------- */

/**
 * @title MockERC20MintBurn
 * @notice Simple ERC20 with mint/burn capabilities for testing.
 */
contract ForkMockERC20MintBurn is ERC20, IERC20MintBurn {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external override returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external override returns (bool) {
        _burn(account, amount);
        return true;
    }
}

/**
 * @title MockSeigniorageNFTVaultDFPkg
 * @notice Mock package that bypasses vault registry caller check for testing.
 */
contract ForkMockSeigniorageNFTVaultDFPkg is SeigniorageNFTVaultDFPkg {
    constructor(PkgInit memory pkgInit) SeigniorageNFTVaultDFPkg(pkgInit) {}

    function processArgs(bytes memory pkgArgs) public pure override returns (bytes memory) {
        return pkgArgs;
    }
}

/**
 * @title MockSeigniorageDETF
 * @notice Minimal mock for ISeigniorageDETF for testing.
 */
contract ForkMockSeigniorageDETF is ISeigniorageDETF {
    IERC20 public override seigniorageToken;
    ISeigniorageNFTVault public override seigniorageNFTVault;
    IERC20 public override reserveVaultRateTarget;
    address public override reservePool;
    IERC20 public lpToken;

    mapping(address => uint256) public claimedAmounts;
    uint256 public lpTokenReserve;

    constructor(IERC20 rateTarget_, IERC20 lpToken_) {
        reserveVaultRateTarget = rateTarget_;
        lpToken = lpToken_;
        lpTokenReserve = 0;
    }

    function setNFTVault(ISeigniorageNFTVault vault) external {
        seigniorageNFTVault = vault;
    }

    function setLpTokenReserve(uint256 reserve) external {
        lpTokenReserve = reserve;
    }

    function underwrite(IERC20, uint256, uint256, address, bool) external pure returns (uint256) {
        return 0;
    }

    function previewClaimLiquidity(uint256 lpAmount) external pure returns (uint256 liquidityOut) {
        return lpAmount;
    }

    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity) {
        claimedAmounts[recipient] += lpAmount;
        extractedLiquidity = lpAmount;
    }

    function withdrawRewards(uint256, address) external pure returns (uint256 rewards) {
        return 0;
    }

    function reserveOfToken(address token_) external view returns (uint256 reserve) {
        if (token_ == address(lpToken)) {
            return lpTokenReserve;
        }
        return 0;
    }
}

    /**
     * @title TestBase_SeigniorageFork
     * @notice Base test contract for Seigniorage fork tests on Base mainnet.
     * @dev Creates an 80/20 weighted pool on mainnet Balancer V3 and sets up
     *      the full Seigniorage NFT Vault infrastructure for testing.
     *
     *      Key validations:
     *      - NFT vault operations work with mainnet Balancer pool
     *      - Bonus multiplier calculations
     *      - Lock/unlock mechanics
     *      - Reward distribution
     */
    contract TestBase_SeigniorageFork is TestBase_BaseFork, IndexedexTest {
        using Seigniorage_Component_FactoryService for ICreate3FactoryProxy;

        /* ---------------------------------------------------------------------- */
        /*                              Constants                                 */
        /* ---------------------------------------------------------------------- */

        uint256 internal constant INITIAL_MINT = 1_000_000e18;
        uint256 internal constant LOCK_AMOUNT = 1000e18;
        uint256 internal constant POOL_INIT_AMOUNT = 100_000e18;

        uint256 internal constant MIN_LOCK_DURATION = 7 days;
        uint256 internal constant MAX_LOCK_DURATION = 365 days;
        uint256 internal constant BASE_BONUS_MULTIPLIER = ONE_WAD; // 1x
        uint256 internal constant MAX_BONUS_MULTIPLIER = 4 * ONE_WAD; // 4x

        /* ---------------------------------------------------------------------- */
        /*                         Mainnet Contracts                              */
        /* ---------------------------------------------------------------------- */

        IVault internal balancerVault;
        IBalancerRouter internal balancerRouter;
        WeightedPoolFactory internal weightedPoolFactory;
        IPermit2 internal permit2;

        /* ---------------------------------------------------------------------- */
        /*                             Test Users                                 */
        /* ---------------------------------------------------------------------- */

        address internal alice;
        address internal bob;
        address internal charlie;
        address internal nftVaultOwner;

        /* ---------------------------------------------------------------------- */
        /*                            Test Tokens                                 */
        /* ---------------------------------------------------------------------- */

        ERC20PermitMintableStub internal seigniorageToken;
        ForkMockERC20MintBurn internal rewardToken;
        ForkMockERC20MintBurn internal lpToken; // Simulates BPT from Balancer pool

        /* ---------------------------------------------------------------------- */
        /*                          Mock DETF                                     */
        /* ---------------------------------------------------------------------- */

        ForkMockSeigniorageDETF internal mockSeigniorageDETF;

        /* ---------------------------------------------------------------------- */
        /*                        Vault Components                                */
        /* ---------------------------------------------------------------------- */

        IFacet internal erc20Facet;
        IFacet internal erc2612Facet;
        IFacet internal erc5267Facet;
        IFacet internal erc4626Facet;
        IFacet internal erc4626BasicVaultFacet;
        IFacet internal erc4626StandardVaultFacet;
        IFacet internal erc721Facet;
        IFacet internal seigniorageNFTVaultFacet;
        ISeigniorageNFTVaultDFPkg internal nftVaultDFPkg;
        ISeigniorageNFTVault internal nftVault;

        /* ---------------------------------------------------------------------- */
        /*                               8020 Pool                                */
        /* ---------------------------------------------------------------------- */

        address internal weighted8020Pool;

        /* ---------------------------------------------------------------------- */
        /*                                Setup                                   */
        /* ---------------------------------------------------------------------- */

        function setUp() public virtual override(TestBase_BaseFork, IndexedexTest) {
            // Initialize Base fork first
            TestBase_BaseFork.setUp();

            // Initialize IndexedEx infrastructure
            IndexedexTest.setUp();

            // Setup test users
            _setupUsers();

            // Bind to mainnet contracts
            _bindMainnetContracts();

            // Create test tokens
            _deployMockTokens();

            // Create 80/20 weighted pool on mainnet
            _create8020Pool();

            // Setup mock DETF
            _setupMockDETF();

            // Deploy vault components
            _deployVaultFacets();
            _deployVaultPackage();
            _deployNFTVault();

            // Distribute tokens to users
            _distributeTokens();
        }

        /* ---------------------------------------------------------------------- */
        /*                            User Setup                                  */
        /* ---------------------------------------------------------------------- */

        function _setupUsers() internal virtual {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
            charlie = makeAddr("charlie");
            nftVaultOwner = makeAddr("nftVaultOwner");
        }

        /* ---------------------------------------------------------------------- */
        /*                      Mainnet Contract Binding                          */
        /* ---------------------------------------------------------------------- */

        function _bindMainnetContracts() internal virtual {
            balancerVault = IVault(BASE_MAIN.BALANCER_V3_VAULT);
            balancerRouter = IBalancerRouter(BASE_MAIN.BALANCER_V3_ROUTER);
            weightedPoolFactory = WeightedPoolFactory(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY);
            // Canonical Permit2 address (same on all EVM chains)
            permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

            _assertHasCode(address(balancerVault), "Balancer V3 Vault");
            _assertHasCode(address(balancerRouter), "Balancer V3 Router");
            _assertHasCode(address(weightedPoolFactory), "Balancer V3 Weighted Pool Factory");
            _assertHasCode(address(permit2), "Permit2");
        }

        /* ---------------------------------------------------------------------- */
        /*                         Token Deployment                               */
        /* ---------------------------------------------------------------------- */

        function _deployMockTokens() internal virtual {
            seigniorageToken = new ERC20PermitMintableStub("Fork Seigniorage Token", "fSEIG", 18, address(this), 0);
            vm.label(address(seigniorageToken), "ForkSeigniorageToken");

            rewardToken = new ForkMockERC20MintBurn("Fork Reward Token", "fRWD", 18);
            vm.label(address(rewardToken), "ForkRewardToken");

            // LP token simulates the BPT from the 80/20 pool
            lpToken = new ForkMockERC20MintBurn("Fork LP Token", "fBPT", 18);
            vm.label(address(lpToken), "ForkLPToken");
        }

        /* ---------------------------------------------------------------------- */
        /*                          Pool Creation                                 */
        /* ---------------------------------------------------------------------- */

        function _create8020Pool() internal virtual {
            // Create a secondary token for the 80/20 pool
            ERC20PermitMintableStub stableToken =
                new ERC20PermitMintableStub("Fork Stable Token", "fSTABLE", 18, address(this), 0);
            vm.label(address(stableToken), "ForkStableToken");

            // Sort tokens by address
            address[] memory tokens = new address[](2);
            if (address(seigniorageToken) < address(stableToken)) {
                tokens[0] = address(seigniorageToken);
                tokens[1] = address(stableToken);
            } else {
                tokens[0] = address(stableToken);
                tokens[1] = address(seigniorageToken);
            }

            // Create token configs
            TokenConfig[] memory tokenConfigs = new TokenConfig[](2);
            tokenConfigs[0] = TokenConfig({
                token: IERC20(tokens[0]),
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });
            tokenConfigs[1] = TokenConfig({
                token: IERC20(tokens[1]),
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });

            // 80/20 weights (0.8e18 for seigniorage, 0.2e18 for stable)
            uint256[] memory weights = new uint256[](2);
            if (tokens[0] == address(seigniorageToken)) {
                weights[0] = 0.8e18;
                weights[1] = 0.2e18;
            } else {
                weights[0] = 0.2e18;
                weights[1] = 0.8e18;
            }

            // Create pool on mainnet factory
            PoolRoleAccounts memory roleAccounts;
            weighted8020Pool = weightedPoolFactory.create(
                "Fork 80/20 Seigniorage Pool",
                "fSEIG-80-STABLE-20-BPT",
                tokenConfigs,
                weights,
                roleAccounts,
                0.003e18, // 0.3% swap fee
                address(0), // no hooks
                false, // not donation enabled
                false, // not liquidity bootstrapping
                bytes32(keccak256(abi.encodePacked(block.timestamp, "fork-8020-pool")))
            );
            vm.label(weighted8020Pool, "Fork8020Pool");

            // Initialize pool with liquidity
            _init8020Pool(tokens, stableToken);
        }

        function _init8020Pool(address[] memory, ERC20PermitMintableStub stableToken) internal {
            // Mint tokens for initialization
            seigniorageToken.mint(address(this), POOL_INIT_AMOUNT);
            stableToken.mint(address(this), POOL_INIT_AMOUNT);

            // Balancer V3 Router uses Permit2 for token transfers
            // Step 1: Approve Permit2 to spend tokens
            seigniorageToken.approve(address(permit2), type(uint256).max);
            stableToken.approve(address(permit2), type(uint256).max);

            // Step 2: Give Router allowance via Permit2 (with max expiration)
            permit2.approve(address(seigniorageToken), address(balancerRouter), type(uint160).max, type(uint48).max);
            permit2.approve(address(stableToken), address(balancerRouter), type(uint160).max, type(uint48).max);

            // Get sorted token order for the pool
            (IERC20[] memory poolTokens,,,) = balancerVault.getPoolTokenInfo(weighted8020Pool);

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = POOL_INIT_AMOUNT;
            amounts[1] = POOL_INIT_AMOUNT;

            // Initialize pool
            balancerRouter.initialize(weighted8020Pool, poolTokens, amounts, 0, false, bytes(""));
        }

        /* ---------------------------------------------------------------------- */
        /*                          Mock DETF Setup                               */
        /* ---------------------------------------------------------------------- */

        function _setupMockDETF() internal virtual {
            mockSeigniorageDETF = new ForkMockSeigniorageDETF(
                IERC20(address(seigniorageToken)), IERC20(address(lpToken))
            );
            vm.label(address(mockSeigniorageDETF), "ForkMockSeigniorageDETF");
        }

        /* ---------------------------------------------------------------------- */
        /*                       Vault Facet Deployment                           */
        /* ---------------------------------------------------------------------- */

        function _deployVaultFacets() internal virtual {
            erc20Facet = VaultComponentFactoryService.deployERC20Facet(create3Factory);
            erc2612Facet = VaultComponentFactoryService.deployERC2612Facet(create3Factory);
            erc5267Facet = VaultComponentFactoryService.deployERCC5267Facet(create3Factory);
            erc4626Facet = VaultComponentFactoryService.deployERC4626Facet(create3Factory);
            erc4626BasicVaultFacet = VaultComponentFactoryService.deployERC4626BasedBasicVaultFacet(create3Factory);
            erc4626StandardVaultFacet = VaultComponentFactoryService.deployERC4626StandardVaultFacet(create3Factory);

            erc721Facet = IFacet(address(new ERC721Facet()));
            vm.label(address(erc721Facet), "ERC721Facet");

            seigniorageNFTVaultFacet = create3Factory.deploySeigniorageNFTVaultFacet();
        }

        function _deployVaultPackage() internal virtual {
            ISeigniorageNFTVaultDFPkg.PkgInit memory pkgInit = ISeigniorageNFTVaultDFPkg.PkgInit({
                erc721Facet: erc721Facet,
                erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                seigniorageNFTVaultFacet: seigniorageNFTVaultFacet,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager))
            });

            nftVaultDFPkg = ISeigniorageNFTVaultDFPkg(address(new ForkMockSeigniorageNFTVaultDFPkg(pkgInit)));
            vm.label(address(nftVaultDFPkg), "ForkSeigniorageNFTVaultDFPkg");
        }

        function _deployNFTVault() internal virtual {
            ISeigniorageNFTVaultDFPkg.PkgArgs memory pkgArgs = ISeigniorageNFTVaultDFPkg.PkgArgs({
                name: "Fork Seigniorage NFT Vault",
                symbol: "fSNFT",
                detfToken: ISeigniorageDETF(address(mockSeigniorageDETF)),
                claimToken: IERC20(address(seigniorageToken)),
                lpToken: IERC20(address(lpToken)),
                rewardToken: IERC20MintBurn(address(rewardToken)),
                decimalOffset: 0,
                owner: nftVaultOwner
            });

            address nftVaultAddr =
                diamondPackageFactory.deploy(IDiamondFactoryPackage(address(nftVaultDFPkg)), abi.encode(pkgArgs));

            nftVault = ISeigniorageNFTVault(nftVaultAddr);
            vm.label(nftVaultAddr, "ForkSeigniorageNFTVault");

            mockSeigniorageDETF.setNFTVault(nftVault);
        }

        /* ---------------------------------------------------------------------- */
        /*                        Token Distribution                              */
        /* ---------------------------------------------------------------------- */

        function _distributeTokens() internal virtual {
            seigniorageToken.mint(alice, INITIAL_MINT);
            seigniorageToken.mint(bob, INITIAL_MINT);
            seigniorageToken.mint(charlie, INITIAL_MINT);
        }

        /* ---------------------------------------------------------------------- */
        /*                          Helper Functions                              */
        /* ---------------------------------------------------------------------- */

        function _lockSharesForUser(address user, uint256 amount, uint256 lockDuration)
            internal
            returns (uint256 tokenId)
        {
            uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

            vm.prank(nftVaultOwner);
            tokenId = nftVault.lockFromDetf(amount, bptReserveBefore, lockDuration, user);

            mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + amount);
        }

        function _distributeRewards(uint256 amount) internal {
            rewardToken.mint(address(nftVault), amount);
        }

        function _skipTime(uint256 duration) internal {
            skip(duration);
        }

        function _warpToUnlock(uint256 tokenId) internal {
            ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
            vm.warp(info.unlockTime);
        }

        function _expectedBonusMultiplier(uint256 lockDuration) internal pure returns (uint256) {
            if (lockDuration >= MAX_LOCK_DURATION) {
                return MAX_BONUS_MULTIPLIER;
            }

            uint256 bonusRange = MAX_BONUS_MULTIPLIER - BASE_BONUS_MULTIPLIER;
            uint256 ratio = (lockDuration * ONE_WAD) / MAX_LOCK_DURATION;
            uint256 quadraticRatio = (ratio * ratio) / ONE_WAD;
            return BASE_BONUS_MULTIPLIER + (bonusRange * quadraticRatio) / ONE_WAD;
        }

        function _expectedEffectiveShares(uint256 originalShares, uint256 lockDuration)
            internal
            pure
            returns (uint256)
        {
            uint256 bonus = _expectedBonusMultiplier(lockDuration);
            return (originalShares * bonus) / ONE_WAD;
        }

        /* ---------------------------------------------------------------------- */
        /*                       Fork-Specific Sanity Test                        */
        /* ---------------------------------------------------------------------- */

        function test_sanity_seigniorageInfrastructureValid() public view {
            // Verify mainnet contracts are bound
            assertEq(address(balancerVault), BASE_MAIN.BALANCER_V3_VAULT, "Vault should be mainnet");
            assertEq(
                address(weightedPoolFactory), BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY, "Factory should be mainnet"
            );

            // Verify 80/20 pool was created
            assertTrue(_hasCode(weighted8020Pool), "8020 pool should exist");

            // Verify NFT vault was created
            assertTrue(_hasCode(address(nftVault)), "NFT vault should exist");
        }
    }
