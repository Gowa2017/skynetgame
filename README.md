# Start

```
make
```

# Protobuf

Message's define in `public/proto`, this have some limit.

- Every proto define file must define it package, and package name must like `s2c.group` or other.

Then we can compile the message's to a `.pb` user `public/proto/compile.sh` :

```sh
bash public/proto/compile.sh
```

After this, there will generate a proto message to a inter id map file at `public/proto/protomap.lua`， and message's lua annation lib at `public/proto/proto.lua`。

Then, we define our `pb` file and `protomap` file at skynet config file:

```lua
protoFile   = 'public/proto/proto.pb'
protoMap    = 'public/proto/protomap.lua'
```

# About protobuf messages

We use skynet 'snax.gateserver' to receive data on network，`go.service.gate.lua` is a wrapper for it, it's main response is to manage the connect's and determinate where to forward the network data.

Some service call 'gate' service withe `forward` command will make the gate forward network data to it.

```lua
   skynet.redirect(agent, c.client, "client", fd, msg, sz)
```

There we use the skynet message type **Client**， whick we define it's unpack method in `conf/message.lua`。

# About service

All skynet message types are defined here. We use `go.service` to enable a message type, only need to pass a table which contains the message's command handlers.

```lua
local service = require("go.service")
service.setMessageCmds("lua", { socket = SOCKET, cmd    = CMD }, true, false)
service.start(function() gate = skynet.newservice("gate") end)
```

Other service send message will like this:

```lua
skynet.call(addr, 'lua', 'socket.data', ...)
```

# mongodb

user tingsh to install mongodb 5.0.4.

```js
use admin
db.createUser(
  {
    user: "root",
    pwd: "wouinibaba", // or cleartext password
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)

use account
db.createUser({
  user: "acc",
  pwd: "wouinibaba", // Or  "<cleartext password>"
  roles: [{ role: "readWrite", db: "account" }],
});

use game
db.createUser({
  user: "game",
  pwd: "wouinibaba", // Or  "<cleartext password>"
  roles: [{ role: "readWrite", db: "game" }],
});
```
