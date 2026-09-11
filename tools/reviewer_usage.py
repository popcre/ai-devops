#!/usr/bin/env python3
"""Truthful usage from DeepSeek responses and qualified OpenCode step events.

Owner: #333. Both adapters use this formatter; no prompt or response text is
returned. OpenCode 1.18.12 normalizes absent counters to zero, so its observed
numbers never claim to recover missingness from the original provider.
"""
import argparse
import datetime
import json
import math
import sys


def number(value, *, tokens=True):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    try:
        finite = math.isfinite(value)
    except OverflowError:
        return None
    if not finite or value < 0 or (tokens and int(value) != value):
        return None
    return int(value) if tokens else value


def add(values):
    return sum(values) if values and all(v is not None for v in values) else None


def nested(obj, *keys):
    for key in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


def deepseek(response):
    usage = response.get('usage') if isinstance(response, dict) else None
    usage = usage if isinstance(usage, dict) else {}
    fields = {
        'input': number(usage.get('prompt_tokens')),
        'cache_read': number(usage.get('prompt_cache_hit_tokens')),
        'cache_write': None,
        'output': number(usage.get('completion_tokens')),
        'reasoning': number(nested(usage, 'completion_tokens_details', 'reasoning_tokens')),
        'total': number(usage.get('total_tokens')),
        'cost': None,
    }
    coherent = not (fields['input'] is not None and fields['cache_read'] is not None
                    and fields['cache_read'] > fields['input'])
    if not coherent:
        fields['cache_read'] = None
    return {
        'scope': 'turn', 'counters': fields,
        'counter_provenance': 'provider-response.usage',
        'counting_semantics': 'input includes cache_read; output includes reasoning; do not add overlapping fields',
        'completeness': 'core-complete' if coherent and fields['input'] is not None and fields['output'] is not None else 'partial',
        'availability_reason': 'only returned valid counters; cache_write and billed cost unsupported',
        'provider_completion_id': response.get('id') if isinstance(response, dict) else None,
    }


def opencode(events, version):
    fields = ('input', 'cache_read', 'cache_write', 'output', 'reasoning', 'total')
    empty = {name: None for name in (*fields, 'cost')}
    if version != '1.18.12':
        return {'scope': 'turn', 'counters': empty, 'completeness': 'unavailable',
                'availability_reason': 'unqualified-opencode-version'}
    starts, finishes = {}, {}
    invalid = False
    last_reason = None
    for event in events:
        if not isinstance(event, dict) or event.get('type') not in ('step_start', 'step_finish'):
            continue  # Never add message aggregates to their constituent parts.
        part = event.get('part')
        if not isinstance(part, dict):
            invalid = True
            continue
        ids = (event.get('sessionID'), part.get('messageID'), part.get('id'))
        if not all(isinstance(v, str) and v for v in ids):
            invalid = True
            continue
        if part.get('sessionID', ids[0]) != ids[0]:
            invalid = True
            continue
        target = finishes if event['type'] == 'step_finish' else starts
        if ids in target:
            if target[ids] != part:
                invalid = True  # Conflicting cumulative/update events cannot be summed.
            continue
        target[ids] = part
        if event['type'] == 'step_finish':
            last_reason = part.get('reason')
    sessions = {key[0] for key in (*starts, *finishes)}
    start_messages = sorted(key[:2] for key in starts)
    finish_messages = sorted(key[:2] for key in finishes)
    complete = bool(finishes) and not invalid and len(sessions) == 1 and start_messages == finish_messages and last_reason == 'stop'
    rows = []
    adapter_costs = []
    for part in finishes.values():
        tokens = part.get('tokens')
        uncached = number(nested(tokens, 'input'))
        cached = number(nested(tokens, 'cache', 'read'))
        written = number(nested(tokens, 'cache', 'write'))
        visible = number(nested(tokens, 'output'))
        reasoning = number(nested(tokens, 'reasoning'))
        rows.append({'input': add([uncached, cached, written]), 'cache_read': cached,
                     'cache_write': written, 'output': add([visible, reasoning]),
                     'reasoning': reasoning, 'total': number(nested(tokens, 'total'))})
        adapter_costs.append(number(part.get('cost'), tokens=False))
    counters = {key: add([row[key] for row in rows]) if complete else None for key in fields}
    counters['cost'] = None  # OpenCode model-price estimates are not billed provider cost.
    all_counters = complete and all(counters[k] is not None for k in fields)
    return {
        'scope': 'turn', 'counters': counters, 'unique_steps': len(finishes),
        'counter_provenance': 'opencode-1.18.12-step-finish-adapter-values',
        'counting_semantics': 'sum unique step parts; input includes cache; output includes reasoning; message aggregates excluded',
        'completeness': 'adapter-complete-provider-missingness-unknown' if all_counters else 'partial',
        'availability_reason': 'adapter coerces absent or invalid provider counters to zero; original missingness unavailable' if all_counters else 'incomplete-conflicting-or-invalid-step-counters',
        'adapter_cost_estimate': add(adapter_costs) if complete else None,
        'cost_provenance': 'opencode model-price calculation; price-effective-date unavailable; not billed cost',
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('adapter', choices=('deepseek', 'opencode'))
    parser.add_argument('input_file')
    parser.add_argument('--version', default='')
    parser.add_argument('--provider', required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--session', default='')
    parser.add_argument('--run', default='')
    args = parser.parse_args()
    with open(args.input_file, encoding='utf-8-sig') as source:
        data = json.load(source) if args.adapter == 'deepseek' else [json.loads(line) for line in source if line.strip()]
    result = deepseek(data) if args.adapter == 'deepseek' else opencode(data, args.version)
    result.update(schema_version=1, provider=args.provider, model=args.model,
                  runtime_version=args.version or None, session_id=args.session or None,
                  run_id=args.run or None, observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    json.dump(result, sys.stdout, allow_nan=False, sort_keys=True)
    sys.stdout.write('\n')


if __name__ == '__main__':
    main()
