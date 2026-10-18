import Foundation
import CryptoKit
/// Three-way task merge: unrelated additions survive; deletion never resurrects an old task.
enum TaskReconcile {
    static func active(_ tasks:[DeskTask])->[DeskTask]{tasks.filter{!$0.done}}
    static func same(_ a:DeskTask?,_ b:DeskTask?)->Bool{a?.id==b?.id && a?.title==b?.title && a?.due.map{Int64($0.timeIntervalSince1970)}==b?.due.map{Int64($0.timeIntervalSince1970)} && (a?.pinned ?? false)==(b?.pinned ?? false) && a?.repeatRule==b?.repeatRule && a?.repeatSeries==b?.repeatSeries && a?.repeatDay==b?.repeatDay}
    static func equal(_ a:[DeskTask],_ b:[DeskTask])->Bool{let x=active(a),y=active(b);return x.count==y.count && x.allSatisfy{item in same(item,y.first{$0.id==item.id})}}
    static func merge(base:[DeskTask],local:[DeskTask],remote:[DeskTask])throws->[DeskTask]{
        for list in [active(base),active(local),active(remote)]{guard Set(list.map{$0.id}).count==list.count else{throw DeskError(message:"设备事项ID重复，请核对清单")}}
        let b=Dictionary(uniqueKeysWithValues:active(base).map{($0.id,$0)}),l=Dictionary(uniqueKeysWithValues:active(local).map{($0.id,$0)}),r=Dictionary(uniqueKeysWithValues:active(remote).map{($0.id,$0)})
        var result=r
        for id in Set(b.keys).union(l.keys){
            if same(b[id],l[id]){continue}
            if !same(b[id],r[id]) && !same(l[id],r[id]){throw DeskError(message:"同一事项在另一端也被修改，请重新读取并核对，未覆盖设备")}
            result[id]=l[id]
        }
        guard result.count<=8 else{throw DeskError(message:"合并后超过八条，双方更改已保留，请先整理清单")}
        let order=active(remote).map{$0.id}+active(local).map{$0.id};var seen=Set<String>()
        return order.compactMap{id in guard seen.insert(id).inserted else{return nil};return result[id]}
    }
    static func items(_ state:DeviceState)->[DeskTask]{state.tasks.enumerated().map{index,item in let stable="legacy-"+SHA256.hash(data:Data((String(index)+item.title+(item.due ?? "")).utf8)).map{String(format:"%02x",$0)}.joined();return DeskTask(id:item.id ?? stable,title:item.title,due:item.due.flatMap{parseISODate($0)},pinned:item.pinned,repeatRule:item.repeatRule,repeatSeries:item.repeatSeries,repeatDay:item.repeatDay)}}
}
