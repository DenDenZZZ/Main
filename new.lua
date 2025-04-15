repeat print("Project DZ is loading..") task.wait(5) until game:IsLoaded()

local Utility = loadstring(game:HttpGet("https://raw.githubusercontent.com/DenDenZZZ/Main/refs/heads/main/Blade%20Ball%20-%20Utility.lua"))()
setfpscap(200)
print("Project DZ has successfully loaded!!")

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    Stats = game:GetService("Stats"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
    HttpService = game:GetService("HttpService"),
    UserInputService = game:GetService("UserInputService"),
    Workspace = game:GetService("Workspace")
}

local Player = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera
local DZUI = Instance.new("ScreenGui", gethui and gethui() or Player:WaitForChild("PlayerGui"))
DZUI.Name = "Project DZ - " .. Player.UserId
DZUI.ResetOnSpawn = false

local Auto_Parry = {Connection = nil, Parried = false, Curved = false, Tornado = false, Cooldown = 0, Curving = 0}

Services.RunService.PreSimulation:Connect(function()
    local Ball = Utility:GetBall()
    if not Ball then
      return
    end
    local Character = Player.Character
    if not Character then 
      return
    end
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then
      return
    end
    local Target, Distance = Utility:GetTarget()
    if not Target then
      return
    end
    Utility:BallData()
    Utility:TargetData()
    Utility:PlayerData()
end)

Services.RunService.Heartbeat:Connect(function()
  if not Player.Character or not Utility.Data.Player.humanoidrootpart or not Utility.Data.Ball.ball or Utility.Data.Ball.speed <= 0 then
    return
  end
  
  if Utility:IsCurved() then
    Auto_Parry.Curving = tick()
    Auto_Parry.Curved = true
    repeat
      Services.RunService.Heartbeat:Wait()
    until (Utility.Data.Ball.distance / Utility.Data.Ball.speed) / 1.5 <= Auto_Parry.Curving or Utility.Data.Ball.distance <= Utility.Data.Ball.speed / 10
    Auto_Parry.Curved = false
  end
    
    if Utility.Data.Ball.target == Player.Name then
      if Utility.Data.Ball.distance / Utility.Data.Ball.speed <= 0.6 and Utility.Parries <= 1 and not Auto_Parry.Curved and not Auto_Parry.Parried then
        Utility:Parry()
        Auto_Parry.Parried = true
        Auto_Parry.Cooldown = tick()
        
        if Auto_Parry.Parried then
          repeat
            Services.RunService.Heartbeat:Wait()
          until (tick() - Auto_Parry.Cooldown) >= 1 or not Auto_Parry.Parried
          Auto_Parry.Parried = false
        end
      end
    end
end)

Services.Workspace.Balls.ChildAdded:Connect(function()
    if Auto_Parry.Connection then Auto_Parry.Connection:Disconnect() end
    
    local Ball = Utility:GetBall()
    if not Ball then
      return
    end
    
    Auto_Parry.Connection = Ball:GetAttributeChangedSignal("target"):Connect(function()
        Auto_Parry.Parried = false
    end)
end)

Services.Workspace.Balls.ChildRemoved:Connect(function()
  Utility.Data.Ball.target = nil
  Utility.Parries = 0
  Auto_Parry.Connection = nil
end)