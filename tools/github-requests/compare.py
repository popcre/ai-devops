#!/usr/bin/env python3
"""Conditional paired-cohort arithmetic for #658; never grants programme acceptance.

Consumes scrubbed observations, not raw responses. Source/clock/census qualification
must be established by the owning live supervisors. This module cannot authenticate
an edited JSON artifact. Reuses #660's measurement namespace; consolidate into the
existing reporter once the live cohort interface is qualified.
"""
import argparse
import collections
import hashlib
import json
import os
import re
import stat

LABELS = {
    'pr_wait': {'merged', 'closed', 'checks_failed', 'ejected', 'deadline'},
    'blocker_watch_tick': {'completed'},
    'blocker_watch_wake': {'completed', 'failed'},
    'blocker_watch_alarm': {'completed', 'failed'},
    'blocker_watch_links': {'completed', 'failed'},
    'verify_dispatch': {'dispatched', 'duplicate_refused', 'failed'},
    'verify_status': {'completed', 'failed'},
    'verify_cancel': {'cancel_requested', 'refused', 'failed'},
    'transcript_privacy': {'verified', 'refused', 'failed', 'skipped'},
}
KEYS = {'case_id', 'operation', 'outcome', 'observed_completed_writes',
        'failed_write_attempts', 'observed_external_writes', 'complete',
        'graphql_points', 'replay_reads', 'unchanged_writes', 'duration_ms', 'detection_ms'}


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate field')
        result[key] = value
    return result


def integer(value):
    return type(value) is int and 0 <= value <= 1000000000


def validate(data, phase):
    if (type(data) is not dict or set(data) != {'schema', 'phase', 'workload_kind', 'source_sha', 'observations'}
            or type(data['schema']) is not int or data['schema'] != 1 or data['phase'] != phase
            or data['workload_kind'] not in {'natural_live', 'offline_trace_replay'}
            or not isinstance(data['source_sha'], str) or not re.fullmatch('[0-9a-f]{40}', data['source_sha'])
            or type(data['observations']) is not list or len(data['observations']) > 100000):
        raise ValueError('invalid cohort')
    seen = set()
    for row in data['observations']:
        if (type(row) is not dict or set(row) != KEYS or row['operation'] not in LABELS
                or row['outcome'] not in LABELS[row['operation']] or type(row['complete']) is not bool
                or not isinstance(row['case_id'], str) or not re.fullmatch('[0-9a-f]{32}', row['case_id'])
                or row['case_id'] in seen):
            raise ValueError('invalid observation')
        seen.add(row['case_id'])
        for field in ('observed_completed_writes', 'failed_write_attempts', 'observed_external_writes',
                      'graphql_points', 'replay_reads', 'unchanged_writes'):
            if row[field] is not None and not integer(row[field]):
                raise ValueError('invalid count')
        for field in ('duration_ms', 'detection_ms'):
            interval = row[field]
            if interval is not None and (type(interval) is not list or len(interval) != 2
                    or not all(integer(v) for v in interval) or interval[0] > interval[1]):
                raise ValueError('invalid interval')
    return data


def load(path, phase):
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0))
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > 8388608:
            raise ValueError('invalid artifact')
        raw = stream.read(8388609)
    if len(raw) > 8388608:
        raise ValueError('invalid artifact')
    data = json.loads(raw, object_pairs_hook=unique,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError('invalid number')))
    return validate(data, phase), hashlib.sha256(raw).hexdigest()


def savings(before, after, field, threshold, known=lambda row: True):
    if not before or any(row[field] is None or not known(row) for row in before + after):
        return {'state': 'unknown', 'reason': 'missing_observations'}
    baseline = sum(row[field] for row in before)
    candidate = sum(row[field] for row in after)
    if baseline == 0:
        return {'state': 'unknown' if candidate == 0 else 'fail', 'reason': 'zero_baseline',
                'baseline': baseline, 'candidate': candidate}
    return {'state': 'pass' if candidate * 100 <= baseline * (100 - threshold) else 'fail',
            'baseline': baseline, 'candidate': candidate,
            'reduction_percent': (baseline - candidate) * 100 / baseline}


