// Placement and naming for the desktop widgets.
//
// Split from Settings.js, which validates values. This file only decides where
// surfaces sit and what each widget is called, so the desktop surface and the
// popup cannot disagree about either.
var NAMES = {
  clock: "Clock",
  system: "Load",
  gpu: "Graphics",
  power: "Power profile",
  battery: "Battery"
}

var GLYPHS = {
  clock: "\uF017",
  system: "\uF4BC",
  gpu: "\uF2DB",
  power: "\uF06B",
  battery: "\uF240"
}

// Which screen edges a surface anchors to. Anchoring to a single edge is what
// makes layer-shell centre the surface along it, so "-center" and "middle-" are
// expressed by leaving the opposite pair unset rather than by any arithmetic.
function anchorsFor(position) {
  var name = ["top-left", "top-center", "top-right",
    "middle-left", "middle-right",
    "bottom-left", "bottom-center", "bottom-right"].indexOf(String(position)) !== -1
    ? String(position) : "top-right"
  var parts = name.split("-")
  return {
    top: parts[0] === "top",
    bottom: parts[0] === "bottom",
    left: parts[1] === "left",
    right: parts[1] === "right"
  }
}

// Default (un-dragged) positions: a vertical stack flowing from the chosen
// corner. `entries` is [{id, w, h}] in display order; heights come from the
// live cards, so the stack settles as they measure themselves. A widget the
// user has dragged keeps its absolute position and is not part of this flow.
function flowPositions(position, entries, gap, marginX, marginY, screenW, screenH) {
  var name = ["top-left", "top-center", "top-right",
    "middle-left", "middle-right",
    "bottom-left", "bottom-center", "bottom-right"].indexOf(String(position)) !== -1
    ? String(position) : "top-right"
  var parts = name.split("-")
  var vertical = parts[0]
  var horizontal = parts[1]

  var list = entries || []
  var total = 0
  for (var i = 0; i < list.length; i++) total += Math.max(0, Number(list[i].h) || 0)
  if (list.length > 1) total += gap * (list.length - 1)

  var startY
  if (vertical === "bottom") startY = screenH - marginY - total
  else if (vertical === "middle") startY = Math.round((screenH - total) / 2)
  else startY = marginY

  var out = {}
  var y = startY
  for (var k = 0; k < list.length; k++) {
    var item = list[k]
    var w = Math.max(0, Number(item.w) || 0)
    var x
    if (horizontal === "right") x = screenW - w - marginX
    else if (horizontal === "center") x = Math.round((screenW - w) / 2)
    else x = marginX
    out[item.id] = { x: Math.round(x), y: Math.round(y) }
    y += Math.max(0, Number(item.h) || 0) + gap
  }
  return out
}

function widgetName(id) {
  return NAMES[String(id || "")] || ""
}

function widgetGlyph(id) {
  return GLYPHS[String(id || "")] || ""
}
