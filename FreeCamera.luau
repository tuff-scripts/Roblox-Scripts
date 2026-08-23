local PLRS = game:GetService("Players")
local RNS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local UserSettings = UserSettings():GetService("UserGameSettings")

local plr = PLRS.LocalPlayer
local plrGui = plr.PlayerGui

local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() camera = workspace.CurrentCamera end)

local function new(c, p, prop) 
    local obj = Instance.new(c) 
    if not prop then obj.Parent = p return obj end 
    for k, v in prop do obj[k] = v end 
    obj.Parent = p 
    return obj 
end

local active = false 
local scriptable = Enum.CameraType.Scriptable
local lastSpeed = 0 
local lastJump = 0 
local lastType = false
local wasFirstPerson = false
local lastMinZoom, lastMaxZoom = 0.5, 128

-- State tracking
local pitch = 0
local yaw = 0

-- Angular & Linear Velocity
local velYaw = 0
local velPitch = 0
local targetVelYaw = 0
local targetVelPitch = 0
local moveVel = Vector3.zero

local camSpeed = 50
local smoothCam = false

local lastConn = false 
local inputBeganConn = false
local inputChangedConn = false
local inputEndedConn = false
local camPos = Vector3.zero

-- Touch tracking for multi-finger isolation
local cameraTouchInput = nil

-- Sensitivity
local sX, sY = 1.0, 0.7

local function updateSensitivity()
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        sX = 1.0
        sY = 0.7
    else
        local mouseSens = UserSettings.MouseSensitivity
        sX = math.max(0.1, mouseSens * 1.0)
        sY = math.max(0.1, mouseSens * 0.7)
    end
end
local toggleBtn = false
updateSensitivity()
UserSettings:GetPropertyChangedSignal("MouseSensitivity"):Connect(updateSensitivity)

local function resetCharacterTransparency(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            if part.Name ~= "HumanoidRootPart" then
                part.LocalTransparencyModifier = 0
            end
        end
    end
end

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.UseJumpPower = true

    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() 
        if not active then return end 
        local w = hum.WalkSpeed 
        if 0 == w then return end 
        lastSpeed = w 
        hum.WalkSpeed = 0 
    end)

    hum:GetPropertyChangedSignal("JumpPower"):Connect(function() 
        if not active then return end 
        local jp = hum.JumpPower 
        if 0 == jp then return end 
        lastJump = jp 
        hum.JumpPower = 0 
    end)
end

if plr.Character then setupCharacter(plr.Character) end
plr.CharacterAdded:Connect(function(char)
    if active and lastType then
        camera.CameraType = lastType
        active = false if toggleBtn then toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) toggleBtn.Text = "Toggle Freecam: OFF" end
        if lastConn then lastConn:Disconnect() lastConn = false end
        if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = false end
        if inputChangedConn then inputChangedConn:Disconnect() inputChangedConn = false end
        if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = false end
    end
    setupCharacter(char)
end)

camera:GetPropertyChangedSignal("CameraType"):Connect(function() 
    if not active then return end 
    local t = camera.CameraType 
    if t == scriptable then return end 
    lastType = t 
    camera.CameraType = scriptable
end)

local function isInsideJoystickZone(position)
    local viewportSize = camera.ViewportSize
    -- Strictly isolated to the bottom-left corner joystick area
    local isLeftZone = position.X < (viewportSize.X * 0.4)
    local isBottomZone = position.Y > (viewportSize.Y * 0.275)
    return isLeftZone and isBottomZone
end

-- UI Setup
local ui = new("ScreenGui", plrGui, {Name = "FreecamUI", ResetOnSpawn = false})

local mainFrame = new("Frame", ui, {
    Size = UDim2.new(0, 200, 0, 150),
    Position = UDim2.new(1, -210, 0, 10),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Active = true
})
new("UICorner", mainFrame, {CornerRadius = UDim.new(0, 8)})

local dragBar = new("TextLabel", mainFrame, {
    Size = UDim2.new(1, 0, 0, 30),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(45, 45, 45),
    BackgroundTransparency = 0.1,
    Text = "    Free Camera 🔥",
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.SourceSansBold,
    TextSize = 14,
    BorderSizePixel = 0
})
new("UICorner", dragBar, {CornerRadius = UDim.new(0, 8)})

local dragging, dragInput, dragStart, startPos
dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
dragBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

toggleBtn = new("TextButton", mainFrame, {
    Size = UDim2.new(0.9, 0, 0, 30),
    Position = UDim2.new(0.05, 0, 0, 35),
    BackgroundColor3 = Color3.fromRGB(200, 50, 50),
    Text = "Toggle Freecam: OFF",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.SourceSansBold,
    TextSize = 13,
    BorderSizePixel = 0
})
new("UICorner", toggleBtn, {CornerRadius = UDim.new(0, 6)})

local speedBox = new("TextBox", mainFrame, {
    Size = UDim2.new(0.9, 0, 0, 30),
    Position = UDim2.new(0.05, 0, 0, 72),
    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    Text = "Speed: 50",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.SourceSans,
    TextSize = 13,
    BorderSizePixel = 0
})
new("UICorner", speedBox, {CornerRadius = UDim.new(0, 6)})

speedBox.FocusLost:Connect(function()
    local val = tonumber(speedBox.Text:match("%d+"))
    if val then
        camSpeed = val
        speedBox.Text = "Speed: " .. tostring(camSpeed)
    else
        speedBox.Text = "Speed: " .. tostring(camSpeed)
    end
end)

