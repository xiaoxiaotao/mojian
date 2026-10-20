import SwiftUI
struct PresetGallery:View {
 @EnvironmentObject var store:DeskStore
 var body:some View {
  VStack(alignment:.leading,spacing:16){
   Text("先选用途，再调排版。").font(.system(size:22,weight:.semibold))
   Text("六套现成组合，离线也能预览。预览使用当前数据，不修改配置；确认应用时才全刷一次。").font(.system(size:13)).foregroundStyle(muted)
   LazyVGrid(columns:[GridItem(.adaptive(minimum:280),spacing:18)],spacing:18){
    ForEach(DeskPreset.all){preset in
     Card(padding:16){VStack(alignment:.leading,spacing:12){
      ScreenPreview(content:preview(preset)).accessibilityLabel(preset.name+"，当前数据预览")
      Text(preset.name).font(.headline)
      Text(preset.summary).font(.system(size:13)).foregroundStyle(muted).fixedSize(horizontal:false,vertical:true)
      Text(preset.requirements.joined(separator:"\n")).font(.caption).foregroundStyle(muted).fixedSize(horizontal:false,vertical:true)
      Button("预览「\(preset.name)」"){store.extensions.preview(preset.template)}.buttonStyle(Quiet())
     }}
    }
   }
  }
 }
 func preview(_ preset:DeskPreset)->ScreenContent {
  var content=store.content
  if let (settings,calendar)=try? DeskExtensions.apply(preset.template,to:store.settings){content.settings=settings;content.afterHours=calendar}
  return content
 }
}
