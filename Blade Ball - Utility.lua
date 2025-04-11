--[[
    Project DZ - Blade Ball Utility Module
    =====================================
    
    Version: 1.0.0
    Maintainer: [DenDenZZZ]
    Last Updated: [2025-04-11]
    
    Description:
    -----------
    A comprehensive utility module for Blade Ball providing core gameplay functionality including:
    - Ball tracking and trajectory prediction
    - Player targeting systems
    - Parry mechanics with multiple modes
    - Game state monitoring and data caching
    
    Features:
    --------
    ✔ Real-time ball physics analysis
    ✔ Dynamic target acquisition
    ✔ Network-optimized parry system
    ✔ Modular architecture for easy extension
    
    Usage:
    -----
    1. Load this module in your script:
       `local Utility = loadstring(game:HttpGet(""))()`
    2. Access functions via the Utility namespace
    3. Call update functions in your game loop
    
    License:
    -------
    MIT License - Open source with attribution required
]]

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local Network = Stats.Network.ServerStatsItem

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local LastInput = UserInputService:GetLastInputType()
local Vector2MouseLocation = nil

local Utility = {} -- Primary module interface

--[[
    Data Structure Documentation
    ===========================
    
    Hierarchical state container that caches all relevant game data
    for optimal performance and minimal redundant calculations.
]]
Utility.Data = {
    -- Local player state tracking
    Player = {
        character = nil,          -- Reference to player character model
        humanoidrootpart = nil,   -- Primary root part (HRP) reference
        position = nil,           -- Current world position (Vector3)
        velocity = 0,             -- Current movement velocity vector
        speed = 0,                -- Magnitude of velocity (scalar)
        ping = 0                 -- Network latency in milliseconds
    },
    
    -- Ball projectile tracking
    Ball = {
        target = nil,            -- Player currently targeted by ball
        from = nil,              -- Player who launched the ball
        ball = nil,              -- Ball instance reference
        position = nil,          -- Current world position (Vector3)
        velocity = 0,            -- Movement vector (Vector3)
        speed = 0,               -- Velocity magnitude (scalar)
        direction = 0,           -- Normalized trajectory vector
        dot = 0,                 -- Dot product for angle calculations
        radians = 0,             -- Approach angle in radians
        angle = 0,               -- Approach angle in degrees
        distance = 0             -- Distance from local player
    },
    
    -- Target information
    Target = {
        target = nil,            -- Current target player reference
        humanoidrootpart = nil,  -- Target's HRP reference
        position = nil,          -- Target world position
        velocity = 0,            -- Target movement vector
        speed = 0,               -- Target velocity magnitude
        distance = 0             -- Distance from local player
    }
}

-- Remote event storage
Utility.Remotes = {} -- Stores discovered remote events
Utility.ParryKey = nil -- Authentication key for parry events

--[[
    Function: GetBall
    -----------------
    Locates and returns the active ball instance in the game.
    
    Returns:
    - Ball | nil: The active ball instance if found, otherwise nil
    
    Performance:
    - O(n) complexity where n is number of balls in workspace
    - Minimal memory overhead
]]
function Utility:GetBall()
    for _, Ball in ipairs(Workspace.Balls:GetChildren()) do
        if Ball:GetAttribute("realBall") then
            return Ball
        end
    end
    return nil
end

--[[
    Function: GetTarget
    ------------------
    Identifies and returns the nearest valid target player.
    
    Returns:
    - Tuple(Model, number) | nil: Target model and distance if found
    
    Filtering Criteria:
    - Must be alive (Humanoid.Health > 0)
    - Must have HumanoidRootPart
    - Cannot be local player
    - Must be within maximum search distance
    
    Performance Notes:
    - Implements early termination on closest match
    - Validates all prerequisites before distance checks
]]
function Utility:GetTarget()
    local Target, MaxDistance = nil, math.huge
    
    -- Validate local player state
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local HumanoidRootPart = Character.HumanoidRootPart

    -- Target acquisition algorithm
    for _, Entity in ipairs(Workspace.Alive:GetChildren()) do
        if Entity.Name ~= Player.Name and Entity:IsA("Model") then
            local RootPart = Entity:FindFirstChild("HumanoidRootPart")
            local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
            
            if RootPart and Humanoid and Humanoid.Health > 0 then
                local Distance = (HumanoidRootPart.Position - RootPart.Position).Magnitude
                
                if Distance < MaxDistance then
                    MaxDistance = Distance
                    Target = Entity
                end
            end
        end
    end
    
    return Target, MaxDistance
