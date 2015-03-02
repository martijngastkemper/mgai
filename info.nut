class MGAI extends AIInfo {
  function GetAuthor()      { return "Martijn Gastkemper"; }
  function GetName()        { return "MGAI"; }
  function GetDescription() { return "Transports oil"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2015-03-02"; }
  function CreateInstance() { return "MGAI"; }
  function GetShortName()   { return "XXXX"; }
  function GetAPIVersion()  { return "1.0"; }
}

/* Tell the core we are an AI */
RegisterAI(MGAI());