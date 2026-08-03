-- Compose the approved game previews into an 8-column PZ tileset image.

local inputRoot = app.params["inputRoot"]
local outputFile = app.params["outputFile"]
local tileWidth = tonumber(app.params["tileWidth"])
local tileHeight = tonumber(app.params["tileHeight"])

if not inputRoot or not outputFile or not tileWidth or not tileHeight then
  error("inputRoot, outputFile, tileWidth and tileHeight are required")
end

local machines = { "centrifuge", "bio-analyzer" }
local orientations = { "front-left", "rear-left", "rear-right", "front-right" }
local synthParts = {
  "synth_S_primary_0_0",
  "synth_S_extension_1_0",
  "synth_E_primary_0_0",
  "synth_E_extension_0_1",
  "synth_N_primary_0_0",
  "synth_N_extension_1_0",
  "synth_W_primary_0_0",
  "synth_W_extension_0_1",
}
local sprite = Sprite(tileWidth * 8, tileHeight * 3, ColorMode.RGB)
sprite.filename = outputFile
sprite.layers[1].name = "equipment"
local canvas = Image(sprite.width, sprite.height, ColorMode.RGB)

for row, machine in ipairs(machines) do
  for column, orientation in ipairs(orientations) do
    local filename = inputRoot .. "/" .. machine .. "/" .. orientation .. ".png"
    local image = Image { fromFile = filename }
    if image:isEmpty() then
      error("Could not load preview: " .. filename)
    end
    if image.width ~= tileWidth or image.height ~= tileHeight then
      error("Unexpected preview dimensions: " .. filename)
    end
    canvas:drawImage(
      image,
      Point((column - 1) * tileWidth, (row - 1) * tileHeight)
    )
  end
end

for column, part in ipairs(synthParts) do
  local filename = inputRoot .. "/synthesizer-2x1/" .. part .. ".png"
  local image = Image { fromFile = filename }
  if image:isEmpty() then
    error("Could not load synthesizer part: " .. filename)
  end
  if image.width ~= tileWidth or image.height ~= tileHeight then
    error("Unexpected synthesizer part dimensions: " .. filename)
  end
  canvas:drawImage(image, Point((column - 1) * tileWidth, 2 * tileHeight))
end

sprite:newCel(sprite.layers[1], 1, canvas, Point(0, 0))

local saved = sprite:saveAs(outputFile)
if not saved then
  error("Aseprite could not save: " .. outputFile)
end
sprite:close()
