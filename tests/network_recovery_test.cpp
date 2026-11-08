#include <cassert>
#include <cstdio>
#include "../firmware/src/network_recovery_policy.h"
int main(){
 NetworkRecoveryPolicy p;
 assert(p.next(100,false,false)==0);assert(p.next(15099,false,false)==0);
 assert(p.next(15100,false,false)==1);assert(p.next(45100,false,false)==1);
 assert(p.next(105100,false,false)==1);assert(p.next(165100,false,false)==2);
 assert(p.next(165101,false,false)==0);
 assert(p.next(165102,true,false)==0&&p.attempts==0&&!p.offline);
 p.next(200000,false,false);assert(p.next(214999,false,false)==0);
 // Credential provisioning and live workers must never trigger recovery resets.
 assert(p.next(230000,false,true)==0&&p.attempts==0);
 assert(p.next(244999,false,false)==0);assert(p.next(245000,false,false)==1);
 NetworkRecoveryPolicy wrap;wrap.next(0xfffffff0U,false,false);
 assert(wrap.next(uint32_t(0xfffffff0U+14999U),false,false)==0);
 assert(wrap.next(uint32_t(0xfffffff0U+15000U),false,false)==1);
 puts("PASS: bounded reconnect escalation, healthy reset, provisioning/worker pause, rollover");
}
