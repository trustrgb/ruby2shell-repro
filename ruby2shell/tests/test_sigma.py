"""Parse with pySigma and check normalized-event semantics using fixtures.

The small evaluator intentionally supports only the operators in these rules.
It is a reference check, not execution by a production SIEM backend.
"""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import unittest

import yaml
from sigma.collection import SigmaCollection

RULE_PATH = Path(__file__).resolve().parents[1] / 'detection' / 'sigma_ruby_crash_correlation.yml'
RULE_TEXT = RULE_PATH.read_text(encoding='utf-8-sig')
DOCUMENTS = list(yaml.safe_load_all(RULE_TEXT))
BASE_RULES = {rule['name']: rule for rule in DOCUMENTS if 'detection' in rule}
CORRELATION = next(rule['correlation'] for rule in DOCUMENTS if 'correlation' in rule)
EPOCH = datetime(2026, 11, 20, tzinfo=timezone.utc)


def matches(rule, event):
    if event.get('logsource') != rule['logsource']:
        return False
    detection = rule['detection']
    if detection['condition'] != 'selection and required_context':
        raise ValueError('Unsupported fixture-evaluator condition')
    for selection in ('selection', 'required_context'):
        for key, expected in detection[selection].items():
            field, modifier = key.split('|', 1)
            value = event.get(field)
            if modifier == 'exists':
                if (value is not None) != expected:
                    return False
            elif modifier == 'contains':
                if not isinstance(value, str) or not any(item in value for item in expected):
                    return False
            elif modifier == 're':
                if not isinstance(value, str) or re.search(expected, value) is None:
                    return False
            else:
                raise ValueError(f'Unsupported modifier: {modifier}')
    return True


def correlated(events):
    assert CORRELATION['type'] == 'temporal'
    span = CORRELATION['timespan']
    assert re.fullmatch(r'\d+m', span)
    window = timedelta(minutes=int(span[:-1]))
    groups = {}
    for event in events:
        key = tuple(event.get(field) for field in CORRELATION['group-by'])
        if any(value in (None, '') for value in key):
            continue
        for name in CORRELATION['rules']:
            if matches(BASE_RULES[name], event):
                groups.setdefault(key, []).append((event['timestamp'], name))
    for group in groups.values():
        for start, _ in group:
            seen = {name for stamp, name in group if start <= stamp <= start + window}
            if set(CORRELATION['rules']).issubset(seen):
                return True
    return False


def request(seconds=0, instance='node-a/web-1', raw=None):
    return dict(logsource={'category': 'webserver'}, service_instance=instance,
                request_raw=raw if raw is not None else '/test?input=' + '%dF' * 21,
                timestamp=EPOCH + timedelta(seconds=seconds))


def crash(seconds=20, instance='node-a/web-1', message='[BUG] Segmentation fault'):
    return dict(logsource={'category': 'application', 'product': 'ruby'},
                service_instance=instance, message=message,
                timestamp=EPOCH + timedelta(seconds=seconds))


class SigmaTests(unittest.TestCase):
    def test_pysigma_parses_and_resolves_references(self):
        collection = SigmaCollection.from_yaml(RULE_TEXT)
        self.assertEqual(len(collection.rules), 3)
        self.assertFalse(collection.errors)
        for rule in collection.rules:
            self.assertFalse(rule.errors)

    def test_matching_pair(self):
        self.assertTrue(correlated([request(), crash()]))

    def test_order_not_required(self):
        self.assertTrue(correlated([request(20), crash(0)]))

    def test_only_requests_or_only_crashes(self):
        self.assertFalse(correlated([request()] * 5))
        self.assertFalse(correlated([crash()] * 5))

    def test_different_instance(self):
        self.assertFalse(correlated([request(), crash(instance='node-b/web-1')]))

    def test_outside_window(self):
        self.assertFalse(correlated([request(), crash(61)]))

    def test_short_or_double_encoded_sequence(self):
        for raw in ('%DF' * 20, '%25DF' * 21, 'hello'):
            with self.subTest(raw=raw):
                self.assertFalse(correlated([request(raw=raw), crash()]))

    def test_missing_or_empty_instance(self):
        for instance in (None, ''):
            self.assertFalse(correlated([request(instance=instance), crash(instance=instance)]))

    def test_normal_message_or_wrong_product(self):
        self.assertFalse(correlated([request(), crash(message='GET completed')]))
        event = crash()
        event['logsource'] = {'category': 'application', 'product': 'other'}
        self.assertFalse(correlated([request(), event]))


if __name__ == '__main__':
    unittest.main(verbosity=2)
