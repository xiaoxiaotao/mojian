"""Run the real autonomy dispatcher with detached TLS, BLE and display stubs."""
from pathlib import Path
import os, subprocess, tempfile, unittest
ROOT=Path(__file__).resolve().parents[1]
class AutonomyDispatchTest(unittest.TestCase):
    def test_dispatch(self):
        source=(ROOT/'firmware/src/autonomy.h').read_text()
        dispatch=source[source.index('void updateAutonomy(){'):]
        with tempfile.TemporaryDirectory() as d:
            cpp=Path(d)/'dispatch.cpp';exe=Path(d)/'dispatch'
            cpp.write_text(STUBS+dispatch+CHECKS)
            subprocess.run([os.environ.get('CXX','c++'),'-std=c++17',str(cpp),'-o',str(exe)],check=True)
            result=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            print(result.stdout.strip())
STUBS=r'''
#include <cassert>
#include <cstdint>
#include <string>
#include <cstdio>
#include <ctime>
#define portENTER_CRITICAL(x) ((void)0)
#define portEXIT_CRITICAL(x) ((void)0)
#define time(...) testEpoch
constexpr int WL_CONNECTED=3,pdPASS=1,PaintAutonomy=1;
struct AutoWeather{bool ok=false;int httpStatus=0,tlsError=0;uint32_t address=0;};
struct AutoJob{double latitude,longitude;};
struct Plane{void write(unsigned,const unsigned char*,unsigned){}} plane;
Plane* localIncoming=nullptr;unsigned char PartImage[48000];constexpr unsigned PLANE_BYTES=48000;
struct Guard{bool failed=false;}displayGuard;
struct Server{int getConnectedCount(){return connected?1:0;}bool connected=false;} server;
struct NimBLEDevice{static bool getInitialized(){return true;}static Server* getServer(){return &server;}};
struct Wifi{int status(){return online?WL_CONNECTED:0;}bool online=true;}WiFi;
bool autoResultReady=false,autoFetching=false,autoEnabled=true,localMode=true,hasBase=true,provisionAttempt=false,bleSuspended=false,localRestartBle=false,busy=false,allocationOK=true,paintOK=true,taskOK=true;
AutoWeather autoResult,autoCache;int autoMux=0,autoLastHTTP=0,autoLastTLS=0,saved=0,paints=0,fetches=0,overlays=0,acquires=0,releases=0;
uint32_t autoLastAddress=0,autoNextFetch=0,clockMS=1000;
time_t testEpoch=1800000000,autoMinute=-1;
double autoLatitude=31.,autoLongitude=120.;std::string autoError,localLayoutID;
uint32_t millis(){return clockMS;}
bool autoSave(){++saved;return true;}
bool localDisplayBusy(){return busy;}
bool localAcquireFrame(){++acquires;localIncoming=allocationOK?&plane:nullptr;return allocationOK;}
void localRelease(){++releases;localIncoming=nullptr;}
void overlayAutonomy(Plane&,const std::string&){++overlays;}
bool startLocalPaint(int,bool full,bool,bool,unsigned,time_t){assert(!full);++paints;return paintOK;}
void localSuspendBle(){bleSuspended=true;}
void fetchAutoWeather(void*){}
int xTaskCreate(void(*)(void*),const char*,int,void* job,int,void*){++fetches;if(taskOK){delete static_cast<AutoJob*>(job);return pdPASS;}return 0;}
void reset(){autoResultReady=autoFetching=bleSuspended=localRestartBle=busy=provisionAttempt=server.connected=false;autoEnabled=localMode=hasBase=allocationOK=paintOK=taskOK=WiFi.online=true;localIncoming=nullptr;displayGuard.failed=false;autoResult=autoCache=AutoWeather();autoLastHTTP=autoLastTLS=saved=paints=fetches=overlays=acquires=releases=0;clockMS=1000;autoNextFetch=0;testEpoch=1800000000;autoMinute=-1;autoError="";}
'''
CHECKS=r'''
int main(){
 reset();hasBase=false;updateAutonomy();assert(fetches==1&&autoFetching&&paints==0&&acquires==0&&!hasBase);
 autoResultReady=true;autoResult.ok=true;autoResult.httpStatus=200;updateAutonomy();assert(saved==1&&autoCache.ok&&autoLastHTTP==200&&!autoFetching&&!hasBase&&paints==0&&localRestartBle);
 reset();displayGuard.failed=true;updateAutonomy();assert(fetches==1&&paints==0&&acquires==0&&displayGuard.failed);
 reset();updateAutonomy();assert(paints==1&&overlays==1&&fetches==0&&localIncoming);
 reset();allocationOK=false;updateAutonomy();assert(paints==0&&fetches==1&&autoFetching);
 for(int guard=0;guard<6;guard++){reset();if(guard==0)busy=true;if(guard==1)localIncoming=&plane;if(guard==2)provisionAttempt=true;if(guard==3)autoFetching=true;if(guard==4)autoEnabled=false;if(guard==5)localMode=false;updateAutonomy();assert(!paints&&!fetches&&!acquires);}
 reset();hasBase=false;server.connected=true;updateAutonomy();assert(!fetches&&!paints);
 reset();hasBase=false;WiFi.online=false;updateAutonomy();assert(!fetches&&!paints);
 reset();hasBase=false;testEpoch=0;updateAutonomy();assert(!fetches&&!paints);
 reset();hasBase=false;taskOK=false;updateAutonomy();assert(fetches==1&&!autoFetching&&localRestartBle&&autoNextFetch==121000&&!paints);
 reset();paintOK=false;updateAutonomy();assert(paints==1&&releases==1&&!localIncoming&&!fetches);
 reset();hasBase=false;autoNextFetch=clockMS+1000;updateAutonomy();assert(!fetches);
 reset();hasBase=false;clockMS=0xfffffff0U;autoNextFetch=0x10U;updateAutonomy();assert(!fetches);clockMS=0x10U;updateAutonomy();assert(fetches==1);
 puts("PASS: real autonomy dispatcher keeps weather independent, preserves baseline/fault locks and respects leases/BLE/offline guards");
}
'''
if __name__=='__main__':unittest.main()
