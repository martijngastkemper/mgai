class MGAI extends AIController 
{
   constructor() {
     this.oilCargoId = this.fetchOilCargoId()    
     this.connectedOilRigs = [];
     this.failedOilRigs = [];
   }
   
   function fetchOilCargoId()
   {
     local cargoList = AICargoList();
     cargoList.Valuate(AICargo.HasCargoClass, AICargo.CC_LIQUID);
     cargoList.KeepValue(1);
     if (cargoList.Count() == 0) AILog.Error("Your game doesn't have any oil cargo, and as we are an oil only AI, we can't do anything");

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
  while (true) {
    this.Sleep(25);
  
    local oilRig = this.pickOilRig()
    
    if( oilRig == false ) {
      AILog.Info("No suitable oil rig found.")
      continue;
    }
    
    local refinery = this.searchRefinery(oilRig);
    
    if( refinery == false ) {
      AILog.Info("No suitable oil rig found")
      this.failedOilRigs.append(oilRig);
      continue
    }
    
    local dockTile = this.buildDock(refinery)
    
    if( dockTile == false ) {
      this.failedOilRigs.append(oilRig);
      continue
    }
    
    local depotTile = this.buildDepot(oilRig)
    if( depotTile == false ) {
      this.failedOilRigs.append(oilRig);
      continue
    }

    local ship = this.buildShip(
      AIIndustry.GetDockLocation(oilRig),
      dockTile,
      depotTile
    )  

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

function MGAI::buildDock(refinery)
{
  AILog.Info("Let's build a dock near " + AIIndustry.GetName(refinery));
  local tiles = AITileList_IndustryAccepting(refinery, 5)
  
  /* Check if there's already a station */
  local station = null
  foreach( tile, value in tiles ) {
    station = AIStation.GetStationID(tile)
    if( station && AIStation.IsValidStation(station) ) {
        AILog.Info("Dock already build")
        return tile;
    }
  }
  
  tiles.Valuate(AITile.IsCoastTile)
  tiles.KeepValue(1)
  
  if( tiles.Count() == 0 ) {
    AILog.Info("No place for a dock.")
    return false
  }
  
  local dockTile = false
  local dockStation = false
  
  foreach( tile, value in tiles )
  {
    if( AIMarine.BuildDock(tile, AIStation.STATION_NEW))
    {
      dockTile = tile
      dockStation = AIStation.GetStationID(tile)
      break
    }
  }
  
  if( dockTile == false ) {
    AILog.Info("Dock building failed")
    return false
  } else {
    AILog.Info("Dock has been build")
    return dockTile
  }
}

function MGAI::buildDepot(oilRig) {
  AILog.Info("Let's build a depot near " + AIIndustry.GetName(oilRig));

  local x = AIMap.GetTileX(AIIndustry.GetLocation(oilRig))
  local y = AIMap.GetTileY(AIIndustry.GetLocation(oilRig))

  local tiles = AITileList()
  tiles.AddRectangle(AIMap.GetTileIndex(x - 5, y - 5), AIMap.GetTileIndex( x + 5, y + 5) )
  
  /* Check if there's already a depot */
  local depot = null
  foreach( tile, value in tiles ) {
    if( AIMarine.IsWaterDepotTile(tile) ) {
        AILog.Info("Depot already build")
        return tile;
    }
  }
  
  tiles.Valuate(AITile.IsWaterTile)
  tiles.KeepValue(1)
  tiles.Valuate(AITile.IsStationTile)
  tiles.KeepValue(0)

  foreach( tile, value in tiles ) {
    if( !AIMap.IsValidTile(tile)) {
       continue
    }

    local frontTiles = GetAdjacentTiles(tile)
    frontTiles.Valuate(AITile.IsWaterTile)
    frontTiles.KeepValue(1)
    frontTiles.Valuate(AITile.IsStationTile)
    frontTiles.KeepValue(0)
  
    foreach( frontTile, value in frontTiles ) {
      if( !AIMap.IsValidTile(frontTile)) {
        continue
      }
    
      if( AIMarine.BuildWaterDepot(tile, frontTile) ) {
        AILog.Info("Depot has been build")
        return tile
      }
    }
  }
  
  AILog.Info("Depot building failed")
  return false
}

function MGAI::buildShip(source, destination, dock)
{
  AILog.Info("Let's build a ship" )
  
  local vehicle_list = AIEngineList(AIVehicle.VT_WATER)
  vehicle_list.Valuate(AIEngine.GetCargoType )
  vehicle_list.KeepValue(oilCargoId)

  local ship = AIVehicle.BuildVehicle(dock, vehicle_list.Begin())
  
  if( !ship ) {
    AILog.Warning("Building failed with an error: " + AIError.GetLastErrorString());
    return false
  }
  
  AIOrder.AppendOrder(ship, source, AIOrder.OF_FULL_LOAD)
  AIOrder.AppendOrder(ship, destination, AIOrder.OF_UNLOAD)

  AIVehicle.StartStopVehicle(ship)
  return ship
}

function MGAI::pickOilRig()
{
  local oilrigs = AIIndustryList_CargoProducing(this.oilCargoId)

  foreach(oilRig in this.failedOilRigs) {
    oilrigs.RemoveItem(oilRig)
  }
 
  foreach(oilRig in this.connectedOilRigs) {
    oilrigs.RemoveItem(oilRig)
  }

  oilrigs.Valuate(AIIndustry.GetLastMonthTransported, this.oilCargoId)
  oilrigs.KeepValue(0)
  oilrigs.Valuate(AIIndustry.HasDock)
  oilrigs.KeepValue(1)
  
  local foundOilRig = oilrigs.Begin()

  AILog.Info(AIIndustry.GetName(foundOilRig))
  
  return foundOilRig
}

function MGAI::searchRefinery(oilrig)
{
  local refineries_list = AIIndustryList_CargoAccepting(oilCargoId)
  local destination = null;

  foreach( refinery, value in refineries_list )
  {
    if( AIMap.DistanceManhattan( AIIndustry.GetLocation(oilrig), AIIndustry.GetLocation(refinery) ) < 250 ) {
        AILog.Info(AIIndustry.GetName(refinery))
        return refinery;
    }
  }
  
  return false;
}


