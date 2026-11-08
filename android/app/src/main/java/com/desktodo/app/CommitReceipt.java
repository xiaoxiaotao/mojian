package com.desktodo.app;
import org.json.*;
/** A queued upload is not a display receipt; pending keeps the native send queue occupied. */
final class CommitReceipt {
 static boolean completed(String expected,JSONObject value)throws Exception{
  if(expected==null||expected.isEmpty()||value==null||!expected.equals(value.optString("transaction_id")))throw new Exception("设备刷新回执不匹配，未确认同步成功");
  String status=value.optString("status");
  if(status.equals("completed"))return true;
  if(status.equals("pending"))return false;
  if(status.equals("failed"))throw new Exception(value.optString("error","设备刷新失败，未确认同步成功"));
  throw new Exception("设备刷新状态未知，未确认同步成功");
 }
}
