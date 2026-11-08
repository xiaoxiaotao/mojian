#pragma once
#include "paged_plane.h"
void referencePartialBegin(const uint8_t* previous);
bool referencePartialRect(const uint8_t* previous,const PagedPlane& current,
                          unsigned x,unsigned y,unsigned w,unsigned h,bool accent);
void referencePartialEnd();
