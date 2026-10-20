import AppKit
import CoreText
// Screen bitmaps only; native controls continue using platform accessibility fonts.
enum ScreenFonts {
 static let registration:Void = {
  for file in ["SourceHanSansSC-Medium.otf","LXGWWenKaiGBScreen.ttf","Inter-Variable.ttf"] {
   guard let url=Bundle.main.resourceURL?.appendingPathComponent("Fonts/"+file),FileManager.default.fileExists(atPath:url.path) else{preconditionFailure("Missing bundled screen font: "+file)}
   CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)
  }
 }()
 static func isDigits(_ value:String)->Bool { !value.isEmpty && value.unicodeScalars.allSatisfy{$0.value<128 || "°▲▼—".unicodeScalars.contains($0)} }
 static func isVerse(_ value:String)->Bool {["下班之后","把时间，还给生活。","今天的留白，也很珍贵。"].contains(value)}
 static func font(_ value:String,_ size:CGFloat,_ bold:Bool)->NSFont {
  _=registration
  if isDigits(value),let font=NSFont(name:bold ? "Inter-Regular_SemiBold":"Inter-Regular_Medium",size:size){return font}
  if isVerse(value),let font=NSFont(name:"LXGWWenKaiGBScreen",size:size){return font}
  guard let font=NSFont(name:"SourceHanSansSC-Medium",size:size) else{preconditionFailure("Screen font registration failed")};return font
 }
}
