#!/usr/bin/env python3
"""Truthful usage from DeepSeek responses, qualified OpenCode step events, and
Muse Code durable-store model_completed events.

Owner: #333. The adapters share this formatter; no prompt or response text is
returned. OpenCode 1.18.12 normalizes absent counters to zero, so its observed
numbers never claim to recover missingness from the original provider. The
muse-code adapter reads the CLI's own durable session store, scoped to one run,
reports no total because the store carries none, and prices the turn from the
CLI's first-party model catalog whenever that row is readable.
"""
import argparse
import datetime
import decimal
import json
import math
import os
import pathlib
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


MUSE_CODE_FIELDS = ('input', 'cache_read', 'cache_write', 'output', 'reasoning', 'total')


def muse_code_unavailable(reason):
    return {'scope': 'turn', 'counters': {name: None for name in (*MUSE_CODE_FIELDS, 'cost')},
            'completeness': 'unavailable', 'availability_reason': reason}


def catalog_price(value):
    """A per-million catalog price as an exact positive decimal, else None."""
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        return None
    try:
        price = decimal.Decimal(str(value).strip())
    except decimal.InvalidOperation:
        return None
    return price if price.is_finite() and price > 0 else None


def muse_code_is_link(path):
    """A symlink or, on Windows Python 3.12+, a directory junction.

    Path.is_symlink() alone reports junctions as regular directories on
    Windows, and junctions need no special privilege to create."""
    if path.is_symlink():
        return True
    isjunction = getattr(os.path, 'isjunction', None)
    return bool(isjunction and isjunction(path))


def muse_code_catalog_row(path, model):
    """The model's row from the CLI's first-party catalog beside the sessions
    tree, or None when no truthful row exists. Every non-linked *.json sibling
    must be a valid first-party catalog file (source provider_catalog, rows
    array) — an unreadable or foreign sibling could hide a duplicate row, so
    uniqueness is unprovable and nothing is priced. The model's row must then
    be unique across the files and belong to the meta provider. The file name
    is a provider/profile encoding that changes between builds; only the *.json
    glob and the model_id selection are stable. Linked files and linked catalog
    directories are refused, matching the doctor's catalog checks; everything
    above the muse root is the calling wrapper's verified private store."""
    if not model:
        return None
    sessions = next((parent for parent in path.parents if parent.name == 'sessions'), None)
    if sessions is None:
        return None
    muse_root = sessions.parent
    catalog_dir = muse_root / 'model-catalog'
    if muse_code_is_link(muse_root) or muse_code_is_link(catalog_dir):
        return None
    try:
        files = sorted(catalog_dir.glob('*.json'))
    except OSError:
        return None
    candidates = []
    for file in files:
        if muse_code_is_link(file):
            continue
        try:
            catalog = json.loads(file.read_text(encoding='utf-8-sig'))
        except (OSError, ValueError):
            return None
        if not (isinstance(catalog, dict) and catalog.get('source') == 'provider_catalog'):
            return None
        rows = catalog.get('rows')
        if not isinstance(rows, list):
            return None
        for row in rows:
            if isinstance(row, dict) and row.get('model_id') == model:
                candidates.append(row)
    if len(candidates) != 1 or candidates[0].get('provider_id') != 'meta':
        return None
    return candidates[0]


def muse_code_catalog_cost(counters, row):
    """Catalog-priced estimate from the summed counters, in the row's currency.

    The store's input counter already includes the cached portion, so cached
    tokens are priced at the cached rate and never again at the input rate.
    Only a row that is itself Meta first-party (provider_id meta) is priced,
    whatever path handed it in. Returns (estimate, currency); (None, None)
    whenever anything needed to price truthfully is missing, malformed, or
    unrepresentable."""
    if not isinstance(row, dict) or row.get('provider_id') != 'meta':
        return None, None
    cost = row.get('cost')
    if not isinstance(cost, dict):
        return None, None
    prices = {name: catalog_price(cost.get(name)) for name in ('input', 'output', 'cached')}
    currency = cost.get('currency')
    if any(price is None for price in prices.values()):
        return None, None
    if not isinstance(currency, str) or not currency:
        return None, None
    input_tokens, cached, output = counters['input'], counters['cache_read'], counters['output']
    if input_tokens is None or cached is None or output is None:
        return None, None
    try:
        per_million = ((input_tokens - cached) * prices['input']
                       + cached * prices['cached']
                       + output * prices['output'])
        total = float(per_million / decimal.Decimal(1_000_000))
    except (decimal.DecimalException, OverflowError, ValueError):
        return None, None
    # float() maps an out-of-range decimal to inf without raising; an estimate
    # that cannot be represented honestly is no estimate.
    return (total, currency) if math.isfinite(total) else (None, None)


