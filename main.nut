require("Pathfinder.nut");
require("utilities.nut");

class MGAI extends AIController
{
  constructor() {
    this.oilCargoId = this.fetchOilCargoId();
    this.connectedOilRigs = [];
    this.failedOilRigs = [];
    this.pathfinder = ShipPathfinder();
  }

  function fetchOilCargoId()
  {
    local cargoList = AICargoList();
    cargoList.Valuate(AICargo.HasCargoClass, AICargo.CC_LIQUID);
    cargoList.KeepValue(1);
    if (cargoList.Count() == 0) {
      AILog.Error("Your game doesn't have any oil cargo, and as we are an oil only AI, we can't do anything");
    }

    return cargoList.Begin();
  }

  oilCargoId = null;
  connectedOilRigs = null;
  failedOilRigs = null;
  pathfinder = null;
}

function MGAI::Save()
{
  local table = {connectedOilRigs = this.connectedOilRigs, failedOilRigs = this.failedOilRigs};
  return table;
}

function MGAI::Load(version, data)
{
  AILog.Info("Loading");
  if (data.rawin("connectedOilRigs")) {
    this.connectedOilRigs = data.rawget("connectedOilRigs");
    AILog.Info("Connected oil rigs: " + this.connectedOilRigs.len());
  }

  if (data.rawin("failedOilRigs")) {
    this.failedOilRigs = data.rawget("failedOilRigs");
    AILog.Info("Failed oil rigs: " + this.failedOilRigs.len());
  }
}

function MGAI::Start()
{

  while (true) {
    this.Sleep(50);
    this.PollEvents();

    local oilRig = this.PollForAOilRig();

    if (oilRig == false) {
      AILog.Info("No suitable oil rig found.");
      continue;
    }
    if (this.BuildRoute(oilRig)) {
      this.connectedOilRigs.append(oilRig);
      continue;
    }

    if (AIError.GetLastError() != AIError.ERR_NOT_ENOUGH_CASH) {
      this.failedOilRigs.append(oilRig);
    }
  }
}

function MGAI::BuildRoute(oilRig) {
  AILog.Info("Start connecting " + AIIndustry.GetName(oilRig));

  local nearbyRefineries = this.FindNearbyRefineries(oilRig);

  if (nearbyRefineries.IsEmpty()) {
    AILog.Info("No nearby refineries found");
    return false;
  }

  local finalDockTile = null;

  foreach(refinery, value in nearbyRefineries) {
    AILog.Info("Check nearby refinery: " + AIIndustry.GetName(refinery));

    local dockTiles = this.GetDockableTiles(refinery);
    if (dockTiles.IsEmpty()) {
      AILog.Info("No place for a dock.");
      continue;
    }

    local path = this.GetPathBetweenRefineryAndOilRig(oilRig, dockTiles);
    if (path == false) {
      AILog.Info("No ship path between oilrig and refinery.");
      continue;
    }

    finalDockTile = path.GetTile();

    this.BuildDock(finalDockTile);

    break;
  }

  if (finalDockTile == null) return false;

  local depotTile = this.BuildDepot(oilRig);
  if(depotTile == false) return false;

  return this.BuildShip(
    AIIndustry.GetDockLocation(oilRig),
    finalDockTile,
    depotTile
  );
}


function MGAI::PollEvents()
{
  while (AIEventController.IsEventWaiting()) {
    local e = AIEventController.GetNextEvent();
    switch (e.GetEventType()) {
      case AIEvent.ET_INDUSTRY_OPEN:
        local ec = AIEventIndustryOpen.Convert(e);
        local i  = ec.GetIndustryID();
        AILog.Info("We have a new industry (" + AIIndustry.GetName(i) + ")");
        if (AIIndustry.IsCargoAccepted(i, this.oilCargoId)) {
          this.failedOilRigs = [];
        }
        break;
    }
  }
}

function MGAI::GetAdjacentTiles(tile)
{
  local adjTiles = AITileList();

  foreach (offset in Utilities.offsets) {
    adjTiles.AddTile(tile - offset);
  }

  return adjTiles;
}

function MGAI::GetPathBetweenRefineryAndOilRig(oilRig, refineryDockableTiles)
{
  local oilRigTiles = AITileList_IndustryProducing(oilRig, 1);

  this.pathfinder.InitializePath(Utilities.AIListToArray(oilRigTiles), Utilities.AIListToArray(refineryDockableTiles));

  local path = this.pathfinder.FindPath(500);

  if (path == null) return false;

  return path;
}

