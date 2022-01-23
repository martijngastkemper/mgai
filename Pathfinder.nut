require("utilities.nut");

class ShipPathfinder {

  constructor() {
    local AyStar = import("graph.aystar", "", 6);
    this._pathfinder = AyStar(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._max_cost = 10000000;

    this._cost_tile = 100;

    // Will be added to _cost_tile
    this._cost_turn = 10;

  }

  function InitializePath(sources, goals, ignored_tiles = []) {
    local nsources = [];

    foreach (tile in sources) {
      local path = [tile, 0xFF];
      nsources.push(path);
    }
    this._goals = goals;
    this._pathfinder.InitializePath(nsources, goals, ignored_tiles);
  }

  function FindPath(iterations);

  _pathfinder = null;
  _goals = null;
  _max_cost = null;
  _cost_tile = null;
  _cost_turn = null;

}

function ShipPathfinder::_Cost(self, path, new_tile, new_direction) {
  if (path == null) return 0;

  local prev_tile = path.GetTile();

  local cost = self._cost_tile;

  local distance = AIMap.DistanceManhattan(new_tile, prev_tile);
  if (distance > 1) {
    return path.GetCost();
  }

  // Turning on sea is expansive. This makes rivers and coasts cheaper 🤞
  if (AITile.IsSeaTile(prev_tile) && AITile.IsSeaTile(new_tile) && path.GetParent() != null && (prev_tile - path.GetParent().GetTile()) != (new_tile - prev_tile)) {
    cost += self._cost_turn;
  }

  return path.GetCost() + cost;
}

function ShipPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
  local min_cost = self._max_cost;
  /* As estimate we multiply the lowest possible cost for a single tile with
	 * with the minimum number of tiles we need to traverse. */
  foreach (goal_tile in goal_tiles) {
    min_cost = min(AIMap.DistanceManhattan(cur_tile, goal_tile) * self._cost_tile, min_cost);
  }
  return min_cost;
}

function ShipPathfinder::_Neighbours(self, path, cur_tile) {
  if (path.GetCost() >= self._max_cost) return [];

  local tiles = [];
  AISign.BuildSign(cur_tile, "y");

  if (self.IsRiverPart(cur_tile)) {
    local riverEnd = self.GetOtherRiverEnd(cur_tile, path.GetParent().GetTile());

    if (riverEnd) {
      AILog.Info("Start of river: " + Utilities.PrintTile(cur_tile));
      AILog.Info("End of river: " + Utilities.PrintTile(riverEnd[0]));
      tiles.push(riverEnd)
    }
  }

  foreach (offset in Utilities.offsets) {
    local next_tile = cur_tile + offset;

    /* Don't turn back */
    if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;

    // Sea (rivers and canels are handle before), valid slopes and dock tiles can be neighbours
    // - Sea is a neighbour, canals and rivers are handle before
    // - River parts, a river can split, so handle the path finder must follow the new rivers
    // - A goal could be a coast tile, so not covered by the other checks
    if (AITile.IsSeaTile(next_tile) || self.IsRiverPart(next_tile) || self.IsGoal(next_tile)) {
      tiles.push([next_tile, self.GetDirection(cur_tile, next_tile)]);
    }
  }
  return tiles;
}

function ShipPathfinder::IsGoal(next_tile) {
  foreach (goal in this._goals) {
    if (goal == next_tile) {
      return true;
    }
  }
}

// Look for the end of a river. That could be the sea, a split or land
function ShipPathfinder::GetOtherRiverEnd(cur_tile, prev_tile) {
  local length = 0;
  local nextTiles = null;
  while (this.IsRiverPart(cur_tile)){
    nextTiles = [];
    length += 1;

    foreach (offset in Utilities.offsets) {
      local next_tile = cur_tile + offset;

      /* Don't turn back */
      if (next_tile == prev_tile) continue;

      if (this.IsRiverPart(next_tile) && AIMarine.AreWaterTilesConnected(cur_tile, next_tile)) {
        nextTiles.append([next_tile, this.GetDirection(cur_tile, next_tile)]);
      }
    }

    // We found one next river, so it's straight, continue search
    if (nextTiles.len() == 1) {
      prev_tile = cur_tile;
      cur_tile = nextTiles.pop()[0];
    } else {
      // Rivers must be at least 2 tiles long
      if (length == 1) return false;
      return [cur_tile, this.GetDirection(prev_tile, cur_tile)];
    }
  };

  return false;
}

function ShipPathfinder::IsRiverPart(tile) {
  return AIMarine.IsCanalTile(tile) || AITile.IsRiverTile(tile) || AIMarine.IsLockTile(tile);
}

function ShipPathfinder::_CheckDirection(self, tile, existing_direction, new_direction) {
  return false;
}

function ShipPathfinder::FindPath(iterations) {
  return this._pathfinder.FindPath(iterations);
}

function ShipPathfinder::GetDirection(from, to)
{
  if (from - to == 1) return 1;
  if (from - to == -1) return 2;
  if (from - to == AIMap.GetMapSizeX()) return 4;
  if (from - to == -AIMap.GetMapSizeX()) return 8;
}
