#pragma once
// Suspend a memory-heavy service only while its replacement buffer is owned.
// Allocation failure must restore it immediately rather than waiting for an
// unrelated weather request or another user action.
template<class Suspend,class Allocate,class Restore>
auto acquireBorrowedFrame(Suspend suspend,Allocate allocate,Restore restore)->decltype(allocate()){
 suspend();auto buffer=allocate();if(!buffer)restore();return buffer;
}
