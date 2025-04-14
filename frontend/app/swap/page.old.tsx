// 'use client'

// import { useCallback, useEffect, useMemo, useState } from 'react'
// import { useAccount, usePublicClient } from 'wagmi'
// import { useReadContract, useWriteContract } from 'wagmi'
// import { erc20Abi } from 'viem'
// import { formatUnits, parseUnits } from 'viem'

// // Import addresses from the new structure
// import platform from '../addresses/sepolia/base_deployments.json'
// import constProdPools from '../addresses/sepolia/constProdPools.json'
// import strategyVaults from '../addresses/sepolia/strategyVault.json'
// import tokens from '../addresses/sepolia/tokens.json'
// import erc4626 from '../addresses/sepolia/erc4626.json'

// // Helper functions - moved outside component to prevent re-creation
// function getPoolAddress(poolKey: string): `0x${string}` | null {
//   // Check constProdPools first (Balancer V3)
//   if (constProdPools[poolKey as keyof typeof constProdPools]) return constProdPools[poolKey as keyof typeof constProdPools] as `0x${string}`
//   // Check strategyVaults
//   if (strategyVaults[poolKey as keyof typeof strategyVaults]) return strategyVaults[poolKey as keyof typeof strategyVaults] as `0x${string}`
//   return null
// }

// function getTokenAddress(tokenKey: string): `0x${string}` | null {
//   if (tokenKey === 'ETH') return null // Special case
//   if (tokenKey === 'WETH9') return platform.weth9 as `0x${string}`
//   if (tokens[tokenKey as keyof typeof tokens]) return tokens[tokenKey as keyof typeof tokens] as `0x${string}`
//   if (erc4626[tokenKey as keyof typeof erc4626]) return erc4626[tokenKey as keyof typeof erc4626] as `0x${string}`
//   if (strategyVaults[tokenKey as keyof typeof strategyVaults]) return strategyVaults[tokenKey as keyof typeof strategyVaults] as `0x${string}`
//   return null
// }

// function getTokenDecimals(token: string): number {
//   // Most tokens use 18 decimals, USDC uses 6
//   if (token.includes('USDC')) return 6
//   return 18
// }

// // Pool options with real addresses and proper categorization
// // Note: UniV2 pools are NOT included here as they are not actual swap pools
// const poolOptions = [
//   // Balancer V3 Constant Product Pools
//   { value: 'abConstProdPool', label: 'TTA/TTB Balancer Pool', type: 'balancer' },
//   { value: 'acConstProdPool', label: 'TTA/TTC Balancer Pool', type: 'balancer' },
//   { value: 'bcConstProdPool', label: 'TTB/TTC Balancer Pool', type: 'balancer' },
//   { value: 'aWETHConstProdPool', label: 'TTA/WETH Balancer Pool', type: 'balancer' },
//   { value: 'bWETHConstProdPool', label: 'TTB/WETH Balancer Pool', type: 'balancer' },
//   { value: 'cWETHConstProdPool', label: 'TTC/WETH Balancer Pool', type: 'balancer' },
//   { value: 'aWrapperConstProdPool', label: 'TTA Wrapper Balancer Pool', type: 'balancer' },
//   { value: 'bWrapperConstProdPool', label: 'TTB Wrapper Balancer Pool', type: 'balancer' },
//   { value: 'cWrapperConstProdPool', label: 'TTC Wrapper Balancer Pool', type: 'balancer' },
//   { value: 'wethWrapperConstProdPool', label: 'WETH Wrapper Balancer Pool', type: 'balancer' },
  
//   // Strategy Vaults
//   { value: 'abUniV2PoolStrategyVault', label: 'TTA/TTB Strategy Vault', type: 'vault' },
//   { value: 'acUniV2PoolStrategyVault', label: 'TTA/TTC Strategy Vault', type: 'vault' },
//   { value: 'bcUniV2PoolStrategyVault', label: 'TTB/TTC Strategy Vault', type: 'vault' },
//   { value: 'aWethUniV2PoolStrategyVault', label: 'TTA/WETH Strategy Vault', type: 'vault' },
//   { value: 'bWethUniV2PoolStrategyVault', label: 'TTB/WETH Strategy Vault', type: 'vault' },
//   { value: 'cWethUniV2PoolStrategyVault', label: 'TTC/WETH Strategy Vault', type: 'vault' }
// ]

