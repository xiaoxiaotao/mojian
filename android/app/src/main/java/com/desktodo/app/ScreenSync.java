package com.desktodo.app;
import org.json.*;
/** Layout ownership and visual acknowledgements are independent of task equality. */
final class ScreenSync {
 static boolean same(Object a,Object b){try{return SyncPolicy.canonical(a).equals(SyncPolicy.canonical(b));}catch(Exception e){return false;}}
 static boolean sameProfile(JSONObject a,JSONObject b){return same(a==null?null:a.optJSONObject("phone_settings"),b==null?null:b.optJSONObject("phone_settings"));}
 static boolean acknowledged(JSONObject cfg,JSONObject latest){return latest!=null&&DeskModel.layoutId(cfg).equals(latest.optString("layout_id"))&&same(device(cfg),device(latest.optJSONObject("phone_settings")==null?new JSONObject():latest.optJSONObject("phone_settings")));}
 static JSONObject device(JSONObject cfg){try{return DeskExtras.deviceConfig(cfg);}catch(Exception e){return new JSONObject();}}
 static JSONObject actual(JSONObject desired,JSONObject state,boolean full){if(!full&&!DeskModel.layoutId(desired).equals(state.optString("layout_id"))&&state.optJSONObject("phone_settings")!=null)return DeskModel.copy(state.optJSONObject("phone_settings"));return DeskModel.copy(desired);}
 static boolean patchAllowed(String id,JSONObject actual){return id.endsWith(".phone")&&actual.optInt("cardsVersion",0)==1;}
}
