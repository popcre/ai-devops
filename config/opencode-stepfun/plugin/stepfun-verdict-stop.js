// stepfun-verdict-stop.js: end a StepFun OpenCode turn once its verdict is out.
//
// Pinned OpenCode 1.18.12 compacts a long session automatically (the profile
// keeps compaction.auto on, so long reviews never overflow) and, after every
// automatic compaction, injects a synthetic user message, "Continue if you
// have next steps...". When that compaction lands after the model has already
// written its final "## Verdict" block, the model is told to keep going and
// re-runs checks, re-compacts, and is told to continue again. Incident
// 20261021T232515Z-al8960ofc-stepfun-2912426: the report shows three
// compaction summaries, one after the verdict, and the door call ran 22
// minutes with no output; 20261021T205639Z-al8960ofc-stepfun-2505628 is the
// same silent overrun killed by a 900 s caller timeout.
//
// This plugin only declines that synthetic continue once a verdict block has
// been completed in the session. Compaction itself, every timeout, the gated
// shell, and every report check are unchanged; a compaction before the verdict
// still continues as before.
//
// OpenCode calls every export of a plugin file as a plugin, so this file
// exports exactly one function and nothing else.

const VERDICT_BLOCK = /^## Verdict[ \t]*\r?\n[ \t]*(APPROVE|REJECT|BLOCKED)[ \t]*\r?$/m

export const StepfunVerdictStop = async () => {
  const delivered = new Set()
  return {
    "experimental.text.complete": async (input, output) => {
      if (input && input.sessionID && output && typeof output.text === "string" && VERDICT_BLOCK.test(output.text)) {
        delivered.add(input.sessionID)
      }
    },
    "experimental.compaction.autocontinue": async (input, output) => {
      if (input && delivered.has(input.sessionID) && output) output.enabled = false
    },
  }
}
