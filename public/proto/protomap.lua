return {
  c2s     = {
    ["c2s.login.Auth"] = 20002,
    ["c2s.login.Handshake"] = 20003,
    ["c2s.login.Login"] = 20001,
  },
  c2sbyid = {
    [20001] = "c2s.login.Login",
    [20002] = "c2s.login.Auth",
    [20003] = "c2s.login.Handshake",
  },
  s2c     = {
    ["s2c.login.Challenge"] = 10001,
    ["s2c.login.HandshakeOK"] = 10003,
    ["s2c.login.Key"] = 10004,
    ["s2c.login.LoginOK"] = 10002,
  },
  s2cbyid = {
    [10004] = "s2c.login.Key",
    [10001] = "s2c.login.Challenge",
    [10002] = "s2c.login.LoginOK",
    [10003] = "s2c.login.HandshakeOK",
  },
}
