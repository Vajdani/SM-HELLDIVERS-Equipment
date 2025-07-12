dofile("ProgressBar.lua")

VideoPlayer = class()

local fps = 1/60

function VideoPlayer:init(gui, name, path, frames)
    self.progressBar = ProgressBar():init(gui, name, path, frames)
    self.progressBar:update(1)

    self.currentFrame = 1

    return self
end

function VideoPlayer:update(dt)
    -- self.currentFrame = (self.currentFrame + 1)%self.progressBar.steps
    -- self.progressBar:update(self.currentFrame)

    self.currentFrame = max((self.currentFrame + dt/fps)%self.progressBar.steps, 1)
    self.progressBar:update(self.currentFrame)
end