#!/usr/bin/env python3
"""Check a task-gate policy against config/task-gates.schema.json.

Why this exists rather than a library: the machines that run these suites are
not guaranteed to have `jsonschema` installed, and a contract that can only be
checked where an optional dependency happens to be present is not a contract.
This validates the small, closed subset of JSON Schema the task-gate schema
actually uses, and it fails loudly on any keyword it does not understand, so the
schema can never quietly grow past what is being enforced.

Usage:
  validate-task-gates.py [--schema PATH] POLICY [POLICY ...]

Exit status: 0 valid, 1 invalid (reasons on stdout), 2 usage or unreadable file.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

KNOWN = {
    "$schema", "$id", "$defs", "$ref", "title", "description",
    "type", "const", "required", "properties", "additionalProperties",
    "items", "minItems", "minLength", "minProperties", "minimum", "uniqueItems",
}
TYPES = {
    "object": dict, "array": list, "string": str,
    "integer": int, "number": (int, float), "boolean": bool, "null": type(None),
}


def resolve(schema, root):
    seen = 0
    while "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/"):
            raise ValueError("only local $ref is supported: %s" % ref)
        node = root
        for part in ref[2:].split("/"):
            node = node[part]
        merged = {k: v for k, v in schema.items() if k != "$ref"}
        schema = dict(node, **merged)
        seen += 1
        if seen > 10:
            raise ValueError("$ref chain too deep: %s" % ref)
    return schema


def check(value, schema, root, path, errors):
    schema = resolve(schema, root)
    unknown = set(schema) - KNOWN
    if unknown:
        raise ValueError("schema uses unsupported keywords at %s: %s"
                         % (path, ", ".join(sorted(unknown))))

    if "type" in schema:
        wanted = schema["type"]
        wanted = wanted if isinstance(wanted, list) else [wanted]
        # JSON has no separate boolean-vs-integer, so keep them apart by hand.
        ok = any(
            isinstance(value, TYPES[t]) and not (t in ("integer", "number") and isinstance(value, bool))
            for t in wanted
        )
        if not ok:
            errors.append("%s: expected %s, found %s" % (path, "/".join(wanted), type(value).__name__))
            return
    if "const" in schema and value != schema["const"]:
        errors.append("%s: must be %r, found %r" % (path, schema["const"], value))
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append("%s: must not be empty" % path)
    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append("%s: must be at least %s" % (path, schema["minimum"]))
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append("%s: needs at least %d entries" % (path, schema["minItems"]))
        if schema.get("uniqueItems") and len(value) != len(set(map(json.dumps, value))):
            errors.append("%s: entries must be unique" % path)
        if "items" in schema:
            for i, item in enumerate(value):
                check(item, schema["items"], root, "%s[%d]" % (path, i), errors)
    if isinstance(value, dict):
        if len(value) < schema.get("minProperties", 0):
            errors.append("%s: must declare at least %d entries" % (path, schema["minProperties"]))
        for name in schema.get("required", []):
            if name not in value:
                errors.append("%s: missing required key '%s'" % (path, name))
        props = schema.get("properties", {})
        extra = schema.get("additionalProperties", True)
        for key, item in value.items():
            where = "%s.%s" % (path, key)
            if key in props:
                check(item, props[key], root, where, errors)
            elif extra is False:
                errors.append("%s: unknown key '%s'" % (path, key))
            elif isinstance(extra, dict):
                check(item, extra, root, where, errors)


def cross_check(policy, path, errors):
    """Agreements the shape alone cannot express."""
    classes = policy.get("change_classes")
    actions = policy.get("actions")
    if classes is None or actions is None:
        return  # a consumer declaration does not carry the central tables
    known_class, known_action = set(classes), set(actions)

    def named_classes(node, where):
        for rule in node.get("paths", []) or []:
            if rule.get("class") not in known_class:
                errors.append("%s: %s names an undeclared class '%s'" % (path, where, rule.get("class")))
        for cls, gate in (node.get("gates") or {}).items():
            if cls not in known_class:
                errors.append("%s: %s gates an undeclared class '%s'" % (path, where, cls))
            for action in (gate or {}).get("forbidden_actions", []):
                if action not in known_action:
                    errors.append("%s: %s forbids an undeclared action '%s'" % (path, where, action))

    named_classes(policy.get("default", {}), "default")
    for rule in policy.get("rules", []) or []:
        named_classes(rule, "rule %s" % rule.get("match"))

    fallback = policy.get("default", {}).get("fallback_class")
    if fallback in known_class:
        weakest = min(classes, key=lambda c: classes[c]["rank"])
        if fallback == weakest:
            errors.append("%s: the fallback class is the weakest class, so an "
                          "unrecognised file would silently downgrade the task" % path)
    elif fallback is not None:
        errors.append("%s: fallback_class '%s' is not a declared class" % (path, fallback))


def main(argv=None):
    here = pathlib.Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default=str(here / "config" / "task-gates.schema.json"))
    ap.add_argument("policy", nargs="+")
    args = ap.parse_args(argv)

    try:
        root = json.loads(pathlib.Path(args.schema).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print("cannot read schema: %s" % exc)
        return 2

    bad = 0
    for name in args.policy:
        try:
            policy = json.loads(pathlib.Path(name).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print("cannot read policy: %s" % exc)
            bad += 1
            continue
        errors = []
        check(policy, root, root, pathlib.Path(name).name, errors)
        cross_check(policy, pathlib.Path(name).name, errors)
        if errors:
            bad += 1
            for line in errors:
                print(line)
        else:
            print("ok %s" % name)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
