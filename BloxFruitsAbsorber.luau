local fti = firetouchinterest or (syn and syn.fire_touch_interest) or (fluxus and fluxus.fire_touch_interest)
if not fti then warn("Your executor don't support functions required for this script to run.") return end
warn("🤔🤔.3")
local TPSERV = game:GetService("TeleportService")
local HTTPSERV = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local PLRS = game:GetService("Players")

local plr = PLRS.LocalPlayer
local cmd = RS.Remotes.CommF_
local browse = RS.__ServerBrowser

local l = false task.delay(30, function() if l then return end plr:Kick() end) l = plr:WaitForChild("DataLoaded", math.huge)
if not getgenv().TeamSet then cmd:InvokeServer("SetTeam2", "Pirates") getgenv().TeamSet = true end

local char = plr.Character or plr.CharacterAdded:Wait() char:WaitForChild("CharacterReady", 10)
local rp = char:WaitForChild("HumanoidRootPart", 10)
plr.CharacterAdded:Connect(function(c) char:WaitForChild("CharacterReady") rp = c:WaitForChild("HumanoidRootPart") end)

local inter = getgenv().InteractedFruits
if not inter then getgenv().InteractedFruits = {} inter = getgenv().InteractedFruits end

--Server
local placeId = game.PlaceId
local function HttpGet(url)
    return pcall(HTTPSERV.JSONDecode, HTTPSERV, game:HttpGet(url))
end
local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?excludeFullGames=true&limit=100"
local function hop()
  while true do
    local s, res 
    while true do 
      s, res = HttpGet(url)
      if s and res and res.data and #res.data > 0 then break end 
      task.wait(3) 
    end
    local servers = res.data 
    local len = #servers
    while len > 0 do
      local idx = math.random(1, len)
      local jobId = servers[idx].id
      if browse:InvokeServer("teleport", jobId) then return end
      table.remove(servers, idx) 
      len = #servers
      task.wait(0.5)
    end
    task.wait(3)
  end
end
--Fruits
local function getFruit(f)
  if not (f and rp) or inter[f] then return end
  local handle = f:FindFirstChild("Handle") if not handle then return end
  while f.Parent ~= char and f.Parent == workspace do fti(handle, rp, 0) wait(0.05) fti(handle, rp, 1) end
  if f.Parent ~= char then return end
  local spl = string.split(f.Name, " ")
  local name = "Unknown" if spl and 0 ~= #spl then name = spl[1] end
  if true == cmd:InvokeServer("StoreFruit", f:GetAttribute("OriginalName"), f) then print("Picked up "..name.." Fruit!") return true end
  inter[f] = true f.EatRemote:InvokeServer("Drop") f:Destroy() end
wait(1)
for _, c in pairs(workspace:GetChildren()) do if not (c:GetAttribute("OriginalName") and c:FindFirstChild("Fruit")) then continue end getFruit(c) end
workspace.ChildAdded:Connect(function(c) if c:GetAttribute("OriginalName") and c:FindFirstChild("Fruit") then getFruit(c) end end)

warn("Executed🤔") wait(1) print("Hop") hop()
