require("utilities.nut");

class ShipPathfinder {

  constructor() {
    local AyStar = import("graph.aystar", "", 6);
    this._pathfinder = AyStar(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._max_cost = 10000000;

    this._cost_tile = 100;

    // Will be added to _cost_tile
    this._cost_coast = -100;
    this._cost_lock = 45;
    this._cost_turn = 10;

  }

  function InitializePath(sources, goals, ignored_tiles = []) {
    local nsources = [];

    foreach (tile in sources) {
      /* tile and direction. direction is to the first goal to have something of a direction */
      local direction = this.GetDirectionToGoal(this, tile, goals[0]);
      local path = [tile, direction ? direction : 1];
      nsources.push(path);
    }
    this._goals = goals;
    this._pathfinder.InitializePath(nsources, goals, ignored_tiles);
  }

  function FindPath(iterations);

  _pathfinder = null;
  _goals = null;
  _max_cost = null;
  _cost_coast = null;
  _cost_lock = null;
  _cost_tile = null;
  _cost_turn = null;

}

function ShipPathfinder::_Cost(self, path, new_tile, new_direction) {
  if (path == null) return 0;
  AILog.Info(Utilities.PrintTile(new_tile));

  local prev_tile = path.GetTile();

  local cost = self._cost_tile;

//  if (!AITile.IsCoastTile(new_tile)) {
    if (path.GetParent() != null && (prev_tile - path.GetParent().GetTile()) != (new_tile - prev_tile)) {
      cost += self._cost_turn;
    }
//  }

//  if (AITile.IsCoastTile(new_tile)) {
//    cost += self._cost_coast;
//  }

//  if (Utilities.IsValidSlope(new_tile) && AITile.IsWaterTile(new_tile)) {
//    if (!AIMarine.IsLockTile(new_tile)) {
//      cost += self._cost_lock
//    }
//  }

  AILog.Info(cost);
  AILog.Info(path.GetCost());
  return path.GetCost() + cost;
}

function ShipPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
  local min_cost = self._max_cost;
  local coast_correction = 0;
//  if (AITile.IsCoastTile(cur_tile)) coast_correction = 1;
  /* As estimate we multiply the lowest possible cost for a single tile with
	 * with the minimum number of tiles we need to traverse. */
  foreach (tile in goal_tiles) {
    min_cost = min((AIMap.DistanceManhattan(cur_tile, tile) - coast_correction) * self._cost_tile, min_cost);
  }
  AISign.BuildSign(cur_tile, "" + min_cost);
  return min_cost;
}

function ShipPathfinder::_Neighbours(self, path, cur_tile) {
  local tiles = [];

  if (path.GetCost() >= self._max_cost) return [];

  foreach (offset in Utilities.offsets) {
    local next_tile = cur_tile + offset;

    /* Don't turn back */
    if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;

    // Skip going from land tile to land tile
//    if (Utilities.IsValidSlope(cur_tile) && Utilities.IsValidSlope(next_tile)) continue;

    // Water, valid slopes and dock tiles can be neighbours
    if (!AITile.IsWaterTile(next_tile) && !AITile.IsCoastTile(next_tile) && !AIMarine.IsDockTile(next_tile)) continue;

    tiles.push([next_tile, self._dir(cur_tile, next_tile)]);
  }
  return tiles;
}

function ShipPathfinder::_CheckDirection(self, tile, existing_direction, new_direction) {
  return false;
}

function ShipPathfinder::FindPath(iterations) {
  return this._pathfinder.FindPath(iterations);
}

/**
 * Get the direction between two points.
 */
function ShipPathfinder::_dir(from, to)
{
  local diff = to - from;
  local mapsize = AIMap.GetMapSizeX();
  if (diff == -1) return 1; // NE
  if (diff == mapsize) return 2; // SE
  if (diff == 1) return 4; // SW
  if (diff == -mapsize) return 8; // NW
  throw("Shouldn't come here in _dir");
}

function ShipPathfinder::GetDirectionToGoal(self, cur_tile, goal_tile)
{
  local cur_x = AIMap.GetTileX(cur_tile);
  local cur_y = AIMap.GetTileY(cur_tile);
  local dx = AIMap.GetTileX(goal_tile) - cur_x;
  local dy = AIMap.GetTileY(goal_tile) - cur_y;

  local abs_dx = abs(dx);
  local abs_dy = abs(dy);

  // If we sumbled upon an actual goal_tile skip the distance logic
  if (abs_dx + abs_dy == 0) {
    return null;
  }

  local next_x = cur_x;
  local next_y = cur_y;

  // When the x movement is bigger then y travers on the x axis else on y
  if (abs_dx >= abs_dy) {
    next_x = cur_x + ((dx >= -1 && dx <= 1 ) ? dx : dx / abs_dx);
  } else {
    next_y = cur_y + ((dy >= -1 && dy <= 1 ) ? dy : dy / abs_dy);
  }

  // Get the direction for the goal
  local next_tile = AIMap.GetTileIndex(next_x, next_y);
  return this._dir(cur_tile, next_tile);
}
