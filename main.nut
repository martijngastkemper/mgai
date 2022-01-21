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
    } else {
      this.Sleep(50);
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

  local path = null;
  local costs = null;

  foreach(refinery, value in nearbyRefineries) {
    AILog.Info("Check nearby refinery: " + AIIndustry.GetName(refinery));

    local dockTiles = this.GetDockableTiles(refinery);
    if (dockTiles.IsEmpty()) {
      AILog.Info("No place for a dock.");
      continue;
    }

    path = this.GetPathBetweenRefineryAndOilRig(oilRig, dockTiles);
    if (path == false) {
      AILog.Info("No ship path between oilrig and refinery.");
      continue;
    }

    local accounting = AIAccounting();
    local test = AITestMode();
    if (!this.BuildPath(path, test)) {
      AILog.Info("Path between oilrig and refinery can't be build.");
      continue;
    };

    costs = accounting.GetCosts();
    AILog.Info(costs);
    break;
  }

  if (!path) return false;

  local accounting = AIAccounting();
  if (!this.BuildDepot(oilRig, AITestMode())) return false;
  costs += accounting.GetCosts();

  if (!this.FixMoney(costs)) return false;

  if (!this.BuildPath(path)) return false;

  local depotTile = this.BuildDepot(oilRig);
  if(depotTile == false) return false;

  if (!this.FixMoney(20000)) return false;

  return this.BuildShip(
    AIIndustry.GetDockLocation(oilRig),
    path.GetTile(),
    depotTile
  );
}

function MGAI::BuildPath(path, test = null) {
  if (test) {
    AILog.Info("Test building path, starting at " + Utilities.PrintTile(path.GetTile()));
  } else {
    AILog.Info("Build path, starting at " + Utilities.PrintTile(path.GetTile()));
  }
  local firstIteration = true;

  while (path != null) {
    local par = path.GetParent();
    if (par != null) {
      local last_node = path.GetTile();

      if (firstIteration) {
        AILog.Info("Build a dock");
        if (!this.BuildDock(last_node)) {
           AILog.Info("Building failed");
           if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
             return false;
           }
        }
      } else if (Utilities.IsValidSlope(last_node) && !AIMarine.IsLockTile(last_node)) {
        AILog.Info("Build a lock");
        if (!AIMarine.BuildLock(last_node)) {
          AILog.Info("Building failed");
          if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
            return false;
          }
        }
      }
    }
    path = par;
    firstIteration = false;
  }
  return true;
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

  return AIMarine.BuildDock(tile, AIStation.STATION_JOIN_ADJACENT);
}

function MGAI::BuildDepot(oilRig, test = null) {
  if (test) {
    AILog.Info("Let's find a place for a depot near " + AIIndustry.GetName(oilRig));
  } else {
    AILog.Info("Let's build a depot near " + AIIndustry.GetName(oilRig));
  }

  local tiles = AITileList_IndustryProducing(oilRig, 3);

  /* Check if there's already a depot */
  local depot = null;
  foreach( tile, value in tiles ) {
    if( AIMarine.IsWaterDepotTile(tile) ) {
      AILog.Info("Depot already exists");
      return tile;
    }
  }

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

  this.FixMoney(AIEngine.GetPrice(engine));

  local ship = AIVehicle.BuildVehicle(depot, engine);

  if (!AIVehicle.IsValidVehicle(ship)) return false;

  AIOrder.AppendOrder(ship, source, AIOrder.OF_FULL_LOAD);
  AIOrder.AppendOrder(ship, destination, AIOrder.OF_UNLOAD);

  AIVehicle.StartStopVehicle(ship);
  return true;
}

function MGAI::FixMoney(money)
{
  local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
  local loan = AICompany.GetLoanAmount();

  /* Take a loan when balance is to low */
  if (balance < money) {
    return AICompany.SetMinimumLoanAmount(min(loan + money, AICompany.GetMaxLoanAmount()));
  }

  return true;
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

  local HasWaterNearby = function (refinery) {
    local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
    local tiles = AITileList_IndustryAccepting(refinery, radius);
    tiles.Valuate(AITile.IsWaterTile);
    tiles.KeepValue(1);
    return !tiles.IsEmpty();
  }
  refineries.Valuate(HasWaterNearby);
  refineries.KeepValue(1);

  local GetDistance = function (refinery, oilRig) {
    return AIMap.DistanceManhattan(AIIndustry.GetLocation(oilRig), AIIndustry.GetLocation(refinery));
  }
  refineries.Valuate(GetDistance, oilRig);
  refineries.KeepBelowValue(150);

  refineries.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

  return refineries;
}
