// Behaviour check for config/opencode-plugins/verdict-stop.js.
// Usage: node tests/opencode-verdict-stop-plugin.mjs <plugin path>
import { pathToFileURL } from "node:url"
import { resolve } from "node:path"

let p = process.argv[2]
// Git Bash passes /c/... paths; node on Windows needs C:/...
const m = /^\/([a-zA-Z])\/(.*)$/.exec(p)
if (process.platform === "win32" && m) p = `${m[1]}:/${m[2]}`
const mod = await import(pathToFileURL(resolve(p)).href)
const fail = (msg) => { console.error(`verdict-stop: ${msg}`); process.exit(1) }

// OpenCode calls every export of a plugin file as a plugin function.
const fns = Object.values(mod)
if (fns.length !== 1 || typeof fns[0] !== "function") fail("must export exactly one function")
const hooks = await fns[0]({})
const ask = async (sessionID) => {
  const out = { enabled: true }
  await hooks["experimental.compaction.autocontinue"]({ sessionID }, out)
  return out.enabled
}
const say = (sessionID, text) => hooks["experimental.text.complete"]({ sessionID }, { text })

await say("s1", "Working through the packet. Earlier wording said approve.\n## Verdict pending")
if (!(await ask("s1"))) fail("a compaction before the verdict must still continue")
await say("s1", "Findings.\r\n## Verdict\r\nREJECT\r\n")
if (await ask("s1")) fail("a compaction after the verdict must not continue")
if (!(await ask("s2"))) fail("another session must be unaffected")
await say("s3", "## Verdict\nAPPROVE")
if (await ask("s3")) fail("APPROVE verdict must stop the continue")
await say("s4", "Findings.\n\nVERDICT: APPROVE 0123abcd")
if (await ask("s4")) fail("terminal VERDICT: line must stop the continue")
await say("s5", "Findings.\nAPPROVE only after the tests pass")
if (!(await ask("s5"))) fail("a qualified decision line is not a verdict")
console.log("verdict-stop plugin ok")
