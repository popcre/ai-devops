# grok-paid-keys.sh — the one list of xAI/Grok paid API-key variables.
#
# Owner rule (Albert, 2026-10-07, "remove the paid fallback"): Grok runs only
# on the subscription OAuth login (~/.grok/auth.json) and never bills a paid
# API key. Every Grok launcher (bin/ai-grok-review, bin/ai-grok-implement,
# tools/lib/review-doors/grok.sh) sources this file and calls
# grok_strip_paid_keys before any grok process starts, so no child inherits a
# key. Unsetting happens in-process: no name or value ever reaches argv.
# Names come from the grok 1.0.44 binary (XAI_API_KEY, GROK_CODE_XAI_API_KEY,
# GROK_DEPLOYMENT_KEY) plus GROK_API_KEY and any XAI_* / GROK_*API_KEY.

grok_paid_key_names() { # prints one exported paid-key variable name per line
  local n
  for n in $(compgen -e); do
    case "$n" in
      XAI_*|GROK_*API_KEY|GROK_*_XAI_*|GROK_DEPLOYMENT_KEY) printf '%s\n' "$n" ;;
    esac
  done
}

grok_strip_paid_keys() { # unset every paid-key variable in the current shell
  local n
  for n in XAI_API_KEY GROK_CODE_XAI_API_KEY GROK_API_KEY GROK_DEPLOYMENT_KEY $(grok_paid_key_names); do
    unset "$n" 2>/dev/null || true
  done
}
