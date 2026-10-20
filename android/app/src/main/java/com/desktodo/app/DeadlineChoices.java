package com.desktodo.app;
import android.widget.*;import java.time.*;import java.util.function.Consumer;
final class DeadlineChoices {
 static Instant hourAfter(Instant now){return now.plusSeconds(3600);}
 static Instant tomorrowMorning(Instant now){return now.atZone(ScreenData.ZONE).toLocalDate().plusDays(1).atTime(9,0).atZone(ScreenData.ZONE).toInstant();}
 static ZonedDateTime selection(String due,Instant now){try{return Instant.parse(due).atZone(ScreenData.ZONE);}catch(Exception e){return now.atZone(ScreenData.ZONE);}}
 static void controls(MainActivity a,LinearLayout form,Consumer<Instant> select){LinearLayout row=new LinearLayout(a);for(String title:new String[]{"1小时后","明天9点"}){Button button=AppUi.button(a,title,false,()->select.accept(title.equals("1小时后")?hourAfter(Instant.now()):tomorrowMorning(Instant.now())));row.addView(button,new LinearLayout.LayoutParams(0,-2,1));}form.addView(row);}
}
