"""Muse Code durable-store usage cases invoked by the Muse Code engine suite.

Rows mirror the private store shape verified live on 2026-09-17 (plan
ai-muse-native-engine-parity §6a): token counters live under
.payload.event.usage on runtime.session / model_completed rows. No prompt or
response text is included.
"""
import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('reviewer_usage', ROOT / 'tools/reviewer_usage.py')
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)
PINNED = (ROOT / 'config' / 'muse-code' / 'version').read_text(encoding='utf-8').strip()
RUN = '15bc2f6e-c7db-4d34-a234-c7f5668ff30b'
DECOY = '99999999-9999-4999-8999-999999999999'


def completed(run, i, o, cr, cw, r):
    return {'payload_type': 'runtime.session',
            'payload': {'run_id': run,
                        'event': {'kind': 'model_completed', 'model': 'muse-spark-1.3-contributor',
                                  'usage': {'input_tokens': i, 'output_tokens': o, 'cached_tokens': cr,
                                            'cache_write_tokens': cw, 'cache_read_tokens': cr,
                                            'reasoning_tokens': r}}}}


# Mirrors the first-party catalog row verified live on 2026-09-17 (plan
# ai-muse-native-engine-parity §6c); prices are per-million strings.
CATALOG_ROW = {'model_id': 'muse-spark-1.3-contributor', 'provider_id': 'meta',
               'visibility': 'visible',
               'context_limit': 1007997, 'output_limit': 128000, 'is_current': True,
               'cost': {'input': '0.10', 'output': '0.20', 'cached': '0.002', 'currency': 'USD'}}


def catalog_json(rows=None, source='provider_catalog', provider='meta'):
    row = dict(CATALOG_ROW, provider_id=provider)
    return json.dumps({'profile_id': 'tbh', 'provider_id': 'meta',
                       'rows': [row] if rows is None else rows,
                       'schema_version': 1, 'source': source})


