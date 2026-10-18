import csv,unittest
from pathlib import Path
class PartitionTest(unittest.TestCase):
 def test_preserves_persistent_regions(self):
  source=Path(__file__).parents[1]/'firmware/partitions.csv'
  rows={row[0].strip():row for row in csv.reader(line for line in source.read_text().splitlines() if line and not line.startswith('#'))}
  expected={'nvs':(0x9000,0x5000),'otadata':(0xe000,0x2000),'spiffs':(0x290000,0x160000),'coredump':(0x3f0000,0x10000)}
  for name,region in expected.items():self.assertEqual((int(rows[name][3],0),int(rows[name][4],0)),region)
  start,size=int(rows['app0'][3],0),int(rows['app0'][4],0);self.assertEqual(start,0x10000);self.assertLessEqual(start+size,0x290000)
  self.assertEqual(len(rows),5)
if __name__=='__main__':unittest.main()
