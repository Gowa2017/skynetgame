return {
  c2s     = {
    ["c2s.game.Enter"] = 20005,
    ["c2s.game.Logon"] = 20004,
    ["c2s.game.Quit"] = 20006,
    ["c2s.login.ChallengeResp"] = 20002,
    ["c2s.login.Handshake"] = 20003,
    ["c2s.login.Login"] = 20001,
  },
  c2sbyid = {
    [20006] = { "c2s", "game", "Quit" },
    [20001] = { "c2s", "login", "Login" },
    [20002] = { "c2s", "login", "ChallengeResp" },
    [20003] = { "c2s", "login", "Handshake" },
    [20004] = { "c2s", "game", "Logon" },
    [20005] = { "c2s", "game", "Enter" },
  },
  s2c     = {
    ["s2c.game.Save"] = 10006,
    ["s2c.game.Scene"] = 10001,
    ["s2c.game.SceneEntitys"] = 10002,
    ["s2c.login.Challenge"] = 10003,
    ["s2c.login.Key"] = 10004,
    ["s2c.login.Resp"] = 10005,
  },
  s2cbyid = {
    [10003] = { "s2c", "login", "Challenge" },
    [10004] = { "s2c", "login", "Key" },
    [10005] = { "s2c", "login", "Resp" },
    [10006] = { "s2c", "game", "Save" },
    [10001] = { "s2c", "game", "Scene" },
    [10002] = { "s2c", "game", "SceneEntitys" },
  },
}
