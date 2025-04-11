-- [[ Project DZ - Blade Ball Utility Module : Open Source script that provides assistance to new Blade Ball Script Developer — Feel Free to use this as a reference as i will be updating this normally!]]
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local Network = Stats.Network.ServerStatsItem
local Player = Players.LocalPlayer

local Utility = {}  -- Main utility namespace

-- Consolidated data structure with hierarchical organization
-- Contains all cached game state information for performance
Utility.Data = {
    Player = {  -- Local player state tracking
        character = nil,          -- Player character model reference
        humanoidrootpart = nil,   -- Root part for position tracking
        position = nil,           -- Current world position (Vector3)
        velocity = 0,             -- Current movement velocity
        speed = 0,               -- Magnitude of velocity vector
        ping = 0                 -- Network latency in milliseconds
    },
    Ball = {    -- Active ball projectile tracking
        target = nil,            -- Player target reference
        from = nil,              -- Ball origin player
        ball = nil,              -- Ball instance reference
        position = nil,          -- Current world position
        velocity = 0,            -- Movement vector
        speed = 0,              -- Velocity magnitude
        direction = 0,           -- Normalized trajectory vector
        dot = 0,                 -- Dot product for angle calculations
        radians = 0,             -- Angle in radians
        angle = 0,               -- Angle in degrees
        distance = 0             -- Distance from local player
    },
    Target = {  -- Current target information
        target = nil,            -- Target player reference
        humanoidrootpart = nil,  -- Target's root part
        position = nil,          -- Target world position
        velocity = 0,            -- Target movement vector
        speed = 0,              -- Target velocity magnitude
        distance = 0            -- Distance from local player
    }
}

--[[
    Locates and returns the active ball instance
    @return Ball | nil - The active ball or nil if none found
]]
function Utility.GetBall()
    for _, Ball in ipairs(Workspace.Balls:GetChildren()) do
        if Ball:GetAttribute("realBall") then
            return Ball
        end
    end
end

--[[
    Finds the nearest valid target player
    @return Tuple(Model, number) | nil - Target model and distance, or nil if none
]]
function Utility.GetTarget()
    local Target, MaxDistance = nil, math.huge  -- Initialize tracking variables
    
    -- Validate local player state
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local HumanoidRootPart = Character.HumanoidRootPart

    -- Iterate through all potential targets
    for _, Entity in ipairs(Workspace.Alive:GetChildren()) do
        -- Filter criteria: Not self, must be Model with valid Humanoid
        if Entity.Name ~= Player.Name and Entity:IsA("Model") then
            local RootPart = Entity:FindFirstChild("HumanoidRootPart")
            local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
            
            -- Check if target is valid and alive
            if RootPart and Humanoid and Humanoid.Health > 0 then
                local Distance = (HumanoidRootPart.Position - RootPart.Position).Magnitude
                
                -- Update nearest target
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
    Updates and returns comprehensive ball data
    @param Pos (Vector3) - Reference position for calculations
    @return Multiple values containing complete ball state
]]
function Utility.BallData(Pos)
    local Ball = Utility.GetBall()
    if not Ball then return nil end  -- Early exit if no ball
    
    -- Extract basic ball properties
    Utility.Data.Ball.target = Ball:GetAttribute("target")
    Utility.Data.Ball.from = Ball:GetAttribute("from")
    Utility.Data.Ball.ball = Ball
    Utility.Data.Ball.position = Ball.Position
    Utility.Data.Ball.velocity = Ball:FindFirstChild("zoomies").VectorVelocity
    Utility.Data.Ball.speed = Utility.Data.Ball.velocity.Magnitude
    
    -- Calculate trajectory vectors and angles
    Utility.Data.Ball.direction = (Pos - Utility.Data.Ball.position).Unit
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
    Updates and returns current target information
    @return Multiple values containing target state data
]]
function Utility.TargetData()
    local Target, Distance = Utility.GetTarget()
    if not Target then return nil end  -- Early exit if no target
    
    -- Cache target components
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
    Updates and returns local player state information
    @return Multiple values containing player state data
]]
function Utility.PlayerData()
    -- Validate character state
    Utility.Data.Player.character = Player.Character
    if not Utility.Data.Player.character then return nil end
    
    Utility.Data.Player.humanoidrootpart = Utility.Data.Player.character:FindFirstChild("HumanoidRootPart")
    if not Utility.Data.Player.humanoidrootpart then return nil end
    
    -- Update movement metrics
    Utility.Data.Player.position = Utility.Data.Player.humanoidrootpart.Position
    Utility.Data.Player.velocity = Utility.Data.Player.humanoidrootpart.Velocity
    Utility.Data.Player.speed = Utility.Data.Player.velocity.Magnitude
    Utility.Data.Player.ping = math.ceil(Network["Data Ping"]:GetValue())
    
    return unpack({
        Utility.Data.Player.character, Utility.Data.Player.humanoidrootpart, Utility.Data.Player.position,
        Utility.Data.Player.velocity, Utility.Data.Player.speed, Utility.Data.Player.ping
    })
end

return Utility