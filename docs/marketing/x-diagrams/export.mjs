#!/usr/bin/env node
/**
 * Render each 1600x900 board to PNG.
 * Usage (from repo root):
 *   node docs/marketing/x-diagrams/export.mjs
 */

import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const repo = path.resolve(here, '../../..')
const outDir = path.join(here, 'out')
const require = createRequire(path.join(repo, 'frontend/apps/dtf/package.json'))
const { chromium } = require('playwright')

const boards = [
  '01-what-is-detf',
  '02-core-shape',
  '03-lifecycle',
  '04-mint-bond-claim',
  '05-policy-open',
  '06-bond-nft',
]

fs.mkdirSync(outDir, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({
  viewport: { width: 1600, height: 900 },
  deviceScaleFactor: 2,
})

for (const name of boards) {
  const html = path.join(here, `${name}.html`)
  await page.goto(pathToFileURL(html).href, { waitUntil: 'networkidle' })
  const board = page.locator('#board')
  await board.waitFor({ state: 'visible' })
  const dest = path.join(outDir, `${name}.png`)
  await board.screenshot({ path: dest, type: 'png' })
  console.log(path.relative(repo, dest))
}

await browser.close()
