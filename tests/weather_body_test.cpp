#include "../firmware/src/weather_body.h"
#include <cassert>
#include <cstdio>
#include <string>
#include <vector>
struct Feed {
 std::string bytes;size_t at=0;uint32_t* now;uint32_t began=0,step=0;bool stayOpen=false;
 int available(){return at<bytes.size()&&(!step||uint32_t(*now-began)>=(at+1)*step)?1:0;}
 int read(){return at<bytes.size()?(unsigned char)bytes[at++]:-1;}
 bool connected(){return at<bytes.size()||stayOpen;}
};
struct Result {bool ok;size_t size;uint32_t elapsed;std::string body;};
static Result run(const std::string& text,bool chunked,int length=-1,bool open=false,unsigned step=0,uint32_t total=15000,uint32_t idle=3000,uint32_t initial=0){
 uint32_t now=initial;Feed feed{text,0,&now,initial,step,open};std::vector<char> body(8193);size_t used=0;
 bool ok=readWeatherBody(feed,chunked,length,body.data(),8192,used,[&]{return now;},[&]{++now;},total,idle);
 assert(used<=8192);return {ok,used,uint32_t(now-initial),std::string(body.data(),used)};
}
int main(){
 auto r=run("hello",false,5);assert(r.ok&&r.body=="hello");
 r=run("hello",false);assert(r.ok&&r.body=="hello");
 assert(!run("hel",false,5).ok);assert(!run("",false,8193).ok);
 assert(run(std::string(8192,'a'),false,8192).ok);
 assert(!run(std::string(8193,'a'),false).ok);
 r=run("3\r\nabc\r\n2;foo=bar\r\nde\r\n0\r\nServer: test\r\n\r\n",true);assert(r.ok&&r.body=="abcde");
 assert(run("0\r\n\r\n",true).ok);
 for(const char* bad:{"z\r\n", "1\r\naX\n0\r\n\r\n", "1\r\n", "0\r\n", ";x\r\n", "-1\r\n", "FFFFFFFFFFFFFFFFFFFFFFFF\r\n", "1\na\r\n0\r\n\r\n"})assert(!run(bad,true).ok);
 assert(!run("2001\r\n",true).ok);
 assert(run("2000\r\n"+std::string(8192,'a')+"\r\n0\r\n\r\n",true).ok);
 assert(!run("1000\r\n"+std::string(4096,'a')+"\r\n1001\r\n",true).ok);
 assert(!run("1;"+std::string(128,'x')+"\r\na\r\n0\r\n\r\n",true).ok);
 std::string many;for(unsigned i=0;i<3000;i++)many+="1\r\na\r\n";many+="0\r\n\r\n";assert(!run(many,true).ok);
 // A kept-open unknown response must terminate at the idle deadline.
 r=run("hello",false,-1,true,0,20,5);assert(!r.ok&&r.elapsed==5);
 // A live drip resets idle but cannot evade the overall deadline.
 r=run(std::string(100,'x'),false,-1,true,2,20,5);assert(!r.ok&&r.elapsed==20);
 r=run("1\r\nx\r\n0\r\n\r\n",true,-1,true,2,20,5);assert(!r.ok&&r.elapsed==20);
 r=run("1\r\nx\r\n0\r\n\r\n",true,-1,true,1,100,5);assert(r.ok&&r.body=="x");
 r=run("",false,-1,true,0,20,5,0xfffffffeU);assert(!r.ok&&r.elapsed==5);
 r=run(std::string(100,'x'),false,-1,true,2,20,5,0xfffffff0U);assert(!r.ok&&r.elapsed==20);
 puts("PASS: weather fixed/chunked/unknown bodies, size/framing bounds, malformed/truncated responses, idle/total deadlines and rollover");
}
