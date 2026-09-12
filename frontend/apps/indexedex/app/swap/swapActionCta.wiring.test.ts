/**
 * Structural audit: live Swap page primary CTA must be sequential ActionCta
 * with split approval handlers (K17 / Wave 1 PR5).
 *
 * Exercises the real shipped source entry point (page.tsx), not a re-implementation.
 */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const here = dirname(fileURLToPath(import.meta.url))
const pageSource = readFileSync(join(here, 'page.tsx'), 'utf8')

describe('Swap page ActionCta wiring (shipped source)', () => {
  it('imports resolveWalletGate and ActionCta', () => {
    expect(pageSource).toMatch(/import\s*\{[^}]*resolveWalletGate/)
    expect(pageSource).toMatch(/from ['"]\.\.\/lib\/tx\/actionState['"]/)
    expect(pageSource).toMatch(/import\s*\{\s*ActionCta\s*\}/)
  })

  it('renders a single ActionCta primary with swap-submit test id', () => {
    expect(pageSource).toMatch(/<ActionCta[\s\S]*?data-testid=["']swap-submit["']/)
    // Must not keep a second raw Swap button as dual primary
    const rawSwapButtons = pageSource.match(
      /data-testid=["']swap-submit["'][\s\S]{0,200}onClick=\{handleSwap\}/,
    )
    // ActionCta uses onExecute={() => void handleSwap()}, not raw button onClick=handleSwap on swap-submit
    expect(pageSource).toMatch(/onExecute=\{\(\)\s*=>\s*void handleSwap\(\)\}/)
    expect(rawSwapButtons).toBeNull()
  })

  it('wires split approval handlers only on ActionCta legs', () => {
    expect(pageSource).toMatch(
      /onApproveTokenPermit2=\{\(\)\s*=>\s*void handleIssuePermit2Approval\(\)\}/,
    )
    expect(pageSource).toMatch(
      /onApprovePermit2Router=\{\(\)\s*=>\s*void handleIssueRouterApproval\(\)\}/,
    )
    // ActionCta multi-leg must not call one-shot handleApproval
    const actionCtaBlock = pageSource.match(/<ActionCta[\s\S]*?\/>/)
    expect(actionCtaBlock?.[0] ?? '').not.toMatch(/handleApproval/)
  })

  it('passes signedMode into resolveWalletGate for signed approval path', () => {
    expect(pageSource).toMatch(/signedMode:\s*effectiveApprovalMode\s*===\s*['"]signed['"]/)
  })

  it('tracks distinct pending legs (approve vs execute)', () => {
    expect(pageSource).toMatch(/setPendingLeg\(['"]approve-token-permit2['"]\)/)
    expect(pageSource).toMatch(/setPendingLeg\(['"]approve-permit2-router['"]\)/)
    expect(pageSource).toMatch(/setPendingLeg\(['"]execute['"]\)/)
    expect(pageSource).toMatch(/pendingLeg=\{effectiveSwapPendingLeg\}/)
  })

  it('does not render dual primary Approve + Swap buttons side by side', () => {
    // Old dual primary patterns removed from live path
    expect(pageSource).not.toMatch(
      /data-testid=["']swap-approve-permit2["'][\s\S]{0,400}data-testid=["']swap-approve-router["'][\s\S]{0,400}data-testid=["']swap-submit["']/,
    )
    expect(pageSource).not.toMatch(
      /onClick=\{handleApproval\}[\s\S]{0,200}data-testid=["']swap-submit["']/,
    )
  })
})
