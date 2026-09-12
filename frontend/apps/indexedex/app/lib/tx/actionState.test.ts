import { describe, expect, it } from 'vitest'
import {
  gateToPendingLeg,
  pendingLabelForLeg,
  resolveWalletGate,
  type WalletGate,
} from './actionState'

const base = {
  isConnected: true,
  isWrongNetwork: false,
  amountValid: true,
  hasPreview: true,
  needsTokenApproval: false,
  needsPermit2Approval: false,
  executeLabel: 'Deposit',
}

describe('resolveWalletGate', () => {
  it('returns disconnected when wallet not connected', () => {
    const gate = resolveWalletGate({ ...base, isConnected: false })
    expect(gate.kind).toBe('disconnected')
    expect(gate.label).toMatch(/connect/i)
  })

  it('returns wrong-network before approve/execute', () => {
    const gate = resolveWalletGate({
      ...base,
      isWrongNetwork: true,
      needsTokenApproval: true,
    })
    expect(gate.kind).toBe('wrong-network')
    expect(gate.label).toMatch(/switch/i)
  })

  it('returns approve token→Permit2 when needsTokenApproval', () => {
    const gate = resolveWalletGate({ ...base, needsTokenApproval: true })
    expect(gate).toEqual({
      kind: 'approve',
      leg: 'token-permit2',
      label: 'Approve token for Permit2',
    })
  })

  it('returns approve permit2→router when token ok but permit2 needs approval', () => {
    const gate = resolveWalletGate({ ...base, needsPermit2Approval: true })
    expect(gate).toEqual({
      kind: 'approve',
      leg: 'permit2-router',
      label: 'Approve Permit2 for router',
    })
  })

  it('prioritizes token→Permit2 over permit2→router', () => {
    const gate = resolveWalletGate({
      ...base,
      needsTokenApproval: true,
      needsPermit2Approval: true,
    })
    expect(gate.kind).toBe('approve')
    if (gate.kind === 'approve') expect(gate.leg).toBe('token-permit2')
  })

  it('returns execute when ready', () => {
    const gate = resolveWalletGate(base)
    expect(gate).toEqual({ kind: 'execute', label: 'Deposit' })
  })

  it('disables without preview', () => {
    const gate = resolveWalletGate({ ...base, hasPreview: false })
    expect(gate.kind).toBe('disabled')
    if (gate.kind === 'disabled') expect(gate.reason).toBe('no-preview')
  })

  it('disables with invalid amount before preview check', () => {
    const gate = resolveWalletGate({
      ...base,
      amountValid: false,
      hasPreview: false,
    })
    expect(gate.kind).toBe('disabled')
    if (gate.kind === 'disabled') expect(gate.reason).toBe('invalid-amount')
  })

  it('skips permit2→router in signed mode', () => {
    const gate = resolveWalletGate({
      ...base,
      needsPermit2Approval: true,
      signedMode: true,
    })
    expect(gate.kind).toBe('execute')
  })

  it('Swap explicit mode: token approve before permit2→router before execute', () => {
    const swapBase = { ...base, executeLabel: 'Swap (Exact In)' as const }
    const token = resolveWalletGate({
      ...swapBase,
      needsTokenApproval: true,
      needsPermit2Approval: true,
      signedMode: false,
    })
    expect(token.kind).toBe('approve')
    if (token.kind === 'approve') expect(token.leg).toBe('token-permit2')

    const router = resolveWalletGate({
      ...swapBase,
      needsTokenApproval: false,
      needsPermit2Approval: true,
      signedMode: false,
    })
    expect(router.kind).toBe('approve')
    if (router.kind === 'approve') expect(router.leg).toBe('permit2-router')

    const exec = resolveWalletGate({
      ...swapBase,
      needsTokenApproval: false,
      needsPermit2Approval: false,
      signedMode: false,
    })
    expect(exec).toEqual({ kind: 'execute', label: 'Swap (Exact In)' })
  })

  it('Swap signed mode: only token→Permit2 then execute (no second approve CTA)', () => {
    const token = resolveWalletGate({
      ...base,
      executeLabel: 'Swap (Exact Out)',
      needsTokenApproval: true,
      needsPermit2Approval: true,
      signedMode: true,
    })
    expect(token.kind).toBe('approve')
    if (token.kind === 'approve') expect(token.leg).toBe('token-permit2')

    const afterToken = resolveWalletGate({
      ...base,
      executeLabel: 'Swap (Exact Out)',
      needsTokenApproval: false,
      needsPermit2Approval: true,
      signedMode: true,
    })
    expect(afterToken).toEqual({ kind: 'execute', label: 'Swap (Exact Out)' })
  })

  it('never implies Approve and Execute together (single kind)', () => {
    const samples: WalletGate[] = [
      resolveWalletGate({ ...base, isConnected: false }),
      resolveWalletGate({ ...base, isWrongNetwork: true }),
      resolveWalletGate({ ...base, needsTokenApproval: true }),
      resolveWalletGate({ ...base, needsPermit2Approval: true }),
      resolveWalletGate(base),
      resolveWalletGate({ ...base, hasPreview: false }),
    ]
    for (const gate of samples) {
      // Exactly one primary action kind
      expect(['disconnected', 'wrong-network', 'approve', 'execute', 'disabled']).toContain(
        gate.kind,
      )
      if (gate.kind === 'approve') {
        expect(gate.kind).not.toBe('execute')
      }
      if (gate.kind === 'execute') {
        expect(gate.kind).not.toBe('approve')
      }
    }
  })
})

describe('pendingLabelForLeg', () => {
  it('reflects active leg in loading label', () => {
    expect(pendingLabelForLeg('approve-token-permit2', 'Approve')).toMatch(/Approving token/)
    expect(pendingLabelForLeg('approve-permit2-router', 'Approve')).toMatch(/Approving Permit2/)
    expect(pendingLabelForLeg('execute', 'Deposit')).toMatch(/Submitting/)
    expect(pendingLabelForLeg(null, 'Deposit')).toBe('Deposit')
  })
})

describe('gateToPendingLeg', () => {
  it('maps approve legs correctly when pending', () => {
    const tokenGate = resolveWalletGate({ ...base, needsTokenApproval: true })
    expect(gateToPendingLeg(tokenGate, true)).toBe('approve-token-permit2')
    const routerGate = resolveWalletGate({ ...base, needsPermit2Approval: true })
    expect(gateToPendingLeg(routerGate, true)).toBe('approve-permit2-router')
    expect(gateToPendingLeg(resolveWalletGate(base), true)).toBe('execute')
    expect(gateToPendingLeg(resolveWalletGate(base), false)).toBe(null)
  })
})
