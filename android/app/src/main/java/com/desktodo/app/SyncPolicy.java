package com.desktodo.app;

import org.json.*;
import java.util.*;

/** Reconcile read-only observations before any automatic retry. */
final class SyncPolicy {
    enum Recovery { CLEAN, ACKNOWLEDGED, RETRY, CONFLICT }

    static String canonical(Object value) throws JSONException {
        if (value == null || value == JSONObject.NULL) return "null";
        if (value instanceof JSONObject) {
            JSONObject object = (JSONObject)value;
            List<String> keys = new ArrayList<>();
            Iterator<String> it = object.keys();
            while (it.hasNext()) keys.add(it.next());
            Collections.sort(keys);
            List<String> parts = new ArrayList<>();
            for (String key : keys) parts.add(JSONObject.quote(key)+":"+canonical(object.get(key)));
            return "{"+String.join(",",parts)+"}";
        }
        if (value instanceof JSONArray) {
            JSONArray array=(JSONArray)value;
            List<String> parts=new ArrayList<>();
            for(int i=0;i<array.length();i++) parts.add(canonical(array.get(i)));
            return "["+String.join(",",parts)+"]";
        }
        return value instanceof String ? JSONObject.quote((String)value) : value.toString();
    }

    static boolean sameTasks(JSONArray a, JSONArray b) {
        if (a==null || b==null || a.length()!=b.length()) return false;
        try {
            List<String> left=new ArrayList<>(),right=new ArrayList<>();
            for(int i=0;i<a.length();i++){left.add(canonical(a.get(i)));right.add(canonical(b.get(i)));}
            Collections.sort(left);Collections.sort(right);
            return left.equals(right);
        } catch(JSONException e){return false;}
    }

    static boolean sameLayout(JSONObject a,JSONObject b) {
        return a!=null && b!=null && a.optString("layout_id").equals(b.optString("layout_id"));
    }

    static Recovery recovery(JSONObject baseline,JSONObject latest,JSONArray local,boolean dirty) {
        if(!dirty)return Recovery.CLEAN;
        if(!sameLayout(baseline,latest))return Recovery.CONFLICT;
        if(sameTasks(local,latest.optJSONArray("tasks")))return Recovery.ACKNOWLEDGED;
        return sameTasks(baseline.optJSONArray("tasks"),latest.optJSONArray("tasks")) ? Recovery.RETRY : Recovery.CONFLICT;
    }

    static boolean frameChanged(JSONObject a,JSONObject b){
        return !sameLayout(a,b) || !sameTasks(a.optJSONArray("tasks"),b.optJSONArray("tasks"))
            || !a.optString("content_key").equals(b.optString("content_key"))
            || !a.optString("updated_at").equals(b.optString("updated_at"))
            || a.optBoolean("needs_full")!=b.optBoolean("needs_full");
    }

    static long retryDelay(int failures){return Math.min(60_000L,5_000L << Math.min(4,Math.max(0,failures-1)));}
}
