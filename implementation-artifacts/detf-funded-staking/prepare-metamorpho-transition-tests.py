from pathlib import Path
import sys,json,datetime
root=Path.cwd();p=root/'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Morpho.t.sol';s=p.read_text();s=s.replace('import {IERC20}', 'import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";\nimport {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IERC20}',1).replace('contract ERC4626StandardExchange_Morpho_Test is TestBase_ERC4626MorphoHermetic {', 'contract ERC4626StandardExchange_Morpho_Test is TestBase_ERC4626MorphoHermetic, TransitionQuoteAssertions {')
needle='    function test_Morpho_vaultTokens_membership()'
addition='''    function test_Morpho_projectedSequenceIncludesPendingFundedFees() public {
        for (uint256 i; i < 2; ++i) {
            uint256 checkpoint = vm.snapshotState();
            vm.startPrank(MORPHO_OWNER);
            morphoVault.setFeeRecipient(i == 0 ? FEE_RECIPIENT : se);
            morphoVault.setFee(0.1e18);
            vm.stopPrank();
            vm.prank(user);
            seIn.exchangeIn(IERC20(address(loanToken)), 2_000 ether, IERC20(se), 0, user, false, block.timestamp);
            _accrueMorphoInterest();
            // Quote all future steps before executing any of them. The first
            // operation realizes actual performance-fee shares, including when
            // the SE itself receives them; later steps cannot mint them again.
            _assertQuoteSequence(se, IERC20(address(loanToken)), user, 1 ether);
            _mintLoan(address(this), 100 ether);
            uint256 shares = morphoVault.deposit(100 ether, address(this));
            _assertExternalExchangeQuote(se, IERC20(address(morphoVault)), IERC20(address(loanToken)), shares);
            assertTrue(vm.revertToStateAndDelete(checkpoint));
        }
    }

'''
assert needle in s;s=s.replace(needle,addition+needle,1)
a=root/'implementation-artifacts/detf-funded-staking'
if '--apply' in sys.argv:
 p.write_text(s)
 p=root/'test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol';s=p.read_text();r='test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Morpho.t.sol';
 if r not in s:p.write_text(s+'\nimport {ERC4626StandardExchange_Morpho_Test} from "'+r+'";\n')
else:(a/'pending-metamorpho-transition-tests.txt').write_text(s)
(a/'metamorpho-transition-tests.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Real MetaMorpho performance fees to an external recipient or the buffered SE; nested mint/redeem sequence, external protocol-share conversion and exact state equality.'},indent=2)+'\n')
print('prepared' if '--apply' not in sys.argv else 'applied')
