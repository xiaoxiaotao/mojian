// Host fixture for the generated, real WebServer multipart parser. No sockets.
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <cstdint>
#include <vector>
class String: public std::string {
 public:
 using std::string::string;
 String(const std::string& s):std::string(s){}
 String substring(size_t from,size_t to=std::string::npos)const{return from>size()?String():String(substr(from,to==npos?npos:to-from));}
 int indexOf(char c,size_t from=0)const{auto p=find(c,from);return p==npos?-1:(int)p;}
 void replace(const String& from,const String& to){size_t at=0;while((at=find(from,at))!=npos){std::string::replace(at,from.size(),to);at+=to.size();}}
 void trim(){while(!empty()&&isspace(back()))pop_back();while(!empty()&&isspace(front()))erase(0,1);}
 long toInt()const{return strtol(c_str(),nullptr,10);}
 operator const char*()const{return c_str();}
 bool startsWith(const String& prefix)const{return compare(0,prefix.size(),prefix)==0;}
 bool equalsIgnoreCase(const String& s)const{if(size()!=s.size())return false;for(size_t i=0;i<size();++i)if(tolower(at(i))!=tolower(s[i]))return false;return true;}
};
uint32_t fakeTime=0;
uint32_t millis(){return fakeTime;}
void delay(uint32_t n){fakeTime+=n;}
#define F(x) x
#define FPSTR(x) x
#define log_v(...) ((void)0)
#define log_e(...) ((void)0)
#define WEBSERVER_MAX_POST_ARGS 32
#define HTTP_UPLOAD_BUFLEN 1436
#define HTTP_RAW_BUFLEN 1436
#define HTTP_MAX_POST_WAIT 5000
namespace mime {enum{txt};struct Entry{const char* mimeType;};Entry mimeTable[]={{"text/plain"}};}
const char* Content_Type="Content-Type";
const char* filename="filename";
struct WiFiClient {
 std::string data;size_t offset=0;bool open=true;uint32_t gap=0,next=0;
 int available(){return offset<data.size()&&fakeTime>=next?1:0;}
 bool connected(){return open;}
 int read(){if(!available())return -1;next=fakeTime+gap;return (unsigned char)data[offset++];}
 void stop(){open=false;}
 void flush(){}
};
#include "../firmware/src/request_guard.h"
enum HTTPUploadStatus{UPLOAD_FILE_START,UPLOAD_FILE_WRITE,UPLOAD_FILE_END,UPLOAD_FILE_ABORTED};
struct HTTPUpload{HTTPUploadStatus status;String name,filename,type;size_t totalSize=0,currentSize=0;uint8_t buf[HTTP_UPLOAD_BUFLEN];};
struct RequestArgument{String key,value;};
enum HTTPMethod{HTTP_ANY,HTTP_GET,HTTP_POST,HTTP_PUT,HTTP_PATCH,HTTP_DELETE};
const char* _http_method_str[]={"*","GET","POST","PUT","PATCH","DELETE"};
enum RawStatus{RAW_START,RAW_WRITE,RAW_ABORTED,RAW_END};
struct HTTPRaw{RawStatus status;size_t totalSize=0,currentSize=0;uint8_t buf[HTTP_RAW_BUFLEN];};
struct WebServer;
struct Handler {
 std::string bytes;int starts=0,ends=0,aborts=0;bool leased=false;
 bool canUpload(const String&){return true;}
 Handler* next(){return nullptr;}bool canHandle(HTTPMethod,const String&){return true;}
 bool canRaw(const String&){return false;}void raw(WebServer&,const String&,HTTPRaw&){}
 void upload(WebServer&,const String&,HTTPUpload& u){
  if(u.status==UPLOAD_FILE_START){starts++;leased=true;}
  if(u.status==UPLOAD_FILE_WRITE)bytes.append((char*)u.buf,u.currentSize);
  if(u.status==UPLOAD_FILE_END)ends++;
  if(u.status==UPLOAD_FILE_ABORTED){aborts++;leased=false;}
 }
};
using RequestHandler=Handler;
struct WebServer {
 MojianRequestReader<WiFiClient> _boundedReader;
 std::unique_ptr<HTTPUpload> _currentUpload;
 Handler handler;Handler* _currentHandler=&handler;
 Handler* _firstHandler=&handler;
 int _headerKeysCount=0,_currentVersion=0;RequestArgument* _currentHeaders=nullptr;
 bool _chunked=false;size_t _clientContentLength=0;HTTPMethod _currentMethod=HTTP_ANY;String _hostHeader;
 std::unique_ptr<HTTPRaw> _currentRaw;
 String _currentUri="/api/local/commit";
 RequestArgument* _postArgs=nullptr;RequestArgument* _currentArgs=nullptr;
 int _postArgsLen=0,_currentArgCount=0;
 ~WebServer(){delete[] _postArgs;delete[] _currentArgs;}
 bool hasArg(const String&){return false;}String arg(const String&){return "";}
 int _uploadReadByte(WiFiClient&);
 void _uploadWriteByte(uint8_t);
 bool _parseForm(WiFiClient&,String,uint32_t);
 bool _parseFormUploadAborted();
 bool _parseRequest(WiFiClient&);bool _parseRequestBounded(WiFiClient&);
 bool _collectHeader(const char*,const char*){return false;}
 void _parseArguments(const String&){delete[] _currentArgs;_currentArgs=new RequestArgument[1];_currentArgCount=0;}
 bool parse(WiFiClient& c){
  _boundedReader.begin(c);_boundedReader.beginBody();
  bool ok=_parseForm(c,"BOUND",c.data.size())&&!_boundedReader.failed();
  if(!ok){c.stop();if(_currentUpload&&_currentUpload->status!=UPLOAD_FILE_ABORTED)_parseFormUploadAborted();}
  return ok;
 }
};
