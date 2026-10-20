import Foundation

@MainActor enum ReliabilityTest {
    static func run()async {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("mojian-reliability-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:directory)}
        var reads=0,sends=0,failSend=false,fullFlags:[Bool]=[]
        var remoteLayout="mac.focus.red-v2"
        var remoteTasks:[DeviceState.Item]=[.init(id:"device-old",title:"Old device task",due:nil)]
        let transport=DeviceTransport(state:{_,_ in
            reads+=1
            return DeviceState(tasks:remoteTasks,local_mode:true,needs_full:false,layout_id:remoteLayout,external_layout:true,baseline_ready:true)
        },send:{_,_,_,_,_,_,full,_ in
            sends+=1;fullFlags.append(full)
            if failSend{throw URLError(.networkConnectionLost)}
        })
        let store=DeskStore(dataDirectory:directory,startServices:false,transport:transport)
        store.deviceToken="fixture-only";store.settings.deviceURL="http://fixture.invalid";store.settings.layout = .focus;store.settings.autoSync=true
        await store.connectDevice()
        precondition(store.connected && store.tasks.isEmpty,"Reconnect must not resurrect old device tasks")
        remoteTasks=[];await store.recoverConnection()
        precondition(sends==1 && !store.syncPending)
        await store.send(full:false)
        precondition(sends==1,"Unchanged frame and metadata should not send twice")
        failSend=true;store.settings.note="Offline saved note"
        await store.send(full:false)
        precondition(!store.connected && store.syncPending && !store.isSending)
        failSend=false;await store.connectDevice();await store.recoverConnection()
        precondition(store.connected && !store.syncPending && sends==3)
        remoteLayout="mac.focus.red-v2.phone";await store.connectDevice();let count=sends
        await store.recoverConnection()
        precondition(sends==count && store.syncPending,"Reconnect must not overwrite phone layout")
        precondition(fullFlags.allSatisfy{!$0},"Recovery must never silently full refresh")
        precondition(store.requiresLayoutApplication && store.phoneOwnsScreen && store.syncStatus.contains("手机控制"))
        await store.send(full:false)
        precondition(sends==count && store.syncStatus.contains("接管并同步"),"Retry must explain ownership rather than silently do nothing")
        await store.applyLayout()
        precondition(sends==count+1 && fullFlags.last==true && !store.requiresLayoutApplication && !store.syncPending,"Explicit application restores Mac control")
        precondition(ConnectionRecovery.delay(1)==5 && ConnectionRecovery.delay(6)==60)
        precondition(ConnectionRecovery.transient(URLError(.timedOut)))
        precondition(!ConnectionRecovery.transient(DeskError(message:"wrong token")))
        var deliveredTitles:[[String]]=[]
        let queued=DeskStore(dataDirectory:directory.appendingPathComponent("queue"),startServices:false,transport:DeviceTransport(state:transport.state,send:{_,_,_,tasks,_,_,_,_ in
            deliveredTitles.append(tasks.map{$0.title})
            try await Task.sleep(nanoseconds:30_000_000)
        }))
        remoteLayout="mac.focus.red-v2";queued.deviceToken="fixture-only";queued.settings.layout = .focus;queued.settings.autoSync=true
        await queued.connectDevice()
        let first=Task{await queued.send(full:false)}
        try? await Task.sleep(nanoseconds:10_000_000)
        queued.tasks.append(DeskTask(title:"Latest edit",due:nil))
        await queued.send(full:false)
        await first.value
        precondition(deliveredTitles.count==2 && deliveredTitles.last==["Latest edit"] && !queued.isSending && !queued.syncPending,"Edits during transmission must drain the latest snapshot")
        let bridge=HarnessBridge(timeoutNanoseconds:80_000_000,command:(URL(fileURLWithPath:"/bin/cat"),[]))
        for _ in 0..<2 {
            do{_=try await bridge.run(prompt:"fixture",key:"fixture-only",model:"fixture",context:[:],home:directory,session:nil,automatic:false);preconditionFailure("Expected timeout")}
            catch{precondition(error.localizedDescription.contains("超时"))}
        }
        let request=Task{try await bridge.run(prompt:"fixture",key:"fixture-only",model:"fixture",context:[:],home:directory,session:nil,automatic:false)}
        try? await Task.sleep(nanoseconds:10_000_000);bridge.close()
        do{_=try await request.value;preconditionFailure("Expected cancellation")}
        catch{precondition(error.localizedDescription.contains("停止"))}
        do {
            let id="mojian-012345abcdef",other="mojian-abcdef012345"
            precondition(DeviceIdentity.valid(id) && !DeviceIdentity.valid("mojian-x.local/attack"))
            precondition(DeviceIdentity.origin(id)=="http://mojian-012345abcdef.local")
            do{try DeviceIdentity.verify(id,other);preconditionFailure("Wrong board accepted")}catch{}
            do{try DeviceIdentity.verify(id,nil);preconditionFailure("Missing board identity accepted")}catch{}
            var attempted:[String]=[]
            let bound=DeskStore(dataDirectory:directory.appendingPathComponent("discovery"),startServices:false,transport:DeviceTransport(state:{address,_ in
                attempted.append(address)
                return DeviceState(device_id:address.contains(".local") ? id:other,tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2.phone",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,_,_ in preconditionFailure("Discovery must not send") }))
            bound.settings.deviceURL="http://192.0.2.1";bound.settings.deviceID=id
            bound.tasks=[DeskTask(id:"local-draft",title:"Keep local draft")]
            await bound.connectDevice()
            precondition(bound.connected && bound.settings.deviceURL==DeviceIdentity.origin(id) && attempted.count==2)
            precondition(bound.tasks.map{$0.id}==["local-draft"] && bound.phoneOwnsScreen,"Discovery cannot import or take over")
            let loaded=DeskStore(dataDirectory:directory.appendingPathComponent("discovery"),startServices:false)
            precondition(loaded.settings.deviceID==id,"Binding persists")
            bound.forgetDeviceBinding();precondition(bound.settings.deviceID==nil && bound.settings.deviceURL.isEmpty && bound.tasks.count==1 && !bound.connected)
        }
        print("PASS: offline recovery, unchanged-frame dedupe, no task resurrection, phone ownership, no automatic full refresh, bounded backoff, Agent timeout/restart/stop")
    }
}