local smoothBtn = new("TextButton", mainFrame, {
    Size = UDim2.new(0.9, 0, 0, 30),
    Position = UDim2.new(0.05, 0, 0, 109),
    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
    Text = "Smooth Cam: OFF",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.SourceSans,
    TextSize = 13,
    BorderSizePixel = 0
})
new("UICorner", smoothBtn, {CornerRadius = UDim.new(0, 6)})

smoothBtn.MouseButton1Click:Connect(function()
    smoothCam = not smoothCam
    smoothBtn.Text = "Smooth Cam: " .. (smoothCam and "ON" or "OFF")
    smoothBtn.BackgroundColor3 = smoothCam and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 60)
end)

local function toggle()
    active = not active 
    toggleBtn.Text = "Toggle Freecam: " .. (active and "ON" or "OFF")
    toggleBtn.BackgroundColor3 = active and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(200, 50, 50)
    
    local char = plr.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local head = char and char:FindFirstChild("Head")
    
    if not active then 
        if lastConn then lastConn:Disconnect() lastConn = false end 
        if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = false end
        if inputChangedConn then inputChangedConn:Disconnect() inputChangedConn = false end
        if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = false end
        if lastType then camera.CameraType = lastType end 
        if hum then
            hum.WalkSpeed = lastSpeed 
            hum.JumpPower = lastJump 
        end
        
        if wasFirstPerson then
            plr.CameraMinZoomDistance = 0.5
            plr.CameraMaxZoomDistance = 0.5
            task.defer(function()
                plr.CameraMinZoomDistance = lastMinZoom
                plr.CameraMaxZoomDistance = lastMaxZoom
            end)
        else
            plr.CameraMinZoomDistance = lastMinZoom
            plr.CameraMaxZoomDistance = lastMaxZoom
        end

        UIS.MouseBehavior = Enum.MouseBehavior.Default
        cameraTouchInput = nil
        return 
    end 
    
    local playerScripts = plr:WaitForChild("PlayerScripts")
    local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
    local controls = playerModule:GetControls()
    
    if hum then
        lastSpeed = hum.WalkSpeed 
        lastJump = hum.JumpPower 
        hum.WalkSpeed = 0 
        hum.JumpPower = 0
    end
    
    lastMinZoom = plr.CameraMinZoomDistance
    lastMaxZoom = plr.CameraMaxZoomDistance
    
    if head then
        wasFirstPerson = (camera.CFrame.Position - head.Position).Magnitude < 2
    else
        wasFirstPerson = false
    end

    plr.CameraMinZoomDistance = 5
    
    camPos = camera.CFrame.Position
    local rx, ry, _ = camera.CFrame:ToOrientation()
    pitch = math.deg(rx)
    yaw = math.deg(ry)
    velYaw = 0
    velPitch = 0
    targetVelYaw = 0
    targetVelPitch = 0
    moveVel = Vector3.zero
    
    lastType = camera.CameraType
    camera.CameraType = scriptable
    UIS.MouseBehavior = Enum.MouseBehavior.Default

    inputBeganConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            if not cameraTouchInput and not isInsideJoystickZone(input.Position) then
                cameraTouchInput = input
            end
        end
    end)

    inputChangedConn = UIS.InputChanged:Connect(function(input, gameProcessed)
        local isMouse = (input.UserInputType == Enum.UserInputType.MouseMovement)
        local isAssignedTouch = (input.UserInputType == Enum.UserInputType.Touch and input == cameraTouchInput)
        
        if isMouse or isAssignedTouch then
            local delta = input.Delta
            if smoothCam then
                targetVelYaw = targetVelYaw - (delta.X * sX * 7.5)
                targetVelPitch = targetVelPitch - (delta.Y * sY * 7.5)
            else
                yaw = yaw - (delta.X * sX)
                pitch = pitch - (delta.Y * sY)
                targetVelYaw = -(delta.X * sX * 7.5)
                targetVelPitch = -(delta.Y * sY * 7.5)
                velYaw = targetVelYaw
                velPitch = targetVelPitch
            end
        end
    end)

    inputEndedConn = UIS.InputEnded:Connect(function(input)
        if input == cameraTouchInput then
            cameraTouchInput = nil
        end
    end)
    
    lastConn = RNS.RenderStepped:Connect(function(dt)
        resetCharacterTransparency(plr.Character)

        if smoothCam then
            local rampUp = 1 - math.exp(-10 * dt)
            local damping = math.exp(-8 * dt)
            
            velYaw = velYaw + (targetVelYaw - velYaw) * rampUp
            velPitch = velPitch + (targetVelPitch - velPitch) * rampUp
            
            yaw = yaw + (velYaw * dt)
            pitch = pitch + (velPitch * dt)
            
            targetVelYaw = targetVelYaw * damping
            targetVelPitch = targetVelPitch * damping
            velYaw = velYaw * damping
            velPitch = velPitch * damping
        end
        
        local rotCF = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
        local moveVector = controls:GetMoveVector()
        
        local targetVel = Vector3.zero
        if moveVector.Magnitude > 0 then
            targetVel = (rotCF * Vector3.new(moveVector.X, 0, moveVector.Z)).Unit * camSpeed
        end
        
        if smoothCam then
            moveVel = moveVel:Lerp(targetVel, 1 - math.exp(-8 * dt))
        else
            moveVel = targetVel
        end
        
        camPos += (moveVel * dt)
        camera.CFrame = CFrame.new(camPos) * rotCF
    end)
end

toggleBtn.MouseButton1Click:Connect(toggle)
