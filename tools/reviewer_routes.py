#!/usr/bin/env python3
"""Shared candidate reviewer routes (#2549/#2550, plan_deepseek-harness-openrouter.md).

Route data lives in config/reviewer-routes.json. This module loads and
validates it, builds the OpenCode / DeepSeek Harness runtime configuration for
one route, and owns the safe outcome mapping both entry points share (GitHub
review via bin/ai-review-simple, second opinions via bin/ai-second-opinion and
bin/ai-deepseek-agent). Nothing here is active until a caller selects a route
explicitly; every existing default stays unchanged.

Engines:
  opencode        - the pinned OpenCode runtime with a fresh private profile
  deepseek-harness - the pinned DeepSeek Harness headless profile (dsh)
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROUTES_FILE = os.environ.get("AI_REVIEWER_ROUTES_FILE") or os.path.join(
    ROOT, "config", "reviewer-routes.json")
DSH_VERSION_FILE = os.path.join(ROOT, "config", "deepseek-harness", "version")

ENGINES = ("opencode", "deepseek-harness")
OPENROUTER_URL = "https://openrouter.ai/api/v1"
# Logical reviewer ids stay separate from route ids (plan section 9 step 1).
EXPECTED_ROUTES = ("deepseek-openrouter", "muse-meta", "muse-openrouter", "hy4-openrouter")
NAME_RE = re.compile(r"^[a-z][a-z0-9-]*$")

_cache = {}


class RouteError(Exception):
    """An unknown or malformed route selection. Never retried, never defaulted."""


def _load():
    if "data" not in _cache:
        try:
            with open(ROUTES_FILE, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, ValueError) as exc:
            raise RouteError(f"route registry unreadable: {exc}") from None
        if data.get("version") != 1 or not isinstance(data.get("routes"), dict):
            raise RouteError("route registry schema mismatch")
        for rid, spec in data["routes"].items():
            if not NAME_RE.match(rid or ""):
                raise RouteError(f"malformed route id: {rid!r}")
            if spec.get("engine") not in ENGINES:
                raise RouteError(f"route {rid}: unknown engine {spec.get('engine')!r}")
            for field in ("reviewer", "model", "key_file", "key_env", "override", "timeout"):
                if not spec.get(field):
                    raise RouteError(f"route {rid}: missing {field}")
            if not re.match(r"^[A-Z][A-Z0-9_]*$", spec["key_env"]):
                raise RouteError(f"route {rid}: bad key_env {spec['key_env']!r}")
            if not re.match(r"^[A-Z][A-Z0-9_]*$", spec["override"]):
                raise RouteError(f"route {rid}: bad override {spec['override']!r}")
            if "/" not in spec["model"]:
                raise RouteError(f"route {rid}: model must be <provider>/<model>")
            if spec.get("base_url") and not spec["base_url"].startswith("https://"):
                raise RouteError(f"route {rid}: base_url must be https")
        _cache["data"] = data
    return _cache["data"]


def routes():
    """The validated route table (id -> spec copy)."""
    return {rid: dict(spec) for rid, spec in _load()["routes"].items()}


def route(route_id):
    """One validated route spec, or RouteError for anything unknown."""
    try:
        spec = _load()["routes"][route_id]
    except (KeyError, TypeError):
        raise RouteError(f"unknown reviewer route: {route_id!r}") from None
    if not NAME_RE.match(route_id or ""):
        raise RouteError(f"unknown reviewer route: {route_id!r}")
    return dict(spec)


def routes_for_reviewer(reviewer):
    """Ordered candidate routes for a logical reviewer ([] when it has none)."""
    return [rid for rid, spec in _load()["routes"].items() if spec["reviewer"] == reviewer]


def candidate_plan(rotation_order):
    """Expand a reviewer rotation into the candidate attempt list.

    Each reviewer's slot uses its candidate routes when it has any (muse:
    meta first then OpenRouter; deepseek: the OpenRouter route) and stays the
    legacy reviewer otherwise; the final Hy4 fallback runs only after the
    whole primary rotation is exhausted."""
    plan = []
    for reviewer in rotation_order:
        candidate = routes_for_reviewer(reviewer)
        plan.extend(candidate or [reviewer])
    fallback = _load().get("automatic_fallback", {}).get("final")
    if fallback and fallback in _load()["routes"]:
        plan.append(fallback)
    return plan


def opencode_provider_block(spec):
    """The OpenCode provider block for an opengine-engine route (plan section 5
    shapes, custom OpenAI-compatible connection for OpenRouter)."""
    provider_id = spec["model"].split("/", 1)[0]
    model_id = spec["model"].split("/", 1)[1]
    if provider_id == "meta-model-api":  # the direct Muse connection (existing spec)
        return {"meta-model-api": {
            "npm": "@ai-sdk/openai", "name": "Meta Model API",
            "options": {"baseURL": "https://api.meta.ai/v1",
                        "apiKey": "{env:%s}" % spec["key_env"]},
            "models": {"muse-spark-1.3-contributor": {
                "name": "Muse Spark 1.3 Contributor",
                "limit": {"context": 1048576, "output": 65536}}}}}
    return {provider_id: {
        "npm": "@ai-sdk/openai-compatible", "name": provider_id,
        "options": {"baseURL": spec["base_url"] or OPENROUTER_URL,
                    "apiKey": "{env:%s}" % spec["key_env"]},
        "models": {model_id: {
            "name": model_id, "tool_call": True,
            "limit": {"context": 1048576, "output": 65536}}}}}


def opencode_spec(route_id):
    """An ai-review-simple PROVIDERS-shaped spec for a route's OpenCode run."""
    spec = route(route_id)
    if spec["engine"] != "opencode":
        raise RouteError(f"route {route_id} does not use the OpenCode engine")
    out = {"model": spec["model"], "provider": opencode_provider_block(spec),
           "key_file": spec["key_file"], "key_env": spec["key_env"],
           "override": spec["override"], "timeout": int(spec["timeout"])}
    out["route"] = route_id
    return out