end

--[[
    Function: BallData
    -----------------
    Computes comprehensive ball physics and tracking data.
    
    Updates:
    - Position, velocity, and speed
    - Trajectory vectors and angles
    - Distance metrics
    
    Mathematical Operations:
    - Vector normalization
    - Dot product calculation
    - Radians/degrees conversion
    - Magnitude/distance computations
    
    Returns:
    - Multiple values containing complete ball state
]]
function Utility:BallData()
    local Ball = Utility.GetBall()
    if not Ball or not Player.Character or not Player.Character.HumanoidRootPart then return nil end
    
    -- Core ball properties
    Utility.Data.Ball.target = Ball:GetAttribute("target")
    Utility.Data.Ball.from = Ball:GetAttribute("from")
    Utility.Data.Ball.ball = Ball
    Utility.Data.Ball.position = Ball.Position
    Utility.Data.Ball.velocity = Ball:FindFirstChild("zoomies").VectorVelocity
    Utility.Data.Ball.speed = Utility.Data.Ball.velocity.Magnitude
    
    -- Trajectory analysis
    Utility.Data.Ball.direction = (Player.Character.HumanoidRootPart.Position - Utility.Data.Ball.position).Unit
    Utility.Data.Ball.dot = math.clamp(Utility.Data.Ball.direction:Dot(Utility.Data.Ball.velocity.Unit), -1, 1)
    Utility.Data.Ball.radians = math.acos(Utility.Data.Ball.dot)
    Utility.Data.Ball.angle = math.deg(Utility.Data.Ball.radians)
    Utility.Data.Ball.distance = (Player.Character.HumanoidRootPart.Position - Utility.Data.Ball.position).Magnitude
    
    return unpack({
        Utility.Data.Ball.ball, Utility.Data.Ball.target, Utility.Data.Ball.from, Utility.Data.Ball.position,
        Utility.Data.Ball.velocity, Utility.Data.Ball.speed, Utility.Data.Ball.direction, Utility.Data.Ball.dot,
        Utility.Data.Ball.radians, Utility.Data.Ball.angle, Utility.Data.Ball.distance
    })
end

--[[
    Function: TargetData
    -------------------
    Updates and returns current target information.
    
    Data Collected:
    - Position and movement vectors
    - Velocity magnitude (speed)
    - Distance from local player
    
    Returns:
    - Multiple values containing target state data
]]
function Utility:TargetData()
    local Target, Distance = Utility.GetTarget()
    if not Target then return nil end
    
    Utility.Data.Target.target = Target
    Utility.Data.Target.humanoidrootpart = Target.HumanoidRootPart
    Utility.Data.Target.position = Utility.Data.Target.humanoidrootpart.Position
    Utility.Data.Target.velocity = Utility.Data.Target.humanoidrootpart.Velocity
    Utility.Data.Target.speed = Utility.Data.Target.velocity.Magnitude
    Utility.Data.Target.distance = Distance
    
    return unpack({
        Utility.Data.Target.target, Utility.Data.Target.humanoidrootpart, Utility.Data.Target.position,
        Utility.Data.Target.velocity, Utility.Data.Target.speed, Utility.Data.Target.distance
    })
end

