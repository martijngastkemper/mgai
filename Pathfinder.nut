require("AYStar.nut");
require("utilities.nut");

class ShipPathfinder {

  constructor() {
    this._pathfinder = AyStar(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._max_cost = 10000000;
    this._cost_tile = 100;
    this._cost_turn = 150;
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
  _cost_tile = null;
  _cost_turn = null;

}

function ShipPathfinder::_Cost(self, path, new_tile, new_direction) {
  if (path == null) return 0;

  local prev_tile = path.GetTile();

  local cost = self._cost_tile;

  if (path.GetParent() != null && (prev_tile - path.GetParent().GetTile()) != (new_tile - prev_tile)) {
    cost += self._cost_turn;
  }

  return path.GetCost() + cost;
}

function ShipPathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
  local min_cost = self._max_cost;

  /* The costs of continuing path */
  local _cost_tile = self._cost_tile;

  foreach (goal_tile in goal_tiles) {
    local goal_direction = self.GetDirectionToGoal(self, cur_tile, goal_tile);

    local distance = AIMap.DistanceSquare(cur_tile, goal_tile);

    if (goal_direction == null) {
      min_cost = min(min_cost, distance * self._cost_tile);
      continue;
    }

    /* The direction is not forward */
    if ((cur_direction & goal_direction) == 0) {
      _cost_tile = self._cost_tile * 3;
    }

    /* The direction is backwards */
    if (Utilities.GetOppositeDirection(cur_direction) == goal_direction) {
      _cost_tile = self._cost_tile * 4;
    }

    min_cost = min(min_cost, distance * _cost_tile);
  }
  return min_cost;
}

function ShipPathfinder::_Neighbours(self, path, cur_tile) {
  local tiles = [];

  if (path.GetCost() >= self._max_cost) return [];

  foreach (offset in Utilities.offsets) {
    local next_tile = cur_tile + offset;

    /* Don't turn back */
    if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;

    local validSlope = function (tile) {
      local slope = AITile.GetSlope(tile);
      return slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW || slope == AITile.SLOPE_SE || slope == AITile.SLOPE_NE;
    }

    if (!AITile.IsWaterTile(next_tile) && !validSlope(next_tile) && !AIMarine.IsDockTile(next_tile)) continue;

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
