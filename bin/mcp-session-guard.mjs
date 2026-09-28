#!/usr/bin/env node
// mcp-session-guard — run one MCP helper so it cannot outlive its session.
//
// Why this exists (edge-dev3 OOM 2026-09-28): Claude/Codex sessions spawn
// several MCP servers (often through `npx` / `npm exec`). When a session ends —
// especially by OOM SIGKILL — those helpers were left orphaned. npm does not
// reliably forward stdin EOF to the real server, so the server never notices
// the client is gone and keeps running. Over a long day that piled up to ~2,098
// node processes / ~18.5 GB RSS and the kernel killed claude-desktop.
//
// This guard is the permanent fix at the launch boundary (without disabling any
// server). For the child it starts, it:
//   1. Owns the child's stdin and forwards it — so when the client's stdin
//      closes, THIS process sees EOF even if npm would have swallowed it.
//   2. Places the child in its own process group (POSIX) so one signal can
//      reap npx -> npm -> node, not just the top PID.
//   3. Detects parent death (PPID change / parent PID gone) and shuts down.
//   4. Forwards SIGINT/SIGTERM/SIGHUP to the whole group.
//   5. Always kills the child tree on any exit path.
//
// Usage: mcp-session-guard.mjs [--] <command> [args...]
// Exit:  child's exit code, or 143/130 when shut down by signal/EOF/parent.

import { spawn } from 'node:child_process'
import process from 'node:process'

const args = process.argv.slice(2)
if (args[0] === '--') args.shift()
if (args.length === 0) {
  process.stderr.write('mcp-session-guard: usage: mcp-session-guard.mjs [--] <command> [args...]\n')
  process.exit(2)
}

const isWin = process.platform === 'win32'
const command = args[0]
const commandArgs = args.slice(1)
const parentPidAtStart = process.ppid
let shuttingDown = false
let child = null

if (process.env.MCP_SESSION_GUARD_DEBUG) {
  process.stderr.write(
    `mcp-session-guard: start ppid=${parentPidAtStart} cmd=${command} args=${JSON.stringify(commandArgs)} stdinTTY=${process.stdin.isTTY}\n`
  )
}

function killTree(signal) {
  if (!child || child.pid == null) return
  const pid = child.pid
  try {
    if (isWin) {
      spawn('taskkill', ['/PID', String(pid), '/T', '/F'], {
        stdio: 'ignore',
        windowsHide: true,
      }).on('error', () => {})
    } else {
      // Negative PID = the child's whole process group (see detached below).
      try {
        process.kill(-pid, signal)
      } catch {
        try {
          process.kill(pid, signal)
        } catch {
          /* already gone */
        }
      }
    }
  } catch {
    /* already gone */
  }
}

function shutdown(reason, code) {
  if (process.env.MCP_SESSION_GUARD_DEBUG) {
    process.stderr.write(`mcp-session-guard: shutdown (${reason}) code=${code}\n`)
  }
  if (shuttingDown) return
  shuttingDown = true
  clearInterval(orphanTimer)
  killTree('SIGTERM')
  const force = setTimeout(() => {
    killTree('SIGKILL')
    process.exit(code)
  }, 2000)
  if (typeof force.unref === 'function') force.unref()
  child?.on('exit', () => {
    clearTimeout(force)
    process.exit(code)
  })
  // If the child is already gone, leave immediately.
  if (!child || child.exitCode != null || child.signalCode != null) {
    clearTimeout(force)
    process.exit(code)
  }
}

function parentGone() {
  if (process.ppid !== parentPidAtStart) return true
  try {
    // Signal 0: existence check only.
    process.kill(parentPidAtStart, 0)
    return false
  } catch {
    return true
  }
}

// POSIX: new process group so one kill reaps the whole npx/npm/node chain.
// Windows: taskkill /T walks the tree instead.
const spawnOpts = {
  stdio: ['pipe', 'inherit', 'inherit'],
  windowsHide: true,
}
if (!isWin) spawnOpts.detached = true

try {
  child = spawn(command, commandArgs, spawnOpts)
} catch (err) {
  process.stderr.write(`mcp-session-guard: cannot start ${command}: ${err.message}\n`)
  process.exit(127)
}

child.on('error', (err) => {
  process.stderr.write(`mcp-session-guard: cannot start ${command}: ${err.message}\n`)
  shutdown('spawn-error', 127)
})

child.on('exit', (code, signal) => {
  clearInterval(orphanTimer)
  if (process.env.MCP_SESSION_GUARD_DEBUG) {
    process.stderr.write(`mcp-session-guard: child exit code=${code} signal=${signal}\n`)
  }
  if (shuttingDown) {
    process.exit(code ?? 143)
    return
  }
  shuttingDown = true
  if (signal) {
    // Mirror the child's death signal on ourselves (same as exec).
    for (const s of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.removeAllListeners(s)
    try {
      process.kill(process.pid, signal)
    } catch {
      process.exit(143)
    }
    return
  }
  process.exit(code ?? 1)
})

// Own stdin: we forward bytes to the child and observe EOF ourselves. This is
// what makes "client went away" visible even when npm would swallow it.
if (child.stdin) {
  child.stdin.on('error', () => {
    // Child closed stdin early (or died). Not fatal by itself.
  })
  const onStdinGone = (reason) => {
    // A short-lived child may exit before stdin is used (e.g. `</dev/null`).
    // Never override its real exit code with a shutdown code.
    if (child && child.exitCode == null && child.signalCode == null) {
      shutdown(reason, 143)
    }
  }
  process.stdin.on('error', () => onStdinGone('stdin-error'))
  process.stdin.on('end', () => {
    if (process.env.MCP_SESSION_GUARD_DEBUG) {
      process.stderr.write('mcp-session-guard: stdin end\n')
    }
    onStdinGone('stdin-eof')
  })
  process.stdin.on('close', () => {
    if (process.env.MCP_SESSION_GUARD_DEBUG) {
      process.stderr.write('mcp-session-guard: stdin close\n')
    }
  })
  process.stdin.pipe(child.stdin)
}

for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(sig, () => shutdown(sig, sig === 'SIGINT' ? 130 : 143))
}

// Parent-death poll (no prctl binding in Node). Catches OOM SIGKILL of the
// client when no signal was delivered to us and stdin may linger in a zombie
// pipe holder. Cheap: two syscalls every 2s per helper.
const orphanTimer = setInterval(() => {
  if (parentGone() && child && child.exitCode == null && child.signalCode == null) {
    shutdown('parent-gone', 143)
  }
}, 2000)
if (typeof orphanTimer.unref === 'function') orphanTimer.unref()
