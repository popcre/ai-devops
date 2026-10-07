"""Incremental provider-error inspection for the existing owned-tree supervisor.

No network, subprocesses, log copies, assistant text or tool output. Receipts
contain normalized refusal evidence, never arbitrary provider response content.
"""
from __future__ import annotations

import json
import datetime
import os
import re
import time
from pathlib import Path

from reviewer_admission import credit_match_text

PROVIDERS = frozenset(("grok", "muse", "qwen", "gemini", "deepseek", "stepfun", "glm"))
LIMIT = 65536
INTERVAL = .25


def qwen_monthly_reset(message: str, observed: datetime.datetime | None = None) -> str | None:
    """Resolve the actual International one-month Token Plan refusal grammar.

    A partial month/day is authority only when exactly one future UTC date lies
    within the plan's bounded monthly window; arbitrary dates remain unknown.
    """
    frame = re.fullmatch(r"\[API Error: ([^\r\n]*)\]", message)
    if frame:
        message = frame.group(1)
    match = re.fullmatch(r"Quota exhausted: Your token-plan 1-month quota has been exhausted\. The quota will reset at ((?:\d{4}-)?\d{2}-\d{2} \d{2}:\d{2}:\d{2}) UTC\.", message)
    if not match:
        return None
    observed = observed or datetime.datetime.now(datetime.timezone.utc)
    observed = observed.astimezone(datetime.timezone.utc)
    raw = match.group(1)
    values = [raw] if len(raw) == 19 else [f"{year}-{raw}" for year in (observed.year, observed.year + 1)]
    candidates = []
    for value in values:
        try:
            date = datetime.datetime.strptime(value, "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
        except ValueError:
            continue
        if observed < date <= observed + datetime.timedelta(days=32):
            candidates.append(date)
    if len(candidates) != 1:
        return None
    return candidates[0].isoformat().replace("+00:00", "Z")


def error_payload(provider: str, row: object) -> object | None:
    """Accept exact provider error envelopes; deliberately ignore answer fields."""
    if not isinstance(row, dict):
        return None
    kind = row.get("type", "")
    if kind in ("assistant", "text", "tool_use", "tool_result", "user"):
        return None
    if kind == "error" and isinstance(row.get("error"), (dict, str)):
        return row["error"]
    if provider == "muse" and re.search(r"(?:terminal\.failed|error|fail)", str(row.get("payload_type", ""))):
        payload = row.get("payload")
        if isinstance(payload, dict):
            return {k: v for k, v in payload.items() if k not in ("text", "response", "content")}
    if provider == "gemini":
        if row.get("event") == "result":
            return error_payload(provider, row.get("result"))
        if row.get("status") != "SUCCESS" and isinstance(row.get("error"), (dict, str)):
            return row["error"]
    if provider == "qwen" and kind == "result":
        result = row.get("result")
        # The CLI places its own API refusal in an otherwise successful result.
        if isinstance(result, str) and re.fullmatch(r"\[API Error: [^\r\n]*\]", result):
            return {"message": result}
        if row.get("is_error") is True:
            return row.get("error") or {"message": result}
    # The direct DeepSeek HTTP API's documented error body has only .error.
    # Unknown event kinds never inherit that shape: they may carry tool output.
    if provider == "deepseek" and not kind and set(row) == {"error"} and isinstance(row.get("error"), dict):
        return row["error"]
    return None


def refusal(provider: str, error: object) -> dict | None:
    try:
        text = json.dumps(error, ensure_ascii=True) if not isinstance(error, str) else error
    except (ValueError, TypeError, RecursionError):
        return None
    credit = credit_match_text(text.lower(), provider)
    allowance = ((provider == "qwen" and bool(re.search(r"token.plan.{0,80}quota.{0,30}exhaust", text, re.I)))
                 or (provider == "glm" and bool(re.search(r"limit exhausted|\b1310\b", text, re.I)))
                 or (provider == "gemini" and bool(re.search(r"quota_exhausted|daily quota.{0,30}exhaust", text, re.I))))
    if not credit and not allowance:
        return None
    message = "out of credits" if credit else "subscription quota exhausted"
    code = "Arrearage" if provider == "qwen" and credit else ("1310" if provider == "glm" and allowance else "credit_exhausted" if credit else "quota_exhausted")
    receipt = {"provider": provider, "failure_class": "out-of-credit" if credit else "allowance-exhausted",
               "error": {"code": code, "message": message}}
    # Preserve only explicit provider dates, never infer from retry-after/backoff.
    if isinstance(error, dict):
        for field in ("reset_at", "resetAt", "quota_reset_at"):
            value = error.get(field)
            if isinstance(value, str) and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:Z|[+-]\d\d:\d\d)", value):
                receipt["provider_reset_at"] = value
                break
    reset = re.search(r"reset at (\d{1,4}-\d{1,2}(?:-\d{1,2})? \d{1,2}:\d\d(?::\d\d)?(?: UTC)?)", text, re.I)
    if reset:
        receipt["provider_quota_reset_at"] = reset.group(1)
        receipt["error"]["message"] += "; quota will reset at " + reset.group(1)
    if provider == "qwen" and allowance:
        message = error.get("message") if isinstance(error, dict) else error
        resolved = qwen_monthly_reset(message) if isinstance(message, str) else None
        if resolved:
            receipt["reset_at"] = resolved
            receipt["reset_source"] = "qwen-international-monthly-token-plan-error"
    return receipt


