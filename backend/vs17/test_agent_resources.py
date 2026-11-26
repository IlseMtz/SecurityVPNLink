import base64
import unittest
from unittest.mock import patch

from agent_resources import apply_snapshot


class ResourcePolicyTest(unittest.TestCase):
    def setUp(self):
        self.key = base64.b64encode(bytes(range(32))).decode()
        self.captured = 10_000_000
        self.request = {'capturedAt': self.captured, 'entries': [
            [self.key, '10.78.0.2', 'TCP', 80, '172.30.77.10', self.captured + 3000]]}

    @patch('agent_resources.ipset')
    def test_applies_exact_tuple_until_window_closes(self, ipset):
        with patch('agent_resources.time.time', return_value=(self.captured + 1000) / 1000):
            result = apply_snapshot(self.request, self.key + '\t10.78.0.2/32\n')
        self.assertEqual(result['applied'], 1)
        self.assertIn('10.78.0.2,tcp:80,172.30.77.10 timeout 2', ipset.call_args_list[1].kwargs['data'])
        self.assertEqual(ipset.call_args.args, ('swap', 'sl_lab_next', 'sl_lab_live'))

    @patch('agent_resources.ipset')
    def test_reused_address_does_not_grant_to_different_peer(self, ipset):
        with patch('agent_resources.time.time', return_value=self.captured / 1000):
            result = apply_snapshot(self.request, 'other-key\t10.78.0.2/32\n')
        self.assertEqual(result['applied'], 0)
        self.assertEqual([c.args[0] for c in ipset.call_args_list], ['flush', 'swap'])

    @patch('agent_resources.ipset')
    def test_expired_snapshot_and_outside_destination_are_rejected(self, ipset):
        with patch('agent_resources.time.time', return_value=(self.captured + 5000) / 1000):
            with self.assertRaisesRegex(ValueError, 'expirado'):
                apply_snapshot(self.request, '')
        self.request['entries'][0][4] = '172.16.0.4'
        with patch('agent_resources.time.time', return_value=self.captured / 1000):
            with self.assertRaisesRegex(ValueError, 'laboratorio'):
                apply_snapshot(self.request, '')
        ipset.assert_not_called()


if __name__ == '__main__':
    unittest.main()
