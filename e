--[[
    priv9 visual library

    local Visuals = loadstring(...)()
    local esp = Visuals.new()
    esp:TrackPlayers({team_check = true})

    This module is standalone. It downloads and registers its own private copies
    of the ProggyClean and Tahoma/ProggyTiny faces.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local rgb = Color3.fromRGB
local vec2 = Vector2.new
local dim2 = UDim2.new
local fromOffset = UDim2.fromOffset
local clamp = math.clamp
local min = math.min
local max = math.max
local floor = math.floor
local atan2 = math.atan2
local deg = math.deg
local insert = table.insert
local remove = table.remove
local find = table.find

local Visuals = {}
Visuals.__index = Visuals

local Entity = {}
Entity.__index = Entity

local DEFAULT_THEME = {
    outline = rgb(10, 10, 10),
    inline = rgb(35, 35, 35),
    text = rgb(220, 220, 220),
    text_outline = rgb(0, 0, 0),
    background = rgb(20, 20, 20),
    muted = rgb(145, 145, 145),
    ["1"] = Color3.fromHex("#245771"),
    ["2"] = Color3.fromHex("#215D63"),
    ["3"] = Color3.fromHex("#1E6453"),
}

local DEFAULTS = {
    enabled = true,
    team_check = false,
    max_distance = 2500,
    distance_unit = "st",
    box = true,
    box_thickness = 2,
    box_padding = 1,
    box_fill = false,
    box_fill_transparency = 0.92,
    name = true,
    name_gradient = true,
    name_size = 11,
    text_size = 11,
    healthbar = true,
    health_text = true,
    health_width = 4,
    distance = true,
    tool = true,
    tracer = false,
    tracer_origin = "Bottom",
    chams = false,
    chams_fill_transparency = 0.72,
    chams_outline_transparency = 0.1,
    gradient = true,
    gradient_rotation = 0,
}

local BODY_PART_NAMES = {
    Head = true,
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}

local function clone(source)
    local target = {}
    for key, value in source do
        target[key] = value
    end
    return target
end

local function merge(base, override)
    local result = clone(base)
    for key, value in override or {} do
        result[key] = value
    end
    return result
end

local function create(class_name, properties)
    local object = Instance.new(class_name)
    for property, value in properties or {} do
        object[property] = value
    end
    return object
end

local function colorSequence(colors)
    if typeof(colors) == "ColorSequence" then
        return colors
    elseif typeof(colors) == "Color3" then
        return ColorSequence.new(colors)
    end

    local list = colors or {DEFAULT_THEME["1"], DEFAULT_THEME["2"], DEFAULT_THEME["3"]}
    local points = {}
    local denominator = max(#list - 1, 1)
    for index, value in list do
        insert(points, ColorSequenceKeypoint.new((index - 1) / denominator, value))
    end
    return ColorSequence.new(points)
end

local function setLine(frame, origin, destination, thickness)
    local delta = destination - origin
    frame.Position = fromOffset(origin.X, origin.Y)
    frame.Size = fromOffset(delta.Magnitude, thickness)
    frame.Rotation = deg(atan2(delta.Y, delta.X))
end

local function setGuiVisible(objects, visible)
    for _, object in objects do
        if object and object.Parent and object:IsA("GuiObject") then
            object.Visible = visible
        end
    end
end

local function getFontSet()
    local fallback = Font.fromEnum(Enum.Font.Code)
    local fonts = {
        ProggyClean = fallback,
        ProggyTiny = fallback,
        TahomaBold = fallback,
    }

    local asset = getcustomasset or getsynasset
    if type(isfile) ~= "function" or type(writefile) ~= "function" or type(makefolder) ~= "function" or type(asset) ~= "function" then
        return fonts
    end

    local ok, loaded = pcall(function()
        local directory = "priv9_visuals"
        local font_directory = directory .. "/fonts"
        if type(isfolder) ~= "function" or not isfolder(directory) then
            makefolder(directory)
        end
        if type(isfolder) ~= "function" or not isfolder(font_directory) then
            makefolder(font_directory)
        end

        local function register(name, file_name, url)
            local font_path = font_directory .. "/" .. file_name
            local manifest_path = font_directory .. "/" .. name .. ".font"
            if not isfile(font_path) then
                writefile(font_path, game:HttpGet(url))
            end

            writefile(manifest_path, HttpService:JSONEncode({
                name = name,
                faces = {{
                    name = "Regular",
                    weight = 200,
                    style = "Normal",
                    assetId = asset(font_path),
                }},
            }))
            return Font.new(asset(manifest_path), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        end

        local tiny = register(
            "Priv9VisualTiny",
            "tahoma_bold.ttf",
            "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/tahoma_bold.ttf"
        )
        return {
            ProggyClean = register(
                "Priv9VisualProggyClean",
                "ProggyClean.ttf",
                "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyClean.ttf"
            ),
            ProggyTiny = tiny,
            TahomaBold = tiny,
        }
    end)

    return ok and loaded or fonts
end

local function getTheme()
    return clone(DEFAULT_THEME)
end

local function getParent(requested)
    if requested then
        return requested
    end
    if gethui then
        return gethui()
    end
    return CoreGui
end

local function getTargetModel(target)
    if typeof(target) ~= "Instance" then
        return nil
    elseif target:IsA("Player") then
        return target.Character
    elseif target:IsA("Model") then
        return target
    elseif target:IsA("BasePart") then
        return target:FindFirstAncestorOfClass("Model")
    end
end

local function getTargetPlayer(target)
    if typeof(target) == "Instance" and target:IsA("Player") then
        return target
    end
    local model = getTargetModel(target)
    return model and Players:GetPlayerFromCharacter(model) or nil
end

local function getToolName(model)
    local tool = model and model:FindFirstChildOfClass("Tool")
    return tool and tool.Name or ""
end

local function isRenderableBodyPart(part, model)
    if not part:IsA("BasePart") or part.Transparency >= 0.95 or part.Name == "HumanoidRootPart" then
        return false
    end
    local accessory = part:FindFirstAncestorOfClass("Accessory")
    local tool = part:FindFirstAncestorOfClass("Tool")
    return not (accessory and accessory:IsDescendantOf(model)) and not (tool and tool:IsDescendantOf(model))
end

local function getRenderableBodyParts(model)
    local parts = {}
    local rig_parts = {}
    local is_character = model:FindFirstChildOfClass("Humanoid") ~= nil
    for _, descendant in model:GetDescendants() do
        if isRenderableBodyPart(descendant, model) then
            insert(parts, descendant)
            if BODY_PART_NAMES[descendant.Name] then
                insert(rig_parts, descendant)
            end
        end
    end
    return is_character and #rig_parts > 0 and rig_parts or parts
end

local function projectModel(model, padding, parts)
    if not Camera or not model or not model.Parent then
        return nil
    end

    local minimum = vec2(math.huge, math.huge)
    local maximum = vec2(-math.huge, -math.huge)
    local projected_points = 0

    for _, part in parts do
        if not part.Parent or not isRenderableBodyPart(part, model) then
            continue
        end
        local half = part.Size * 0.5
        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    local world = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                    local point = Camera:WorldToViewportPoint(world)
                    if point.Z > 0.05 then
                        minimum = vec2(min(minimum.X, point.X), min(minimum.Y, point.Y))
                        maximum = vec2(max(maximum.X, point.X), max(maximum.Y, point.Y))
                        projected_points += 1
                    end
                end
            end
        end
    end

    if projected_points == 0 or minimum.X == math.huge then
        return nil
    end

    local viewport = Camera.ViewportSize
    if maximum.X < 0 or maximum.Y < 0 or minimum.X > viewport.X or minimum.Y > viewport.Y then
        return nil
    end

    local padding_vector = typeof(padding) == "Vector2" and padding or vec2(padding or 0, padding or 0)
    minimum -= padding_vector
    maximum += padding_vector
    minimum = vec2(floor(clamp(minimum.X, 0, viewport.X) + 0.5), floor(clamp(minimum.Y, 0, viewport.Y) + 0.5))
    maximum = vec2(floor(clamp(maximum.X, 0, viewport.X) + 0.5), floor(clamp(maximum.Y, 0, viewport.Y) + 0.5))
    if maximum.X - minimum.X < 2 or maximum.Y - minimum.Y < 2 then
        return nil
    end

    return minimum, maximum
end

function Visuals.new(options)
    options = options or {}
    local self = setmetatable({}, Visuals)
    self.fonts = getFontSet()
    self.theme = merge(getTheme(), options.theme)
    self.options = merge(DEFAULTS, options.defaults)
    self.enabled = options.enabled ~= false
    self.entities = {}
    self.connections = {}
    self.gradients = {}
    self.gradient_colors = options.gradient_colors or {
        self.theme["1"],
        self.theme["2"],
        self.theme["3"],
    }
    self.animated_gradients = options.animated_gradients or false
    self.gradient_speed = options.gradient_speed or 35
    self.flags = nil
    self.flag_map = nil

    self.gui = create("ScreenGui", {
        Parent = getParent(options.parent),
        Name = options.name or "priv9_visuals",
        DisplayOrder = options.display_order or 8,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, self.gui)
    end

    self.connections.render = RunService.RenderStepped:Connect(function(delta)
        self:_step(delta)
    end)
    self.connections.camera = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = Workspace.CurrentCamera
    end)

    return self
end

function Visuals:_gradient(parent, colors, rotation)
    local gradient = create("UIGradient", {
        Parent = parent,
        Color = colorSequence(colors or self.gradient_colors),
        Rotation = rotation or 0,
    })
    insert(self.gradients, {
        object = gradient,
        linked = colors == nil,
        base_rotation = rotation or 0,
    })
    return gradient
end

function Visuals:_text(properties)
    properties = properties or {}
    properties.Parent = self.gui
    properties.BackgroundTransparency = 1
    properties.BorderSizePixel = 0
    properties.FontFace = properties.FontFace or self.fonts.ProggyClean
    properties.TextColor3 = properties.TextColor3 or self.theme.text
    properties.TextSize = properties.TextSize or 12
    properties.TextStrokeColor3 = properties.TextStrokeColor3 or self.theme.text_outline
    properties.TextStrokeTransparency = properties.TextStrokeTransparency or 0
    properties.ZIndex = properties.ZIndex or 6
    return create("TextLabel", properties)
end

function Visuals:_side(rotation)
    local shadow = create("Frame", {
        Parent = self.gui,
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.outline,
        ZIndex = 3,
    })
    local side = create("Frame", {
        Parent = self.gui,
        BorderSizePixel = 0,
        BackgroundColor3 = rgb(255, 255, 255),
        ZIndex = 4,
    })
    local gradient = self:_gradient(side, nil, rotation)
    return shadow, side, gradient
end

function Visuals:Add(target, options)
    if self.entities[target] then
        self.entities[target]:SetOptions(options or {})
        return self.entities[target]
    end

    local entity = setmetatable({}, Entity)
    entity.library = self
    entity.target = target
    entity.player = getTargetPlayer(target)
    entity.options = merge(self.options, options)
    entity.objects = {}
    entity.gradients = {}
    entity.destroyed = false

    local objects = entity.objects
    local gradient_rotation = entity.options.gradient_rotation or 0
    objects.fill = create("Frame", {
        Parent = self.gui,
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.background,
        BackgroundTransparency = entity.options.box_fill_transparency,
        ZIndex = 1,
    })

    objects.top_shadow, objects.top, entity.gradients.top = self:_side(gradient_rotation)
    objects.bottom_shadow, objects.bottom, entity.gradients.bottom = self:_side(gradient_rotation)
    objects.left_shadow, objects.left, entity.gradients.left = self:_side(gradient_rotation + 90)
    objects.right_shadow, objects.right, entity.gradients.right = self:_side(gradient_rotation + 90)

    objects.name = self:_text({
        FontFace = self.fonts.ProggyTiny,
        Text = "",
        TextSize = entity.options.name_size,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    entity.gradients.name = self:_gradient(objects.name, nil, gradient_rotation)

    objects.health_outline = create("Frame", {
        Parent = self.gui,
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.outline,
        ZIndex = 4,
    })
    objects.health_background = create("Frame", {
        Parent = self.gui,
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.inline,
        ZIndex = 5,
    })
    objects.health_clip = create("Frame", {
        Parent = self.gui,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 6,
    })
    objects.health_fill = create("Frame", {
        Parent = objects.health_clip,
        BorderSizePixel = 0,
        BackgroundColor3 = rgb(255, 255, 255),
        ZIndex = 6,
    })
    entity.gradients.health = self:_gradient(objects.health_fill, entity.options.health_gradient or {
        rgb(70, 190, 105),
        rgb(220, 190, 72),
        rgb(220, 72, 72),
    }, 90)

    objects.health_text = self:_text({Text = "", TextSize = entity.options.text_size, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7})
    objects.distance = self:_text({Text = "", TextSize = entity.options.text_size, TextXAlignment = Enum.TextXAlignment.Center})
    objects.tool = self:_text({Text = "", TextSize = entity.options.text_size, TextXAlignment = Enum.TextXAlignment.Center})
    objects.tracer_shadow = create("Frame", {
        Parent = self.gui,
        AnchorPoint = vec2(0, 0.5),
        BorderSizePixel = 0,
        BackgroundColor3 = self.theme.outline,
        ZIndex = 2,
    })
    objects.tracer = create("Frame", {
        Parent = self.gui,
        AnchorPoint = vec2(0, 0.5),
        BorderSizePixel = 0,
        BackgroundColor3 = rgb(255, 255, 255),
        ZIndex = 3,
    })
    entity.gradients.tracer = self:_gradient(objects.tracer, nil, gradient_rotation)

    objects.highlight = create("Highlight", {
        Parent = self.gui,
        Enabled = false,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = self.theme["2"],
        FillTransparency = entity.options.chams_fill_transparency,
        OutlineColor = self.theme["1"],
        OutlineTransparency = entity.options.chams_outline_transparency,
    })

    self.entities[target] = entity
    entity:SetOptions(entity.options)
    entity:SetVisible(false)
    return entity
end

Visuals.AddPlayer = Visuals.Add
Visuals.AddModel = Visuals.Add

function Visuals:Remove(target)
    local entity = self.entities[target]
    if entity then
        entity:Destroy()
    end
end

function Visuals:Get(target)
    return self.entities[target]
end

function Visuals:TrackPlayers(options)
    self.tracking_players = true
    self.tracked_options = options or self.tracked_options or {}

    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            self:Add(player, self.tracked_options)
        end
    end

    if not self.connections.player_added then
        self.connections.player_added = Players.PlayerAdded:Connect(function(player)
            if player ~= LocalPlayer then
                self:Add(player, self.tracked_options)
            end
        end)
        self.connections.player_removing = Players.PlayerRemoving:Connect(function(player)
            self:Remove(player)
        end)
    end
    return self
end

function Visuals:StopTrackingPlayers(remove_players)
    self.tracking_players = false
    for _, key in {"player_added", "player_removing"} do
        if self.connections[key] then
            self.connections[key]:Disconnect()
            self.connections[key] = nil
        end
    end
    if remove_players ~= false then
        local pending = {}
        for target, entity in self.entities do
            if entity.player then
                insert(pending, target)
            end
        end
        for _, target in pending do
            self:Remove(target)
        end
    end
    return self
end

function Visuals:BindFlags(flags, mapping)
    self.flags = flags
    self.flag_map = mapping or {
        enabled = "visuals_enabled",
        box = "visuals_box",
        box_fill = "visuals_box_fill",
        name = "visuals_name",
        healthbar = "visuals_healthbar",
        health_text = "visuals_health_text",
        distance = "visuals_distance",
        tool = "visuals_tool",
        tracer = "visuals_tracer",
        chams = "visuals_chams",
        team_check = "visuals_team_check",
        max_distance = "visuals_max_distance",
    }
    return self
end

function Visuals:_syncFlags()
    if not self.flags or not self.flag_map then
        return
    end
    for option, flag in self.flag_map do
        local value = self.flags[flag]
        if value ~= nil then
            if option == "enabled" then
                self.enabled = value
            else
                self.options[option] = value
                for _, entity in self.entities do
                    entity.options[option] = value
                end
            end
        end
    end
end

function Visuals:SetEnabled(value)
    self.enabled = not not value
    if not self.enabled then
        for _, entity in self.entities do
            entity:SetVisible(false)
        end
    end
    return self
end

function Visuals:SetOptions(options)
    for key, value in options or {} do
        self.options[key] = value
    end
    for _, entity in self.entities do
        entity:SetOptions(options)
    end
    return self
end

function Visuals:SetGradient(colors, transparency)
    self.gradient_colors = colors
    local sequence = colorSequence(colors)
    for index = #self.gradients, 1, -1 do
        local record = self.gradients[index]
        if not record.object or not record.object.Parent then
            remove(self.gradients, index)
        elseif record.linked then
            record.object.Color = sequence
            if transparency ~= nil then
                record.object.Transparency = typeof(transparency) == "NumberSequence" and transparency or NumberSequence.new(transparency)
            end
        end
    end
    return self
end

function Visuals:SetAnimatedGradients(value, speed)
    self.animated_gradients = not not value
    if speed then
        self.gradient_speed = speed
    end
    if not self.animated_gradients then
        self.gradient_rotation = 0
        for _, record in self.gradients do
            if record.object and record.object.Parent then
                record.object.Rotation = record.base_rotation
            end
        end
    end
    return self
end

function Visuals:SetHealthGradient(colors, transparency)
    for _, entity in self.entities do
        entity:SetHealthGradient(colors, transparency)
    end
    self.options.health_gradient = colors
    return self
end

function Visuals:SetTheme(theme)
    for key, value in theme or {} do
        self.theme[key] = value
    end
    self:SetGradient({self.theme["1"], self.theme["2"], self.theme["3"]})
    for _, entity in self.entities do
        entity:_applyTheme()
    end
    return self
end

function Visuals:_step(delta)
    self:_syncFlags()
    if self.animated_gradients then
        self.gradient_rotation = (self.gradient_rotation or 0) + (delta * self.gradient_speed)
        for _, record in self.gradients do
            if record.linked and record.object and record.object.Parent then
                record.object.Rotation = record.base_rotation + self.gradient_rotation
            end
        end
    end

    for _, entity in self.entities do
        entity:_update()
    end
end

function Visuals:Unload()
    local pending = {}
    for target in self.entities do
        insert(pending, target)
    end
    for _, target in pending do
        self:Remove(target)
    end
    for _, connection in self.connections do
        connection:Disconnect()
    end
    table.clear(self.connections)
    table.clear(self.gradients)
    if self.gui then
        self.gui:Destroy()
    end
    self.enabled = false
end

function Entity:_applyTheme()
    local theme = self.library.theme
    local objects = self.objects
    objects.fill.BackgroundColor3 = theme.background
    objects.health_outline.BackgroundColor3 = theme.outline
    objects.health_background.BackgroundColor3 = theme.inline
    objects.tracer_shadow.BackgroundColor3 = theme.outline
    objects.highlight.FillColor = theme["2"]
    objects.highlight.OutlineColor = theme["1"]
    for _, key in {"top_shadow", "bottom_shadow", "left_shadow", "right_shadow"} do
        objects[key].BackgroundColor3 = theme.outline
    end
    for _, key in {"name", "health_text", "distance", "tool"} do
        objects[key].TextColor3 = theme.text
        objects[key].TextStrokeColor3 = theme.text_outline
    end
end

function Entity:SetOptions(options)
    for key, value in options or {} do
        self.options[key] = value
    end
    self.objects.fill.BackgroundTransparency = self.options.box_fill_transparency
    self.objects.highlight.FillTransparency = self.options.chams_fill_transparency
    self.objects.highlight.OutlineTransparency = self.options.chams_outline_transparency
    for _, key in {"top", "bottom", "left", "right"} do
        local gradient = self.objects[key]:FindFirstChildOfClass("UIGradient")
        if gradient then
            gradient.Enabled = self.options.gradient
        end
        self.objects[key].BackgroundColor3 = self.library.theme["1"]
    end
    if self.gradients.name then
        self.gradients.name.Enabled = self.options.name_gradient
    end
    self.objects.name.TextSize = self.options.name_size
    for _, key in {"health_text", "distance", "tool"} do
        self.objects[key].TextSize = self.options.text_size
    end
    if options and options.gradient_colors then
        self:SetGradient(options.gradient_colors, options.gradient_transparency)
    end
    if options and options.health_gradient then
        self:SetHealthGradient(options.health_gradient, options.health_gradient_transparency)
    end
    return self
end

function Entity:SetGradient(colors, transparency)
    local sequence = colorSequence(colors)
    for key, gradient in self.gradients do
        if gradient and gradient.Parent and key ~= "health" then
            gradient.Color = sequence
            if transparency ~= nil then
                gradient.Transparency = typeof(transparency) == "NumberSequence" and transparency or NumberSequence.new(transparency)
            end
            for _, record in self.library.gradients do
                if record.object == gradient then
                    record.linked = false
                    break
                end
            end
        end
    end
    return self
end

function Entity:SetHealthGradient(colors, transparency)
    local gradient = self.gradients.health
    gradient.Color = colorSequence(colors)
    if transparency ~= nil then
        gradient.Transparency = typeof(transparency) == "NumberSequence" and transparency or NumberSequence.new(transparency)
    end
    self.options.health_gradient = colors
    return self
end

function Entity:SetVisible(value)
    setGuiVisible(self.objects, value)
    if self.objects.highlight then
        self.objects.highlight.Enabled = value and self.options.chams
    end
    self.visible = value
end

function Entity:_update()
    if self.destroyed then
        return
    end

    local library = self.library
    local options = self.options
    local model = getTargetModel(self.target)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)

    if not Camera or not library.enabled or not options.enabled or not model or not root or (humanoid and humanoid.Health <= 0) then
        self:SetVisible(false)
        return
    end

    if self.model ~= model then
        self.model = model
        self.body_parts = getRenderableBodyParts(model)
    end
    if options.team_check and self.player and LocalPlayer and self.player.Team ~= nil and self.player.Team == LocalPlayer.Team then
        self:SetVisible(false)
        return
    end

    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    if distance > options.max_distance then
        self:SetVisible(false)
        return
    end

    local top_left, bottom_right = projectModel(model, options.box_padding, self.body_parts)
    if not top_left then
        self.body_parts = getRenderableBodyParts(model)
        top_left, bottom_right = projectModel(model, options.box_padding, self.body_parts)
    end
    if not top_left then
        self:SetVisible(false)
        return
    end

    local objects = self.objects
    local width = bottom_right.X - top_left.X
    local height = bottom_right.Y - top_left.Y
    local thickness = max(1, floor(options.box_thickness + 0.5))
    local shadow_thickness = thickness + 2
    local center_x = top_left.X + width * 0.5

    self:SetVisible(true)
    objects.fill.Visible = options.box and options.box_fill
    objects.fill.Position = fromOffset(top_left.X + thickness, top_left.Y + thickness)
    objects.fill.Size = fromOffset(max(0, width - thickness * 2), max(0, height - thickness * 2))

    local box_visible = options.box
    for _, key in {"top", "bottom", "left", "right", "top_shadow", "bottom_shadow", "left_shadow", "right_shadow"} do
        objects[key].Visible = box_visible
    end

    objects.top_shadow.Position = fromOffset(top_left.X - 1, top_left.Y - 1)
    objects.top_shadow.Size = fromOffset(width + 2, shadow_thickness)
    objects.bottom_shadow.Position = fromOffset(top_left.X - 1, bottom_right.Y - thickness - 1)
    objects.bottom_shadow.Size = fromOffset(width + 2, shadow_thickness)
    objects.left_shadow.Position = fromOffset(top_left.X - 1, top_left.Y - 1)
    objects.left_shadow.Size = fromOffset(shadow_thickness, height + 2)
    objects.right_shadow.Position = fromOffset(bottom_right.X - thickness - 1, top_left.Y - 1)
    objects.right_shadow.Size = fromOffset(shadow_thickness, height + 2)

    objects.top.Position = fromOffset(top_left.X, top_left.Y)
    objects.top.Size = fromOffset(width, thickness)
    objects.bottom.Position = fromOffset(top_left.X, bottom_right.Y - thickness)
    objects.bottom.Size = fromOffset(width, thickness)
    objects.left.Position = fromOffset(top_left.X, top_left.Y)
    objects.left.Size = fromOffset(thickness, height)
    objects.right.Position = fromOffset(bottom_right.X - thickness, top_left.Y)
    objects.right.Size = fromOffset(thickness, height)

    objects.name.Visible = options.name
    objects.name.Text = options.display_name or (self.player and self.player.DisplayName) or model.Name
    objects.name.Position = fromOffset(top_left.X - 20, top_left.Y - 14)
    objects.name.Size = fromOffset(width + 40, 12)

    local health = humanoid and humanoid.Health or options.health or 100
    local max_health = humanoid and humanoid.MaxHealth or options.max_health or 100
    local health_ratio = clamp(max_health > 0 and health / max_health or 0, 0, 1)
    local health_visible = options.healthbar and humanoid ~= nil
    local health_width = max(2, floor(options.health_width + 0.5))
    local health_x = top_left.X - health_width - 4
    local empty_height = floor(height * (1 - health_ratio) + 0.5)
    local filled_height = max(0, height - empty_height)
    objects.health_outline.Visible = health_visible
    objects.health_background.Visible = health_visible
    objects.health_clip.Visible = health_visible
    objects.health_fill.Visible = health_visible
    objects.health_outline.Position = fromOffset(health_x - 1, top_left.Y - 1)
    objects.health_outline.Size = fromOffset(health_width + 2, height + 2)
    objects.health_background.Position = fromOffset(health_x, top_left.Y)
    objects.health_background.Size = fromOffset(health_width, height)
    objects.health_clip.Position = fromOffset(health_x, top_left.Y + empty_height)
    objects.health_clip.Size = fromOffset(health_width, filled_height)
    objects.health_fill.Position = fromOffset(0, -empty_height)
    objects.health_fill.Size = fromOffset(health_width, height)

    objects.health_text.Visible = health_visible and options.health_text and health_ratio < 0.995
    objects.health_text.Text = tostring(floor(health + 0.5))
    objects.health_text.Position = fromOffset(health_x - 38, top_left.Y + empty_height - 6)
    objects.health_text.Size = fromOffset(35, 11)

    objects.distance.Visible = options.distance
    objects.distance.Text = string.format("[%d%s]", floor(distance + 0.5), options.distance_unit)
    objects.distance.Position = fromOffset(top_left.X - 20, bottom_right.Y + 1)
    objects.distance.Size = fromOffset(width + 40, 11)

    local tool_name = getToolName(model)
    objects.tool.Visible = options.tool and tool_name ~= ""
    objects.tool.Text = tool_name
    objects.tool.Position = fromOffset(top_left.X - 20, bottom_right.Y + (options.distance and 12 or 1))
    objects.tool.Size = fromOffset(width + 40, 11)

    objects.tracer.Visible = options.tracer
    objects.tracer_shadow.Visible = options.tracer
    if options.tracer then
        local viewport = Camera.ViewportSize
        local origin
        if typeof(options.tracer_origin) == "Vector2" then
            origin = options.tracer_origin
        elseif options.tracer_origin == "Center" then
            origin = viewport * 0.5
        elseif options.tracer_origin == "Mouse" and LocalPlayer then
            origin = vec2(LocalPlayer:GetMouse().X, LocalPlayer:GetMouse().Y)
        else
            origin = vec2(viewport.X * 0.5, viewport.Y - 2)
        end
        local destination = vec2(center_x, bottom_right.Y)
        setLine(objects.tracer_shadow, origin, destination, thickness + 2)
        setLine(objects.tracer, origin, destination, thickness)
    end

    objects.highlight.Adornee = model
    objects.highlight.Enabled = options.chams
end

function Entity:Destroy()
    if self.destroyed then
        return
    end
    self.destroyed = true
    self.library.entities[self.target] = nil
    for _, object in self.objects do
        if object then
            object:Destroy()
        end
    end
    table.clear(self.objects)
end

Visuals.create = Visuals.new

return Visuals