// // Token options with real addresses - now including Strategy Vault tokens and UniV2 LP tokens
// const tokenOptions = [
//   { value: 'ETH', label: 'ETH', address: null }, // Special case for ETH
//   { value: 'WETH9', label: 'WETH9', address: platform.weth9 },
//   { value: 'TestTokenA', label: 'Test Token A', address: tokens.TestTokenA },
//   { value: 'TestTokenB', label: 'Test Token B', address: tokens.TestTokenB },
//   { value: 'TestTokenC', label: 'Test Token C', address: tokens.TestTokenC },
//   { value: 'ttA4626', label: 'Test Token A ERC4626', address: erc4626.ttA4626 },
//   { value: 'ttB4626', label: 'Test Token B ERC4626', address: erc4626.ttB4626 },
//   { value: 'ttC4626', label: 'Test Token C ERC4626', address: erc4626.ttC4626 },
//   { value: 'weth4626', label: 'WETH9 ERC4626', address: erc4626.weth4626 },
  
//   // Uniswap V2 Pool Tokens (LP tokens)
//   { value: 'abUniV2Pool', label: 'TTA/TTB UniV2 LP', address: erc4626.abUniV2Pool },
//   { value: 'acUniV2Pool', label: 'TTA/TTC UniV2 LP', address: erc4626.acUniV2Pool },
//   { value: 'bcUniV2Pool', label: 'TTB/TTC UniV2 LP', address: erc4626.bcUniV2Pool },
//   { value: 'aWethUniV2Pool', label: 'TTA/WETH UniV2 LP', address: erc4626.aWethUniV2Pool },
//   { value: 'bWethUniV2Pool', label: 'TTB/WETH UniV2 LP', address: erc4626.bWethUniV2Pool },
//   { value: 'cWethUniV2Pool', label: 'TTC/WETH UniV2 LP', address: erc4626.cWethUniV2Pool },
  
//   // Strategy Vault Tokens (vault shares)
//   { value: 'abUniV2PoolStrategyVault', label: 'TTA/TTB Strategy Vault', address: strategyVaults.abUniV2PoolStrategyVault },
//   { value: 'acUniV2PoolStrategyVault', label: 'TTA/TTC Strategy Vault', address: strategyVaults.acUniV2PoolStrategyVault },
//   { value: 'bcUniV2PoolStrategyVault', label: 'TTB/TTC Strategy Vault', address: strategyVaults.bcUniV2PoolStrategyVault },
//   { value: 'aWethUniV2PoolStrategyVault', label: 'TTA/WETH Strategy Vault', address: strategyVaults.aWethUniV2PoolStrategyVault },
//   { value: 'bWethUniV2PoolStrategyVault', label: 'TTB/WETH Strategy Vault', address: strategyVaults.bWethUniV2PoolStrategyVault },
//   { value: 'cWethUniV2PoolStrategyVault', label: 'TTC/WETH Strategy Vault', address: strategyVaults.cWethUniV2PoolStrategyVault }
// ]

// // Strategy Vault options for dropdown selection
// const vaultOptions = [
//   { value: 'abUniV2PoolStrategyVault', label: 'TTA/TTB Strategy Vault' },
//   { value: 'acUniV2PoolStrategyVault', label: 'TTA/TTC Strategy Vault' },
//   { value: 'bcUniV2PoolStrategyVault', label: 'TTB/TTC Strategy Vault' },
//   { value: 'aWethUniV2PoolStrategyVault', label: 'TTA/WETH Strategy Vault' },
//   { value: 'bWethUniV2PoolStrategyVault', label: 'TTB/WETH Strategy Vault' },
//   { value: 'cWethUniV2PoolStrategyVault', label: 'TTC/WETH Strategy Vault' }
// ]

// export default function SwapPage() {
//   const { address, isConnected } = useAccount()
//   const publicClient = usePublicClient()

//   // Core state
//   const [selectedPool, setSelectedPool] = useState('')
//   const [tokenIn, setTokenIn] = useState('')
//   const [tokenOut, setTokenOut] = useState('')
//   const [amountIn, setAmountIn] = useState('')
//   const [useEthIn, setUseEthIn] = useState(false)
//   const [useEthOut, setUseEthOut] = useState(false)
//   const [slippage, setSlippage] = useState(1)
//   const [useTokenInVault, setUseTokenInVault] = useState(false)
//   const [useTokenOutVault, setUseTokenOutVault] = useState(false)
//   const [selectedVaultIn, setSelectedVaultIn] = useState<`0x${string}` | ''>('')
//   const [selectedVaultOut, setSelectedVaultOut] = useState<`0x${string}` | ''>('')

//   // Derived state
//   const tokenInAddress = useMemo(() => {
//     if (useEthIn) return platform.weth9 as `0x${string}`
//     if (!tokenIn) return null
//     return getTokenAddress(tokenIn)
//   }, [useEthIn, tokenIn])

//   const tokenOutAddress = useMemo(() => {
//     if (useEthOut) return platform.weth9 as `0x${string}`
//     if (!tokenOut) return null
//     return getTokenAddress(tokenOut)
//   }, [useEthOut, tokenOut])

