-- Build one non-animated .aseprite document from four approved RGBA state PNGs.

local stateNames = { "off", "ready", "working", "broken" }
local inputDir = app.params["inputDir"]
local outputFile = app.params["outputFile"]

if not inputDir or not outputFile then
  error("inputDir and outputFile script parameters are required")
end

local images = {}
local width = nil
local height = nil

for _, stateName in ipairs(stateNames) do
  local filename = inputDir .. "/" .. stateName .. ".png"
  local image = Image { fromFile = filename }
  if image:isEmpty() then
    error("Could not load state image: " .. filename)
  end
  if not width then
    width = image.width
    height = image.height
  elseif image.width ~= width or image.height ~= height then
    error("State dimensions do not match: " .. filename)
  end
  images[stateName] = image
end

local sprite = Sprite(width, height, ColorMode.RGB)
sprite.filename = outputFile
sprite.layers[1].name = stateNames[1]
sprite:newCel(sprite.layers[1], 1, images[stateNames[1]], Point(0, 0))

for index = 2, #stateNames do
  local stateName = stateNames[index]
  local layer = sprite:newLayer()
  layer.name = stateName
  sprite:newCel(layer, 1, images[stateName], Point(0, 0))
end

-- Only one state is visible at a time. The document has one frame and is not
-- an animation; layers are toggled/exported by name.
for index, layer in ipairs(sprite.layers) do
  layer.isVisible = index == 1
end

local saved = sprite:saveAs(outputFile)
if not saved then
  error("Aseprite could not save: " .. outputFile)
end
sprite:close()