class MuseCodeUsageCases(unittest.TestCase):
    def result(self, events, version=PINNED, run=RUN, catalog_row=None,
               model='muse-spark-1.3-contributor'):
        return usage.muse_code(events, version, run, catalog_row=catalog_row, model=model)

    def test_maps_sums_and_scopes_model_completed_rows(self):
        events = [completed(RUN, 19835, 472, 8561, 0, 387),
                  {'payload_type': 'session.end'},
                  completed(RUN, 100, 28, 0, 0, 3),
                  completed(DECOY, 999999, 999999, 999999, 999999, 999999)]
        result = self.result(events)
        self.assertEqual(result['counters'], {'input': 19935, 'cache_read': 8561, 'cache_write': 0,
                                              'output': 500, 'reasoning': 390, 'total': None, 'cost': None})
        self.assertEqual(result['model_calls'], 2)
        self.assertEqual(result['completeness'], 'core-complete')
        self.assertIsNone(result['availability_reason'])
        self.assertEqual(result['counter_provenance'], 'muse-code-%s-durable-store-model-completed' % PINNED)
        self.assertIn('input includes cache_read', result['counting_semantics'])

    def test_unmatched_run_is_unavailable(self):
        result = self.result([completed(DECOY, 1, 2, 0, 0, 0)])
        self.assertEqual(result['completeness'], 'unavailable')
        self.assertEqual(result['availability_reason'], 'no-model-completed-for-run')
        self.assertIsNone(result['counters']['input'])

    def test_empty_run_scope_is_refused(self):
        result = self.result([completed(RUN, 1, 2, 0, 0, 0)], run='')
        self.assertEqual(result['availability_reason'], 'no-model-completed-for-run')

    def test_unqualified_runtime_does_not_reuse_semantics(self):
        result = self.result([completed(RUN, 1, 2, 0, 0, 0)], version='9.9.9')
        self.assertEqual(result['availability_reason'], 'unqualified-muse-code-version')
        self.assertIsNone(result['counters']['input'])

    def test_impossible_cache_subset_is_unknown(self):
        result = self.result([completed(RUN, 5, 2, 7, 0, 1)])
        self.assertIsNone(result['counters']['cache_read'])
        self.assertEqual(result['counters']['input'], 5)
        self.assertEqual(result['completeness'], 'partial')

    def test_invalid_counter_is_partial_never_zero(self):
        row = completed(RUN, 19835, 472, 8561, 0, 387)
        row['payload']['event']['usage']['input_tokens'] = 'many'
        result = self.result([row])
        self.assertIsNone(result['counters']['input'])
        self.assertEqual(result['completeness'], 'partial')
        self.assertEqual(result['availability_reason'], 'incomplete-or-invalid-model-completed-counters')

    def test_zero_is_preserved(self):
        result = self.result([completed(RUN, 0, 0, 0, 0, 0)])
        self.assertEqual(result['counters']['input'], 0)
        self.assertEqual(result['completeness'], 'core-complete')

    def test_non_object_row_is_unreadable(self):
        result = self.result(['junk'])
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')

    def test_reader_reports_garbage_lines_unreadable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'session.jsonl'
            path.write_text(json.dumps(completed(RUN, 1, 2, 0, 0, 0)) + '\nnot-json\n', encoding='utf-8')
            result = usage.muse_code_read(str(path), PINNED, RUN)
        self.assertEqual(result['completeness'], 'unavailable')
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')

    def test_reader_reports_missing_store_unreadable(self):
        missing = ROOT / 'tests' / 'fixtures' / 'muse-code' / 'absent-session.jsonl'
        result = usage.muse_code_read(str(missing), PINNED, RUN)
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')

    def test_catalog_prices_the_cached_portion_once(self):
        # 19835 input includes the 8561 cached tokens: the uncached 11274 pay
        # the input rate, the cached 8561 the cached rate, output the output
        # rate. (11274*0.10 + 8561*0.002 + 472*0.20) / 1e6 = 0.001238922 USD.
        result = self.result([completed(RUN, 19835, 472, 8561, 0, 387)], catalog_row=CATALOG_ROW)
        self.assertEqual(result['catalog_cost_estimate'], 0.001238922)
        self.assertEqual(result['catalog_cost_currency'], 'USD')
        self.assertEqual(result['cost_provenance'],
                         'first-party model catalog price; estimate, not billed cost')
        self.assertEqual(result['completeness'], 'core-complete')

    def test_catalog_absent_leaves_estimate_null_and_completeness_intact(self):
        result = self.result([completed(RUN, 19835, 472, 8561, 0, 387)])
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertIsNone(result['catalog_cost_currency'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_nonpositive_or_missing_price_is_never_an_estimate(self):
        for cost in ({'input': '0.10', 'output': '0.20', 'cached': '0', 'currency': 'USD'},
                     {'input': '0.10', 'output': 'cheap', 'cached': '0.002', 'currency': 'USD'},
                     {'input': '0.10', 'output': '0.20', 'cached': '0.002'},
                     {'input': '-1', 'output': '0.20', 'cached': '0.002', 'currency': 'USD'}):
            with self.subTest(cost=cost):
                result = self.result([completed(RUN, 19835, 472, 8561, 0, 387)],
                                     catalog_row=dict(CATALOG_ROW, cost=cost))
                self.assertIsNone(result['catalog_cost_estimate'])
                self.assertIsNone(result['catalog_cost_currency'])

    def test_extreme_finite_prices_never_degrade_the_usage(self):
        # Prices far outside float range are finite decimals; pricing must fall
        # back to no estimate, never raise into usage-formatting-failed and
        # never emit an infinity the JSON writer would refuse.
        for price in ('1E+999999', '1E+400'):
            with self.subTest(price=price):
                result = self.result([completed(RUN, 19835, 472, 8561, 0, 387)],
                                     catalog_row=dict(CATALOG_ROW, cost={'input': price, 'output': '0.20',
                                                                         'cached': '0.002', 'currency': 'USD'}))
                self.assertIsNone(result['catalog_cost_estimate'])
                self.assertEqual(result['completeness'], 'core-complete')

    def test_partial_counters_carry_no_estimate(self):
        row = completed(RUN, 19835, 472, 8561, 0, 387)
        row['payload']['event']['usage']['output_tokens'] = 'many'
        result = self.result([row], catalog_row=CATALOG_ROW)
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'partial')

    def test_incoherent_cache_read_carry_no_estimate(self):
        # The coherence guard drops cache_read to None; without a trustworthy
        # split of input into cached and uncached there is nothing to price.
        result = self.result([completed(RUN, 5, 2, 7, 0, 1)], catalog_row=CATALOG_ROW)
        self.assertIsNone(result['catalog_cost_estimate'])

    def test_reader_prices_from_the_catalog_beside_the_sessions_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            # Any *.json name must do: the real file name is a provider/profile
            # encoding that changes between builds.
            (catalog / 'teststub__glob.json').write_text(catalog_json(), encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertEqual(result['catalog_cost_estimate'], 0.001238922)
        self.assertEqual(result['catalog_cost_currency'], 'USD')

    def test_reader_without_a_catalog_keeps_usage_complete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 1, 2, 0, 0, 0)) + '\n', encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_duplicate_model_rows_across_files_are_ambiguity_not_price(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            catalog.joinpath('a__file.json').write_text(catalog_json(), encoding='utf-8')
            catalog.joinpath('b__file.json').write_text(catalog_json(), encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_foreign_provider_row_is_not_first_party_price(self):
        result = self.result([completed(RUN, 19835, 472, 8561, 0, 387)],
                             catalog_row=dict(CATALOG_ROW, provider_id='someone-else'))
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_non_first_party_source_file_is_never_priced_from(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            catalog.joinpath('manual__file.json').write_text(
                catalog_json(source='manual'), encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_other_model_rows_are_never_priced_with_this_models_row(self):
        # A fallback or mixed-model run has no single catalog price; charging
        # the requested model's price for another model's tokens would be a
        # false estimate.
        foreign = completed(RUN, 100, 28, 0, 0, 3)
        foreign['payload']['event']['model'] = 'muse-spark-1.3'
        result = self.result([completed(RUN, 19835, 472, 8561, 0, 387), foreign],
                             catalog_row=CATALOG_ROW)
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertIsNone(result['catalog_cost_currency'])
        self.assertEqual(result['counters']['input'], 19935)
        self.assertEqual(result['completeness'], 'core-complete')

    def test_row_without_model_identity_is_never_priced(self):
        row = completed(RUN, 19835, 472, 8561, 0, 387)
        del row['payload']['event']['model']
        result = self.result([row], catalog_row=CATALOG_ROW)
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_valid_row_with_an_unreadable_sibling_is_not_unique_enough(self):
        # A sibling that cannot be read could carry a duplicate row: uniqueness
        # is unprovable, so no price.
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            catalog.joinpath('good__file.json').write_text(catalog_json(), encoding='utf-8')
            catalog.joinpath('broken__sibling.json').write_text('not-json', encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_reader_refuses_an_unparseable_catalog_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 1, 2, 0, 0, 0)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            (catalog / 'broken__file.json').write_text('not-json', encoding='utf-8')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_reader_refuses_a_linked_catalog_file(self):
        # Parity with the doctor's linked-file refusal: a link must not supply
        # pricing attributed to the first-party catalog.
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            log = root / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
            log.parent.mkdir(parents=True)
            log.write_text(json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n', encoding='utf-8')
            catalog = root / 'muse' / 'model-catalog'
            catalog.mkdir()
            real = root / 'real-catalog.json'
            real.write_text(catalog_json(), encoding='utf-8')
            link = catalog / 'linked__file.json'
            try:
                link.symlink_to(real)
            except (OSError, NotImplementedError):
                self.skipTest('symlinks unavailable on this filesystem')
            result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
        self.assertIsNone(result['catalog_cost_estimate'])
        self.assertEqual(result['completeness'], 'core-complete')

    def test_reader_refuses_a_linked_catalog_directory(self):
        # A linked model-catalog directory (or muse root) is outside the
        # wrapper-verified private store and must not price anything. Symlinks
        # cover POSIX; on Windows, a directory junction needs no privilege.
        line = json.dumps(completed(RUN, 19835, 472, 8561, 0, 387)) + '\n'
        row_file = catalog_json()
        for target in ('model-catalog', 'muse'):
            with self.subTest(linked=target):
                with tempfile.TemporaryDirectory() as tmp:
                    root = pathlib.Path(tmp)
                    store = root / 'store'
                    if target == 'model-catalog':
                        # The log is real; only the catalog directory is a link.
                        sessions = store / 'muse' / 'sessions' / '2026' / '09' / '17' / RUN
                        sessions.mkdir(parents=True)
                        log = sessions / 'session.jsonl'
                        log.write_text(line, encoding='utf-8')
                        real = root / 'real-catalog'
                        real.mkdir()
                        real.joinpath('realstub__row.json').write_text(row_file, encoding='utf-8')
                        link = store / 'muse' / 'model-catalog'
                    else:
                        # The whole muse tree (log and catalog) lives behind a link.
                        real = root / 'real-muse'
                        real.joinpath('sessions', '2026', '09', '17', RUN).mkdir(parents=True)
                        real.joinpath('sessions', '2026', '09', '17', RUN, 'session.jsonl').write_text(
                            line, encoding='utf-8')
                        real.joinpath('model-catalog').mkdir()
                        real.joinpath('model-catalog', 'realstub__row.json').write_text(row_file, encoding='utf-8')
                        store.mkdir()
                        link = store / 'muse'
                        log = link / 'sessions' / '2026' / '09' / '17' / RUN / 'session.jsonl'
                    linked = False
                    try:
                        link.symlink_to(real, target_is_directory=True)
                        linked = True
                    except (OSError, NotImplementedError):
                        junction = subprocess.run(
                            ['cmd', '/c', 'mklink', '/J', str(link), str(real)],
                            capture_output=True)
                        linked = junction.returncode == 0 and link.exists()
                    if not linked:
                        self.skipTest('no symlink or junction support on this filesystem')
                    result = usage.muse_code_read(str(log), PINNED, RUN, 'muse-spark-1.3-contributor')
                self.assertIsNone(result['catalog_cost_estimate'])
                self.assertEqual(result['completeness'], 'core-complete')


if __name__ == '__main__':
    unittest.main()