class Reader:
    def __init__(self, path: str, stderr: bool):
        self.path, self.stderr = path, stderr
        self.offset = 0
        self.pending = b""
        self.identity = None
        self.bytes_read = 0
        self.discard_line = False
        self.stderr_error_frame = False

    def read(self, provider: str) -> dict | None:
        try:
            with open(self.path, "rb") as handle:
                stat = os.fstat(handle.fileno())
                identity = (stat.st_dev, stat.st_ino)
                if self.identity != identity or stat.st_size < self.offset:
                    self.offset, self.pending, self.discard_line = 0, b"", False
                    self.stderr_error_frame = False
                self.identity = identity
                handle.seek(self.offset)
                data = handle.read(LIMIT)
                self.offset += len(data)
        except (FileNotFoundError, PermissionError, OSError):
            return None
        self.bytes_read += len(data)
        if not data:
            return None
        pieces = (self.pending + data).split(b"\n")
        self.pending = pieces.pop()
        for line in pieces:
            if self.discard_line:
                self.discard_line = False
                continue
            hit = self.parse(provider, line)
            if hit:
                return hit
        if len(self.pending) > LIMIT:
            self.pending = b""
            self.discard_line = True
        if not self.discard_line:
            return self.parse(provider, self.pending)
        return None

    def parse(self, provider: str, line: bytes) -> dict | None:
        if not line or len(line) > LIMIT:
            return None
        text = line.decode("utf-8", "replace").strip()
        try:
            row = json.loads(text)
        except (ValueError, RecursionError):
            if provider == "stepfun" and re.match(r"^4\d\d: \{", text):
                try:
                    return refusal(provider, json.loads(text.split(": ", 1)[1]))
                except (ValueError, RecursionError):
                    return None
            # Stderr must explicitly identify a provider/API error. JSON-looking
            # incomplete fragments stay buffered; arbitrary quoted text is ignored.
            if self.stderr and re.match(r"^(?:Error:|API error)", text, re.I):
                self.stderr_error_frame = "{" in text
                return refusal(provider, text)
            if self.stderr and self.stderr_error_frame and re.match(r'^"message"\s*:', text):
                return refusal(provider, text)
            if text == "}":
                self.stderr_error_frame = False
            return None
        error = error_payload(provider, row)
        return refusal(provider, error) if error is not None else None


class Monitor:
    def __init__(self, provider: str, output: str, stderr: str, marker: str):
        if provider not in PROVIDERS:
            raise ValueError("unsupported credit provider")
        self.provider, self.marker = provider, marker
        if os.path.lexists(marker):
            raise ValueError("credit receipt already exists; retain the original refusal")
        self.readers = [Reader(output, False), Reader(stderr, True)]
        self.next_check = 0.
        self.hit = False
        self.publication_failed = False

    def safe_check(self) -> bool:
        try:
            return self.check()
        except OSError:
            self.publication_failed = True
            return True # The supervisor must tear down its own tree on failure.

    def check(self) -> bool:
        if self.hit:
            return True
        now = time.monotonic()
        if now < self.next_check:
            return False
        self.next_check = now + INTERVAL
        for reader in self.readers:
            receipt = reader.read(self.provider)
            if receipt:
                # mkstemp-reserved parent directory belongs to this invocation.
                descriptor = os.open(self.marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
                    json.dump(receipt, handle, separators=(",", ":"))
                    handle.write("\n")
                os.chmod(self.marker, 0o600)
                self.hit = True
                return True
        return False
