-- [[ Project DZ - Blade Ball Utility Module : Open Source script that provides assistance to new Blade Ball Script Developer — Feel Free to use this as a reference as i will be updating this normally!]]
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local Network = Stats.Network.ServerStatsItem
local Player = Players.LocalPlayer

local Utility = {}  -- Main utility namespace

-- Consolidated data structure with hierarchical organization
-- Contains all cached game state information for performance
local Data = {
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
    Data.Ball.target = Ball:GetAttribute("target")
    Data.Ball.from = Ball:GetAttribute("from")
    Data.Ball.ball = Ball
    Data.Ball.position = Ball.Position
    Data.Ball.velocity = Ball:FindFirstChild("zoomies").VectorVelocity
    Data.Ball.speed = Data.Ball.velocity.Magnitude
    
    -- Calculate trajectory vectors and angles
    Data.Ball.direction = (Pos - Data.Ball.position).Unit
    Data.Ball.dot = math.clamp(Data.Ball.direction:Dot(Data.Ball.velocity.Unit), -1, 1)
    Data.Ball.radians = math.acos(Data.Ball.dot)
    Data.Ball.angle = math.deg(Data.Ball.radians)
    Data.Ball.distance = (Player.Character.HumanoidRootPart.Position - Data.Ball.position).Magnitude
    
    return unpack({
        Data.Ball.ball, Data.Ball.target, Data.Ball.from, Data.Ball.position,
        Data.Ball.velocity, Data.Ball.speed, Data.Ball.direction, Data.Ball.dot,
        Data.Ball.radians, Data.Ball.angle, Data.Ball.distance
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
    Data.Target.target = Target
    Data.Target.humanoidrootpart = Target.HumanoidRootPart
    Data.Target.position = Data.Target.humanoidrootpart.Position
    Data.Target.velocity = Data.Target.humanoidrootpart.Velocity
    Data.Target.speed = Data.Target.velocity.Magnitude
    Data.Target.distance = Distance or 
        (Player.Character.HumanoidRootPart.Position - Data.Target.position).Magnitude
    
    return unpack({
        Data.Target.target, Data.Target.humanoidrootpart, Data.Target.position,
        Data.Target.velocity, Data.Target.speed, Data.Target.distance
    })
end

--[[
    Updates and returns local player state information
    @return Multiple values containing player state data
]]
function Utility.PlayerData()
    -- Validate character state
    Data.Player.character = Player.Character
    if not Data.Player.character then return nil end
    
    Data.Player.humanoidrootpart = Data.Player.character:FindFirstChild("HumanoidRootPart")
    if not Data.Player.humanoidrootpart then return nil end
    
    -- Update movement metrics
    Data.Player.position = Data.Player.humanoidrootpart.Position
    Data.Player.velocity = Data.Player.humanoidrootpart.Velocity
    Data.Player.speed = Data.Player.velocity.Magnitude
    Data.Player.ping = math.ceil(Network["Data Ping"]:GetValue())
    
    return unpack({
        Data.Player.character, Data.Player.humanoidrootpart, Data.Player.position,
        Data.Player.velocity, Data.Player.speed, Data.Player.ping
    })
end

return Utility