-- Build a non-animated .aseprite document from four approved orientation PNGs.

local layerNames = { "front-left", "rear-left", "rear-right", "front-right" }
local inputDir = app.params["inputDir"]
local outputFile = app.params["outputFile"]

if not inputDir or not outputFile then
  error("inputDir and outputFile script parameters are required")
end

local images = {}
local width = nil
local height = nil

for _, layerName in ipairs(layerNames) do
  local filename = inputDir .. "/" .. layerName .. ".png"
  local image = Image { fromFile = filename }
  if image:isEmpty() then
    error("Could not load orientation image: " .. filename)
  end
  if not width then
    width = image.width
    height = image.height
  elseif image.width ~= width or image.height ~= height then
    error("Orientation dimensions do not match: " .. filename)
  end
  images[layerName] = image
end

local sprite = Sprite(width, height, ColorMode.RGB)
sprite.filename = outputFile
sprite.layers[1].name = layerNames[1]
sprite:newCel(sprite.layers[1], 1, images[layerNames[1]], Point(0, 0))

for index = 2, #layerNames do
  local layerName = layerNames[index]
  local layer = sprite:newLayer()
  layer.name = layerName
  sprite:newCel(layer, 1, images[layerName], Point(0, 0))
end

for index, layer in ipairs(sprite.layers) do
  layer.isVisible = index == 1
end

local saved = sprite:saveAs(outputFile)
if not saved then
  error("Aseprite could not save: " .. outputFile)
end
sprite:close()
