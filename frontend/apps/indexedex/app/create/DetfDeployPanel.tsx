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
import { CP_DETF_PKG_ABI, DETF_WIRE_ABI, HOOK_STAGED_INIT_ABI } from './lib/detfAbi'
import { buildCpDetfArgs, premineCpDetf } from './lib/detfDeploy'
import { rememberCreatedDetf } from '../lib/detf/createdDetfs'
import { createAppReadClient } from './lib/sePoolRead'
import { resolveSePlatform } from './lib/sePlatform'

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
  const canDeploy = ready && oneVault && !!platform.cpDetfPkg && !!plan.vaults[0] && !!plan.pairToken

  const gate = resolveWalletGate({
    isConnected,
    isWrongNetwork: false,
    amountValid: canDeploy,
    hasPreview: canDeploy,
    needsTokenApproval: false,
    needsPermit2Approval: false,
    executeLabel: 'Deploy DETF',
  })

  const writeOnAppNetwork = async (params: Parameters<typeof writeContractAsync>[0]) => {
    const localWallet = walletChainId === CHAIN_ID_ANVIL || walletChainId === CHAIN_ID_LOCALHOST
    if (typeof walletChainId === 'number' && walletChainId !== selectedChainId && !localWallet) {
      await switchChainAsync({ chainId: selectedChainId })
    }
    const { chainId: _c, chain: _ch, ...rest } = params as typeof params & { chainId?: number; chain?: unknown }
    return writeContractAsync(rest)
  }

  const connectWallet = () => {
    const connector =
      connectors.find((c) => c.id === 'metaMask' || c.id === 'metaMaskSDK') ??
      connectors.find((c) => c.id === 'injected') ??
      connectors[0]
    if (connector) connect({ connector })
  }

  const run = async () => {
    setStatus(null)
    if (!canDeploy || !address) {
      setStatus('Finish the plan, then connect a wallet.')
      return
    }
    if (!publicClient) {
      setStatus('No RPC client.')
      return
    }
    setPending(true)
    try {
      const args = buildCpDetfArgs(plan, address)
      if (args.creationPairPerDetfWad === 0n) throw new Error('Peg must be greater than 0.')
      setStatus('Mining hook nonce…')
      const readClient = createAppReadClient(selectedChainId)
      const { predictedDetf, mineNonce } = await premineCpDetf(readClient, platform, args)
      setStatus(`Deploying DETF at ${predictedDetf.slice(0, 8)}…`)
      const hash = await writeOnAppNetwork({
        address: platform.cpDetfPkg!,
        abi: CP_DETF_PKG_ABI,
        functionName: 'deployVault',
        args: [args, mineNonce],
      })
      await publicClient.waitForTransactionReceipt({ hash })

      const hook = (await readClient.readContract({
        address: predictedDetf,
        abi: DETF_WIRE_ABI,
        functionName: 'reserveHook',
      })) as Address
      if (!hook || hook === zeroAddress) throw new Error('DETF deployed but reserve hook is missing.')

      setStatus('Opening the reserve pool…')
      const pairHash = await writeOnAppNetwork({
        address: hook,
        abi: HOOK_STAGED_INIT_ABI,
        functionName: 'deployPair',
        args: [predictedDetf, args.pairToken],
      })
      await publicClient.waitForTransactionReceipt({ hash: pairHash })

      setStatus('Finalizing the reserve hook…')
      const finHash = await writeOnAppNetwork({
        address: hook,
        abi: HOOK_STAGED_INIT_ABI,
        functionName: 'finalizeInitialization',
      })
      await publicClient.waitForTransactionReceipt({ hash: finHash })

      setStatus('Wiring bond NFT…')
      const nftHash = await writeOnAppNetwork({
        address: predictedDetf,
        abi: DETF_WIRE_ABI,
        functionName: 'completeReserveBondNft',
      })
      await publicClient.waitForTransactionReceipt({ hash: nftHash })

      setStatus('Wiring claim token…')
      const claimHash = await writeOnAppNetwork({
        address: predictedDetf,
        abi: DETF_WIRE_ABI,
        functionName: 'completeReserveClaim',
      })
      await publicClient.waitForTransactionReceipt({ hash: claimHash })

      rememberCreatedDetf({
        chainId: selectedChainId,
        address: predictedDetf,
        name: plan.name.trim() || 'DETF',
        symbol: plan.symbol.trim() || 'DETF',
        decimals: 18,
      })
      setStatus('DETF is deployed. Bond to turn it on.')
      router.push(`/create/bond?detf=${predictedDetf}`)
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
        {oneVault
          ? 'This sends the package transaction, then wires the reserve hook, bond NFT, and claim token. The DETF stays off until someone bonds.'
          : 'This wizard deploys a Single Pool DETF. Pick one vault to deploy on-chain from here.'}
      </p>
      {!platform.cpDetfPkg ? (
        <p className="mt-3 text-sm text-[var(--danger,#E6386A)]">No Single Pool DETF package on this network.</p>
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