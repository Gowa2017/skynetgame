-- 我们还可以将配置写在环境变量中
-- LuaFormatter off
include "config.path.lua"
------------skynet相关-------------
thread    = 2      -- 启动多少个工作线程。通常不要将它配置超过你实际拥有的 CPU 核心数。
start     = "clientstart"-- 你自己的启动逻辑
logger    = nil    -- 它决定了 skynet 内建的 skynet_error 这个 C API 将信息输出到什么文件中。如果 logger 配置为 nil ，将输出到标准输出。你可以配置一个文件名来将信息记录在特定文件中。
-- logservice= ""  -- 默认是 logger，我们也可以使用我们定义的 C 服务
-- logpath   = ""  -- 配置一个路径，当你运行时为一个服务打开 log 时，这个服务所有的输入消息都会被记录在这个目录下，文件名为服务地址。
harbor    = 0      -- 通常为 0 ，单节点模式，多节点的话优先使用 cluster 模式。当是单节点模式时，不需要配置 master starndalone address
-- standalone = "127.0.0.1:2013" -- 主节点监听
-- master     = "127.0.0.1:2013" -- 指定 skynet 控制中心的地址和端口，如果你配置了 standalone 项，那么这一项通常和 standalone 相同。
-- address    = "127.0.0.1:2016"当前 skynet 节点的地址和端口，方便其它节点和它组网。注：即使你只使用一个节点，也需要开启控制中心，并额外配置这个节点的地址和端口。

-- enablessl = true   -- 默认为空。如果需要通过 ltls 模块支持 https ，那么需要设置为 true 。
cluster   = "cluster.lua"     -- 它决定了集群配置文件的路径。
-- profile   = true   -- 默认为 true, 可以用来统计每个服务使用了多少 cpu 时间。在 DebugConsole 中可以查看。会对性能造成微弱的影响，设置为 false 可以关闭这个统计。
---* preload 的目的，是将一些全局内容给加载来，或是预先加载一些比较耗时的内容
preload     = root .. "lualib/preload.lua" --preload can define SERVICE_DESC = table.concat({...}) to get a better log output
----------------------相关定义-------------
--- 必须在一个叫做 conf.message 的模块中定义消息，放在哪里不重要，只要 require 能找到就行
logLevel    = 0    -- 日志级别 0 all，1 debug 2 info 3 warning 4 error 5 critical，级别越高打印的日志越少
dev         = true -- 暂时无用
protoFile   = 'public/proto/proto.pb'
protoMap    = 'public/proto/protomap.lua'
daobiao     = 'public/daobiao/server.lua'
mode        = 'G'
-- LuaFormatter on
