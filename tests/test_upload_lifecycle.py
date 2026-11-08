"""Compile the actual upload callbacks with detached frame/BLE ownership stubs."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class UploadLifecycleTest(unittest.TestCase):
    def test_real_callbacks(self):
        text=(ROOT/'firmware/src/local_portal.h').read_text()
        upload=text[text.index('void localUpload(){'):text.index('void setupLocalPortal(){')]
        portal=text[text.index('void handleLocalPortal(){'):text.index('// Small pre-rendered')]
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'upload.cpp';binary=Path(folder)/'upload'
            early=text[text.index('void localCommit(){'):text.index(' String metadata=deviceWeb.arg("metadata");',text.index('void localCommit(){'))].replace('void localCommit(){','void localCommitEarly(){')+'}\n'
            source.write_text(STUBS+upload+early+portal+CHECKS)
            subprocess.run([os.environ.get('CXX','c++'),'-std=c++17','-I'+str(ROOT/'firmware/src'),str(source),'-o',str(binary)],check=True)
            result=subprocess.run([str(binary)],check=True,capture_output=True,text=True)
            self.assertIn('PASS',result.stdout);print(result.stdout.strip())

STUBS=r'''
#include <cassert>
#include <cstdint>
#include <cstring>
#include <string>
#include <cstdio>
#include "paged_plane.h"
enum {UPLOAD_FILE_START,UPLOAD_FILE_WRITE,UPLOAD_FILE_ABORTED};
struct HTTPUpload{int status=UPLOAD_FILE_START;size_t currentSize=0;uint8_t buf[4]={1,2,3,4};};
struct Server{HTTPUpload value;int closes=0,begins=0;HTTPUpload& upload(){return value;}void handleClient(){}void close(){++closes;}void begin(){++begins;}}deviceWeb;
struct Logger{void println(const char*){}}Serial;
uint32_t now=0,localUploadActivity=0;uint32_t millis(){return now;}
constexpr size_t PLANE_BYTES=48000;PagedPlane frame;PagedPlane* localIncoming=nullptr;
bool localUploadAllowed=false,autoFetching=false,provisionAttempt=false,localRestartBle=false,busy=false;
size_t localReceived=0;int localUploadStatus=400,lastStatus=0;bool allocationOK=true;void localReply(int status,const char*){lastStatus=status;}int releases=0,bleStarts=0;std::string localUploadError;
bool localDisplayBusy(){return busy;}void finishLocalPaint(){}
void localRelease(){++releases;frame.release();localIncoming=nullptr;localUploadAllowed=false;localRestartBle=true;}
bool localAcquireFrame(){if(!allocationOK)return false;assert(frame.allocate());localIncoming=&frame;return true;}
void startBluetooth(){++bleStarts;}
void reset(){frame.release();allocationOK=true;localUploadStatus=400;lastStatus=0;deviceWeb=Server();now=0;localUploadActivity=0;localIncoming=nullptr;localUploadAllowed=false;autoFetching=false;provisionAttempt=false;localRestartBle=false;busy=false;localReceived=0;releases=bleStarts=0;localUploadError="";}
'''
CHECKS=r'''
int main(){
 reset();localUpload();assert(localIncoming&&localUploadAllowed);deviceWeb.value.status=UPLOAD_FILE_WRITE;deviceWeb.value.currentSize=4;localUpload();assert(localReceived==4&&frame[3]==4);
 localReceived=3998;localUpload();assert(localReceived==4002&&frame[3998]==1&&frame[4000]==3&&frame[4001]==4);
 deviceWeb.value.status=UPLOAD_FILE_ABORTED;localUpload();assert(!localIncoming&&releases==1&&localRestartBle);
 // Duplicate file START clears upload acceptance, but the original request
 // still owns its frame. ABORT must release it even though allowed is false.
 reset();localUpload();localUpload();assert(localIncoming&&!localUploadAllowed&&!localUploadError.empty());deviceWeb.value.status=UPLOAD_FILE_ABORTED;localUpload();assert(!localIncoming&&releases==1);
 // A rejected upload during display must never release the worker's buffer.
 reset();localIncoming=&frame;busy=true;localUpload();deviceWeb.value.status=UPLOAD_FILE_ABORTED;localUpload();assert(localIncoming==&frame&&releases==0);
 // Watchdog uses frame ownership, not the last file's acceptance flag.
 reset();localIncoming=&frame;localUploadAllowed=false;now=30000;handleLocalPortal();assert(!localIncoming&&releases==1&&deviceWeb.closes==1&&bleStarts==1);
 reset();localIncoming=&frame;busy=true;now=120000;handleLocalPortal();assert(localIncoming==&frame&&releases==0&&deviceWeb.closes==0);
 // Wraparound is still bounded, and a live upload isn't prematurely freed.
 reset();localIncoming=&frame;localUploadActivity=UINT32_MAX-1000;now=28999;handleLocalPortal();assert(!localIncoming&&releases==1);
 reset();localIncoming=&frame;now=29999;handleLocalPortal();assert(localIncoming&&releases==0);
 reset();autoFetching=true;localUpload();localCommitEarly();assert(lastStatus==423&&!localIncoming);
 reset();allocationOK=false;localUpload();localCommitEarly();assert(lastStatus==503&&!localIncoming);
 reset();localUpload();localCommitEarly();assert(lastStatus==400&&!localIncoming);
 reset();busy=true;localIncoming=&frame;localCommitEarly();assert(lastStatus==423&&localIncoming==&frame&&releases==0);
 puts("PASS: real upload callbacks normal/duplicate abort cleanup, worker ownership, watchdog and rollover");
}
'''

if __name__=='__main__':unittest.main()
