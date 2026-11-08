"""Exercise production mount invocation and state guard without a real flash."""
from pathlib import Path
import re, os, subprocess, tempfile, unittest
ROOT=Path(__file__).resolve().parents[1]
class StorageSafetyTest(unittest.TestCase):
 def test_no_format_or_false_empty_state(self):
  text=(ROOT/'firmware/src/local_portal.h').read_text()
  mount=re.search(r'storageReady=LittleFS\.begin\([^;]*;',text).group(0)
  start=text.index('deviceWeb.on("/api/local/state",HTTP_GET,[]{')+len('deviceWeb.on("/api/local/state",HTTP_GET,[]{')
  guard=text[start:text.index('  JsonDocument doc;',start)]
  cpp='''#include <cassert>
#include <string>
std::string snapshot="existing user snapshot";bool mountable=false,storageReady=false,localSnapshotError=false;int replies=0,status=0;
struct FS {bool begin(bool format){if(!mountable&&format){snapshot.clear();return true;}return mountable;}}LittleFS;
void localReply(int code,const char*){status=code;}
void initialize(){'''+mount+'''}
void state(){'''+guard+'''++replies;}
int main(){initialize();assert(!storageReady&&snapshot=="existing user snapshot");state();assert(status==503&&replies==0);mountable=true;initialize();status=0;state();assert(storageReady&&status==0&&replies==1&&snapshot=="existing user snapshot");localSnapshotError=true;status=0;state();assert(status==503&&replies==1&&snapshot=="existing user snapshot");localSnapshotError=false;status=0;state();assert(status==0&&replies==2);}
'''
  with tempfile.TemporaryDirectory() as d:
   source=Path(d)/'storage.cpp';exe=Path(d)/'storage';source.write_text(cpp)
   subprocess.run([os.environ.get('CXX','c++'),'-std=c++17',str(source),'-o',str(exe)],check=True)
   subprocess.run([str(exe)],check=True)
  print('PASS: failed mount preserves snapshot and refuses false empty state; mounted storage serves normally')
if __name__=='__main__':unittest.main()
