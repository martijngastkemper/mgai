require("AYStar.nut");
require("utilities.nut");

class Pathfinder {

  _pathfinder = null;
  _goals = null;
  _max_cost = null;
  _tile_cost = null;

  constructor() {
    this._pathfinder = AyStar(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._max_cost = 30000;
    this._tile_cost = 2;
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
}

function Pathfinder::_Cost(self, path, new_tile, new_direction) {
  if (path == null) return 0;

  return path.GetCost() + self._tile_cost;
}

function Pathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
  local min_cost = self._max_cost;

  /* The costs of continuing path */
  local _tile_cost = self._tile_cost;

  foreach (goal_tile in goal_tiles) {
    local goal_direction = self.GetDirectionToGoal(self, cur_tile, goal_tile);

    local distance = AIMap.DistanceSquare(cur_tile, goal_tile);

    if (goal_direction == null) {
      min_cost = min(min_cost, distance * _tile_cost);
      continue;
    }

    /* The direction is not forward */
    if ((cur_direction & goal_direction) == 0) {
      _tile_cost = self._tile_cost * 3;
    }

    /* The direction is backwards */
    if (Utilities.GetOppositeDirection(cur_direction) == goal_direction) {
      _tile_cost = self._tile_cost * 4;
    }

    min_cost = min(min_cost, distance * _tile_cost);
  }
  return min_cost;
}

function Pathfinder::_Neighbours(self, path, cur_tile) {
  local tiles = [];

  if (path.GetCost() >= self._max_cost) return [];

  foreach (offset in Utilities.offsets) {
    local next_tile = cur_tile + offset;

    /* Only water (includes river and canals) and lock tiles are neighbours */
    if (!AITile.IsWaterTile(next_tile) && !AIMarine.IsLockTile(next_tile)) continue;

    /* Don't turn back */
    if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;

    /* Check for water connection because of sea to river tiles */
    local connected = AIMarine.AreWaterTilesConnected(cur_tile, next_tile);
    if (!connected) continue;

    if (path.GetParent() == null) {
      tiles.push([next_tile, self._GetDirection(null, cur_tile, next_tile)]);
    } else {
      tiles.push([next_tile, self._GetDirection(path.GetParent().GetTile(), cur_tile, next_tile)]);
    }
  }
  return tiles;
}

function Pathfinder::_CheckDirection(self, tile, existing_direction, new_direction) {
  return false;
}

function Pathfinder::FindPath(iterations) {
  foreach(sign, value in AISignList()) {
    AISign.RemoveSign(sign);
  }

  return this._pathfinder.FindPath(iterations);
}

function Pathfinder::_dir(from, to)
{
  local diff = to - from;
  local mapsize = AIMap.GetMapSizeX();
  if (diff == -1) return 1; // NE
  if (diff == mapsize) return 2; // SE
  if (diff == 1) return 4; // SW
  if (diff == -mapsize) return 8; // NW
  throw("Shouldn't come here in _dir");
}

/**
 * Get the direction between two or three points. The first 4 bytes contain the direction from => to. The second 4
 * bytes contain the direction pre_from => from.
 */
function Pathfinder::_GetDirection(pre_from, from, to)
{
  local result = this._dir(from,to) | (pre_from == null ? 0 : (this._dir(pre_from, from) << 4));
  return result;
}


function Pathfinder::GetDirectionToGoal(self, cur_tile, goal_tile)
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
  return this._GetDirection(null, cur_tile, next_tile);
}
