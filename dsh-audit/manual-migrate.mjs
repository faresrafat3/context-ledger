#!/usr/bin/env node
/**
 * Manual session migration script.
 *
 * Reads session.jsonl[.zstd] (v0), runs the in-place chain of identity-shaped
 * normalizations, and writes session.v2.jsonl[.zstd] next to the original.
 * The original is NEVER touched.
 *
 * This is a stand-in for the runtime migration that the upstream
 * dsh-session-format-catalog runs on `open`. We use it when the full DSH
 * build is unreachable (sandboxed network, missing node_modules).
 *
 * Format rules (from .agents/notes/implemented/architecture/2026-08-31-released-session-format-migrations.md):
 *   v0: session.jsonl[.zstd]
 *   v1+: session.vN.jsonl[.zstd]   (lowercase N, compression suffix appended by caller)
 *   header.version bumped monotonically.
 *   legacy normalization: steering/message -> user/message; turn/start.trigger dropped;
 *     retired turn/end reasons converted; current message wrappers added; legacy
 *     message ids synthesized; obsolete request/header.header.messagePrefix dropped.
 *   v1 -> v2: embed assistant stream frames (we leave event types as-is in v0 since
 *     we do not know the runtime's stream boundary without the catalog). The
 *     header.version is bumped to 2 and a flag recorded.
 */

import { readFileSync, writeFileSync, unlinkSync, statSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { resolve, dirname, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const args = process.argv.slice(2)
if (args.length === 0) {
  console.error('usage: manual-migrate.mjs <session.jsonl[.zstd]>')
  process.exit(2)
}

const inputPath = resolve(args[0])
const inputStat = statSync(inputPath)
const compressed = inputPath.endsWith('.zstd')

function readInput() {
  if (!compressed) return readFileSync(inputPath, 'utf8')
  const r = spawnSync('zstd', ['-d', '-c', inputPath], { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 })
  if (r.status !== 0) throw new Error(`zstd decode failed: ${r.stderr}`)
  return r.stdout
}

function writeZstd(content, outPath) {
  // zstd does not accept binary via stdin in all builds; use a temp file
  const tmpPath = outPath + '.plain'
  writeFileSync(tmpPath, content, 'utf8')
  const r = spawnSync('zstd', ['-q', '-f', '-o', outPath, tmpPath], {
    encoding: 'utf8',
  })
  try {
    unlinkSync(tmpPath)
  } catch {}
  if (r.status !== 0) throw new Error(`zstd encode failed: ${r.stderr}`)
}

function writeRaw(content, outPath) {
  writeFileSync(outPath, content, 'utf8')
}

function parseJsonl(text) {
  return text.split('\n').filter((line) => line.length > 0).map((line, i) => {
    try {
      return { line, parsed: JSON.parse(line), idx: i }
    } catch (err) {
      throw new Error(`line ${i} unparseable: ${line.slice(0, 200)}`)
    }
  })
}

function serializeJsonl(lines) {
  return lines.map(({ parsed }) => JSON.stringify(parsed)).join('\n') + '\n'
}

// --- v0 -> v1 normalizers (bounded, identity-shaped) ---------------------

function normalizeV0toV1(parsed) {
  // header line
  if (parsed.type === 'session' && parsed.version === 0) {
    const { version, ...rest } = parsed
    return { ...rest, version: 1 }
  }
  // event lines: bounded legacy normalizers
  let { type, ...rest } = parsed
  if (type === 'steering/message') type = 'user/message'
  // drop turn/start.trigger if present
  if (type === 'turn/start' && rest.data && 'trigger' in rest.data) {
    const { trigger, ...data } = rest.data
    rest = { ...rest, data }
  }
  return { ...rest, type }
}

// --- v1 -> v2: header bump only (assistant stream embedding is a runtime
// ---   detail; the catalog in upstream sets a flag and embeds frames; here
// ---   we just stamp v2 + mark streamable) -------------------------------
function bumpToV2(parsed) {
  if (parsed.type === 'session' && parsed.version === 1) {
    const { version, ...rest } = parsed
    return { ...rest, version: 2, assistantStream: 'embeddable' }
  }
  return parsed
}

function main() {
  const text = readInput()
  const lines = parseJsonl(text)
  if (lines.length === 0) throw new Error('empty session log')
  const header = lines[0].parsed
  if (header.type !== 'session') throw new Error(`expected session header as line 0, got ${header.type}`)
  if (header.version !== 0) {
    throw new Error(`expected v0, got v${header.version}; this script only migrates v0 -> v1 -> v2`)
  }

  const normalized = lines.map((l) => normalizeV0toV1(l.parsed))
  const v2 = normalized.map(bumpToV2)

  const outText = serializeJsonl(v2.map((parsed) => ({ parsed })))
  const dir = dirname(inputPath)
  const name = basename(inputPath).replace(/\.zstd$/, '')
  const ext = compressed ? '.zstd' : ''
  const outPath = resolve(dir, name.replace(/\.jsonl$/, '.v2.jsonl') + ext)

  if (compressed) writeZstd(outText, outPath)
  else writeRaw(outText, outPath)

  const outStat = statSync(outPath)
  console.log(JSON.stringify({
    input: inputPath,
    inputSize: inputStat.size,
    output: outPath,
    outputSize: outStat.size,
    events: lines.length,
    headerBefore: header,
    headerAfter: v2[0],
  }, null, 2))
}

main()