def harness_patch_yaml(spec):
    """cordis.patch.yml for a deepseek-harness route's private profile
    (validated live 2026-11-16: llm-pi-ai registers the custom adapter)."""
    if spec.get("base_url") and not spec["base_url"].startswith("https://"):
        raise RouteError("route base_url must be https")
    return (
        "- id: llm-pi-ai\n"
        "  config:\n"
        "    providers:\n"
        "      openrouter:\n"
        f"        apiKeyEnv: {spec['key_env']}\n"
        "        api: openai-completions\n"
        f"        baseURL: {spec['base_url']}\n"
        "        models:\n"
        f"          - id: {json.dumps(spec['model'])}\n"
        "- id: agent-default-model\n"
        "  config:\n"
        "    provider: openrouter\n"
        f"    model: {json.dumps(spec['model'])}\n")


def read_key(spec, secrets_dir=None):
    """A route spec's credential: explicit override env, else its key file."""
    if os.environ.get(spec["override"]):
        return os.environ[spec["override"]]
    secrets = secrets_dir or os.environ.get(
        "AI_REVIEW_SIMPLE_SECRETS_DIR", os.path.expanduser("~/.config/ai-devops/secrets"))
    try:
        with open(os.path.join(secrets, spec["key_file"])) as fh:
            raw = fh.read().strip()
    except OSError:
        return None
    return raw.splitlines()[0] if raw else None


def resolve_deepseek_harness():
    """The pinned dsh binary: override, pinned install, then PATH."""
    override = os.environ.get("AI_REVIEW_SIMPLE_DSH")
    if override:
        return override
    try:
        with open(DSH_VERSION_FILE, encoding="utf-8") as fh:
            ver = fh.read().strip()
    except OSError:
        ver = None
    if ver:
        base = os.path.expanduser(f"~/.local/lib/ai-devops/deepseek-harness/{ver}/node_modules/.bin")
        for name in (("dsh.cmd", "dsh") if os.name == "nt" else ("dsh",)):
            pinned = os.path.join(base, name)
            if os.access(pinned, os.X_OK):
                return pinned
    return None


# --- Safe outcome mapping (plan section 8). ---------------------------------
# advance: the chain may try the next connection. terminal: that review stops
# with its actual failure; no silent substitution.
_CREDIT_RE = re.compile(
    r"\b(?:status|code|http|error)[\"' :=]{0,4}(?:402|429|1113)\b|insufficient[ _]balance|"
    r"out of credits?|exceeded your current quota|(?:quota|allowance)\s+(?:exceeded|exhausted|used up)|"
    r"rate[ _-]?limit(?:ed| exceeded)|payment required", re.I)
_AUTH_RE = re.compile(
    r"\b(?:status|code|http|error)[\"' :=]{0,4}401\b|invalid[ _-]api[ _-]?key|"
    r"incorrect api key|authentication\s*(?:failed|error)|api key\s+(?:revoked|not valid|invalid)|"
    r"unauthorized", re.I)
_TRANSPORT_RE = re.compile(
    r"\b(?:status|code|http|error)[\"' :=]{0,4}5\d{2}\b|connection(?:\s+reset)?|econnrefused|"
    r"enotfound|etimedout|timed?\s*out|network|socket hang up|fetch failed|"
    r"bad gateway|service unavailable|gateway", re.I)
_OUTAGE_RE = re.compile(r"outage|degraded|(?:provider|service)[ _-]unavailable|all\b.*\bfailing", re.I)
_POLICY_RE = re.compile(
    r"\b(?:status|code|http|error)[\"' :=]{0,4}403\b|policy|refus|content[ _-]filter|"
    r"moderation|safety system|usage policy|violat(?:es|ion|ing)", re.I)
_READONLY_RE = re.compile(r"\berofs\b|read[ _-]only file system|permission denied.*write|"
                          r"write.*permission denied", re.I)


def classify(text):
    """Map failure text to (decision, kind).

    decision: "advance" (next connection may run) or "terminal" (this review
    stops with its actual failure). Order matters: an ambiguous 403 with no
    invalid-credential wording is a policy refusal, never a failover trigger."""
    text = text or ""
    if _READONLY_RE.search(text):
        return "terminal", "readonly"
    if _CREDIT_RE.search(text):
        return "advance", "credit"
    if _AUTH_RE.search(text):
        return "advance", "auth"
    if _OUTAGE_RE.search(text) and "openrouter" in text.lower():
        return "advance", "shared-outage"
    if _POLICY_RE.search(text):
        return "terminal", "policy"
    if _TRANSPORT_RE.search(text):
        return "advance", "transport"
    return "advance", "unknown"


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(prog="reviewer-routes",
                                 description="Inspect the candidate reviewer route registry.")
    ap.add_argument("--list", action="store_true", help="print route ids")
    ap.add_argument("--plan", metavar="ROTATION", help="expand a reviewer rotation")
    args = ap.parse_args(argv)
    if args.list:
        print(" ".join(sorted(_load()["routes"])))
        return 0
    if args.plan:
        print(" ".join(candidate_plan(args.plan.split())))
        return 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
