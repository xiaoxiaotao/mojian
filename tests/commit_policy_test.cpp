#include <cassert>
#include <cstring>
#include "../firmware/src/local_commit_policy.h"

int main(){
 assert(!localRedLayout(nullptr));
 assert(!localRedLayout("mac.overview"));
 assert(!localRedLayout("mac.overview.phone"));
 assert(localRedLayout("mac.overview.red-v2"));
 assert(localRedLayout("mac.overview.red-v2.phone"));
 assert(localRedLayout("mac.calendar.red-v2.phone"));

 // Plain layouts may stay legacy/empty; a supplied accent still needs an
 // external layout and the exact supported version.
 assert(localAccentPolicy(false,"mac.overview","")==nullptr);
 assert(localAccentPolicy(true,"mac.overview","")==nullptr);
 assert(localAccentPolicy(true,"mac.overview","mojian-red-v2")==nullptr);
 assert(localAccentPolicy(false,"mac.overview","mojian-red-v2")!=nullptr);
 assert(localAccentPolicy(true,"mac.overview","other")!=nullptr);

 // A red-v2 layout must never be committed without its accent declaration,
 // including full commits that would otherwise drop the fixed red plane.
 assert(localAccentPolicy(true,"mac.overview.red-v2","")!=nullptr);
 assert(localAccentPolicy(true,"mac.overview.red-v2.phone","")!=nullptr);
 assert(localAccentPolicy(false,"mac.overview.red-v2","")!=nullptr);
 assert(localAccentPolicy(false,"mac.overview.red-v2","mojian-red-v2")!=nullptr);
 assert(localAccentPolicy(true,"mac.overview.red-v2","other")!=nullptr);
 assert(localAccentPolicy(true,"mac.overview.red-v2","mojian-red-v2")==nullptr);
 assert(localAccentPolicy(true,"mac.overview.red-v2.phone","mojian-red-v2")==nullptr);
 assert(localAccentPolicy(true,"mac.calendar.red-v2.phone","mojian-red-v2")==nullptr);
 return 0;
}
