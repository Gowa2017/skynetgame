--- state.lua 文件用来存在在服务的各模块间共享的数据
return {
    gate    = nil,
    master  = nil,
    clients = {},
}
