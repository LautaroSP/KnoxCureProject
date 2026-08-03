-- Place one already-scaled PNG on a fixed transparent game-preview canvas.

local inputFile = app.params["inputFile"]
local outputFile = app.params["outputFile"]
local canvasWidth = tonumber(app.params["canvasWidth"])
local canvasHeight = tonumber(app.params["canvasHeight"])

if not inputFile or not outputFile or not canvasWidth or not canvasHeight then
  error("inputFile, outputFile, canvasWidth and canvasHeight are required")
end

local image = Image { fromFile = inputFile }
if image:isEmpty() then
  error("Could not load scaled image: " .. inputFile)
end
if image.width > canvasWidth or image.height > canvasHeight then
  error("Scaled image does not fit target canvas")
end

local sprite = Sprite(canvasWidth, canvasHeight, ColorMode.RGB)
sprite.filename = outputFile
sprite.layers[1].name = "sprite"
local x = math.floor((canvasWidth - image.width) / 2)
local y = canvasHeight - image.height
sprite:newCel(sprite.layers[1], 1, image, Point(x, y))

local saved = sprite:saveAs(outputFile)
if not saved then
  error("Aseprite could not save: " .. outputFile)
end
sprite:close()
