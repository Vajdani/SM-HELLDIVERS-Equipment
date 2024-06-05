local function round( value )
	return math.floor( value + 0.5 )
end


---@class ProgressBar
---@field gui GuiInterface The GuiInterface that the progress bar is on.
---@field name string The name of the ImageBox that the progress bar will use.
---@field steps number The amount of steps that the progress bar has.
---@field path string The path to the images that the progress bar can use.
ProgressBar = class()

---Sets up the progress bar and makes it ready to be used.
---@param gui GuiInterface The GuiInterface that the progress bar is on.
---@param name string The name of the ImageBox that the progress bar will use.
---@param path string The path to the images that the progress bar can use.
---@param steps number The amount of steps that the progress bar has.
---@return ProgressBar
function ProgressBar:init(gui, name, path, steps)
    self.gui = gui
    self.name = name
    self.steps = steps
    self.path = path.."/%s.png"

    self:setColour(sm.color.new("#ffffff"))
    self:update(steps)

    return self
end

---Updates the progress bar according to the percentage given.
---@param value number How much the progress bar should be filled. (A number in the range of [0;1])
function ProgressBar:update_percentage(value)
    self:update(value * self.steps)
end

---Updates the progress bar according to the step given.
---@param value number How much the progress bar should be filled. (A number in the range of [0;The progress bar's steps])
function ProgressBar:update(value)
    self.gui:setImage(self.name, self.path:format(round(value)))
end

---Sets the colour of the progress bar
---@param colour Color
function ProgressBar:setColour(colour)
    self.gui:setColor(self.name, colour)
    self.colour = colour
end