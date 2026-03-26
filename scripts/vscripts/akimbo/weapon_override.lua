

local ManualPlayerWeaponInteractionContext = "ManualPlayerWeaponInteractionContext"

local playerReadyShootTime = 0
local playerLastShootTime = 0

---@type EntityHandle
local currentWeaponListener = nil

---Sets if the player can shoot their base weapon.
---@param canAttack boolean
local function setPlayerCanAttack(canAttack)
    if not Entities:FindByName(nil, "akimbo_playerproxy") then
        SpawnEntityFromTableSynchronous("logic_playerproxy", {
            targetname = "akimbo_playerproxy"
        })
    end

    DoEntFire("akimbo_playerproxy", canAttack and "SetCanAttackEnable" or "SetCanAttackDisable", "", 0, nil, nil)
end

---@param action DigitalInputAction
---@param weapon EntityHandle
---@param callback function
local function ListenToGunButton(action, weapon, callback)
    Input:ListenToButton("press", InputHandPrimary, action, nil, function ()
        -- Weapon unequipped check
        if Player:GetWeapon() ~= weapon then
            return
        end

        callback()
    end, ManualPlayerWeaponInteractionContext)
end

---@param gun EntityHandle
local function listenToPistolShoot(gun)
    if IsValidEntity(gun) and gun:GetClassname() == "hlvr_weapon_energygun" and not isinstance(gun, "AkimboPistol") then
        -- print("Setting new gun to listen to")
        if IsValidEntity(currentWeaponListener) then
            -- print("Unregistering old gun")
            currentWeaponListener:UnregisterAnimTagListener()
        end

        currentWeaponListener = gun

        currentWeaponListener:RegisterAnimTagListener(function (tagName, status)
            -- print(tagName, status)
            if tagName == "IsShooting" and status == 1 then
                playerReadyShootTime = Time() + Convars:GetFloat("vr_energygun_rof")
            elseif tagName == "ShootingBurst" and status == 1 then
                playerReadyShootTime = Time() + Convars:GetFloat("vr_energygun_rof") + Convars:GetFloat("vr_energygun_burstfire_rof") * 3
            end
        end)

    end
end

---@type EntityHandle?
local shotgunWithQuickfireUpgrade = nil

ListenToGameEvent("player_shotgun_upgrade_quickfire", function (params)
    Player:Delay(function()
        local shotgun = Player:GetWeapon()
        if shotgun and shotgun:GetClassname() == "hlvr_weapon_shotgun" then
            shotgunWithQuickfireUpgrade = shotgun
        end
    end)
end, nil)

local function overrideEnergygun(weapon, dontListenToFire)
    if not dontListenToFire then
        listenToPistolShoot(weapon)

        ---Manual handling of shooting
        ListenToGunButton(DIGITAL_INPUT_FIRE, weapon, function ()
            if Time() <= playerReadyShootTime then return end

            if not weapon then
                warn("No weapon found for player")
                return
            end

            if weapon:GetClassname() == "hlvr_weapon_energygun" then
                weapon:EntFire("ForceFire")
                playerLastShootTime = Time()
            end
        end)
    end

    ---AnimGraph is modified to override clip ejection behavior.
    ---Manual handling of clip ejection is required at all times.
    ListenToGunButton(DIGITAL_INPUT_EJECT_MAGAZINE, weapon, function ()

        -- print("Pressing eject")
        -- print(weapon, weapon ~= nil and weapon:GetClassname() or "none")
        if weapon and weapon:GetClassname() == "hlvr_weapon_energygun" then
            weapon:SetGraphParameterBool('b_ReloadPressedAkimbo', true)
        end
    end)

    ---AnimGraph is modified to override burst fire behavior.
    ---Manual handling of burst fire is required at all times.
    ListenToGunButton(DIGITAL_INPUT_TOGGLE_BURST_FIRE, weapon, function ()

        -- print("Pressing toggle burst fire")
        if weapon and weapon:GetClassname() == "hlvr_weapon_energygun" and Player:HasWeaponUpgrade("pistol_upgrade_burst_fire") then
            weapon:SetGraphParameterBool('b_SelectorPressedAkimbo', true)
        end
    end)

    ---AnimGraph is modified to override slide release behavior.
    ---Manual handling of slide release is required at all times.
    ListenToGunButton(DIGITAL_INPUT_SLIDE_RELEASE, weapon, function ()

        -- print("Pressing release slide")
        if weapon and weapon:GetClassname() == "hlvr_weapon_energygun" then
            if PistolHasClipWithAmmo(weapon) then
                local slide = weapon:GetFirstChildWithClassname("hlvr_slide_interactable")
                if slide then
                    if slide:GetCycle() >= 0.8 then
                        weapon:SetGraphParameterBool('b_ReleaseSlideAkimbo', true)
                        weapon:Attribute_SetIntValue("HasClipWithAmmo", 0)
                    end
                end
            end
        end
    end)
