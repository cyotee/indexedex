'use client'

import { useConnectModal } from '@rainbow-me/rainbowkit'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from 'wagmi'
import { type Address } from 'viem'

import { CHAIN_ID_ANVIL, CHAIN_ID_LOCALHOST } from '@indexedex/protocol/addressArtifacts'
import { useDeploymentEnvironment } from '@indexedex/protocol/deploymentEnvironment'
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection'

import { ActionCta } from '../components/ui/ActionCta'
import { Card } from '../components/ui/Card'
import { resolveWalletGate } from '../lib/tx/actionState'
import { parseContractError } from '../lib/tx/parseContractError'
import type { CreatePlan } from './lib/createPlan'
import { HOOK_STAGED_INIT_ABI, UNI_V4_DETF_PKG_ABI } from './lib/detfAbi'
import {
  buildHookDeployArgs,
  buildUniV4DetfArgs,
  hookPkgForPlan,
  hookProductTokens,
  predictUniV4Detf,
  premineHook,
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
  const { openConnectModal } = useConnectModal()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: selectedChainId })
  const [status, setStatus] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  const platform = resolveSePlatform(selectedChainId, environment)
  const hookPkg = hookPkgForPlan(plan, platform)
  const canDeploy =
    ready &&
    !!platform.uniV4DetfPkg &&
    !!hookPkg &&
    !!platform.hookFactory &&
    !!platform.diamondPackageFactory &&
    !!platform.poolManager &&
    !!platform.feeOracle &&
    (plan.typeId === 'one-vault' || plan.typeId === 'weighted' || plan.typeId === 'stables')

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

  const connectWallet = () => openConnectModal?.()

  const finishDeploy = async (predictedDetf: Address) => {
    rememberCreatedDetf({
      chainId: selectedChainId,
      address: predictedDetf,
      name: plan.name.trim() || 'DETF',
      symbol: plan.symbol.trim() || 'DETF',
      decimals: 9,
    })
    setStatus('DETF is deployed. Bond to turn it on.')
    router.push(`/create/bond?detf=${predictedDetf}`)
  }

  const openHookDoors = async (hook: Address, tokens: Address[]) => {
    const doors = unorderedPairs(tokens)
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
  }

  const run = async () => {
    setStatus(null)
    if (!canDeploy || !address) {
      setStatus('Finish the plan, then connect a wallet.')
      return
    }
    if (!publicClient) throw new Error('No RPC client.')
    setPending(true)
    try {
      const args = buildUniV4DetfArgs(plan, address)
      setStatus('Predicting the DETF address…')
      const predictedDetf = await predictUniV4Detf(publicClient, platform, args)
      setStatus('Mining hook nonce…')
      const { hookPkg: pkg, mineNonce, predictedHook, scales } = await premineHook(
        publicClient,
        platform,
        plan,
        predictedDetf,
      )
      setStatus('Deploying the reserve hook…')
      const hookCall = buildHookDeployArgs(plan, predictedDetf, platform, mineNonce, scales)
      const hookHash = await writeOnWallet({
        address: pkg,
        abi: hookCall.abi as typeof UNI_V4_DETF_PKG_ABI,
        functionName: 'deployVault',
        args: hookCall.args as never,
      })
      await waitMined(hookHash)
      const hook = predictedHook
      await openHookDoors(hook, hookProductTokens(plan, predictedDetf))
      args.hook = hook
      setStatus(`Deploying DETF at ${predictedDetf.slice(0, 8)}…`)
      const detfHash = await writeOnWallet({
        address: platform.uniV4DetfPkg!,
        abi: UNI_V4_DETF_PKG_ABI,
        functionName: 'deployVault',
        args: [args],
      })
      await waitMined(detfHash)
      await finishDeploy(predictedDetf)
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
        This creates the market the DETF sits in, then the DETF. Bond NFT and claim token are
        wired on create. The DETF stays off until someone bonds.
      </p>
      {!platform.uniV4DetfPkg ? (
        <p className="mt-3 text-sm text-[var(--danger,#E6386A)]">
          No unified DETF create path on this network. Re-export platform addresses after the Uni V4
          DETF package is deployed.
        </p>
      ) : null}
      {platform.uniV4DetfPkg && !hookPkg ? (
        <p className="mt-3 text-sm text-[var(--danger,#E6386A)]">
          No create path on this network for this basket.
        </p>
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
