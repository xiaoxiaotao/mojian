import AppKit
let red=NSColor(calibratedRed:0.75,green:0.08,blue:0.10,alpha:1)
let image=NSImage(size:NSSize(width:800,height:480),flipped:true){rect in
 NSColor.white.setFill();rect.fill();red.setStroke();red.setFill()
 let seal=NSBezierPath(rect:NSRect(x:24,y:80,width:20,height:20));seal.lineWidth=2;seal.stroke()
 func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ size:CGFloat,_ align:NSTextAlignment = .left){
  let style=NSMutableParagraphStyle();style.alignment=align
  (value as NSString).draw(in:NSRect(x:x,y:y,width:width,height:22),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:red,.paragraphStyle:style])
 }
 text("墨",26,80,17,15);text("墨间",56,80,44,16)
 NSRect(x:112,y:88,width:128,height:2).fill()
 text(CommandLine.arguments[2],594,80,182,15,.right)
 return true
}
let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
