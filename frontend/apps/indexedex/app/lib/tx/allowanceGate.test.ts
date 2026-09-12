import { describe, expect, it } from 'vitest'
import { needsApprovalFromAllowance } from './allowanceGate'

describe('needsApprovalFromAllowance', () => {
  const amount = BigInt(1000)

  it('returns false when no effective amount', () => {
    expect(needsApprovalFromAllowance(undefined, undefined)).toBe(false)
    expect(needsApprovalFromAllowance(BigInt(0), undefined)).toBe(false)
  })

  it('returns true while allowance is still loading (undefined/null)', () => {
    // Critical: must not treat unknown as "approved" — Execute would enable too early
    expect(needsApprovalFromAllowance(amount, undefined)).toBe(true)
    expect(needsApprovalFromAllowance(amount, null)).toBe(true)
  })

  it('returns true when allowance is below amount', () => {
    expect(needsApprovalFromAllowance(amount, BigInt(999))).toBe(true)
    expect(needsApprovalFromAllowance(amount, BigInt(0))).toBe(true)
  })

  it('returns false when allowance covers amount', () => {
    expect(needsApprovalFromAllowance(amount, amount)).toBe(false)
    expect(needsApprovalFromAllowance(amount, BigInt(2000))).toBe(false)
  })
})