function MGAI::GetDockableTiles(refinery)
{
  local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);

  local tiles = AITileList_IndustryAccepting(refinery, radius);
  local dockableTiles = AIList();

  local test = AITestMode();

  foreach (tile, value in tiles) {
    if (AIMarine.IsDockTile(tile)) {
      dockableTiles.AddItem(tile, 0);
      continue;
    }

    if (AIMarine.BuildDock(tile, AIStation.STATION_JOIN_ADJACENT)) {
      dockableTiles.AddItem(tile, 0);
    }
  }

  return dockableTiles;
}

function MGAI::BuildDock(tile)
{
  if (AIMarine.IsDockTile(tile)) {
    return true;
  }
  local costs = AIMarine.GetBuildCost(AIMarine.BT_DOCK);
  this.fixMoney(costs);

  return AIMarine.BuildDock(tile, AIStation.STATION_JOIN_ADJACENT);
}

function MGAI::BuildDepot(oilRig) {
  AILog.Info("Let's build a depot near " + AIIndustry.GetName(oilRig));

  local tiles = AITileList_IndustryProducing(oilRig, 3);

  /* Check if there's already a depot */
  local depot = null;
  foreach( tile, value in tiles ) {
    if( AIMarine.IsWaterDepotTile(tile) ) {
      AILog.Info("Depot already exists");
      return tile;
    }
  }

  local costs = AIMarine.GetBuildCost(AIMarine.BT_DEPOT);
  this.fixMoney(costs);

  foreach(tile, value in tiles) {
    foreach(frontTile, value in this.GetAdjacentTiles(tile)) {
      if (AIMarine.BuildWaterDepot(tile, frontTile)) {
        AILog.Info("Build depot");
        return tile;
      }
    }
  }

  AILog.Info("Depot building failed")
  return false;
}

function MGAI::BuildShip(source, destination, depot)
{
  AILog.Info("Let's build a ship" );

  local engines = AIEngineList(AIVehicle.VT_WATER);
  engines.Valuate(AIEngine.GetCargoType );
  engines.KeepValue(this.oilCargoId);

  local engine = engines.Begin();

  this.fixMoney(AIEngine.GetPrice(engine));

  local ship = AIVehicle.BuildVehicle(depot, engine);

  if (!AIVehicle.IsValidVehicle(ship)) return false;

  AIOrder.AppendOrder(ship, source, AIOrder.OF_FULL_LOAD);
  AIOrder.AppendOrder(ship, destination, AIOrder.OF_UNLOAD);

  AIVehicle.StartStopVehicle(ship);
  return true;
}

function MGAI::fixMoney(money)
{
  local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
  local loan = AICompany.GetLoanAmount();

  /* Take a loan when balance is to low */
  if (balance < money) {
    AICompany.SetMinimumLoanAmount(loan + money);
  }
}

function MGAI::PollForAOilRig()
{
  local oilrigs = AIIndustryList_CargoProducing(this.oilCargoId);

  foreach(oilRig in this.failedOilRigs) {
    oilrigs.RemoveItem(oilRig);
  }

  foreach(oilRig in this.connectedOilRigs) {
    oilrigs.RemoveItem(oilRig);
  }

  oilrigs.Valuate(AIIndustry.GetLastMonthTransported, this.oilCargoId);
  oilrigs.KeepValue(0);

  oilrigs.Valuate(AIIndustry.HasDock);
  oilrigs.KeepValue(1);

  // Put the oilrig with the highest production at the beginning so we start with connecting the most valuable oilrig.
  oilrigs.Valuate(AIIndustry.GetLastMonthProduction, this.oilCargoId);
  oilrigs.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

  if (oilrigs.IsEmpty()) return false;

  return oilrigs.Begin();
}

function MGAI::FindNearbyRefineries(oilRig)
{
  local refineries = AIIndustryList_CargoAccepting(oilCargoId);
  local GetDistance = function (refinery, oilRig) {
    return AIMap.DistanceManhattan(AIIndustry.GetLocation(oilRig), AIIndustry.GetLocation(refinery));
  }

  refineries.Valuate(GetDistance, oilRig);
  refineries.KeepBelowValue(150);

  refineries.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

  return refineries;
}
