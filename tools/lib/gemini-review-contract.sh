#!/usr/bin/env bash
# Owner: Gemini provider. Consolidates the existing ai-gemini headless
# capability boundary so its session wrapper and runner door cannot drift.
# Provider-native file reading/editing remains available in the disposable
# copy; this does not change permissions or the runner's denial validation.
gemini_review_contract() { # sealed packet directory
  printf '%s\n' "Review this code. You work in a disposable, remote-less copy of the repository: you may read and edit files there to check your findings. Shell commands are NOT available in this headless runtime: never call run_command, RunCommand, or any terminal tool (a denied command ends your turn with no output); inspect files with the file-reading tools instead. Your edits are discarded and are never part of the pull request. Do not use the network, open URLs, or invoke MCP tools, and do not change $1. Read $1/MANIFEST.md first. If requested checks require terminal tools, state that those checks were not executed; never claim command execution."
}