def p95(rows, field):
    if len(rows) < 20 or any(row[field] is None for row in rows):
        return None
    index = (95 * len(rows) + 99) // 100 - 1
    return [sorted(row[field][bound] for row in rows)[index] for bound in (0, 1)]


def compare(baseline, candidate):
    validate(baseline, 'baseline'); validate(candidate, 'candidate')
    result = {'schema': 1, 'programme_acceptance': 'not_evaluated', 'http_requests': None,
              'scope': 'paired supplied observations; source/clock/census authenticity not granted by this arithmetic',
              'workload_kind': baseline['workload_kind'], 'operations': {}}
    before = {row['case_id']: row for row in baseline['observations']}
    after = {row['case_id']: row for row in candidate['observations']}
    if (baseline['workload_kind'] != candidate['workload_kind'] or not before or before.keys() != after.keys()
            or any((row['operation'], row['outcome']) != (after[key]['operation'], after[key]['outcome'])
                   for key, row in before.items())):
        result['equivalence'] = 'fail'
        result['reason'] = 'unmatched_workload_or_terminal_outcomes'
        return result
    result['equivalence'] = 'pass'
    result['paired_outcomes'] = len(before)
    groups = collections.defaultdict(lambda: ([], []))
    for key, row in before.items():
        if row['outcome'] in {'deadline', 'failed', 'refused', 'duplicate_refused', 'skipped'}:
            continue
        groups[row['operation']][0].append(row)
        groups[row['operation']][1].append(after[key])
    for operation, (left, right) in sorted(groups.items()):
        item = {'equivalent_command_outcomes': len(left), 'sample_floor': 'pass' if len(left) >= 20 else 'unknown'}
        if len(left) < 20:
            item['reason'] = 'fewer_than_twenty_equivalent_outcomes'
            result['operations'][operation] = item
            continue
        complete = lambda r: r['complete'] and r['failed_write_attempts'] == 0 and r['observed_external_writes'] == 0
        item['managed_observed_write_reduction_30_percent'] = savings(left, right, 'observed_completed_writes', 30, complete)
        item['graphql_point_reduction_30_percent'] = savings(left, right, 'graphql_points', 30)
        item['duplicate_read_reduction_50_percent'] = savings(left, right, 'replay_reads', 50)
        writes = [row['unchanged_writes'] for row in right]
        item['zero_duplicate_unchanged_writes'] = ('unknown' if any(v is None for v in writes)
                                                  else 'pass' if sum(writes) == 0 else 'fail')
        first, second = p95(left, 'duration_ms'), p95(right, 'duration_ms')
        latency = {'state': 'unknown', 'baseline_p95_ms': first, 'candidate_p95_ms': second}
        if first is not None and second is not None and first[0] > 0:
            latency['state'] = ('pass' if second[1] * 100 <= first[0] * 105 else
                                'fail' if second[0] * 100 > first[1] * 105 else 'unknown')
        item['p95_duration_within_5_percent'] = latency
        ceiling = 300000 if operation == 'pr_wait' else 600000 if operation.startswith('blocker_watch_') else None
        if ceiling is not None:
            bounds = [row['detection_ms'] for row in right]
            item['detection_ceiling'] = ('unknown' if any(v is None for v in bounds) else
                                        'pass' if max(v[1] for v in bounds) <= ceiling else
                                        'fail' if max(v[0] for v in bounds) > ceiling else 'unknown')
        result['operations'][operation] = item
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline'); parser.add_argument('candidate')
    args = parser.parse_args()
    try:
        baseline, first = load(args.baseline, 'baseline')
        candidate, second = load(args.candidate, 'candidate')
        result = compare(baseline, candidate)
        result['input_sha256'] = {'baseline': first, 'candidate': second}
        print(json.dumps(result, sort_keys=True, allow_nan=False))
    except (OSError, ValueError, TypeError, KeyError, RecursionError):
        parser.exit(2, 'invalid cohort artifact; no acceptance result produced\n')


if __name__ == '__main__':
    main()
