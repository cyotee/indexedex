from pathlib import Path
import difflib,re
p=Path('test/foundry/fork/eth_main/staking/ethereum/LidoService_Fork.t.sol');old=p.read_text();s=old
imports='''import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {HermeticWETH, HermeticStETH, HermeticWstETH, HermeticWithdrawalQueue} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {LidoWstETHStandardExchangeInFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeInFacet.sol";
import {LidoWstETHStandardExchangeOutFacet} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutFacet.sol";
import {LidoWstETHMarkerFacet} from "contracts/protocols/staking/lido/LidoWstETHMarkerFacet.sol";
import {LidoWstETHRebalanceFacet} from "contracts/protocols/staking/lido/LidoWstETHRebalanceFacet.sol";
import {LidoWstETHStandardExchangeDFPkg} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol";
'''
i=re.search(r'pragma solidity [^;]+;',s).end();s=s[:i]+'\n'+imports+s[i:]
s+='''
/// @notice Actual registry-deployed SE against Ethereum's fractional Lido receipt.
/// The inherited hermetic components are replaced with live protocol contracts
/// before deploying the subject SE; no transaction is broadcast to Ethereum.
contract LidoStandardExchangeProjectionFork is TestBase_LidoWstETHStandardExchange, TransitionQuoteAssertions {
    function setUp() public override {
        vm.createSelectFork("ethereum_mainnet_alchemy", 24_000_000);
        super.setUp();
        hermeticWeth = HermeticWETH(payable(EthereumStakingAddresses.WETH));
        hermeticStEth = HermeticStETH(EthereumStakingAddresses.ST_ETH);
        hermeticWstEth = HermeticWstETH(EthereumStakingAddresses.WST_ETH);
        // Queue operations are not involved in the standard liquid/receipt routes.
        // Zero is the existing package's optional queue configuration.
        hermeticQueue = HermeticWithdrawalQueue(payable(address(0)));
        seVault = _deployLidoSe();
        lidoSe = ILidoWstETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.07e18);
        vm.deal(address(this), 1_000 ether);
        IStETH(EthereumStakingAddresses.ST_ETH).submit{value: 500 ether}(address(0));
        uint256 stAmount = hermeticStEth.balanceOf(address(this));
        hermeticStEth.approve(address(hermeticWstEth), stAmount);
        IWstETH(address(hermeticWstEth)).wrap(stAmount);
        hermeticWeth.deposit{value: 500 ether}();
        hermeticWeth.approve(seVault, 200 ether);
        seIn.exchangeIn(IERC20(address(hermeticWeth)), 200 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        hermeticWstEth.approve(seVault, 200 ether);
        seIn.exchangeIn(IERC20(address(hermeticWstEth)), 200 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        assertGt(IWstETH(address(hermeticWstEth)).stEthPerToken(), 1e18, "live non-unit receipt ratio");
    }

    function test_lidoLiveLiquidAndWrappedSequentialQuotes() public {
        _assertQuoteSequence(seVault, IERC20(address(hermeticWeth)), address(this), 1 ether);
        _assertQuoteSequence(seVault, IERC20(address(hermeticWstEth)), address(this), 1 ether);
    }

    function test_lidoLiveExternalMintFeeAttribution() public {
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 7 ether + 19, address(this));
        address beneficiary = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 3 ether + 11, beneficiary);
    }

    function test_lidoLiveExternalStakeChangesReceiptRatio() public {
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 3 ether + 17);
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 7 ether + 29);
    }

    function test_lidoLiveStETHConversionsProjectRounding() public {
        vm.deal(address(this), 5 ether);
        IStETH(address(hermeticStEth)).submit{value: 5 ether}(address(0));
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticStEth)), IERC20(address(hermeticWeth)), hermeticStEth.balanceOf(address(this)) / 2, address(this));
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticStEth)), IERC20(address(hermeticWeth)), hermeticStEth.balanceOf(address(this)) / 2);
    }
}
'''
art=Path('implementation-artifacts/detf-funded-staking');(art/'lido-live-projection-fork.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile=str(p),tofile=str(p))));print('Prepared 4 real-Lido projection tests in existing fork source; not applied')
