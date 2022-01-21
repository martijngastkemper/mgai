class Utilities {
  static offsets = [
    -1,
    AIMap.GetMapSizeX(),
    1,
    AIMap.GetMapSizeX() * -1,
  ];
}

function Utilities::GetOppositeDirection(direction)
{
  if (direction & 1) return 4;
  if (direction & 2) return 8;
  if (direction & 4) return 1;
  if (direction & 8) return 2;
}

function Utilities::AIListToArray(ailist) {
  local sources = [];
  foreach(idx, value in ailist) {
    sources.push(idx);
  }
  return sources;
}

function Utilities::PrintTile(tile) {
  if (typeof tile != "integer") return "invalid tile";
  return AIMap.GetTileX(tile) + "x" + AIMap.GetTileY(tile);
}

function  Utilities::IsValidSlope(tile) {
 local slope = AITile.GetSlope(tile);
 return slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW || slope == AITile.SLOPE_SE || slope == AITile.SLOPE_NE;
}
