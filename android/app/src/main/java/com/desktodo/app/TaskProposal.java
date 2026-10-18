package com.desktodo.app;
import org.json.*;import java.time.Instant;
/** Validates against the current list, then returns a complete local transaction. */
final class TaskProposal {
 static final class Result {final JSONArray tasks,history;Result(JSONArray t,JSONArray h){tasks=t;history=h;}}
 static Result apply(JSONArray current,JSONArray previous,JSONObject p)throws Exception{
  JSONObject args=p.getJSONObject("args");String op=args.getString("operation");JSONArray next=DeskModel.copy(current),history=DeskModel.copy(previous);JSONObject task;int at=-1;
  if(op.equals("add")){if(next.length()>=8)throw new Exception("未完成清单已满");task=DeskModel.copy(p.getJSONObject("newTask"));for(int i=0;i<next.length();i++)if(next.getJSONObject(i).getString("id").equals(task.getString("id")))throw new Exception("该事项已添加");if(args.has("pinned"))task.put("pinned",args.getBoolean("pinned"));}
  else{for(int i=0;i<next.length();i++)if(next.getJSONObject(i).getString("id").equals(args.getString("id")))at=i;if(at<0)throw new Exception("事项已移除，请重新提出");task=DeskModel.copy(next.getJSONObject(at));if(!SyncPolicy.canonical(task).equals(SyncPolicy.canonical(p.getJSONObject("expectedTask"))))throw new Exception("事项已变化，请重新查看清单再提出");}
  if(op.equals("edit")){if(args.has("title"))task.put("title",args.getString("title"));if(args.has("due"))task.put("due",args.get("due"));}
  if(op.equals("pin"))task.put("pinned",args.getBoolean("pinned"));
  if(op.equals("complete")||op.equals("delete")){task.put(op.equals("complete")?"completedAt":"deletedAt",Instant.now().toString()).put("recordType",op.equals("complete")?"completed":"deleted");history.put(task);if(history.length()>100)history.remove(0);next.remove(at);}
  else{if(!java.util.Arrays.asList("add","edit","pin").contains(op))throw new Exception("未知操作");if(at<0)next.put(task);else next.put(at,task);if(DeskModel.pins(next)>3)throw new Exception("最多置顶三项，请先取消其他置顶");}
  return new Result(next,history);
 }
}
