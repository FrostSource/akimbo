local animgraphParamsPistol = {
    "b_Crafting",
    "b_FriendlyTarget",
    "b_IsWorldItem",
    "b_LowKick",
    "b_ReleaseSlide",
    "b_ReloadAction",
    "b_ReloadPressed",
    "b_SelectorPressed",
    "b_Shoot",
    "b_ShootSecondary",
    "f_Trigger"
}

local animgraphParamsRapidfire = {
    "b_AdvanceCapsules",
    "b_AttachClip",
    "b_AttachClip_Fast",
    "b_CantShoot",
    "b_Crafting",
    "b_EnergyballFire",
    "b_FriendlyTarget",
    "b_HammerForward",
    "b_HasCapsuleInChamber",
    "b_HasCapsuleInClip",
    "b_HasExtendedMagazine",
    "b_IsWorldItem",
    "b_MagCasingButtonPressed",
    "b_MagCasingButtonTouched",
    "b_MagCasingOpen",
    "b_ReloadPressedNegative",
    "b_ReloadPressedOpenCasing",
    "b_SelectorPressed",
    "b_Shooting",
    "f_BulletSpread",
    "f_Recoil",
    "f_Trigger"
}

local animgraphParamsShotgun = {
    "b_AutoloaderBack",
    "b_AutoloaderFront",
    "b_Crafting",
    "b_FriendlyTarget",
    "b_IsWorldItem",
    "b_ReleaseSlide",
    "b_ReloadAction",
    "b_ReloadPressed",
    "b_Shoot",
    "f_Trigger"
}
local animgraphParamsShotgunHopper = {
    "b_LoadShell",
    "f_LoadSpeed"
}

local xoffset = 16
local yoffset = 16
local fontSize = 24

---@type EntityHandle[]
local currentDebugEnts = {}

---@param ent EntityHandle
---@param paramsTable string[]
local function DebugAnimGraph(ent, paramsTable)
    table.insert(currentDebugEnts, ent)
    local params = {}
    for _, param in ipairs(paramsTable) do
        table.insert(params, {
            name = param,
            value = nil,
            time = 0,
            x = xoffset,
            y = yoffset
        })
    end

    local colorNormal = Vector(255, 255, 255)
    local colorChange = Vector(0, 255, 0)

    -- DebugDrawScreenTextLine(xoffset, yoffset, 0, ent:GetClassname(), 255, 0, 255, 255, 200000)
    DebugScreenTextPretty(xoffset, yoffset, 0, ent:GetClassname(), 250, 100, 100, 255, 200000, "", fontSize, true)

    xoffset = xoffset + 300

    ent:SetContextThink("AnimGraphDebug", function()
        local origin = ent:GetAbsOrigin()
        for line, param in pairs(params) do
            local value = ent:GetGraphParameter(param.name)
            local color = colorNormal

            if value ~= param.value then
                param.value = value
                param.time = Time()
            end

            local text = param.name .. ": " .. tostring(value)

            if Time() - param.time < 5.0 then
                color = colorChange
            end

            if Time() - param.time < 0.5 then
                text = "    " .. text
            end

            if not IsVREnabled() or IsFakeVREnabled() then
                -- DebugDrawScreenTextLine(param.x, param.y, line, text, color.x, color.y, color.z, 255, 0)
                DebugScreenTextPretty(param.x, param.y, line, text, color.x, color.y, color.z, 255, 0, "", fontSize, false)
            else
                debugoverlay:Text(origin, line, text, 0, color.x, color.y, color.z, 255, 0)
            end

            line = line + 1
        end

        return 0
    end, 0)
end

Convars:RegisterCommand("akimbo_debug_weapon_animgraph", function(cmd, pattern)
    local ent
    if pattern ~= nil then
        ent = Debug.FindEntityByPattern(pattern)
    else
        ent = Player:GetWeapon()
    end

    if ent == nil or not IsValidEntity(ent) then
        warn("No entity found for pattern: " .. pattern)
        return
    end

    for _, debugEnt in ipairs(currentDebugEnts) do
        debugEnt:SetContextThink("AnimGraphDebug", nil, 0)
    end
    currentDebugEnts = {}

    xoffset = 16
    yoffset = 16

    currentDebugEnts = {}

    local curr = Player.CurrentlyEquipped

    debugoverlay:PushAndClearDebugOverlayScope("DebugAnimGraph")

    if curr == "hlvr_weapon_energygun" then DebugAnimGraph(ent, animgraphParamsPistol)
    elseif curr == "hlvr_weapon_rapidfire" then DebugAnimGraph(ent, animgraphParamsRapidfire)
    elseif curr == "hlvr_weapon_shotgun" then
        print(ent:GetClassname())
        DebugAnimGraph(ent, animgraphParamsShotgun)
        local hopper = ent:GetFirstChildWithName("shotgun_autoloader")
        if hopper then
            DebugAnimGraph(hopper, animgraphParamsShotgunHopper)
        end
    end
end, "", 0)