#!/usr/bin/env node
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const repo = path.resolve(here, '../../..')
const outDir = path.join(here, 'out')
const require = createRequire(path.join(repo, 'frontend/apps/dtf/package.json'))
const { chromium } = require('playwright')

fs.mkdirSync(outDir, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 2,
})
const boards = [
  { html: 'architecture-single-se.html', png: 'architecture-single-se.png' },
  { html: 'se-vault-zap.html', png: 'se-vault-zap.png' },
  { html: 'reserve-pool.html', png: 'reserve-pool.png' },
  { html: 'mint-burn-expansion.html', png: 'mint-burn-expansion.png' },
  { html: 'bonding.html', png: 'bonding.png' },
  { html: 'rebasing-claim.html', png: 'rebasing-claim.png' },
]

for (const item of boards) {
  const html = path.join(here, item.html)
  await page.goto(pathToFileURL(html).href, { waitUntil: 'networkidle' })
  const board = page.locator('#board')
  await board.waitFor({ state: 'visible' })
  const dest = path.join(outDir, item.png)
  await board.screenshot({ path: dest, type: 'png' })
  console.log(path.relative(repo, dest))
}
await browser.close()
