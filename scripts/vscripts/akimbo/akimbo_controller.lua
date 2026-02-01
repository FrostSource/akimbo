--[[
    Handles global akimbo weapon logic
]]

local weaponOverride = require("akimbo.weapon_override")

local akimboWeaponSwitchId = -1

function DisableAkimboWeaponSwitch()
    Input:StopListening(akimboWeaponSwitchId)
    akimboWeaponSwitchId = -1
end

function EnableAkimboWeaponSwitch()
    DisableAkimboWeaponSwitch()

    ---This handles equipping/unequipping the akimbo weapon
    ---I don't know of any good way to do this
    akimboWeaponSwitchId = Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_CROUCH_TOGGLE, nil, function ()
        -- print("Toggling akimbo weapon")
        if IsValidEntity(CurrentAkimboWeapon) then
            if CurrentAkimboWeapon:IsEquipped() then
                CurrentAkimboWeapon:Unequip()
            else
                CurrentAkimboWeapon:Equip()
            end
        end
    end)
end

function IsAkimboWeaponSwitchEnabled()
    return akimboWeaponSwitchId ~= -1
end

---@param event PlayerEventWeaponSwitch
ListenToPlayerEvent("weapon_switch", function(event)
    -- print(event.item, IsAkimboWeaponSwitchEnabled(), isinstance(event.item, "AkimboWeapon"))
    -- if event.item and not IsAkimboWeaponSwitchEnabled() and isinstance(event.item, "AkimboWeapon") then
        EnableAkimboWeaponSwitch()
    -- end

    if CurrentAkimboWeapon and CurrentAkimboWeapon:IsEquipped() then
        -- Override weapon completely when akimbo is equipped
        weaponOverride.overrideWeapon(Player:GetWeapon())
    elseif Player.CurrentlyEquipped == "hlvr_weapon_energygun" then
        -- Only override the modified pistol mechanics when akimbo is not equipped
        weaponOverride.overrideWeapon(Player:GetWeapon(), true)
    else
        -- Disable overrides when akimbo is not equipped
        weaponOverride.overrideWeapon(nil)
    end
end)

local function checkEntityBehindHead(entity)
    local handPos = entity:GetAbsOrigin()
    local hmdPos = Player:EyePosition()
    local dir = handPos - hmdPos
    local dot = dir:Dot(Player:EyeAngles():Forward())
    return dot < -5
end

---@param pistol EntityHandle
---@param clip? EntityHandle
local function reloadPistol(pistol, clip)
    if pistol:GetFirstChildWithClassname("item_hlvr_clip_energygun") then
        -- Pistol already has a clip
        return false
    end

    clip = clip or SpawnEntityFromTableSynchronous("item_hlvr_clip_energygun", {
        origin = pistol:GetOrigin()
    })

    StartSoundEventFromPosition("Pistol.ClipInsert", pistol:GetOrigin())

    if isinstance(pistol, "AkimboPistol") then
        ---@cast pistol AkimboPistol
        pistol:InsertClip(clip)
    else
        pistol:EntFire("HandInteractionSucceeded", "0", 0, Player, clip)
    end

    return true
end

---This is for testing only
---@param params PlayerEventVRPlayerReady
ListenToPlayerEvent("vr_player_ready", function(params)
    local defaults = require("akimbo.ammo_defaults")
    local ammo = defaults[GetMapName()]
    if ammo then
        Player:SetItems(ammo.energygun, ammo.shotgun, ammo.rapidfire)
    end

    -- Always give the player a pistol for testing
    if GetMapName() ~= "a1_intro_world" and GetMapName() ~= "a1_intro_world_2" then
        if params.type == "spawn" then
            Player:Delay(function()
                SendToConsole("akimbo_give_pistol")
                -- SendToConsole("akimbo_give_smg")
            end, 0.3) -- needs delay for precache to happen
        end
    end

    ---BodyHolsters integration.
    if IsAddonEnabled("body_holsters")
    or IsAddonEnabled("3144612716") -- public workshop
    or IsAddonEnabled("3328458773") -- test workshop
    then
---@diagnostic disable: undefined-global
        if BodyHolsters then
            BodyHolsters:EnableDualWieldMode()
        end
---@diagnostic enable: undefined-global
    end

    ---Allow the player to reload pistols by moving them behind their head
    Player:SetContextThink("HandsFreeReload", function()
        if Player.Items.ammo.energygun > 0 or Convars:GetBool("sv_infinite_clips") then
            if isinstance(CurrentAkimboWeapon, "AkimboPistol") and CurrentAkimboWeapon:IsEquipped() and checkEntityBehindHead(Player.SecondaryHand) then
                if reloadPistol(CurrentAkimboWeapon) then
                    if not Convars:GetBool("sv_infinite_clips") then
                        Player:SetResources(Player.Items.ammo.energygun - 1)
                    end
                    return 0.1
                end
            end

            if Player.CurrentlyEquipped == "hlvr_weapon_energygun" and checkEntityBehindHead(Player:GetWeapon()) then
                if reloadPistol(Player:GetWeapon()) then
                    if not Convars:GetBool("sv_infinite_clips") then
                        Player:SetResources(Player.Items.ammo.energygun - 1)
                    end
                    return 0.1
                end
            end
        end

        return 0.1
    end, 0.5)
end)

---@param params GameEventPlayerPistolClipInserted
ListenToGameEvent("player_pistol_clip_inserted", function (params)
    if params.bullet_count > 0 then
        ---@type EntityHandle[]
        local emptyPistols = {}
        for _, pistol in ipairs(Entities:FindAllByClassname("hlvr_weapon_energygun")) do
            if not pistol:GetFirstChildWithClassname("item_hlvr_clip_energygun") then
                table.insert(emptyPistols, pistol)
            end
        end

        Player:Delay(function()
            for _, pistol in ipairs(emptyPistols) do
                if pistol:GetFirstChildWithClassname("item_hlvr_clip_energygun") then
                    pistol:Attribute_SetIntValue("HasClipWithAmmo", 1)
                    return
                end
            end
        end, 0.1)
    end
end, nil)

---Checks if the pistol has a clip entity attached with ammo inside it.
---This function relies on the special game event listener to update the HasClipWithAmmo attribute.
---@param pistol EntityHandle
function PistolHasClipWithAmmo(pistol)
    return IsValidEntity(pistol:GetFirstChildWithClassname("item_hlvr_clip_energygun"))
        and (pistol:Attribute_GetIntValue("HasClipWithAmmo", 1) == 1)
end