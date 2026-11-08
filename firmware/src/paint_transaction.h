#pragma once
#include <atomic>
// One owner of the frame/SPI. A finished result must be consumed on the main
// loop before another job can borrow the buffer. Release/acquire publishes all
// driver writes without reading the shadow frame while a worker modifies it.
struct PaintTransaction {
 enum State:unsigned {Idle,Running,Completed,Failed};
 std::atomic<unsigned> state{Idle};
 bool begin(){unsigned expected=Idle;return state.compare_exchange_strong(expected,Running);}
 void finish(bool success){state.store(success?Completed:Failed,std::memory_order_release);}
 unsigned result()const{return state.load(std::memory_order_acquire);}
 bool active()const{return result()!=Idle;}
 void release(){state.store(Idle,std::memory_order_release);}
};
