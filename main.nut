import("util.MinchinWeb", "MinchinWeb", 9);
ShipPathfinder <- MinchinWeb.ShipPathfinder;
Log <- MinchinWeb.Log;

class MGAI extends AIController 
{
  constructor() {
    this.oilCargoId = this.fetchOilCargoId();
    this.connectedOilRigs = [];
    this.failedOilRigs = [];
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
}

function MGAI::Save()
{
  local table = {connectedOilRigs = this.connectedOilRigs, failedOilRigs = this.failedOilRigs};
  return table;
}

function MGAI::Load(version, data)
{
  if (data.rawin("connectedOilRigs")) {
    this.connectedOilRigs = data.rawget("connectedOilRigs");
  }

  if (data.rawin("failedOilRigs")) {
    this.failedOilRigs = data.rawget("failedOilRigs");
  }
}

function MGAI::Start()
{
  _MinchinWeb_Log_.PrintDebugLevel();

  while (true) {
    this.Sleep(50);

    local oilRig = this.pickOilRig();

    if( oilRig == false ) {
      AILog.Info("No suitable oil rig found.");
      continue;
    }

    AILog.Info("Start connecting " + AIIndustry.GetName(oilRig));

    local refineries = this.searchRefineries(oilRig);

    if( refineries.Count() == 0) {
      AILog.Info("No suitable refineries found");
      this.failedOilRigs.append(oilRig);
      continue;
    }

    local dockTile = false;
    foreach(refinery, value in refineries) {
      if (dockTile) {
        continue;
      }
      AILog.Info("Found refinery " + AIIndustry.GetName(refinery));
      if (this.reachable(oilRig, refinery) == false) {
        AILog.Info("Refinery not reachable by water");
        continue;
      }

      AILog.Info("Let's find a tile for a dock near " + AIIndustry.GetName(refinery));
      local dockTiles = this.findDockTiles(oilRig, refinery);
      if (dockTiles == false) {
        AILog.Info("No place for a dock.");
        continue;
      }

      AILog.Info("Let's build a dock near " + AIIndustry.GetName(refinery));
      dockTile = this.buildDock(dockTiles);

    }

    if( dockTile == false ) {
      this.failedOilRigs.append(oilRig);
      continue;
    }

    local depotTile = this.buildDepot(oilRig)
      if( depotTile == false ) {
        this.failedOilRigs.append(oilRig);
        continue;
      }

    local ship = this.buildShip(
        AIIndustry.GetDockLocation(oilRig),
        dockTile,
        depotTile
        );

    if (ship == false) {
      this.failedOilRigs.append(oilRig);
      continue;
    }

    this.connectedOilRigs.append(oilRig);
  }
}

function MGAI::GetAdjacentTiles(tile)
{
  local adjTiles = AITileList();

  adjTiles.AddTile(tile - AIMap.GetTileIndex(1,0));
  adjTiles.AddTile(tile - AIMap.GetTileIndex(0,1));
  adjTiles.AddTile(tile - AIMap.GetTileIndex(-1,0));
  adjTiles.AddTile(tile - AIMap.GetTileIndex(0,-1));

  return adjTiles;
}

function MGAI::reachable(oilRig, refinery)
{
  local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
  local refineryTiles = AITileList_IndustryAccepting(refinery, radius);

  refineryTiles.Valuate(AITile.IsWaterTile);
  refineryTiles.KeepValue(1);

  if (refineryTiles.Count() == 0) {
    return false;
  }
  return true;

  local oilRigTiles = AITileList_IndustryProducing(oilRig, 1);
  oilRigTiles.Valuate(AITile.IsWaterTile);
  oilRigTiles.KeepValue(1);

  local oilRigTile = oilRigTiles.Begin();
  local refineryTile = refineryTiles.Begin();

  local pathfinder = ShipPathfinder();

  pathfinder.InitializePath([oilRigTile], [refineryTile]);

  /* Try to find a path. */
  local path = false;
  while (path == false) {
    path = pathfinder.FindPath(100);
    this.Sleep(1);
  }

  if (path == null) {
    /* No path was found. */
    AILog.Error("pathfinder.FindPath return null");
    return false;
  }

  return true;
}

function MGAI::findDockTiles(oilRig, refinery)
{
  local radius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
  local tiles = AITileList_IndustryAccepting(refinery, radius);

  tiles.Valuate(AITile.IsStationTile);
  tiles.KeepValue(1);

  if (tiles.Count() > 0) {
    return tiles;
  }

  local tiles = AITileList_IndustryAccepting(refinery, radius);

  tiles.Valuate(AITile.IsCoastTile);
  tiles.KeepValue(1);

  return tiles;
}

function MGAI::buildDock(tiles)
{
  /* Check if there's already a dock build */
  local station = null;
  foreach( tile, value in tiles ) {
    station = AIStation.GetStationID(tile);
    if( station && AIStation.IsValidStation(station) ) {
      AILog.Info("Dock already build");
      return tile;
    }
  }

  local dockTile = false;
  local dockStation = false;

  local costs = AIMarine.GetBuildCost(AIMarine.BT_DOCK);
  this.fixMoney(costs);

  foreach( tile, value in tiles )
  {
    if( AIMarine.BuildDock(tile, AIStation.STATION_NEW))
    {
      dockTile = tile;
      dockStation = AIStation.GetStationID(tile);
      break;
    }
  }

  if( dockTile == false ) {
    AILog.Info("Dock building failed");
    return false;
  }

  AILog.Info("Dock has been build");
  return dockTile;
}

function MGAI::buildDepot(oilRig) {
  AILog.Info("Let's build a depot near " + AIIndustry.GetName(oilRig));

  local tiles = AITileList_IndustryProducing(oilRig, 3);
  tiles.Valuate(AITile.IsWaterTile);
  tiles.KeepValue(1);

  /* Check if there's already a depot */
  local depot = null;
  foreach( tile, value in tiles ) {
    if( AIMarine.IsWaterDepotTile(tile) ) {
      AILog.Info("Depot already build");
      return tile;
    }
  }

  tiles.Valuate(AITile.IsWaterTile);
  tiles.KeepValue(1);
  tiles.Valuate(AITile.IsStationTile);
  tiles.KeepValue(0);

  local costs = AIMarine.GetBuildCost(AIMarine.BT_DEPOT);
  this.fixMoney(costs);

  foreach( tile, value in tiles ) {
    if( !AIMap.IsValidTile(tile)) {
      continue;
    }

    local frontTiles = GetAdjacentTiles(tile);
    frontTiles.Valuate(AITile.IsWaterTile);
    frontTiles.KeepValue(1);
    frontTiles.Valuate(AITile.IsStationTile);
    frontTiles.KeepValue(0);

    foreach( frontTile, value in frontTiles ) {
      if( !AIMap.IsValidTile(frontTile)) {
        continue;
      }

      if( AIMarine.BuildWaterDepot(tile, frontTile) ) {
        AILog.Info("Depot has been build");
        return tile;
      }
    }
  }

  AILog.Info("Depot building failed")
    return false;
}

function MGAI::buildShip(source, destination, depot)
{
  AILog.Info("Let's build a ship" );

  local vehicle_list = AIEngineList(AIVehicle.VT_WATER);
  vehicle_list.Valuate(AIEngine.GetCargoType );
  vehicle_list.KeepValue(this.oilCargoId);

  local vehicle = vehicle_list.Begin();

  this.fixMoney(AIEngine.GetPrice(vehicle));

  local ship = AIVehicle.BuildVehicle(depot, vehicle); 

  AIOrder.AppendOrder(ship, source, AIOrder.OF_FULL_LOAD);
  AIOrder.AppendOrder(ship, destination, AIOrder.OF_UNLOAD);

  AIVehicle.StartStopVehicle(ship);
  return ship;
}

function MGAI::fixMoney(money)
{
  local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
  local loan = AICompany.GetLoanAmount();

  /* Repay loan as much as possible */
  if (balance > money) {
    AICompany.SetMinimumLoanAmount(loan - balance);
  }  

  /* Take a loan when balance is to low */
  if (balance < money) {
    AICompany.SetMinimumLoanAmount(loan + money);
  }
}

function MGAI::pickOilRig()
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

  if (oilrigs.Count() == 0) {
    return false;
  }
  return oilrigs.Begin();
}

function MGAI::searchRefineries(oilRig)
{
  local refineries = AIIndustryList_CargoAccepting(oilCargoId);
  local manhattan = function (refinery, oilRig) {
    return AIMap.DistanceManhattan( AIIndustry.GetLocation(oilRig), AIIndustry.GetLocation(refinery) );
  }

  refineries.Valuate(manhattan, oilRig);
  refineries.KeepBelowValue(175);

  return refineries;
}

