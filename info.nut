class MGAI extends AIInfo {
  function GetAuthor()      { return "Martijn Gastkemper"; }
  function GetName()        { return "MGAI"; }
  function GetDescription() { return "Transports oil"; }
  function GetVersion()     { return 2; }
  function GetDate()        { return "2021-04-06"; }
  function CreateInstance() { return "MGAI"; }
  function GetShortName()   { return "XXXX"; }
  function GetAPIVersion()  { return "1.11"; }

  function GetSettings() {
    AddSetting({
      name = "Debug_Level",
      description = "Debug Level ",
      min_value = 0,
      max_value = 7,
      easy_value = 3,
      medium_value = 3,
      hard_value = 3,
      custom_value = 3,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "Use_Pathfinder",
      description = "Disable pathfinder to speedup the AI. Connection by water won't be checked",
      min_value = 0,
      max_value = 1,
      easy_value = 1,
      medium_value = 1,
      hard_value = 1,
      custom_value = 1,
      flags = CONFIG_INGAME
    });
  }
}

/* Tell the core we are an AI */
RegisterAI(MGAI());