//   const poolAddress = useMemo(() => {
//     if (!selectedPool) return null
//     return getPoolAddress(selectedPool)
//   }, [selectedPool])

//   const tokenInVaultAddress = useMemo(() => {
//     if (!useTokenInVault || !selectedVaultIn) return '0x0000000000000000000000000000000000000000' as `0x${string}`
//     return selectedVaultIn
//   }, [useTokenInVault, selectedVaultIn])

//   const tokenOutVaultAddress = useMemo(() => {
//     if (!useTokenOutVault || !selectedVaultOut) return '0x0000000000000000000000000000000000000000' as `0x${string}`
//     return selectedVaultOut
//   }, [useTokenOutVault, selectedVaultOut])

//   const exactAmountIn = useMemo(() => {
//     if (!amountIn || !tokenInAddress) return undefined
//     try {
//       const decimals = getTokenDecimals(tokenIn)
//       return parseUnits(amountIn, decimals)
//     } catch {
//       return undefined
//     }
//   }, [amountIn, tokenInAddress, tokenIn])

//   const deadline = useMemo(() => {
//     return BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now
//   }, [])

//   // Preview hook using generic useReadContract
//   const { data: preview, refetch: refetchPreview, isPending: previewPending } = useReadContract({
//     address: platform.balancerV3StandardExchangeRouter as `0x${string}`,
//     abi: [
//       {
//         inputs: [
//           { name: 'pool', type: 'address' },
//           { name: 'tokenIn', type: 'address' },
//           { name: 'tokenInVault', type: 'address' },
//           { name: 'tokenOut', type: 'address' },
//           { name: 'tokenOutVault', type: 'address' },
//           { name: 'exactAmountIn', type: 'uint256' },
//           { name: 'sender', type: 'address' },
//           { name: 'userData', type: 'bytes' }
//         ],
//         name: 'querySwapSingleTokenExactIn',
//         outputs: [{ name: '', type: 'uint256' }],
//         stateMutability: 'view',
//         type: 'function'
//       }
//     ],
//     functionName: 'querySwapSingleTokenExactIn',
//     args: [
//       poolAddress as `0x${string}`,
//       tokenInAddress as `0x${string}`,
//       tokenInVaultAddress,
//       tokenOutAddress as `0x${string}`,
//       tokenOutVaultAddress,
//       exactAmountIn as bigint,
//       address as `0x${string}`,
//       '0x'
//     ],
//     query: { enabled: !!poolAddress && !!tokenInAddress && !!tokenOutAddress && !!exactAmountIn && !!address }
//   })

//   const minOut = useMemo(() => {
//     if (!exactAmountIn || !preview) return undefined
//     const slippageMultiplier = BigInt(1000 - slippage * 10) // Convert percentage to basis points
//     return (preview * slippageMultiplier) / BigInt(1000)
//   }, [exactAmountIn, preview, slippage])

//   // Route pattern detection
//   const routePattern = useMemo(() => {
//     if (!selectedPool || !tokenInAddress || !tokenOutAddress) return null
    
//     const poolType = poolOptions.find(p => p.value === selectedPool)?.type
//     switch(poolType) {
//       case 'balancer':
//         return 'Direct Balancer V3 Swap'
//       case 'vault':
//         if (useEthIn || useEthOut) return 'Strategy Vault with ETH'
//         if (useTokenInVault || useTokenOutVault) return 'Strategy Vault Pass-Through'
//         return 'Strategy Vault Deposit/Withdrawal'
//       default:
//         return null
//     }
//   }, [selectedPool, tokenInAddress, tokenOutAddress, useEthIn, useEthOut, useTokenInVault, useTokenOutVault])

//   // Generic ERC20 hooks for all token operations - NO TOKEN-SPECIFIC HOOKS
//   const { data: tokenBalance, refetch: refetchBalance } = useReadContract({
//     address: tokenInAddress as `0x${string}`,
//     abi: erc20Abi,
//     functionName: 'balanceOf',
//     args: [address as `0x${string}`],
//     query: { enabled: !!tokenInAddress && !!address }
//   })

//   const { data: tokenAllowance, refetch: refetchAllowance } = useReadContract({
//     address: tokenInAddress as `0x${string}`,
//     abi: erc20Abi,
//     functionName: 'allowance',
//     args: [address as `0x${string}`, platform.permit2 as `0x${string}`],
//     query: { enabled: !!tokenInAddress && !!address }
//   })

