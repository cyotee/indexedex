'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAccount, useConnect, usePublicClient, useSwitchChain, useWriteContract } from 'wagmi'
import { zeroAddress, type Address } from 'viem'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { ActionCta } from '../components/ui/ActionCta'
import { Card } from '../components/ui/Card'
import { resolveWalletGate } from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'
import type { CreatePlan } from './lib/createPlan'
import { CP_DETF_PKG_ABI, DETF_WIRE_ABI, HOOK_STAGED_INIT_ABI, WEIGHTED_DETF_PKG_ABI } from './lib/detfAbi'
import {
  buildCpDetfArgs,
  buildWeightedDetfArgs,
  premineCpDetf,
  premineWeightedDetf,
  productTokensWeighted,
  unorderedPairs,
} from './lib/detfDeploy'
import { rememberCreatedDetf } from '../lib/detf/createdDetfs'
import { resolveSePlatform } from './lib/sePlatform'
import { isPoolInitWalletRevert } from './lib/sePool'

export function DetfDeployPanel({
  plan,
  ready,
}: {
  plan: CreatePlan
  ready: boolean
}) {
  const router = useRouter()
  const { selectedChainId } = useSelectedNetwork()
  const { environment } = useDeploymentEnvironment()
  const { address, isConnected, chainId: walletChainId } = useAccount()
  const { connect, connectors } = useConnect()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: selectedChainId })
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  const platform = resolveSePlatform(selectedChainId, environment)
  const oneVault = plan.typeId === 'one-vault'
  const weighted = plan.typeId === 'weighted'
  const canDeployCp = ready && oneVault && !!platform.cpDetfPkg && !!plan.vaults[0] && !!plan.pairToken
  const canDeployWeighted =
    ready &&
    weighted &&
    !!platform.weightedDetfPkg &&
    !!platform.weightedHookPkg &&
    plan.vaults.length >= 2 &&
    plan.pairTokens.slice(0, plan.vaults.length).every((a) => !!a)
  const canDeploy = canDeployCp || canDeployWeighted

  const gate = resolveWalletGate({
    isConnected,
    isWrongNetwork: false,
    amountValid: canDeploy,
    hasPreview: canDeploy,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: 'Deploy DETF',
  })

  const writeOnWallet = async (params: Parameters<typeof writeContractAsync>[0]) => {
    const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (typeof walletChainId === 'number' && walletChainId !== selectedChainId && !localWallet) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & {
      chainId?: number
      chain?: unknown
    }
    return writeContractAsync(rest)
  }

  const waitMined = async (hash: `0x${string}`) => {
    if (!publicClient) throw new Error('No RPC client.')
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    if (receipt.status === 'reverted') throw new Error('Transaction reverted')
    return receipt
  }

  const connectWallet = () => {
    const connector =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (connector) connect({ connector })
  }

  const finishDeploy = async (predictedDetf: Address) => {
    rememberCreatedDetf({
      chainId: selectedChainId,
      address: predictedDetf,
      name: plan.name.trim() || 'DETF',
      symbol: plan.symbol.trim() || 'DETF',
      decimals: 18,
    })
    setStatus('DETF is deployed. Bond to turn it on.')
    router.push(`/create/bond?detf=${predictedDetf}`)
  }

  const wireHook = async (predictedDetf: Address, pairTokens: Address[]) => {
    if (!publicClient) throw new Error('No RPC client.')
    const hook = (await publicClient.readContract({
      address: predictedDetf,
      abi: DETF_WIRE_ABI,
      functionName: 'reserveHook',
    })) as Address
    if (!hook || hook === zeroAddress) throw new Error('DETF deployed but reserve hook is missing.')

    const doors = unorderedPairs(productTokensWeighted(predictedDetf, pairTokens))
    for (let i = 0; i < doors.length; i++) {
      const [a, b] = doors[i]!
      setStatus(`Opening reserve pool ${i + 1} of ${doors.length}…`)
      try {
        const pairHash = await writeOnWallet({
          address: hook,
          abi: HOOK_STAGED_INIT_ABI,
          functionName: 'deployPair',
          args: [a, b],
        })
        await waitMined(pairHash)
      } catch (err) {
        if (!isPoolInitWalletRevert(err)) throw err
      }
    }

    setStatus('Finalizing the reserve hook…')
    const finHash = await writeOnWallet({
      address: hook,
      abi: HOOK_STAGED_INIT_ABI,
      functionName: 'finalizeInitialization',
    })
    await waitMined(finHash)

    setStatus('Wiring bond NFT…')
    const nftHash = await writeOnWallet({
      address: predictedDetf,
      abi: DETF_WIRE_ABI,
      functionName: 'completeReserveBondNft',
    })
    await waitMined(nftHash)

    setStatus('Wiring claim token…')
    const claimHash = await writeOnWallet({
      address: predictedDetf,
      abi: DETF_WIRE_ABI,
      functionName: 'completeReserveClaim',
    })
    await waitMined(claimHash)
  }

  const runCp = async (creator: Address) => {
    const args = buildCpDetfArgs(plan, creator)
    if (args.creationPairPerDetfWad === 0n) throw new Error('Peg must be greater than 0.')
    setStatus('Mining hook nonce…')
    if (!publicClient) throw new Error('No RPC client.')
    const { predictedDetf, mineNonce } = await premineCpDetf(publicClient, platform, args)
    setStatus(`Deploying DETF at ${predictedDetf.slice(0, 8)}…`)
    const hash = await writeOnWallet({
      address: platform.cpDetfPkg!,
      abi: CP_DETF_PKG_ABI,
      functionName: 'deployVault',
      args: [args, mineNonce],
    })
    await waitMined(hash)
    await wireHook(predictedDetf, [args.pairToken])
    await finishDeploy(predictedDetf)
  }

  const runWeighted = async (creator: Address) => {
    const args = buildWeightedDetfArgs(plan, creator)
    setStatus('Mining hook nonce…')
    if (!publicClient) throw new Error('No RPC client.')
    const { predictedDetf, mineNonce } = await premineWeightedDetf(publicClient, platform, args)
    setStatus(`Deploying DETF at ${predictedDetf.slice(0, 8)}…`)
    const hash = await writeOnWallet({
      address: platform.weightedDetfPkg!,
      abi: WEIGHTED_DETF_PKG_ABI,
      functionName: 'deployVault',
      args: [args, mineNonce],
    })
    await waitMined(hash)
    await wireHook(predictedDetf, args.pairTokens)
    await finishDeploy(predictedDetf)
  }

  const run = async () => {
    setStatus(null)
    if (!canDeploy || !address) {
      setStatus('Finish the plan, then connect a wallet.')
      return
    }
    setPending(true)
    try {
      if (weighted) await runWeighted(address)
      else await runCp(address)
    } catch (err) {
      setStatus(parseContractError(err))
    } finally {
      setPending(false)
    }
  }

  return (
    <Card>
      <p className="landing-section-label">On-chain create</p>
      <h3 className="mt-2 text-lg font-semibold text-[var(--text-primary,#EDEDED)]">Deploy this DETF</h3>
      <p className="mt-3 text-sm leading-relaxed text-[var(--text-muted,#9aa3b2)]">
        {oneVault || weighted
          ? 'This sends the create transaction, then wires the reserve hook, bond NFT, and claim token. The DETF stays off until someone bonds.'
          : 'On-chain create from this page is for one strategy or a weighted mix. Copy the plan for the others.'}
      </p>
      {oneVault && !platform.cpDetfPkg ? (
        <p className="mt-3 text-sm text-[var(--danger,#E6386A)]">No one-strategy DETF create path on this network.</p>
      ) : null}
      {weighted && (!platform.weightedDetfPkg || !platform.weightedHookPkg) ? (
        <p className="mt-3 text-sm text-[var(--danger,#E6386A)]">No weighted DETF create path on this network.</p>
      ) : null}
      <div className="mt-5">
        <ActionCta
          gate={gate}
          pendingLeg={pending ? 'execute' : null}
          onConnect={connectWallet}
          onExecute={() => void run()}
          data-testid="create-deploy-detf"
        />
      </div>
      {status ? <p className="mt-3 text-sm text-[var(--text-primary,#EDEDED)]">{status}</p> : null}
    </Card>
  )
}