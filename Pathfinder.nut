require("AYStar.nut");

class Pathfinder {

  _pathfinder = null;
  _goals = null;
  _max_cost = null;
  _tile_cost = null;
  _offsets = null;

  constructor() {
    this._pathfinder = AyStar(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);
    this._max_cost = 30000;
    this._tile_cost = 2;
    this._offsets = [
      AIMap.GetTileIndex(-1, 0),
      AIMap.GetTileIndex(0, 1),
      AIMap.GetTileIndex(1, 0),
      AIMap.GetTileIndex(0, -1),
    ];
  }

  function InitializePath(sources, goals, ignored_tiles = []) {
    local nsources = [];

    foreach (node in sources) {
      /* tile and direction. direction can't be zero, so let's pick 1 */
      local path = [node, 1];
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
  foreach (tile in goal_tiles) {
    local distance = AIMap.DistanceSquare(cur_tile, tile);
    min_cost = min(min_cost, distance * self._tile_cost);
  }
  return min_cost;
}

function Pathfinder::_Neighbours(self, path, cur_tile) {
  local tiles = [];

  if (path.GetCost() >= self._max_cost) return [];

  foreach (offset in self._offsets) {
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
  local diff = from - to;
  local mapsize = AIMap.GetMapSizeX();
  if (diff == -1) return 1;
  if (diff == mapsize) return 3;
  if (diff == 1) return 5;
  if (diff == -mapsize) return 7;
  throw("Shouldn't come here in _dir");
}

function Pathfinder::_GetDirection(pre_from, from, to)
{
  local result = 1 << ((pre_from == null ? 0 : this._dir(pre_from, from)) + this._dir(from, to));
  return result;
}
