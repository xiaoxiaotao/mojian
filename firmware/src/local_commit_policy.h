#pragma once
#include <string.h>

// Pure commit policy, header-only so host tests can cover it without Arduino.
// A red-v2 layout is only valid when the commit also declares an external
// layout and the matching fixed-red version. A full commit may not silently
// drop the red plane and leave the layout id claiming red.
inline bool localRedLayout(const char* layout){
 return layout&&strstr(layout,".red-v2")!=nullptr;
}
inline const char* localAccentPolicy(bool external,const char* layout,const char* accent){
 if(localRedLayout(layout)&&(!external||!accent||strcmp(accent,"mojian-red-v2")!=0))
  return "红色布局必须声明固定红色版本";
 if(accent&&*accent&&(!external||strcmp(accent,"mojian-red-v2")!=0))
  return "红色布局版本不支持";
 return nullptr;
}
