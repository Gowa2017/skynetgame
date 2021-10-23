return {
  c2s     = {
    login = { Auth      = 20002, Handshake = 20003, Login     = 20001 },
  },
  c2sbyid = {
    [20001] = { "login", "Login" },
    [20002] = { "login", "Auth" },
    [20003] = { "login", "Handshake" },
  },
  s2c     = {
    login = {
      Challenge   = 10001,
      HandshakeOK = 10003,
      Key         = 10004,
      LoginOK     = 10002,
    },
  },
  s2cbyid = {
    [10004] = { "login", "Key" },
    [10001] = { "login", "Challenge" },
    [10002] = { "login", "LoginOK" },
    [10003] = { "login", "HandshakeOK" },
  },
}
