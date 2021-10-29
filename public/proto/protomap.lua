return {
  c2s     = {
    ["c2s.game.Logon"] = 20004,
    ["c2s.login.ChallengeResp"] = 20002,
    ["c2s.login.Handshake"] = 20003,
    ["c2s.login.Login"] = 20001,
  },
  c2sbyid = {
    [20004] = "c2s.game.Logon",
    [20001] = "c2s.login.Login",
    [20002] = "c2s.login.ChallengeResp",
    [20003] = "c2s.login.Handshake",
  },
  s2c     = {
    ["s2c.login.Challenge"] = 10001,
    ["s2c.login.Key"] = 10003,
    ["s2c.login.Resp"] = 10002,
  },
  s2cbyid = {
    [10001] = "s2c.login.Challenge",
    [10002] = "s2c.login.Resp",
    [10003] = "s2c.login.Key",
  },
}
