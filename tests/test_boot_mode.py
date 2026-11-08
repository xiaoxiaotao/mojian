"""Boot/legacy contracts: no local snapshot must keep the legacy poll active."""
from pathlib import Path
import re, unittest
ROOT=Path(__file__).resolve().parents[1]
class BootModeTest(unittest.TestCase):
 def test_legacy_polling_follows_local_mode_absence(self):
  portal=(ROOT/'firmware/src/local_portal.h').read_text()
  main=(ROOT/'firmware/src/main.cpp').read_text()
  setup=portal[portal.index('void setupLocalPortal()'):]
  self.assertRegex(setup,r'legacyPolling\s*=\s*!localMode\s*;')
  self.assertRegex(main,r'if\(localMode\|\|!legacyPolling\)\s*return;')
 def test_snapshot_read_is_size_bounded_before_line_parse(self):
  portal=(ROOT/'firmware/src/local_portal.h').read_text()
  body=portal[portal.index('bool localReadSnapshot'):]
  self.assertRegex(body,r'file\.size\(\)\s*<\s*minimum')
  self.assertRegex(body,r'file\.size\(\)\s*>\s*maximum')
if __name__=='__main__':unittest.main()
