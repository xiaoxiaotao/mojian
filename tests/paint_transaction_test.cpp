#include "../firmware/src/paint_transaction.h"
#include <cassert>
#include <thread>
#include <cstdio>
int main(){
 PaintTransaction job;assert(!job.active());assert(job.begin());assert(job.active());assert(!job.begin());
 job.finish(false);assert(job.result()==PaintTransaction::Failed);assert(!job.begin());job.release();
 // Main-loop finalization must observe all frame writes before returning a
 // completion receipt or lending the buffer again. No hardware/network I/O.
 int shadow[480]={};
 for(int round=1;round<=100;round++){
  assert(job.begin());std::thread display([&]{for(auto& row:shadow)row=round;job.finish(true);});
  while(job.result()==PaintTransaction::Running)std::this_thread::yield();
  assert(job.active()&&!job.begin());for(auto row:shadow)assert(row==round);
  display.join();job.release();assert(!job.active());
 }
 // Task allocation failure returns the lease; no completed receipt exists.
 assert(job.begin());job.release();assert(job.result()==PaintTransaction::Idle);
 puts("PASS: one display owner, failure and completion publication, explicit finalization, task allocation rollback");
}
