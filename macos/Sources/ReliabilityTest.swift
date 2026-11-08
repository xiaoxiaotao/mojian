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
        // A reboot can keep the saved layout ID while losing the controller's display baseline.
        do {
            var baselineReady=true,delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("baseline-loss"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(tasks:[],local_mode:true,needs_full:!baselineReady,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:baselineReady)
            },send:{_,_,_,_,_,_,_,_ in delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true
            await checked.connectDevice();await checked.send(full:false)
            precondition(delivered==1)
            baselineReady=false;await checked.send(full:false)
            precondition(delivered==1 && checked.deviceNeedsFull && checked.syncPending && checked.syncStatus.contains("重建显示基准"),"Cached frame must never hide baseline loss")
        }
        // Never redirect an in-flight snapshot to a newly edited device address.
        do {
            var gate=false,waiting=false,delivered:[String]=[]
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("destination-change"),startServices:false,transport:DeviceTransport(state:{_,_ in
                if gate{waiting=true;try await Task.sleep(nanoseconds:60_000_000)}
                return DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{url,_,_,_,_,_,_,_ in delivered.append(url)}))
            checked.settings.deviceURL="http://old.invalid";checked.settings.layout = .focus
            await checked.connectDevice();gate=true
            let sending=Task{await checked.send(full:false)}
            while !waiting{await Task.yield()}
            checked.settings.deviceURL="http://new.invalid";await sending.value
            precondition(delivered.isEmpty && !checked.connected && !checked.isSending && checked.lastSync==nil,"Address change during read must prevent a redirected write")
        }
        // An old destination's completed send must not become a new destination's receipt.
        do {
            var waiting=false,delivered:[String]=[]
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("stale-receipt"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{url,_,_,_,_,_,_,_ in delivered.append(url);waiting=true;try await Task.sleep(nanoseconds:60_000_000)}))
            checked.settings.deviceURL="http://old.invalid";checked.settings.layout = .focus
            await checked.connectDevice()
            let sending=Task{await checked.send(full:false)}
            while !waiting{await Task.yield()}
            checked.settings.deviceURL="http://new.invalid";await sending.value
            precondition(delivered==["http://old.invalid"] && checked.lastSync==nil && checked.lastDeviceContact==nil && checked.syncPending && !checked.isSending,"Old acknowledgement must not update new target health")
        }
        // Scheduled mode changes may update the Mac preview, but cannot take over a phone screen.
        do {
            var delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("phone-schedule"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2.phone",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,_,_ in delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true;checked.settings.scheduleEnabled=true
            checked.afterHours=WorkSchedule.working(Date(),checked.settings)
            await checked.connectDevice();await checked.checkSchedule()
            precondition(delivered==0 && checked.phoneOwnsScreen && checked.syncPending && checked.syncStatus.contains("手机控制"),"Schedule cannot silently take phone ownership")
        }
        // Device changes are merged and sent on the next recovery pass, rather than waiting a minute.
        do {
            var items:[DeviceState.Item]=[],delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("remote-change"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(tasks:items,local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,_,_ in delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true
            await checked.connectDevice();await checked.send(full:false)
            items=[.init(id:"remote-new",title:"Remote fixture",due:nil)]
            await checked.readDeviceChanges()
            precondition(checked.syncPending && checked.tasks.map{$0.id}==["remote-new"])
            await checked.recoverConnection();precondition(delivered==2 && !checked.syncPending)
        }
        // Phone takeover can occur after the schedule decision but before the state read completes.
        do {
            var layout="mac.focus.red-v2",delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("schedule-race"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:layout,external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,_,_ in delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus
            await checked.connectDevice();layout="mac.focus.red-v2.phone"
            await checked.send(full:true,scheduled:true)
            precondition(delivered==0 && checked.phoneOwnsScreen && checked.syncPending,"Scheduled send must verify fresh ownership before writing")
        }
        // Device polling and an edit share one queue, avoiding six-second read timeouts during full refresh.
        do {
            var gate=false,waiting=false,reading=false,delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("poll-edit"),startServices:false,transport:DeviceTransport(state:{_,_ in
                if gate{waiting=true;reading=true;try await Task.sleep(nanoseconds:40_000_000);reading=false}
                return DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,_,_ in precondition(!reading);delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true
            await checked.connectDevice();gate=true
            let poll=Task{await checked.readDeviceChanges()}
            while !waiting{await Task.yield()}
            await checked.send(full:false);precondition(delivered==0,"Send must queue while poll is in flight")
            await poll.value
            for _ in 0..<100{if delivered>0{break};try? await Task.sleep(nanoseconds:5_000_000)}
            precondition(delivered==1 && !checked.isSending && !checked.syncPending,"Queued edit must drain after polling")
        }
        // A peer may change weather/cards while keeping identical tasks and layout.
        do {
            var key="initial",delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("visual-version"),startServices:false,transport:DeviceTransport(state:{_,_ in
                DeviceState(content_key:key,tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,sentKey,full,_ in precondition(!full);key=sentKey;delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true
            await checked.connectDevice();await checked.send(full:false);await checked.send(full:false)
            precondition(delivered==1,"Matching remote version permits deduplication")
            key="another-writer-frame";await checked.send(full:false)
            precondition(delivered==2 && !checked.syncPending,"Remote visual change cannot reuse the local cached receipt")
            key="another-writer-cards";await checked.readDeviceChanges()
            precondition(checked.syncPending,"Read-only poll must detect visual drift even with equal tasks")
            await checked.recoverConnection()
            precondition(delivered==3 && !checked.syncPending,"Detected visual drift drains by partial update")
        }
        // Every I/O entry point participates in the same gate, including connection and diagnostics.
        for firstOperation in ["connect","send","poll","health"] {
            var block=false,waiting=false,inFlight=0,peak=0,delivered=0,reads=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("io-gate-"+firstOperation),startServices:false,transport:DeviceTransport(state:{_,_ in
                inFlight+=1;peak=max(peak,inFlight);reads+=1
                if block{waiting=true;try await Task.sleep(nanoseconds:30_000_000)}
                inFlight-=1
                return DeviceState(tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,full,_ in precondition(inFlight==0 && !full,"A display commit must never overlap another read or silently full refresh");delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus;checked.settings.autoSync=true
            await checked.connectDevice();block=true
            let first=Task {
                switch firstOperation {
                case "connect":await checked.connectDevice()
                case "send":await checked.send(full:false)
                case "poll":await checked.readDeviceChanges()
                default:await checked.checkHealthConnection()
                }
            }
            while !waiting{await Task.yield()}
            checked.settings.note="Newest queued content"
            await checked.connectDevice();await checked.checkHealthConnection();await checked.send(full:false)
            await first.value
            for _ in 0..<200{if !checked.deviceIOBusy && delivered>0 && !checked.syncPending{break};try? await Task.sleep(nanoseconds:5_000_000)}
            precondition(peak==1 && delivered>0 && reads>=3 && !checked.deviceIOBusy && !checked.syncPending,"Connection, polling, health and queued edits must serialize and drain: \(firstOperation)")
        }
        // Autonomous minute/weather drawing may be busy while HTTP remains responsive.
        do {
            var polls=0,delivered=0
            let checked=DeskStore(dataDirectory:directory.appendingPathComponent("display-busy"),startServices:false,transport:DeviceTransport(state:{_,_ in
                polls+=1
                return DeviceState(display_busy:polls==2,tasks:[],local_mode:true,needs_full:false,layout_id:"mac.focus.red-v2",external_layout:true,baseline_ready:true)
            },send:{_,_,_,_,_,_,full,_ in precondition(polls==3 && !full);delivered+=1}))
            checked.settings.deviceURL="http://fixture.invalid";checked.settings.layout = .focus
            await checked.connectDevice();await checked.send(full:false)
            precondition(delivered==1 && checked.connected && !checked.syncPending,"Busy autonomous refresh must wait before submitting, not mark the device offline")
        }
        // Upload acceptance must never be reported as a completed physical refresh.
        do {
            var polls=0
            try await DeviceCommitReceipt.wait(transaction:"fixture-transaction",pollNanoseconds:0){
                polls+=1;return Data(("{\"transaction_id\":\"fixture-transaction\",\"status\":\""+(polls==1 ? "pending":"completed")+"\"}").utf8)
            }
            precondition(polls==2,"Pending receipt keeps the send open until completed")
            for payload in ["{\"transaction_id\":\"wrong\",\"status\":\"completed\"}","{\"transaction_id\":\"fixture-transaction\",\"status\":\"failed\",\"error\":\"BUSY fixture\"}","{\"transaction_id\":\"fixture-transaction\",\"status\":\"unknown\"}","{}"] {
                do{try await DeviceCommitReceipt.wait(transaction:"fixture-transaction",pollNanoseconds:0){Data(payload.utf8)};preconditionFailure("Invalid/failed receipt accepted")}catch{}
            }
            do{try await DeviceCommitReceipt.wait(transaction:"fixture-transaction",timeout:0,pollNanoseconds:0){Data("{\"transaction_id\":\"fixture-transaction\",\"status\":\"pending\"}".utf8)};preconditionFailure("Pending transaction never timed out")}catch{precondition(ConnectionRecovery.transient(error))}
        } catch {preconditionFailure("Receipt fixture failed: \(error)")}
        // A brief read failure must retry the SAME receipt, never accept a
        // guessed success or restart the frame submission.
        do {
            var polls=0
            try await DeviceCommitReceipt.wait(transaction:"receipt-after-dns",timeout:1,pollNanoseconds:0){
                polls+=1
                if polls==1{throw URLError(.dnsLookupFailed)}
                let state=polls==2 ? "pending":"completed"
                return Data("{\"transaction_id\":\"receipt-after-dns\",\"status\":\"\(state)\"}".utf8)
            }
            precondition(polls==3 && ConnectionRecovery.transient(URLError(.dnsLookupFailed)))
            var cancelledPolls=0
            do{try await DeviceCommitReceipt.wait(transaction:"cancelled",pollNanoseconds:0){cancelledPolls+=1;throw URLError(.cancelled)};preconditionFailure("Cancellation was swallowed")}catch{precondition((error as NSError).code==NSURLErrorCancelled && cancelledPolls==1)}
        }catch{preconditionFailure("Transient receipt retry failed: \(error)")}
        // An online screen awaiting an explicit baseline is not disconnected.
        var healthReads=0,healthSends=0,healthFails=false
        let healthOnly=DeskStore(dataDirectory:directory.appendingPathComponent("health-only"),startServices:false,transport:DeviceTransport(state:{_,_ in
            healthReads+=1
            if healthFails{throw URLError(.cannotConnectToHost)}
            return DeviceState(tasks:[.init(id:"remote-only",title:"Do not import",due:nil)],local_mode:true,needs_full:true,layout_id:"mac.calendar.red-v2",external_layout:true,baseline_ready:false)
        },send:{_,_,_,_,_,_,_,_ in healthSends+=1}))
        healthOnly.settings.deviceURL="http://health.invalid"
        let untouched=healthOnly.tasks
        await healthOnly.checkHealthConnection()
        precondition(healthOnly.connected && healthOnly.deviceNeedsFull && healthOnly.lastDeviceContact != nil)
        precondition(healthOnly.syncStatus.contains("设备在线") && healthOnly.status==healthOnly.syncStatus && healthOnly.lastSync==nil)
        precondition(healthOnly.tasks==untouched && healthSends==0,"Read-only health must not import tasks or send a frame")
        healthFails=true;await healthOnly.checkHealthConnection()
        precondition(!healthOnly.connected && healthOnly.lastDeviceContact==nil)
        healthFails=false;await healthOnly.checkHealthConnection()
        precondition(healthOnly.connected && healthOnly.deviceNeedsFull && healthReads==3 && healthSends==0)
        print("PASS: offline recovery, unchanged-frame dedupe, no task resurrection, phone ownership, no automatic full refresh, bounded backoff, baseline loss, destination races, phone schedule protection, Agent timeout/restart/stop, remote visual version, complete device I/O serialization")
    }
}
