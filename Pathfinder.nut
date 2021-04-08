
class Pathfinder {

  _aystar_class = import("graph.aystar", "", 6);
  _pathfinder = null;
  _goals = null;
  _running = null;
  _max_cost = null;
  _tile_cost = null;
  _offsets = null;

  constructor() {
    this._pathfinder = this._aystar_class(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._running = false;
    this._max_cost = 100000;
    this._tile_cost = 10;
    this._offsets = [
      AIMap.GetTileIndex(0, 1),
      AIMap.GetTileIndex(0, -1),
      AIMap.GetTileIndex(1, 0),
      AIMap.GetTileIndex(-1, 0)
    ];
  }

  function InitializePath(sources, goals, ignored_tiles = []) {
    local nsources = [];

    foreach (node in sources) {
      local path = this._pathfinder.Path(null, node, 0xFF, this._Cost, this);
      nsources.push(path);
    }
    this._goals = goals;
    this._pathfinder.InitializePath(nsources, goals, ignored_tiles);
  }

  function FindPath(iterations);
}

function Pathfinder::_Cost(self, path, new_tile, new_direction) {
  AISign.BuildSign(new_tile, "->");

  if (path == null) return 0;

  return path.GetCost() + self._tile_cost;
}

function Pathfinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
  local min_cost = self._max_cost;

  foreach(goal_tile in goal_tiles) {
    min_cost = min(min_cost, AIMap.DistanceManhattan(cur_tile, goal_tile) * self._tile_cost);
  }

  return min_cost;
}

function Pathfinder::_Neighbours(self, path, cur_tile) {
  local tiles = [];

  foreach (offset in self._offsets) {
    local next_tile = cur_tile + offset;

    /* Don't turn back */
    if (path.GetParent() != null && next_tile == path.GetParent().GetTile()) continue;

    /* Skip non coast and water tiles */
    if (!AITile.IsCoastTile(next_tile) && !AITile.IsWaterTile(next_tile)) continue;

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
  local ret = this._pathfinder.FindPath(iterations);
  this._running = (ret == false) ? true : false;
  if (!this._running && ret != null) {
    foreach (goal in this._goals) {
      if (goal == ret.GetTile()) {
        return this._pathfinder.Path(ret, goal, 0, this._Cost, this);
      }
    }
  }
  return ret;
}

function Pathfinder::_dir(from, to)
{
  if (from - to == 1) return 0;
  if (from - to == -1) return 1;
  if (from - to == AIMap.GetMapSizeX()) return 2;
  if (from - to == -AIMap.GetMapSizeX()) return 3;
  throw("Shouldn't come here in _dir");
}

function Pathfinder::_GetDirection(pre_from, from, to)
{
  local result = 1 << (4 + (pre_from == null ? 0 : 4 * this._dir(pre_from, from)) + this._dir(from, to));
  return result;
}
