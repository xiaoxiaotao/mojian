# 墨间 Agent 引擎

官方 DeepSeek Harness SDK 验证接入，固定 @deepseek-ai/dsh-sdk-client 0.2.1-alpha.5。参考源码固定提交1517a4dbca0a2789ff1d41ba439600f8547d23fa，在原开发机保存在references/deepseek-harness，保留原Git元数据，未修改上游源码。该完整上游克隆忽略提交；新克隆可按此提交自行取得参考源码。

## 架构

SwiftUI → Swift HarnessBridge → Node bridge → 官方SDK sdk-minimal profile → 墨间MCP工具 → Swift本地工具。通过stdio JSONL和权限0700临时目录中的0600 Unix socket连接，不开放公网或本地HTTP端口。

模型Key从钥匙串进入应用内存，经匿名管道传递给桥进程，再以环境变量传入官方模型适配器；不写入配置、参数、诊断或模型上下文。地址仅交给高德解析，模型获得耗时和路况摘要。

mojian.patch.yml禁用默认bash/pwsh、文件与工作目录工具、MCP资源工具，只注册固定墨间工具。后台检查在宿主再次限制为只读；所有任务、记忆和规则写入只产生提案，由原生界面明确确认。没有开放通用Shell、自动安装插件、任意文件访问或网页操作。进程本身不是OS级沙箱，不能宣称达到沙箱隔离。

## 构建和验证

以下命令从独立仓库根目录运行。先执行运行时准备脚本，再将`agent-engine/runtime/bin`加入PATH，使用锁定的Node/npm安装依赖。

- npm ci --prefix agent-engine：按锁文件安装；Node版本须符合上游要求。
- python3 tools/prepare_agent_runtime.py：准备固定、校验SHA256的官方Node运行时。
- runtime/为官方Node v24.22.0 darwin-arm64运行时；下载地址和SHA256见NODE-SOURCE.txt，校验后使用。runtime与node_modules忽略提交，构建时复制到app资源。
- tools/build_macos.sh：编译原生app并打包Agent依赖。
- python3 tools/verify_agent_engine.py --live：真实官方Harness和模型连续工具调用，使用隔离夹具，重启进程后恢复会话，不修改生产待办、偏好或设备。
- app --self-test：作息、跨日提醒窗口、过期路况、提案取消/确认、记忆和提醒开关跨实例保存等。

## 本地数据

~/Library/Application Support/MoJian/agent-state.json保存偏好、提醒规则、最近执行记录、会话ID和最近80条对话。harness/保存官方会话日志；退出重开可恢复。未确认提案不执行、不跨重启自动批准。日志与记忆均为本机个人数据，不应作为分发资源。

## 主动通勤

默认关闭；用户确认提案或手动开启后，下一个工作日上班前3小时进入5分钟检查窗口（支持跨午夜）。到建议出发窗口才唤起模型查询和整理，成功后按到岗日期持久化去重，每天一次；没有变化不定时调用模型。Mac休眠或进程退出不会运行，系统通知另需用户允许；未允许系统通知时结果留在对话。

## 状态与限制

本次属于开发验证版：上游为alpha预览版，Node与整套SDK依赖使app约646MB，尚未裁剪，不是正式销售包。尚未进行长时间耗电、升级迁移或多系统稳定性验证。随包保留依赖LICENSE及Node许可证；正式商业发布仍需正式签名、公证、完整第三方许可清单和数据服务商业授权核对。

资料：https://github.com/deepseek-ai/deepseek-harness 及仓库packages/sdk/client、packages/bundle/sdk-minimal、packages/mcp/mcp-client说明。
