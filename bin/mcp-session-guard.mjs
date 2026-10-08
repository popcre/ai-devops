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
//   2. Keeps the child in THIS process group (no detached) so a harness group
//      kill takes the helper with us, and reaps npx -> npm -> node by walking
//      descendants (plus taskkill /T on Windows).
//   3. Detects parent death (PPID change / parent PID gone) and shuts down.
//   4. Forwards SIGINT/SIGTERM/SIGHUP to the whole tree.
//   5. Always kills the child tree on any exit path.
//
// Usage: mcp-session-guard.mjs [--] <command> [args...]
// Exit:  child's exit code, or 143/130 when shut down by signal/EOF/parent.

import { spawn, spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import process from 'node:process'

const args = process.argv.slice(2)
if (args[0] === '--') args.shift()
if (args.length === 0) {
  process.stderr.write('mcp-session-guard: usage: mcp-session-guard.mjs [--] <command> [args...]\n')
  process.exit(2)
}

const isWin = process.platform === 'win32'
let command = args[0]
let commandArgs = args.slice(1)
const parentPidAtStart = process.ppid
let shuttingDown = false
let child = null
let orphanTimer = null

// Windows .cmd/.bat shims cannot be spawn()ed directly (ENOENT). The repo's own
// catalog documents this: batch files need a shell. Wrap them in cmd /c.
if (isWin && /\.(cmd|bat)$/i.test(command)) {
  commandArgs = ['/c', command, ...commandArgs]
  command = process.env.ComSpec || 'cmd.exe'
}

if (process.env.MCP_SESSION_GUARD_DEBUG) {
  process.stderr.write(
    `mcp-session-guard: start ppid=${parentPidAtStart} cmd=${command} args=${JSON.stringify(commandArgs)} stdinTTY=${process.stdin.isTTY}\n`
  )
}

function killTree(signal) {
  if (!child || child.pid == null) return
  const pid = child.pid
  try {
    // Windows shutdown owns its native teardown acknowledgement separately.
    // Same process group as us (no detached): a harness group kill takes the
    // helper with us. Walk descendants so npx -> npm -> node all die.
    killDescendants(pid, signal)
    try {
      process.kill(pid, signal)
    } catch {
      /* already gone */
    }
  } catch {
    /* already gone */
  }
}

function shutdownWindows(code) {
  // Never submit a stale PID after this managed child has already exited.
  if (!child || child.pid == null || child.exitCode != null || child.signalCode != null) {
    process.exit(code)
    return
  }
  let helperStopped = false, treeStopped = false, finished = false, killer = null
  const finish = (failure) => {
    if (finished) return
    if (!failure && (!helperStopped || !treeStopped)) return
    finished = true
    clearTimeout(force)
    if (failure) {
      // Only the teardown subprocess we own may be stopped here. Never replay
      // taskkill against a PID whose original helper may now be gone/reused.
      if (killer && killer.exitCode == null && killer.signalCode == null) {
        try { killer.kill('SIGKILL') } catch { /* already gone */ }
      }
      process.stderr.write(`mcp-session-guard: Windows helper teardown unconfirmed: ${failure}\n`)
    }
    process.exit(failure ? 1 : code)
  }
  // Retain the existing absolute two-second shutdown bound; it starts before
  // native teardown and never restarts when the direct .cmd child exits.
  const force = setTimeout(() => finish('shutdown deadline reached'), 2000)
  if (typeof force.unref === 'function') force.unref()
  child.once('exit', () => { helperStopped = true; finish() })
  try {
    killer = spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {
      stdio: 'ignore', windowsHide: true,
    })
    killer.on('error', () => finish('native teardown could not start'))
    killer.once('exit', (status) => {
      if (status !== 0) finish(`native teardown exited ${status}`)
      else { treeStopped = true; finish() }
    })
  } catch {
    finish('native teardown could not start')
  }
}

function childPids(pid) {
  const out = []
  // Linux /proc walk — no external binary required.
  try {
    const raw = readFileSync(`/proc/${pid}/task/${pid}/children`, 'utf8')
    for (const tok of raw.split(/\s+/)) {
      const n = Number.parseInt(tok, 10)
      if (Number.isFinite(n) && n > 0) out.push(n)
    }
    if (out.length) return out
  } catch {
    /* not Linux, or already gone */
  }
  try {
    const res = spawnSync('pgrep', ['-P', String(pid)], { encoding: 'utf8' })
    for (const line of (res.stdout || '').split('\n')) {
      const n = Number.parseInt(line.trim(), 10)
      if (Number.isFinite(n) && n > 0) out.push(n)
    }
  } catch {
    /* pgrep missing */
  }
  return out
}

function killDescendants(pid, signal) {
  for (const kid of childPids(pid)) {
    killDescendants(kid, signal)
    try {
      process.kill(kid, signal)
    } catch {
      /* already gone */
    }
  }
}

function shutdown(reason, code) {
  if (process.env.MCP_SESSION_GUARD_DEBUG) {
    process.stderr.write(`mcp-session-guard: shutdown (${reason}) code=${code}\n`)
  }
  if (shuttingDown) return
  shuttingDown = true
  clearInterval(orphanTimer)
  if (isWin) {
    shutdownWindows(code)
    return
  }
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

// Stay in our process group (no detached): a harness group SIGKILL must take
// the helper with us. Windows uses taskkill /T to walk the tree.
const spawnOpts = {
  stdio: ['pipe', 'inherit', 'inherit'],
  windowsHide: true,
}

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
    // The Windows direct child may exit before taskkill finishes its tree.
    // Keep ownership until shutdownWindows confirms both outcomes.
    if (isWin) return
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
    // Give it a tick to report its real exit code; never override it.
    setTimeout(() => {
      if (child && child.exitCode == null && child.signalCode == null) {
        shutdown(reason, 143)
      }
    }, 250)
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
  // Observe EOF here before closing the launcher's pipe. cmd/npm may exit
  // immediately when that pipe ends, losing the root needed to reap its tree.
  // shutdown owns the pipe and the complete child tree from this point.
  process.stdin.pipe(child.stdin, { end: false })
}

for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(sig, () => shutdown(sig, sig === 'SIGINT' ? 130 : 143))
}

// Parent-death poll (no prctl binding in Node). Catches OOM SIGKILL of the
// client when no signal was delivered to us and stdin may linger in a zombie
// pipe holder. Cheap: two syscalls every 2s per helper.
orphanTimer = setInterval(() => {
  if (parentGone() && child && child.exitCode == null && child.signalCode == null) {
    shutdown('parent-gone', 143)
  }
}, 2000)
if (typeof orphanTimer.unref === 'function') orphanTimer.unref()