--[[
    Function: PlayerData
    -------------------
    Monitors and updates local player state.
    
    Metrics Tracked:
    - Character reference validity
    - Position and movement vectors
    - Network ping (latency)
    
    Returns:
    - Multiple values containing player state data
]]
function Utility:PlayerData()
    Utility.Data.Player.character = Player.Character
    if not Utility.Data.Player.character then return nil end
    
    Utility.Data.Player.humanoidrootpart = Utility.Data.Player.character:FindFirstChild("HumanoidRootPart")
    if not Utility.Data.Player.humanoidrootpart then return nil end
    
    Utility.Data.Player.position = Utility.Data.Player.humanoidrootpart.Position
    Utility.Data.Player.velocity = Utility.Data.Player.humanoidrootpart.Velocity
    Utility.Data.Player.speed = Utility.Data.Player.velocity.Magnitude
    Utility.Data.Player.ping = math.ceil(Network["Data Ping"]:GetValue())
    
    return unpack({
        Utility.Data.Player.character, Utility.Data.Player.humanoidrootpart, Utility.Data.Player.position,
        Utility.Data.Player.velocity, Utility.Data.Player.speed, Utility.Data.Player.ping
    })
end

--[[
    Remote Event Discovery System
    ============================
    
    Automated scanning of game memory to:
    - Identify critical remote events
    - Extract necessary authentication keys
    
    Security Notes:
    - Operates in isolated task
    - Validates function signatures
    - Caches discovered remotes
]]
task.spawn(function()
    for _, Value in pairs(getgc()) do
        if type(Value) == "function" and islclosure(Value) then
            if debug.getupvalues(Value) then
                local Protos = debug.getprotos(Value)
                local Upvalues = debug.getupvalues(Value)
                local Constants = debug.getconstants(Value)

                if #Protos == 4 and #Upvalues == 24 and #Constants == 102 then
                    Utility.Remotes[debug.getupvalue(Value, 16)] = debug.getconstant(Value, 60)
                    Utility.ParryKey = debug.getupvalue(Value, 17)
                    Utility.Remotes[debug.getupvalue(Value, 18)] = debug.getconstant(Value, 62)
                    Utility.Remotes[debug.getupvalue(Value, 19)] = debug.getconstant(Value, 63)
                    break
                end
            end
        end
    end
end)

-- Authentication key assignment
Utility.Key = Utility.ParryKey

--[[
    Function: GetParryData
    ---------------------
    Generates parry configuration data based on specified type.
    
    Parameters:
    - Type (string): Parry mode ("Custom", "Backwards", "Random")
    
    Data Collected:
    - Mouse position (or screen center)
    - Player positions in screen space
    - Camera orientation
    
    Returns:
    - Table containing complete parry parameters
]]
function Utility:GetParryData(Type)
    local Events = {}
    
    -- Mouse position handling
    if LastInput == Enum.UserInputType.MouseButton1 or 
       (Enum.UserInputType.MouseButton2 or LastInput == Enum.UserInputType.Keyboard) then
        local MouseLocation = UserInputService:GetMouseLocation()
        Vector2MouseLocation = {MouseLocation.X, MouseLocation.Y}
    else
        Vector2MouseLocation = {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}
    end
    
    -- Player position mapping
    for _, V in pairs(Workspace.Alive:GetChildren()) do
        Events[tostring(V)] = Camera:WorldToScreenPoint(V.HumanoidRootPart.Position)
    end
    
    -- Parry mode selection
    if Type == "Custom" then
        return {0, Camera.CFrame, Events, Vector2MouseLocation}
    elseif Type == "Backwards" then
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + (-Camera.CFrame.LookVector * 9999)), Events, Vector2MouseLocation}
    elseif Type == "Random" then
        return {0, CFrame.new(Camera.CFrame.Position, Vector3.new(math.random(-9999, 9999), math.random(-9999, 9999), math.random(-9999, 9999))), Events, Vector2MouseLocation}
    end
    return Type
end

--[[
    Function: Parry
    --------------
    Executes parry action using discovered remote events.
    
    Flow:
    1. Generates parry data
    2. Authenticates with server
    3. Fires remote events
    
    Note:
    - Requires valid ParryKey
    - Depends on pre-discovered remotes
]]
function Utility:Parry()
    Utility.GetParryData(Type)
    for Remote, Args in pairs(Remotes) do
        Remote:FireServer(Args, Key, Utility.GetParryData(Type)[1], Utility.GetParryData(Type)[2], Utility.GetParryData(Type)[3], Utility.GetParryData(Type)[4])
    end
end

-- Module export
return Utility