//   // Debug logging for allowance data
//   useEffect(() => {
//     if (tokenAllowance !== undefined) {
//       console.log('[Token Allowance Hook]', {
//         tokenAllowance: tokenAllowance.toString(),
//         tokenAllowanceType: typeof tokenAllowance,
//         tokenInAddress,
//         address
//       })
//     }
//   }, [tokenAllowance, tokenInAddress, address])

//   const { data: permit2Allowance, refetch: refetchPermit2Allowance } = useReadContract({
//     address: platform.permit2 as `0x${string}`,
//     abi: [
//       {
//         inputs: [
//           { name: 'owner', type: 'address' },
//           { name: 'token', type: 'address' },
//           { name: 'spender', type: 'address' }
//         ],
//         name: 'allowance',
//         outputs: [
//           { name: 'amount', type: 'uint160' },
//           { name: 'expiration', type: 'uint48' },
//           { name: 'nonce', type: 'uint48' }
//         ],
//         stateMutability: 'view',
//         type: 'function'
//       }
//     ],
//     functionName: 'allowance',
//     args: [address as `0x${string}`, tokenInAddress as `0x${string}`, platform.balancerV3StandardExchangeRouter as `0x${string}`],
//     query: { enabled: !!tokenInAddress && !!address }
//   })

//   // Debug logging for permit2 allowance data
//   useEffect(() => {
//     if (permit2Allowance !== undefined) {
//       console.log('[Permit2 Allowance Hook]', {
//         permit2Allowance: permit2Allowance[0]?.toString(),
//         permit2AllowanceType: typeof permit2Allowance[0],
//         permit2AllowanceFull: permit2Allowance,
//         tokenInAddress,
//         address,
//         routerAddress: platform.balancerV3StandardExchangeRouter
//       })
//     }
//   }, [permit2Allowance, tokenInAddress, address])

//   // Generic swap execution hook - NO TOKEN-SPECIFIC HOOKS
//   const { writeContract: writeSwap, isPending: swapPending } = useWriteContract()

//   // Approval state management
//   const [approvalState, setApprovalState] = useState<'idle' | 'approving' | 'success' | 'error'>('idle')
//   const [approvalError, setApprovalError] = useState<string>('')

//   // Computed values
//   const ready = useMemo(() => {
//     return !!(
//       isConnected &&
//       selectedPool &&
//       tokenInAddress &&
//       tokenOutAddress &&
//       exactAmountIn &&
//       poolAddress &&
//       preview
//     )
//   }, [isConnected, selectedPool, tokenInAddress, tokenOutAddress, exactAmountIn, poolAddress, preview])

//   // Separate approval checks for each step
//   const needsTokenApproval = useMemo(() => {
//     if (!exactAmountIn || !tokenAllowance) return false
    
//     // No buffer needed - exact amount is sufficient
//     const sufficient = tokenAllowance >= exactAmountIn
    
//     console.log('[Token Approval Check]', {
//       exactAmountIn: exactAmountIn.toString(),
//       requiredAmount: exactAmountIn.toString(),
//       tokenAllowance: tokenAllowance.toString(),
//       sufficient,
//       needsApproval: !sufficient
//     })
    
//     return !sufficient
//   }, [exactAmountIn, tokenAllowance])

//   const needsPermit2Approval = useMemo(() => {
//     if (!exactAmountIn || !permit2Allowance) return false
    
//     // No buffer needed - exact amount is sufficient
//     const sufficient = permit2Allowance[0] >= exactAmountIn
    
//     console.log('[Permit2 Approval Check]', {
//       exactAmountIn: exactAmountIn.toString(),
//       requiredAmount: exactAmountIn.toString(),
//       permit2Allowance: permit2Allowance[0].toString(),
//       sufficient,
//       needsApproval: !sufficient
//     })
    
//     return !sufficient
//   }, [exactAmountIn, permit2Allowance])

//   // Overall approval needed if either step needs approval
//   const needsApproval = useMemo(() => {
//     const needsAny = needsTokenApproval || needsPermit2Approval
    
//     console.log('[Overall Approval Check]', {
//       needsTokenApproval,
//       needsPermit2Approval,
//       needsAny
//     })
    
//     return needsAny
//   }, [needsTokenApproval, needsPermit2Approval])

//   // Handlers
//   const handlePreview = useCallback(() => {
//     refetchPreview()
//   }, [refetchPreview])

//   const handleApproval = useCallback(async () => {
//     if (!tokenInAddress || !exactAmountIn || !address) return
    
//     setApprovalState('approving')
//     setApprovalError('')
    
//     try {
//       console.log('[Approval] Starting approval process for amount:', exactAmountIn.toString())
//       console.log('[Approval] Addresses being used:', {
//         tokenInAddress,
//         permit2Address: platform.permit2,
//         routerAddress: platform.balancerV3StandardExchangeRouter,
//         userAddress: address
//       })
      
