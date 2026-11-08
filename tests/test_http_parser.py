"""Compile the generated parser itself against a deterministic host TCP fixture."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('webserver_patch',ROOT/'firmware/tools/prepare_webserver.py')
patch=importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)

class BoundedParserTest(unittest.TestCase):
    def test_actual_multipart_and_reader(self):
        framework=Path(os.environ.get('MOJIAN_ARDUINO_FRAMEWORK',ROOT.parents[1]/'.platformio/packages/framework-arduinoespressif32'))
        with tempfile.TemporaryDirectory() as tmp:
            target=Path(tmp)/'WebServer'
            patch.prepare(framework,target,ROOT/'firmware')
            parser=(target/'src/Parsing.cpp').read_text()
            request=parser[parser.index('static char* readBytesWithTimeout('):parser.index('bool WebServer::_collectHeader(')]
            body=parser[parser.index('void WebServer::_uploadWriteByte('):parser.index('String WebServer::urlDecode(')]
            # urlDecode sits after parseForm; use just the patched parser helpers.
            end=parser.index('bool WebServer::_parseFormUploadAborted(')
            abort=parser[end:]
            code='#include "'+str(ROOT/'tests/http_parser_fixture.h')+'"\n'+request+body+abort+HARNESS
            source=Path(tmp)/'test.cpp';source.write_text(code)
            binary=Path(tmp)/'parser-test'
            built=subprocess.run([os.environ.get('CXX','c++'),'-std=c++17',str(source),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(built.returncode,0,built.stderr)
            result=subprocess.run([str(binary)],check=True,capture_output=True,text=True)
            self.assertIn('PASS',result.stdout)
            print(result.stdout.strip())

HARNESS=r'''
std::string form(const std::string& metadata,const std::string& frame,bool finish=true){return "--BOUND\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n"+metadata+"\r\n--BOUND\r\nContent-Disposition: form-data; name=\"frame\"; filename=\"frame.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n"+frame+(finish?"\r\n--BOUND--\r\n":"");}
void reset(){fakeTime=0;}
int main(){
 // Complete native-style HTTP request uses the exact patched request parser.
 {reset();WebServer s;std::string payload=form("{\"tasks\":[]}",std::string(48000,'x'));WiFiClient c{"POST /api/local/commit?async=1 HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=BOUND\r\nContent-Length: "+std::to_string(payload.size())+"\r\n\r\n"+payload};assert(s._parseRequest(c));assert(s.handler.bytes.size()==48000&&s.handler.ends==1);}
 {reset();WebServer s;WiFiClient c{"POST /api/local/commit HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=BOUND\r\nContent-Length: 60001\r\n\r\n"};assert(!s._parseRequest(c));assert(s.handler.starts==0&&!c.open);}
 {reset();WebServer s;WiFiClient c{"POST /api/local/autonomy HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 8193\r\n\r\n"};assert(!s._parseRequest(c));assert(fakeTime==0);}
 {reset();WebServer s;WiFiClient c{"GET /api/local/health HTTP/1.1\r\nHost: local\r\n\r\n"};assert(s._parseRequest(c));}
 {reset();WebServer s;WiFiClient c{"POST /api/local/remote HTTP/1.1\r\nContent-Length: 0\r\n\r\n"};assert(s._parseRequest(c));}
 {reset();WebServer s;std::string payload=form("{}","pixels",false);WiFiClient c{"POST /api/local/commit HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=BOUND\r\nContent-Length: 50000\r\n\r\n"+payload};assert(!s._parseRequest(c));assert(fakeTime==5000&&s.handler.aborts==1&&!s.handler.leased&&!c.open);}
 // Full 48 KB production-shaped frame and metadata: exact bytes and fields.
 {reset();WebServer s;std::string frame(48000,'\xff');WiFiClient c{form("{\"tasks\":[]}",frame)};assert(s.parse(c));assert(s.handler.bytes==frame);assert(s.handler.starts==1&&s.handler.ends==1&&s.handler.aborts==0);assert(s._currentArgCount==1&&s._currentArgs[0].key=="metadata");}
 // A half-upload with a live silent TCP connection must yield at 5 seconds.
 {reset();WebServer s;WiFiClient c{form("{}","pixels",false)};assert(!s.parse(c));assert(fakeTime==5000);assert(s.handler.aborts==1&&!s.handler.leased&&!c.open);}
 // EOF during the frame or metadata must terminate and clean up immediately.
 {reset();WebServer s;WiFiClient c{form("{}","pixels",false)};c.open=false;assert(!s.parse(c));assert(fakeTime==0&&s.handler.aborts==1);}
 {reset();WebServer s;WiFiClient c{"--BOUND\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n{}"};c.open=false;assert(!s.parse(c));assert(fakeTime==0);}
 // Field length and body limits enforced during parsing, not after allocation.
 {reset();WebServer s;WiFiClient c{form(std::string(8193,'x'),"pixels")};assert(!s.parse(c));assert(s.handler.starts==0);}
 // Original metadata limit remains inclusive; field names have a separate budget.
 {reset();WebServer s;WiFiClient c{form(std::string(8192,'x'),std::string(48000,'x'))};assert(s.parse(c));assert(s._currentArgs[0].value.size()==8192);}
 // Many individually valid fields cannot retain >8KB then double during copying.
 {reset();WebServer s;std::string data;for(int i=0;i<7;++i)data+="--BOUND\r\nContent-Disposition: form-data; name=\"x"+std::to_string(i)+"\"\r\n\r\n"+std::string(8192,'x')+"\r\n";data+="--BOUND--\r\n";WiFiClient c{data};assert(!s.parse(c));assert(s._postArgsLen==1);}
 // Names also have a cumulative ceiling even when values are tiny.
 {reset();WebServer s;std::string data;for(int i=0;i<3;++i)data+="--BOUND\r\nContent-Disposition: form-data; name=\""+std::string(400,'n')+"\"\r\n\r\nx\r\n";data+="--BOUND--\r\n";WiFiClient c{data};assert(!s.parse(c));assert(s._postArgsLen==2);}
 {reset();WebServer s;WiFiClient c{form("{}",std::string(60001,'x'))};assert(!s.parse(c));assert(s.handler.aborts==1&&s.handler.bytes.size()<60000);}
 // A trickle resets idle time but cannot evade the 30 second total deadline.
 {reset();WebServer s;WiFiClient c{form("{}",std::string(48000,'x'))};c.gap=100;assert(!s.parse(c));assert(fakeTime==30000);}
 // Unsigned elapsed checks survive millis rollover.
 {reset();fakeTime=UINT32_MAX-1000;WebServer s;WiFiClient c{""};assert(!s.parse(c));assert(fakeTime==3999);}
 // Headers are capped independently from body; failed state is reset per request.
 {reset();WiFiClient c{std::string(1025,'h')+"\r"};MojianRequestReader<WiFiClient> r;r.begin(c);r.readStringUntil('\r');assert(r.failed());WiFiClient good{"OK\r"};r.begin(good);assert(r.readStringUntil('\r')=="OK"&&!r.failed());}
 printf("PASS: actual multipart parser normal 48KB, silent half-upload, EOF, oversized metadata/body, trickle deadline, rollover, header limit and next request reset\n");
}
'''
if __name__=='__main__':unittest.main()