def muse_code(events, version, run, catalog_row=None, model=''):
    """Format one run's model_completed rows. Pricing happens only when every
    row names the requested model: a fallback or mixed-model run has no single
    catalog price, and attributing one model's price to another's tokens would
    be a false estimate."""
    pin = pathlib.Path(__file__).resolve().parents[1] / 'config' / 'muse-code' / 'version'
    try:
        pinned = pin.read_text(encoding='utf-8-sig').strip()
    except OSError:
        return muse_code_unavailable('unqualified-muse-code-version')
    if not pinned or version != pinned:
        return muse_code_unavailable('unqualified-muse-code-version')
    if not run:
        return muse_code_unavailable('no-model-completed-for-run')
    rows = []
    for event in events:
        if not isinstance(event, dict):
            return muse_code_unavailable('durable-store-unreadable')
        if event.get('payload_type') != 'runtime.session':
            continue
        payload = event.get('payload')
        inner = payload.get('event') if isinstance(payload, dict) else None
        if not isinstance(inner, dict) or inner.get('kind') != 'model_completed':
            continue
        if payload.get('run_id') != run:  # Other runs in the shared session log are not this turn.
            continue
        usage = inner.get('usage')
        if not isinstance(usage, dict):
            usage = {}
        rows.append({'model': inner.get('model'),
                     'input': number(usage.get('input_tokens')),
                     'cache_read': number(usage.get('cache_read_tokens')),
                     'cache_write': number(usage.get('cache_write_tokens')),
                     'output': number(usage.get('output_tokens')),
                     'reasoning': number(usage.get('reasoning_tokens'))})
    if not rows:
        return muse_code_unavailable('no-model-completed-for-run')
    coherent = all(row['input'] is None or row['cache_read'] is None or row['cache_read'] <= row['input']
                   for row in rows)
    counters = {key: add([row[key] for row in rows]) for key in MUSE_CODE_FIELDS[:5]}
    if not coherent:
        counters['cache_read'] = None
    counters['total'] = None  # The store reports no per-run total; never invent one.
    counters['cost'] = None
    complete = coherent and counters['input'] is not None and counters['output'] is not None
    same_model = bool(model) and all(row['model'] == model for row in rows)
    estimate, currency = muse_code_catalog_cost(counters, catalog_row) if same_model else (None, None)
    return {
        'scope': 'turn', 'counters': counters, 'model_calls': len(rows),
        'counter_provenance': 'muse-code-%s-durable-store-model-completed' % version,
        'counting_semantics': 'input includes cache_read; output includes reasoning; store has no total; do not add overlapping fields',
        'completeness': 'core-complete' if complete else 'partial',
        'availability_reason': None if complete else 'incomplete-or-invalid-model-completed-counters',
        'catalog_cost_estimate': estimate,
        'catalog_cost_currency': currency,
        'cost_provenance': 'first-party model catalog price; estimate, not billed cost',
    }


def muse_code_read(path, version, run, model=''):
    try:
        with open(path, encoding='utf-8-sig') as source:
            events = [json.loads(line) for line in source if line.strip()]
    except (OSError, ValueError):
        return muse_code_unavailable('durable-store-unreadable')
    return muse_code(events, version, run, muse_code_catalog_row(pathlib.Path(path), model), model)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('adapter', choices=('deepseek', 'muse-code', 'opencode'))
    parser.add_argument('input_file')
    parser.add_argument('--version', default='')
    parser.add_argument('--provider', required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--session', default='')
    parser.add_argument('--run', default='')
    args = parser.parse_args()
    if args.adapter == 'muse-code':
        result = muse_code_read(args.input_file, args.version, args.run, args.model)
    else:
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