//       // Only approve token -> Permit2 if needed
//       if (needsTokenApproval) {
//         console.log('[Approval] Step 1: Approving token -> Permit2')
//         await writeSwap({
//           address: tokenInAddress as `0x${string}`,
//           abi: erc20Abi,
//           functionName: 'approve',
//           args: [platform.permit2 as `0x${string}`, exactAmountIn]
//         })
        
//         // Wait for token approval confirmation
//         console.log('[Approval] Token approval submitted, waiting for confirmation...')
//         await new Promise(resolve => setTimeout(resolve, 2000)) // Basic wait
//       } else {
//         console.log('[Approval] Step 1: Token approval not needed, skipping')
//       }
      
//       // Only approve Permit2 -> Router if needed
//       if (needsPermit2Approval) {
//         console.log('[Approval] Step 2: Approving Permit2 -> Router')
//         const threeDaysSecs = 3 * 24 * 60 * 60
//         const expiration = Math.floor(Date.now() / 1000) + threeDaysSecs
        
//         await writeSwap({
//           address: platform.permit2 as `0x${string}`,
//           abi: [
//             {
//               inputs: [
//                 { name: 'token', type: 'address' },
//                 { name: 'spender', type: 'address' },
//                 { name: 'amount', type: 'uint160' },
//                 { name: 'expiration', type: 'uint48' }
//               ],
//               name: 'approve',
//               outputs: [],
//               stateMutability: 'nonpayable',
//               type: 'function'
//           }
//           ],
//           functionName: 'approve',
//           args: [tokenInAddress as `0x${string}`, platform.balancerV3StandardExchangeRouter as `0x${string}`, exactAmountIn, expiration]
//         })
        
//         // Wait for permit2 approval confirmation
//         console.log('[Approval] Permit2 approval submitted, waiting for confirmation...')
//         await new Promise(resolve => setTimeout(resolve, 2000)) // Basic wait
//       } else {
//         console.log('[Approval] Step 2: Permit2 approval not needed, skipping')
//       }
      
//       // Force refresh allowances with delays to ensure blockchain state is updated
//       console.log('[Approval] Refreshing allowances...')
//       await new Promise(resolve => setTimeout(resolve, 1000)) // Wait for blockchain state update
      
//       // Refresh allowances multiple times to ensure consistency
//       await Promise.all([
//         refetchAllowance(),
//         refetchPermit2Allowance()
//       ])
      
//       // Double-check the refresh
//       await new Promise(resolve => setTimeout(resolve, 500))
//       await Promise.all([
//         refetchAllowance(),
//         refetchPermit2Allowance()
//       ])
      
//       // Final verification - check if approvals are actually sufficient now
//       await new Promise(resolve => setTimeout(resolve, 500))
//       await Promise.all([
//         refetchAllowance(),
//         refetchPermit2Allowance()
//       ])
      
//       setApprovalState('success')
//       console.log('[Approval] Approval process completed successfully')
      
//       // Reset success state after a delay
//       setTimeout(() => setApprovalState('idle'), 3000)
      
//     } catch (error) {
//       console.error('[Approval] Approval failed:', error)
//       setApprovalState('error')
//       setApprovalError(error instanceof Error ? error.message : 'Approval failed')
      
//       // Reset error state after a delay
//       setTimeout(() => {
//         setApprovalState('idle')
//         setApprovalError('')
//       }, 5000)
//     }
//   }, [tokenInAddress, exactAmountIn, address, writeSwap, refetchAllowance, refetchPermit2Allowance, needsTokenApproval, needsPermit2Approval])

//   const handleSwap = useCallback(async () => {
//     if (!ready || !preview || !minOut || !poolAddress) return
    
//     try {
//       // Check if approvals needed
//       if (needsApproval) {
//         await handleApproval()
//         return
//       }
      
//       // Execute swap with vault addresses using generic hook
//       const swapArgs: readonly [`0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, `0x${string}`, bigint, bigint, bigint, boolean, `0x${string}`] = [
//         poolAddress,
//         tokenInAddress as `0x${string}`,
//         tokenInVaultAddress,
//         tokenOutAddress as `0x${string}`,
//         tokenOutVaultAddress,
//         exactAmountIn as bigint,
//         minOut,
//         deadline,
//         useEthIn || useEthOut, // wethIsEth
//         '0x'
//       ]
      
//       console.log('[Swap] Executing with args:', {
//         args: swapArgs,
//         value: useEthIn ? exactAmountIn : undefined,
//         routePattern,
//         ethHandling: { useEthIn, useEthOut, wethIsEth: useEthIn || useEthOut },
//         vaultHandling: { useTokenInVault, useTokenOutVault, tokenInVaultAddress, tokenOutVaultAddress }
//       })
      