end

local function overrideShotgun(weapon, dontListenToFire)
    if not dontListenToFire then
        ---Manual handling of shooting
        ListenToGunButton(DIGITAL_INPUT_FIRE, weapon, function ()
            if Time() <= playerReadyShootTime then return end

            if not weapon then
                warn("No weapon found for player")
                return
            end

            if weapon:GetClassname() == "hlvr_weapon_shotgun" then
                local delta = Time() - playerLastShootTime

                if delta >= Convars:GetFloat("vr_shotgun_rof") and shotgunWithQuickfireUpgrade == weapon then
                    playerReadyShootTime = Time() + Convars:GetFloat("vr_shotgun_quickfire_rof")
                else
                    playerReadyShootTime = Time() + Convars:GetFloat("vr_shotgun_rof")
                end

                weapon:EntFire("ForceFire")

                playerLastShootTime = Time()
            end
        end)
    end
end

local function overrideRapidfire(weapon, dontListenToFire)
    if not dontListenToFire then
        ---Manual handling of shooting
        ListenToGunButton(DIGITAL_INPUT_FIRE, weapon, function ()
            if Time() <= playerReadyShootTime then return end

            if not weapon then
                warn("No weapon found for player")
                return
            end

            if weapon:GetClassname() == "hlvr_weapon_rapidfire" then
                weapon:SetGraphParameterBool("b_ShootingAkimbo", true)
                Input:ListenToButton("release", InputHandPrimary, DIGITAL_INPUT_FIRE, 1, function ()
                    weapon:SetGraphParameterBool("b_ShootingAkimbo", false)
                    weapon:SetContextThink("RapidfireShooting", nil, 0)
                    Input:StopListeningByContext("RapidfireShooting")
                end, "RapidfireShooting")

                weapon:SetContextThink("RapidfireShooting", function()
                    local wpn = Player:GetWeapon()
                    if wpn and wpn:GetClassname() == "hlvr_weapon_rapidfire" then
                        wpn:EntFire("ForceFire")
                        playerLastShootTime = Time()
                    end
                    return Convars:GetFloat("vr_rapidfire_rof")
                end, 0)
            end
        end)
    end
end

---
---Overrides a player weapon to stop it from affecting the akimbo weapon.
---
---@param weapon EntityHandle|nil # The weapon to override, or nil to disable
local function overrideWeapon(weapon, dontListenToFire)
    Input:StopListeningByContext(ManualPlayerWeaponInteractionContext)

    -- print("override weapon check", weapon)
    if IsValidEntity(currentWeaponListener) then
        currentWeaponListener:UnregisterAnimTagListener()
    end

    if not weapon then
        return
    end

    if CurrentAkimboWeapon and CurrentAkimboWeapon:IsEquipped() then
        -- print("Disabling friendly pose for ", entstr(weapon))
        weapon:SetGraphParameterBool("b_AkimboDisableFriendly", true)
    end

    if weapon:GetClassname() == "hlvr_weapon_energygun" then
        overrideEnergygun(weapon, dontListenToFire)
    elseif weapon:GetClassname() == "hlvr_weapon_shotgun" then
        overrideShotgun(weapon, dontListenToFire)
    elseif weapon:GetClassname() == "hlvr_weapon_rapidfire" then
        overrideRapidfire(weapon, dontListenToFire)
    end
end

return {
    overrideWeapon = overrideWeapon,
    setPlayerCanAttack = setPlayerCanAttack,
}