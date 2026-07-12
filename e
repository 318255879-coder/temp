--[[
    Fyntra visual library

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
    ["1"] = Color3.fromHex("#8B6CFF"),
    ["2"] = Color3.fromHex("#5CC8FF"),
    ["3"] = Color3.fromHex("#5FE1A1"),
}

local DEFAULTS = {
    enabled = true,
    team_check = false,
    max_distance = 2500,
    distance_unit = "st",
    box = true,
    box_thickness = 1,
    box_padding = 0,
    box_fill = false,
    box_fill_transparency = 0.92,
    name = true,
    name_gradient = true,
    health_text_gradient = true,
    distance_gradient = true,
    tool_gradient = true,
    name_size = 11,
    text_size = 11,
    healthbar = true,
    health_text = true,
    health_width = 3,
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

local BOOLEAN_OPTIONS = {
    enabled = true, team_check = true, box = true, box_fill = true, name = true,
    name_gradient = true, healthbar = true, health_text = true, health_text_gradient = true,
    distance = true, distance_gradient = true, tool = true, tool_gradient = true,
    tracer = true, chams = true, gradient = true,
}

local NUMBER_OPTIONS = {
    max_distance = true, box_thickness = true, box_padding = true, box_fill_transparency = true,
    name_size = true, text_size = true, health_width = true, chams_fill_transparency = true,
    chams_outline_transparency = true, gradient_rotation = true,
}

local function sanitizeOption(key, value, fallback)
    if BOOLEAN_OPTIONS[key] then
        return type(value) == "boolean" and value or fallback
    elseif NUMBER_OPTIONS[key] then
        local number = tonumber(value) or fallback
        if string.find(key, "transparency", 1, true) then
            return clamp(number or 0, 0, 1)
        elseif key == "name_size" or key == "text_size" or key == "health_width" or key == "box_thickness" then
            return max(1, number or 1)
        elseif key == "max_distance" then
            return max(0, number or 0)
        end
        return number
    end
    return value
end

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

local function normalizeColors(colors, fallback)
    if typeof(colors) == "ColorSequence" then
        local list = {}
        for _, point in colors.Keypoints do
            insert(list, point.Value)
        end
        return list
    elseif typeof(colors) == "Color3" then
        return {colors, colors}
    end

    local list = {}
    if type(colors) == "table" then
        for _, value in colors do
            if typeof(value) == "Color3" then
                insert(list, value)
            end
        end
    end
    if #list == 0 then
        local fallback_type = typeof(fallback)
        if fallback_type == "ColorSequence" then
            for _, point in fallback.Keypoints do insert(list, point.Value) end
        elseif fallback_type == "Color3" then
            insert(list, fallback)
        elseif type(fallback) == "table" then
            for _, value in fallback do
                if typeof(value) == "Color3" then insert(list, value) end
            end
        else
            list = {DEFAULT_THEME["1"], DEFAULT_THEME["2"], DEFAULT_THEME["3"]}
        end
    end
    if #list == 0 then
        list = {rgb(255, 255, 255), rgb(255, 255, 255)}
    elseif #list == 1 then
        insert(list, list[1])
    end
    return list
end

local function colorSequence(colors, fallback)
    if typeof(colors) == "ColorSequence" then
        return colors
    end
    local list = normalizeColors(colors, fallback)
    local points = {}
    local denominator = max(#list - 1, 1)
    for index, value in list do
        insert(points, ColorSequenceKeypoint.new((index - 1) / denominator, value))
    end
    return ColorSequence.new(points)
end

local function numberSequence(value)
    if typeof(value) == "NumberSequence" then return value end
    local number = tonumber(value)
    return number ~= nil and NumberSequence.new(clamp(number, 0, 1)) or nil
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

local function setProperty(object, property, value)
    if object[property] ~= value then
        object[property] = value
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
        local root = "fyntra"
        local game_directory = root .. "/examplegame"
        local directory = game_directory .. "/visuals"
        local font_directory = directory .. "/fonts"
        if type(isfolder) ~= "function" or not isfolder(root) then
            makefolder(root)
        end
        if type(isfolder) ~= "function" or not isfolder(game_directory) then
            makefolder(game_directory)
        end
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
            "FyntraVisualTiny",
            "tahoma_bold.ttf",
            "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/tahoma_bold.ttf"
        )
        return {
            ProggyClean = register(
                "FyntraVisualProggyClean",
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
        if not part.Parent or part.Transparency >= 0.95 then
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
    options = type(options) == "table" and options or {}
    local self = setmetatable({}, Visuals)
    self.fonts = getFontSet()
    self.theme = merge(getTheme(), type(options.theme) == "table" and options.theme or nil)
    for key, fallback in DEFAULT_THEME do
        if typeof(self.theme[key]) ~= "Color3" then self.theme[key] = fallback end
    end
    self.options = merge(DEFAULTS, type(options.defaults) == "table" and options.defaults or nil)
    for key, value in self.options do
        self.options[key] = sanitizeOption(key, value, DEFAULTS[key])
    end
    self.enabled = options.enabled ~= false
    self.entities = {}
    self.connections = {}
    self.gradients = {}
    self.gradient_colors = normalizeColors(options.gradient_colors, {
        self.theme["1"],
        self.theme["2"],
        self.theme["3"],
    })
    self.text_gradient_colors = {}
    for _, key in {"name", "health_text", "distance", "tool"} do
        local supplied = type(options.text_gradient_colors) == "table" and options.text_gradient_colors[key] or nil
        self.text_gradient_colors[key] = normalizeColors(supplied, self.gradient_colors)
    end
    self.animated_gradients = options.animated_gradients or false
    self.gradient_speed = options.gradient_speed or 35
    self.flags = nil
    self.flag_map = nil
    self.flag_values = {}

    self.gui = create("ScreenGui", {
        Parent = getParent(options.parent),
        Name = options.name or "fyntra_visuals",
        DisplayOrder = options.display_order or 0,
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

function Visuals:_gradient(parent, colors, rotation, group)
    local gradient = create("UIGradient", {
        Parent = parent,
        Color = colorSequence(colors or self.gradient_colors),
        Rotation = rotation or 0,
    })
    insert(self.gradients, {
        object = gradient,
        linked = colors == nil,
        base_rotation = rotation or 0,
        group = group or (colors == nil and "box" or "custom"),
    })
    return gradient
end

function Visuals:_text(properties)
    properties = properties or {}
    properties.Parent = self.gui
    properties.BackgroundTransparency = 1
    properties.BorderSizePixel = 0
    properties.FontFace = properties.FontFace or self.fonts.ProggyTiny
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
    local gradient = self:_gradient(side, nil, rotation, "box")
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
    entity.options = merge(self.options, type(options) == "table" and options or nil)
    for key, value in entity.options do
        entity.options[key] = sanitizeOption(key, value, self.options[key] or DEFAULTS[key])
    end
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
    objects.name.TextColor3 = rgb(255, 255, 255)
    entity.gradients.name = self:_gradient(objects.name, self.text_gradient_colors.name, gradient_rotation, "name")

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
    for _, key in {"health_text", "distance", "tool"} do
        objects[key].TextColor3 = rgb(255, 255, 255)
        entity.gradients[key] = self:_gradient(objects[key], self.text_gradient_colors[key], gradient_rotation, key)
    end
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
    entity.gradients.tracer = self:_gradient(objects.tracer, nil, gradient_rotation, "tracer")

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
    self.tracked_options = type(options) == "table" and options or self.tracked_options or {}

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
        value = sanitizeOption(option, value, self.options[option])
        if value ~= nil and self.flag_values[flag] ~= value then
            self.flag_values[flag] = value
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
    if type(options) ~= "table" then return self end
    for key, value in options do
        self.options[key] = sanitizeOption(key, value, self.options[key])
    end
    for _, entity in self.entities do
        entity:SetOptions(options)
    end
    return self
end

function Visuals:SetGradient(colors, transparency, from_theme)
    self.gradient_colors = normalizeColors(colors, self.gradient_colors)
    if not from_theme then
        self.custom_gradient = true
    end
    local sequence = colorSequence(self.gradient_colors)
    for index = #self.gradients, 1, -1 do
        local record = self.gradients[index]
        if not record.object or not record.object.Parent then
            remove(self.gradients, index)
        elseif record.linked then
            record.object.Color = sequence
            if transparency ~= nil then
                local sequence_value = numberSequence(transparency)
                if sequence_value then record.object.Transparency = sequence_value end
            end
        end
    end
    -- Each box edge owns its gradient. Refresh them directly as well so changing
    -- a picker always affects existing boxes, not just text/tracer records.
    for _, entity in self.entities do
        for _, key in {"top", "bottom", "left", "right"} do
            local edge = entity.objects[key]
            local gradient = entity.gradients[key]
            if edge and edge.Parent then
                edge.BackgroundColor3 = entity.options.gradient ~= false and rgb(255, 255, 255) or self.theme["1"]
            end
            if gradient and gradient.Parent then
                gradient.Enabled = entity.options.gradient ~= false
                gradient.Color = sequence
                if transparency ~= nil then
                    local sequence_value = numberSequence(transparency)
                    if sequence_value then gradient.Transparency = sequence_value end
                end
            end
        end
    end
    return self
end

function Visuals:SetTextGradient(kind, colors, transparency)
    if not self.text_gradient_colors[kind] then
        return false
    end
    local normalized = normalizeColors(colors, self.text_gradient_colors[kind])
    self.text_gradient_colors[kind] = normalized
    for _, entity in self.entities do
        entity:SetTextGradient(kind, normalized, transparency)
    end
    return true
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
    colors = normalizeColors(colors, self.options.health_gradient)
    for _, entity in self.entities do
        entity:SetHealthGradient(colors, transparency)
    end
    self.options.health_gradient = colors
    return self
end

function Visuals:SetTheme(theme)
    if type(theme) ~= "table" then return self end
    for key, value in theme do
        if self.theme[key] ~= nil and typeof(value) == "Color3" then
            self.theme[key] = value
        end
    end
    if not self.custom_gradient then
        self:SetGradient({self.theme["1"], self.theme["2"], self.theme["3"]}, nil, true)
    end
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
            if record.group ~= "health" and record.group ~= "custom" and record.object and record.object.Parent then
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
        local gradient = self.gradients[key]
        objects[key].TextColor3 = gradient and gradient.Enabled and rgb(255, 255, 255) or theme.text
        objects[key].TextStrokeColor3 = theme.text_outline
    end
end

function Entity:SetOptions(options)
    if type(options) ~= "table" then options = {} end
    for key, value in options do
        self.options[key] = sanitizeOption(key, value, self.options[key])
    end
    self.objects.fill.BackgroundTransparency = self.options.box_fill_transparency
    self.objects.highlight.FillTransparency = self.options.chams_fill_transparency
    self.objects.highlight.OutlineTransparency = self.options.chams_outline_transparency
    for _, key in {"top", "bottom", "left", "right"} do
        local gradient = self.gradients[key]
        if gradient then
            gradient.Enabled = self.options.gradient
        end
        self.objects[key].BackgroundColor3 = self.options.gradient and rgb(255, 255, 255) or self.library.theme["1"]
    end
    if self.gradients.name then
        self.gradients.name.Enabled = self.options.name_gradient
        self.objects.name.TextColor3 = self.gradients.name.Enabled and rgb(255, 255, 255) or self.library.theme.text
    end
    for _, key in {"health_text", "distance", "tool"} do
        local gradient = self.gradients[key]
        if gradient then
            gradient.Enabled = self.options[key .. "_gradient"] ~= false
            self.objects[key].TextColor3 = gradient.Enabled and rgb(255, 255, 255) or self.library.theme.text
        end
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
                local sequence_value = numberSequence(transparency)
                if sequence_value then gradient.Transparency = sequence_value end
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

function Entity:SetTextGradient(kind, colors, transparency)
    local gradient = self.gradients[kind]
    if not gradient or not gradient.Parent then
        return false
    end
    gradient.Color = colorSequence(colors, self.library.text_gradient_colors[kind])
    if transparency ~= nil then
        local sequence_value = numberSequence(transparency)
        if sequence_value then gradient.Transparency = sequence_value end
    end
    local enabled_key = kind == "name" and "name_gradient" or (kind .. "_gradient")
    gradient.Enabled = self.options[enabled_key] ~= false
    self.objects[kind].TextColor3 = gradient.Enabled and rgb(255, 255, 255) or self.library.theme.text
    return true
end

function Entity:SetHealthGradient(colors, transparency)
    local gradient = self.gradients.health
    if not gradient or not gradient.Parent then return false end
    gradient.Color = colorSequence(colors)
    if transparency ~= nil then
        local sequence_value = numberSequence(transparency)
        if sequence_value then gradient.Transparency = sequence_value end
    end
    self.options.health_gradient = colors
    return self
end

function Entity:SetVisible(value)
    value = not not value
    if self.visible == value then
        return
    end
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
    local max_distance = max(0, tonumber(options.max_distance) or DEFAULTS.max_distance)
    local box_padding = tonumber(options.box_padding) or DEFAULTS.box_padding
    local box_thickness = tonumber(options.box_thickness) or DEFAULTS.box_thickness
    local health_width_option = tonumber(options.health_width) or DEFAULTS.health_width
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

    local root_point, root_on_screen = Camera:WorldToViewportPoint(root.Position)
    if root_point.Z <= 0.5 or not root_on_screen then
        self:SetVisible(false)
        return
    end

    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    if distance > max_distance then
        self:SetVisible(false)
        return
    end

    local top_left, bottom_right = projectModel(model, box_padding, self.body_parts)
    if not top_left then
        self.body_parts = getRenderableBodyParts(model)
        top_left, bottom_right = projectModel(model, box_padding, self.body_parts)
    end
    if not top_left then
        self:SetVisible(false)
        return
    end

    local objects = self.objects
    local width = bottom_right.X - top_left.X
    local height = bottom_right.Y - top_left.Y
    local thickness = max(1, floor(box_thickness + 0.5))
    local shadow_thickness = thickness + 2
    local center_x = top_left.X + width * 0.5

    self:SetVisible(true)
    setProperty(objects.fill, "Visible", options.box and options.box_fill)
    setProperty(objects.fill, "Position", fromOffset(top_left.X + thickness, top_left.Y + thickness))
    setProperty(objects.fill, "Size", fromOffset(max(0, width - thickness * 2), max(0, height - thickness * 2)))

    local box_visible = options.box
    for _, key in {"top", "bottom", "left", "right", "top_shadow", "bottom_shadow", "left_shadow", "right_shadow"} do
        setProperty(objects[key], "Visible", box_visible)
    end

    setProperty(objects.top_shadow, "Position", fromOffset(top_left.X - 1, top_left.Y - 1))
    setProperty(objects.top_shadow, "Size", fromOffset(width + 2, shadow_thickness))
    setProperty(objects.bottom_shadow, "Position", fromOffset(top_left.X - 1, bottom_right.Y - thickness - 1))
    setProperty(objects.bottom_shadow, "Size", fromOffset(width + 2, shadow_thickness))
    setProperty(objects.left_shadow, "Position", fromOffset(top_left.X - 1, top_left.Y - 1))
    setProperty(objects.left_shadow, "Size", fromOffset(shadow_thickness, height + 2))
    setProperty(objects.right_shadow, "Position", fromOffset(bottom_right.X - thickness - 1, top_left.Y - 1))
    setProperty(objects.right_shadow, "Size", fromOffset(shadow_thickness, height + 2))

    setProperty(objects.top, "Position", fromOffset(top_left.X, top_left.Y))
    setProperty(objects.top, "Size", fromOffset(width, thickness))
    setProperty(objects.bottom, "Position", fromOffset(top_left.X, bottom_right.Y - thickness))
    setProperty(objects.bottom, "Size", fromOffset(width, thickness))
    setProperty(objects.left, "Position", fromOffset(top_left.X, top_left.Y))
    setProperty(objects.left, "Size", fromOffset(thickness, height))
    setProperty(objects.right, "Position", fromOffset(bottom_right.X - thickness, top_left.Y))
    setProperty(objects.right, "Size", fromOffset(thickness, height))

    setProperty(objects.name, "Visible", options.name)
    setProperty(objects.name, "Text", options.display_name or (self.player and self.player.DisplayName) or model.Name)
    setProperty(objects.name, "Position", fromOffset(top_left.X - 20, top_left.Y - 14))
    setProperty(objects.name, "Size", fromOffset(width + 40, 12))

    local health = humanoid and humanoid.Health or options.health or 100
    local max_health = humanoid and humanoid.MaxHealth or options.max_health or 100
    local health_ratio = clamp(max_health > 0 and health / max_health or 0, 0, 1)
    local health_visible = options.healthbar and humanoid ~= nil
    local health_width = max(2, floor(health_width_option + 0.5))
    local health_x = top_left.X - health_width - 4
    local empty_height = floor(height * (1 - health_ratio) + 0.5)
    local filled_height = max(0, height - empty_height)
    setProperty(objects.health_outline, "Visible", health_visible)
    setProperty(objects.health_background, "Visible", health_visible)
    setProperty(objects.health_clip, "Visible", health_visible)
    setProperty(objects.health_fill, "Visible", health_visible)
    setProperty(objects.health_outline, "Position", fromOffset(health_x - 1, top_left.Y - 1))
    setProperty(objects.health_outline, "Size", fromOffset(health_width + 2, height + 2))
    setProperty(objects.health_background, "Position", fromOffset(health_x, top_left.Y))
    setProperty(objects.health_background, "Size", fromOffset(health_width, height))
    setProperty(objects.health_clip, "Position", fromOffset(health_x, top_left.Y + empty_height))
    setProperty(objects.health_clip, "Size", fromOffset(health_width, filled_height))
    setProperty(objects.health_fill, "Position", fromOffset(0, -empty_height))
    setProperty(objects.health_fill, "Size", fromOffset(health_width, height))

    setProperty(objects.health_text, "Visible", health_visible and options.health_text and health_ratio < 0.995)
    setProperty(objects.health_text, "Text", tostring(floor(health + 0.5)))
    setProperty(objects.health_text, "Position", fromOffset(health_x - 38, top_left.Y + empty_height - 6))
    setProperty(objects.health_text, "Size", fromOffset(35, 11))

    setProperty(objects.distance, "Visible", options.distance)
    setProperty(objects.distance, "Text", string.format("[%d%s]", floor(distance + 0.5), options.distance_unit))
    setProperty(objects.distance, "Position", fromOffset(top_left.X - 20, bottom_right.Y + 1))
    setProperty(objects.distance, "Size", fromOffset(width + 40, 11))

    local tool_name = getToolName(model)
    setProperty(objects.tool, "Visible", options.tool and tool_name ~= "")
    setProperty(objects.tool, "Text", tool_name)
    setProperty(objects.tool, "Position", fromOffset(top_left.X - 20, bottom_right.Y + (options.distance and 12 or 1)))
    setProperty(objects.tool, "Size", fromOffset(width + 40, 11))

    setProperty(objects.tracer, "Visible", options.tracer)
    setProperty(objects.tracer_shadow, "Visible", options.tracer)
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

    if objects.highlight.Adornee ~= model then
        objects.highlight.Adornee = model
    end
    if objects.highlight.Enabled ~= options.chams then
        objects.highlight.Enabled = options.chams
    end
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