//       await writeSwap({
//         address: platform.balancerV3StandardExchangeRouter as `0x${string}`,
//         abi: [
//           {
//             inputs: [
//               { name: 'pool', type: 'address' },
//               { name: 'tokenIn', type: 'address' },
//               { name: 'tokenInVault', type: 'address' },
//               { name: 'tokenOut', type: 'address' },
//               { name: 'tokenOutVault', type: 'address' },
//               { name: 'exactAmountIn', type: 'uint256' },
//               { name: 'minAmountOut', type: 'uint256' },
//               { name: 'deadline', type: 'uint256' },
//               { name: 'wethIsEth', type: 'bool' },
//               { name: 'userData', type: 'bytes' }
//             ],
//             name: 'swapSingleTokenExactIn',
//             outputs: [{ name: '', type: 'uint256' }],
//             stateMutability: 'payable',
//             type: 'function'
//           }
//         ],
//         functionName: 'swapSingleTokenExactIn',
//         args: swapArgs,
//         value: useEthIn ? exactAmountIn : undefined
//       })
      
//     } catch (error) {
//       console.error('Swap failed:', error)
//     }
//   }, [ready, preview, minOut, poolAddress, needsApproval, handleApproval, tokenInAddress, tokenOutAddress, exactAmountIn, deadline, useEthIn, useEthOut, writeSwap, routePattern, tokenInVaultAddress, tokenOutVaultAddress, useTokenInVault, useTokenOutVault])

//   function getRouteDescription(): string {
//     if (!routePattern) return ''
    
//     switch(routePattern) {
//       case 'Direct Balancer V3 Swap':
//         return 'Direct swap through Balancer V3 constant product pool'
//       case 'Strategy Vault with ETH':
//         return 'Strategy vault operation with ETH wrapping/unwrapping'
//       case 'Strategy Vault Pass-Through':
//         return 'Swap through strategy vault (deposit/withdraw)'
//       case 'Strategy Vault Deposit/Withdrawal':
//         return 'Direct deposit to or withdrawal from strategy vault'
//       default:
//         return ''
//     }
//   }

//   // Refresh data when dependencies change
//   useEffect(() => {
//     if (tokenInAddress && address) {
//       refetchBalance()
//       refetchAllowance()
//       refetchPermit2Allowance()
//     }
//   }, [tokenInAddress, address, refetchBalance, refetchAllowance, refetchPermit2Allowance])

//   if (!isConnected) {
//     return (
//       <div className="container mx-auto px-4">
//         <div className="text-center pt-10 pb-6">
//           <h1 className="text-3xl font-bold text-white">Swap Tokens</h1>
//           <p className="text-gray-300 mt-2">Connect your wallet to start swapping</p>
//         </div>
//       </div>
//     )
//   }

//   return (
//     <div className="container mx-auto px-4 max-w-2xl">
//       <h1 className="text-3xl font-bold text-white text-center py-8">Swap Tokens</h1>
      
//       {/* Pool Selection */}
//       <div className="mb-6">
//         <label className="block text-sm font-medium text-gray-300 mb-2">Select Pool</label>
//         <select 
//           value={selectedPool} 
//           onChange={(e) => setSelectedPool(e.target.value)}
//           className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//         >
//           <option value="">Select a Pool</option>
//           {poolOptions.map(option => (
//             <option key={option.value} value={option.value}>{option.label}</option>
//           ))}
//         </select>
//       </div>
      
//       {/* Token Selection */}
//       <div className="grid grid-cols-2 gap-4 mb-6">
//         <div>
//           <label className="block text-sm font-medium text-gray-300 mb-2">Token In</label>
//           <select
//             value={tokenIn}
//             onChange={(e) => setTokenIn(e.target.value)}
//             className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//           >
//             <option value="">Select Token In</option>
//             {tokenOptions.map(option => (
//               <option key={option.value} value={option.value}>{option.label}</option>
//             ))}
//           </select>
//           <label className="flex items-center gap-2 text-sm text-gray-300 mt-2">
//             <input
//               type="checkbox"
//               checked={useEthIn}
//               onChange={(e) => setUseEthIn(e.target.checked)}
//             />
//             Use ETH (wrap to WETH)
//           </label>
//         </div>
        
//         <div>
//           <label className="block text-sm font-medium text-gray-300 mb-2">Token Out</label>
//           <select
//             value={tokenOut}
//             onChange={(e) => setTokenOut(e.target.value)}
//             className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//           >
//             <option value="">Select Token Out</option>
//             {tokenOptions.map(option => (
//               <option key={option.value} value={option.value}>{option.label}</option>
//             ))}
//           </select>
//           <label className="flex items-center gap-2 text-sm text-gray-300 mt-2">
//             <input
//               type="checkbox"
//               checked={useEthOut}
//               onChange={(e) => setUseEthOut(e.target.checked)}
//             />
//             Use ETH (unwrap from WETH)
//           </label>
//         </div>
//       </div>
      
