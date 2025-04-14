"use strict";
// Swap Form UI Component
// Extracted from page.tsx to reduce file size
Object.defineProperty(exports, "__esModule", { value: true });
exports.SwapForm = void 0;
function SwapForm({ selectedPool, setSelectedPool, tokenIn, setTokenIn, tokenOut, setTokenOut, amountIn, setAmountIn, amountOut, setAmountOut, lastEditedField, setLastEditedField, useEthIn, setUseEthIn, useEthOut, setUseEthOut, useTokenInVault, setUseTokenInVault, useTokenOutVault, setUseTokenOutVault, selectedVaultIn, setSelectedVaultIn, selectedVaultOut, setSelectedVaultOut, approvalMode, setApprovalMode, showApprovalSettings, setShowApprovalSettings, useMaxApproval, setUseMaxApproval, slippage, setSlippage, builtExactIn, builtExactOut, ready, routePattern, amountInDisplay, amountOutDisplay, minOut, maxIn, approvalState, approvalError, accurateQuote, accurateQuoteLoading, accurateQuoteError, needsTokenApproval, needsPermit2Approval, permit2AllowanceAmount, tokenAllowanceAmount, permit2SpendingLimit, setPermit2SpendingLimit, routerSpendingLimit, setRouterSpendingLimit, handleSetPermit2SpendingLimit, handleSetRouterSpendingLimit, poolOptions, tokenOptions, filteredVaultOptions, handlePreview, handleApproval, handleIssuePermit2Approval, handleIssueRouterApproval, handleGetAccurateQuote, handleSwap, previewPending, swapPending, showDebug, }) {
    const showVaultWarning = approvalMode === 'explicit' && (useTokenInVault || useTokenOutVault);
    const showInVaultWarning = approvalMode === 'explicit' && useTokenInVault;
    const showOutVaultWarning = approvalMode === 'explicit' && useTokenOutVault;
    return (<div className="container mx-auto px-4 max-w-2xl">
      <h1 className="text-3xl font-bold text-white text-center py-4">Swap Tokens</h1>
      
      {/* Approval Mode Settings */}
      <div className="mb-4">
        <button onClick={() => setShowApprovalSettings(!showApprovalSettings)} className="flex items-center justify-between w-full px-4 py-2 bg-slate-700/50 rounded-lg border border-slate-600 hover:bg-slate-700 transition-colors">
          <div className="flex items-center gap-2">
            <svg className="w-5 h-5 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <span className="text-sm font-medium text-gray-200">Approval Settings</span>
          </div>
          <svg className={`w-4 h-4 text-gray-400 transition-transform ${showApprovalSettings ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7"/>
          </svg>
        </button>
        
        {showApprovalSettings && (<div className="mt-2 p-4 bg-slate-700/30 rounded-lg border border-slate-600">
            <div className="text-xs text-gray-400 mb-3">Choose how you authorize token transfers:</div>
            
            {/* Explicit Approval Option */}
            <label className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-all ${approvalMode === 'explicit'
                ? 'bg-blue-600/20 border-blue-500'
                : 'bg-slate-700/30 border-slate-600 hover:border-slate-500'}`}>
              <input type="radio" name="approvalMode" value="explicit" checked={approvalMode === 'explicit'} onChange={() => setApprovalMode('explicit')} className="mt-1"/>
              <div>
                <div className="text-sm font-medium text-white">Approve Token</div>
                <div className="text-xs text-gray-400">Manually approve the router to spend your tokens before each swap</div>
              </div>
            </label>
            
            {/* Signed Approval Option */}
            <label className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-all mt-2 ${approvalMode === 'signed'
                ? 'bg-blue-600/20 border-blue-500'
                : 'bg-slate-700/30 border-slate-600 hover:border-slate-500'}`}>
              <input type="radio" name="approvalMode" value="signed" checked={approvalMode === 'signed'} onChange={() => setApprovalMode('signed')} className="mt-1"/>
              <div>
                <div className="text-sm font-medium text-white">Permit2 Signature</div>
                <div className="text-xs text-gray-400">Sign a one-time permit to authorize the swap without separate approval transaction</div>
              </div>
            </label>
            
            {/* Use Max Approval Toggle */}
            {approvalMode === 'explicit' && (<label className="flex items-center gap-2 mt-3 cursor-pointer">
                <input type="checkbox" checked={useMaxApproval} onChange={(e) => setUseMaxApproval(e.target.checked)} className="rounded bg-slate-700 border-slate-600"/>
                <span className="text-xs text-gray-300">Request max approval (uint256 max)</span>
              </label>)}
          </div>)}
      </div>

      {/* Pool Selection */}
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-300 mb-1">Pool / Strategy</label>
        <select value={selectedPool} onChange={(e) => setSelectedPool(e.target.value)} className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white">
          <option value="">Select a pool...</option>
          {poolOptions.map((pool) => (<option key={pool.value} value={pool.value}>
              {pool.label}
            </option>))}
        </select>
      </div>

      {/* Token In */}
      <div className="mb-4 p-4 bg-slate-700/50 rounded-lg border border-slate-600">
        {showInVaultWarning && (<div className="mb-3 p-2 bg-amber-600/20 border border-amber-500/50 rounded-lg">
            <div className="text-xs text-amber-300">
              Some Standard Exchange Vaults interact with underlying pools. This amount in may not include this interaction with the results of this swap. Use signed approvals or issue the explicit approvals to ensure you get an accurate quote.
            </div>
          </div>)}
        <div className="flex justify-between items-center mb-2">
          <label className="text-sm font-medium text-gray-300">Sell</label>
          <div className="flex gap-2">
            <label className="flex items-center gap-1 text-xs text-gray-400 cursor-pointer">
              <input type="checkbox" checked={useEthIn} onChange={(e) => setUseEthIn(e.target.checked)} className="rounded"/>
              Use ETH
            </label>
            {filteredVaultOptions.length > 0 && (<label className="flex items-center gap-1 text-xs text-gray-400 cursor-pointer">
                <input type="checkbox" checked={useTokenInVault} onChange={(e) => setUseTokenInVault(e.target.checked)} className="rounded"/>
                Deposit Vault
              </label>)}
          </div>
        </div>
        
        {!useEthIn && (<select value={tokenIn} onChange={(e) => setTokenIn(e.target.value)} className="w-full px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white mb-2">
            <option value="">Select token...</option>
            {tokenOptions.filter(t => t.type !== 'vault').map((token) => (<option key={token.value} value={token.value}>
                {token.label}
              </option>))}
          </select>)}
        
        {useTokenInVault && filteredVaultOptions.length > 0 && (<select value={selectedVaultIn} onChange={(e) => setSelectedVaultIn(e.target.value)} className="w-full px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white mb-2">
            <option value="">Select vault...</option>
            {filteredVaultOptions.map((vault) => (<option key={vault.value} value={vault.value}>
                {vault.label}
              </option>))}
          </select>)}
        
        <div className="flex gap-2">
          <input type="number" placeholder="0.0" value={amountIn} onChange={(e) => {
            setAmountIn(e.target.value);
            setLastEditedField('in');
        }} className="flex-1 px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white"/>
          {amountInDisplay && (<span className="text-xs text-gray-400 self-center">{amountInDisplay}</span>)}
        </div>
      </div>

      {/* Swap Direction */}
      <div className="flex justify-center -my-3 relative z-10">
        <button onClick={() => {
            const tempToken = tokenIn;
            const tempAmount = amountIn;
            setTokenIn(tokenOut);
            setTokenOut(tempToken);
            setAmountIn(amountOut);
            setAmountOut(tempAmount);
            setLastEditedField(lastEditedField === 'in' ? 'out' : 'in');
        }} className="p-2 bg-slate-600 rounded-full border-2 border-slate-500 hover:bg-slate-500">
          <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"/>
          </svg>
        </button>
      </div>

      {/* Token Out */}
      <div className="mb-4 p-4 bg-slate-700/50 rounded-lg border border-slate-600 -mt-3">
        {showOutVaultWarning && (<div className="mb-3 p-2 bg-amber-600/20 border border-amber-500/50 rounded-lg">
            <div className="text-xs text-amber-300">
              Some Standard Exchange Vaults interact with underlying pools. This amount out may not include this interaction in the results of this swap. Use signed approvals or issue the explicit approval to ensure you get an accurate quote.
            </div>
          </div>)}
        <div className="flex justify-between items-center mb-2">
          <label className="text-sm font-medium text-gray-300">Buy</label>
          <div className="flex gap-2">
            <label className="flex items-center gap-1 text-xs text-gray-400 cursor-pointer">
              <input type="checkbox" checked={useEthOut} onChange={(e) => setUseEthOut(e.target.checked)} className="rounded"/>
              Get ETH
            </label>
            {filteredVaultOptions.length > 0 && (<label className="flex items-center gap-1 text-xs text-gray-400 cursor-pointer">
                <input type="checkbox" checked={useTokenOutVault} onChange={(e) => setUseTokenOutVault(e.target.checked)} className="rounded"/>
                Withdraw to Vault
              </label>)}
          </div>
        </div>
        
        {!useEthOut && (<select value={tokenOut} onChange={(e) => setTokenOut(e.target.value)} className="w-full px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white mb-2">
            <option value="">Select token...</option>
            {tokenOptions.filter(t => t.type !== 'vault').map((token) => (<option key={token.value} value={token.value}>
                {token.label}
              </option>))}
          </select>)}
        
        {useTokenOutVault && filteredVaultOptions.length > 0 && (<select value={selectedVaultOut} onChange={(e) => setSelectedVaultOut(e.target.value)} className="w-full px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white mb-2">
            <option value="">Select vault...</option>
            {filteredVaultOptions.map((vault) => (<option key={vault.value} value={vault.value}>
                {vault.label}
              </option>))}
          </select>)}
        
        <div className="flex gap-2">
          <input type="number" placeholder="0.0" value={amountOut} onChange={(e) => {
            setAmountOut(e.target.value);
            setLastEditedField('out');
        }} className="flex-1 px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white"/>
          {amountOutDisplay && (<span className="text-xs text-gray-400 self-center">{amountOutDisplay}</span>)}
        </div>
      </div>

      {/* Slippage Setting */}
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-300 mb-1">
          Slippage Tolerance: {slippage}%
        </label>
        <input type="range" min="0.1" max="10" step="0.1" value={slippage} onChange={(e) => setSlippage(parseFloat(e.target.value))} className="w-full"/>
      </div>

      {/* Route Info */}
      {routePattern && (<div className="mb-4 p-3 bg-slate-700/30 rounded-lg border border-slate-600">
          <div className="text-sm text-gray-300">
            <span className="font-medium">Route:</span> {routePattern}
          </div>
          {lastEditedField === 'in' && minOut && (<div className="text-xs text-gray-400 mt-1">
              Min receive: {minOut.toString()} wei
            </div>)}
          {lastEditedField === 'out' && maxIn && (<div className="text-xs text-gray-400 mt-1">
              Max pay: {maxIn.toString()} wei
            </div>)}
        </div>)}

      {/* Approval UI for Explicit Mode */}
      {approvalMode === 'explicit' && ready && !useEthIn && (<div className="mb-4 p-3 bg-slate-700/30 rounded-lg border border-slate-600">
          <div className="space-y-3">
            {/* Permit2 Approval */}
            {needsTokenApproval && (<div>
                <button onClick={handleIssuePermit2Approval} disabled={approvalState === 'approving'} className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed text-sm">
                  Issue Approval: Permit2
                </button>
                <div className="mt-2">
                  <div className="flex gap-2">
                    <input type="number" placeholder="Spending limit" value={permit2SpendingLimit} onChange={(e) => setPermit2SpendingLimit(e.target.value)} className="flex-1 px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white text-sm"/>
                    <button onClick={() => handleSetPermit2SpendingLimit(BigInt(2 ** 160 - 1))} className="px-3 py-2 bg-slate-500 text-white rounded-lg text-sm hover:bg-slate-400">
                      Max
                    </button>
                  </div>
                  {permit2AllowanceAmount !== undefined && (<div className="text-xs text-gray-400 mt-1">
                      Current: {permit2AllowanceAmount.toString()} wei
                    </div>)}
                </div>
              </div>)}

            {/* Router Approval */}
            {needsPermit2Approval && (<div>
                <button onClick={handleIssueRouterApproval} disabled={approvalState === 'approving'} className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed text-sm">
                  Issue Approval: Router
                </button>
                <div className="mt-2">
                  <div className="flex gap-2">
                    <input type="number" placeholder="Spending limit" value={routerSpendingLimit} onChange={(e) => setRouterSpendingLimit(e.target.value)} className="flex-1 px-3 py-2 bg-slate-600 border border-slate-500 rounded-lg text-white text-sm"/>
                    <button onClick={() => handleSetRouterSpendingLimit(BigInt(2 ** 160 - 1))} className="px-3 py-2 bg-slate-500 text-white rounded-lg text-sm hover:bg-slate-400">
                      Max
                    </button>
                  </div>
                  {tokenAllowanceAmount !== undefined && (<div className="text-xs text-gray-400 mt-1">
                      Current: {tokenAllowanceAmount.toString()} wei
                    </div>)}
                </div>
              </div>)}
          </div>
        </div>)}

      {/* Action Buttons */}
      <div className="space-y-3">
        {/* Preview Button */}
        <button onClick={handlePreview} disabled={!ready || previewPending} className="w-full px-4 py-3 bg-slate-600 text-white rounded-lg font-medium hover:bg-slate-500 disabled:opacity-50 disabled:cursor-not-allowed">
          {previewPending ? 'Getting Quote...' : 'Get Quote'}
        </button>

        {/* Get Accurate Quote Button (Permit2 signed) */}
        {approvalMode === 'signed' && (<div>
            <button onClick={handleGetAccurateQuote} disabled={!ready || accurateQuoteLoading || useEthIn} className="w-full px-4 py-3 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-500 disabled:opacity-50 disabled:cursor-not-allowed">
              {accurateQuoteLoading ? 'Signing...' : 'Get Accurate Quote'}
            </button>
            <div className="text-xs text-gray-400 mt-1 text-center">
              This will ask you to sign an approval so we can simulate the transaction to get you an accurate quote.
            </div>
          </div>)}

        {/* Approval Button (legacy - for explicit mode without custom limit) */}
        {approvalMode === 'explicit' && !needsTokenApproval && !needsPermit2Approval && (<button onClick={handleApproval} disabled={approvalState === 'approving'} className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed">
            {approvalState === 'approving' ? 'Approving...' : approvalState === 'success' ? 'Approved ✓' : 'Approve Token'}
          </button>)}

        {approvalError && (<div className="text-red-400 text-sm">{approvalError}</div>)}

        {/* Swap Button */}
        <button onClick={handleSwap} disabled={!ready || swapPending || (approvalMode === 'explicit' && approvalState !== 'success' && !needsTokenApproval && !needsPermit2Approval)} className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed">
          {swapPending ? 'Swapping...' : 'Swap'}
        </button>
      </div>

      {/* Accurate Quote Result */}
      {accurateQuote && !accurateQuoteLoading && (<div className="mt-4 p-3 bg-green-600/20 rounded-lg border border-green-600/50">
          <div className="text-sm text-green-300 font-medium">
            Accurate Quote: {accurateQuote.toString()} wei
          </div>
        </div>)}

      {/* Accurate Quote Error */}
      {accurateQuoteError && (<div className="mt-4 p-3 bg-red-600/20 rounded-lg border border-red-600/50">
          <div className="text-sm text-red-300">
            {accurateQuoteError}
          </div>
        </div>)}
    </div>);
}
exports.SwapForm = SwapForm;
