import importlib.util
import json
from pathlib import Path
import unittest
import urllib.error

spec = importlib.util.spec_from_file_location('observe_display', Path(__file__).resolve().parents[1] / 'tools/observe_display.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ObserveTest(unittest.TestCase):
    def reader(self, health, frame=bytes([255]) * 48000):
        calls = []
        def read(name):
            calls.append(name)
            if name == 'health':
                return json.dumps(health).encode()
            if isinstance(frame, Exception):
                raise frame
            return frame
        return calls, read

    def test_identity_fails_before_frame_read(self):
        calls, read = self.reader({'device_id': 'other'})
        with self.assertRaises(module.IdentityMismatch):
            module.read_sample('unused', 'expected', read)
        self.assertEqual(calls, ['health'])

    def test_idle_reads_only_health_and_frame(self):
        calls, read = self.reader({'device_id': 'expected', 'display_busy': False})
        sample = module.read_sample('unused', 'expected', read)
        self.assertEqual(len(sample['frame_sha256']), 64)
        self.assertEqual(calls, ['health', 'base'])

    def test_busy_and_racing_upload_skip_frame(self):
        calls, read = self.reader({'device_id': 'expected', 'display_busy': True})
        self.assertEqual(module.read_sample('unused', 'expected', read)['frame_skipped'], 'display_busy')
        self.assertEqual(calls, ['health'])
        _, read = self.reader({'device_id': 'expected', 'display_busy': False}, urllib.error.HTTPError('unused', 423, 'busy', None, None))
        self.assertEqual(module.read_sample('unused', 'expected', read)['frame_skipped'], 'became_busy')

    def test_frame_length_and_optical_limit(self):
        _, read = self.reader({'device_id': 'expected'}, b'bad')
        with self.assertRaises(ValueError):
            module.read_sample('unused', 'expected', read)
        summary = module.summarize([{'health': {}, 'frame_sha256': 'same'}] * 2)
        self.assertEqual(summary['optical_result'], 'not_observed')
        self.assertNotIn('display_refresh_commands_delta', summary)

    def test_restart_invalidates_counter_deltas(self):
        rows = [{'health': {'uptime_seconds': t, 'display_refresh_commands': n}} for t, n in [(20, 8), (25, 10)]]
        self.assertEqual(module.summarize(rows)['display_refresh_commands_delta'], 2)
        rows.append({'health': {'uptime_seconds': 1, 'display_refresh_commands': 0}})
        self.assertTrue(module.summarize(rows)['restart_observed'])
        self.assertIsNone(module.summarize(rows)['display_refresh_commands_delta'])


if __name__ == '__main__':
    unittest.main()