//       {/* Vault Selection */}
//       <div className="grid grid-cols-2 gap-4 mb-6">
//         <div>
//           <label className="flex items-center gap-2 text-sm text-gray-300 mb-2">
//             <input
//               type="checkbox"
//               checked={useTokenInVault}
//               onChange={(e) => setUseTokenInVault(e.target.checked)}
//             />
//             Use Token In Vault
//           </label>
//           {useTokenInVault && (
//             <select
//               value={selectedVaultIn}
//               onChange={(e) => setSelectedVaultIn(e.target.value as `0x${string}`)}
//               className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//             >
//               <option value="">Select Vault In</option>
//               {vaultOptions.map(option => (
//                 <option key={option.value} value={strategyVaults[option.value as keyof typeof strategyVaults]}>
//                   {option.label}
//                 </option>
//               ))}
//             </select>
//           )}
//         </div>
        
//         <div>
//           <label className="flex items-center gap-2 text-sm text-gray-300 mb-2">
//             <input
//               type="checkbox"
//               checked={useTokenOutVault}
//               onChange={(e) => setUseTokenOutVault(e.target.checked)}
//             />
//             Use Token Out Vault
//           </label>
//           {useTokenOutVault && (
//             <select
//               value={selectedVaultOut}
//               onChange={(e) => setSelectedVaultOut(e.target.value as `0x${string}`)}
//               className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//             >
//               <option value="">Select Vault Out</option>
//               {vaultOptions.map(option => (
//                 <option key={option.value} value={strategyVaults[option.value as keyof typeof strategyVaults]}>
//                   {option.label}
//                 </option>
//               ))}
//             </select>
//           )}
//         </div>
//       </div>
      
//       {/* Amount Input */}
//       <div className="mb-6">
//         <label className="block text-sm font-medium text-gray-300 mb-2">Amount In</label>
//         <input
//           type="number"
//           value={amountIn}
//           onChange={(e) => setAmountIn(e.target.value)}
//           className="w-full rounded-md border border-slate-600 bg-slate-700 text-white p-3"
//           placeholder="0.0"
//         />
//         {tokenBalance && (
//           <div className="text-xs text-gray-400 mt-1">
//             Balance: {formatUnits(tokenBalance, getTokenDecimals(tokenIn))} {tokenIn}
//           </div>
//         )}
//       </div>
      
//       {/* Slippage */}
//       <div className="mb-6">
//         <label className="block text-sm font-medium text-gray-300 mb-2">Slippage Tolerance</label>
//         <div className="flex items-center gap-2">
//           {[0.1, 0.5, 1].map((v) => (
//             <button
//               key={v}
//               type="button"
//               onClick={() => setSlippage(v)}
//               className={`px-3 py-1 rounded-md border ${slippage === v ? 'bg-blue-600 border-blue-500 text-white' : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'}`}
//             >
//               {v}%
//             </button>
//           ))}
//         </div>
//       </div>
      
//       {/* Route Info */}
//       {routePattern && (
//         <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
//           <div className="text-sm text-blue-300 font-medium">Route: {routePattern}</div>
//           <div className="text-xs text-gray-400 mt-1">
//             {getRouteDescription()}
//           </div>
//         </div>
//       )}
      
//       {/* Preview */}
//       {preview && (
//         <div className="mb-6 p-4 bg-slate-700/50 rounded-lg">
//           <div className="text-sm text-green-300 font-medium">Preview</div>
//           <div className="text-xs text-gray-400 mt-1">
//             Expected Output: {formatUnits(preview, getTokenDecimals(tokenOut))} {tokenOut}
//           </div>
//           {minOut && (
//             <div className="text-xs text-gray-400">
//               Minimum Output: {formatUnits(minOut, getTokenDecimals(tokenOut))} {tokenOut}
//             </div>
//           )}
//         </div>
//       )}
      
//       {/* Action Buttons */}
//       <div className="space-y-3">
//         <button
//           onClick={handlePreview}
//           disabled={!ready}
//           className="w-full py-3 px-4 bg-slate-600 text-white rounded-md disabled:opacity-50"
//         >
//           {previewPending ? 'Previewing...' : 'Preview Quote'}
//         </button>
        
//         {needsApproval && (
//           <div className="space-y-2">
//             {needsTokenApproval && (
//               <div className="text-xs text-yellow-300 text-center">
//                 ⚠️ Token approval needed for Permit2
//               </div>
//             )}
//             {needsPermit2Approval && (
//               <div className="text-xs text-yellow-300 text-center">
//                 ⚠️ Permit2 approval needed for Router
//               </div>
//             )}
//             <button
//               onClick={handleApproval}
//               disabled={approvalState === 'approving'}
//               className="w-full py-3 px-4 bg-yellow-600 text-white rounded-md disabled:opacity-50"
//             >
//               {approvalState === 'approving' ? 'Approving...' : 'Approve Tokens'}
//             </button>
//           </div>
//         )}
        
//         {approvalState === 'success' && (
//           <div className="w-full py-3 px-4 bg-green-600 text-white rounded-md text-center">
//             ✅ Approval Successful! You can now swap.
//           </div>
//         )}
        
//         {approvalState === 'error' && (
//           <div className="w-full py-3 px-4 bg-red-600 text-white rounded-md text-center">
//             ❌ Approval Failed: {approvalError}
//           </div>
//         )}
        
//         <button
//           onClick={handleSwap}
//           disabled={!ready || !preview || needsApproval}
//           className="w-full py-3 px-4 bg-blue-600 text-white rounded-md disabled:opacity-50"
//         >
//           {swapPending ? 'Swapping...' : 'Swap'}
//         </button>
//       </div>
      
//       {/* Debug Info */}
//       {ready && (
//         <div className="mt-6 p-4 bg-slate-700/30 rounded-lg">
//           <div className="text-xs text-gray-400">
//             <div>Pool: {poolAddress}</div>
//             <div>TokenIn: {tokenInAddress}</div>
//             <div>TokenOut: {tokenOutAddress}</div>
//             <div>TokenInVault: {useTokenInVault ? tokenInVaultAddress : 'None'}</div>
//             <div>TokenOutVault: {useTokenOutVault ? tokenOutVaultAddress : 'None'}</div>
//             <div>AmountIn: {exactAmountIn?.toString()} wei</div>
//             <div>MinOut: {minOut?.toString()} wei</div>
//             <div>WethIsEth: {(useEthIn || useEthOut) ? 'true' : 'false'}</div>
//             <div>Ready: {ready ? 'Yes' : 'No'}</div>
//             <div>Needs Token Approval: {needsTokenApproval ? 'Yes' : 'No'}</div>
//             <div>Needs Permit2 Approval: {needsPermit2Approval ? 'Yes' : 'No'}</div>
//             <div>Needs Any Approval: {needsApproval ? 'Yes' : 'No'}</div>
//             <div>Approval State: {approvalState}</div>
//             {approvalError && <div>Approval Error: {approvalError}</div>}
            
//             {/* Chain State Debug Info */}
//             <div className="mt-2 pt-2 border-t border-slate-600">
//               <div className="text-xs text-blue-300 font-medium mb-1">Chain State:</div>
//               <div>Token → Permit2 Allowance: {tokenAllowance ? formatUnits(tokenAllowance, getTokenDecimals(tokenIn)) : 'Loading...'} {tokenIn}</div>
//               <div>Permit2 → Router Allowance: {permit2Allowance ? formatUnits(permit2Allowance[0], getTokenDecimals(tokenIn)) : 'Loading...'} {tokenIn}</div>
//               <div>Required Amount: {exactAmountIn ? formatUnits(exactAmountIn, getTokenDecimals(tokenIn)) : 'N/A'} {tokenIn}</div>
//               <div>Token Address: {tokenInAddress || 'None'}</div>
//               <div>Router Address: {platform.balancerV3StandardExchangeRouter}</div>
              
//               {/* Raw Values for Debugging */}
//               <div className="mt-2 pt-2 border-t border-slate-500">
//                 <div className="text-xs text-yellow-300 font-medium mb-1">Raw Values:</div>
//                 <div>Token Allowance (wei): {tokenAllowance?.toString() || 'undefined'}</div>
//                 <div>Permit2 Allowance (wei): {permit2Allowance ? permit2Allowance[0]?.toString() : 'undefined'}</div>
//                 <div>Exact Amount In (wei): {exactAmountIn?.toString() || 'undefined'}</div>
//                 <div>Hook Status: Token={tokenAllowance !== undefined ? 'Loaded' : 'Loading'}, Permit2={permit2Allowance !== undefined ? 'Loaded' : 'Loading'}</div>
//             <div className="mt-2">
//               <button 
//                 onClick={() => {
//                   console.log('[Debug] Manual refresh triggered')
//                   refetchAllowance()
//                   refetchPermit2Allowance()
//                 }}
//                 className="px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
//               >
//                 🔄 Refresh Allowances
//               </button>
//             </div>
//               </div>
//             </div>
//           </div>
//         </div>
//       )}
//     </div>
//   )
// }