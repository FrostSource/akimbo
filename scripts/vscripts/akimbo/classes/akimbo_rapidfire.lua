if thisEntity then
    -- Inherit this script if attached to entity
    -- Will also load the script at the same time if needed
    inherit("AkimboRapidfire")
    return
end

---
---Akimbo Rapidfire
---
---An akimbo rapidfire/smg is an `hlvr_weapon_rapidfire` that can be equipped in the player's secondary hand.
---
---@class AkimboRapidfire : AkimboWeapon
local base = entity("AkimboRapidfire", "AkimboWeapon")

GlobalPrecache:Add("entity", "hlvr_weapon_rapidfire", {})
-- GlobalPrecache("model_folder", "models/weapons/vr_ipistol")
-- GlobalPrecache("model", "models/weapons/vr_ipistol/vr_ipistol.vmdl")
-- GlobalPrecache("model", "models/weapons/vr_ipistol/vr_ipistol_lhand.vmdl")

-- Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_ARM_GRENADE, nil, function ()
--             print("PRESS")
--         end, "RapidfireShooting2")
-- Input:ListenToButton("release", InputHandSecondary, DIGITAL_INPUT_ARM_GRENADE, nil, function ()
--             print("RELEASE")
--         end, "RapidfireShooting2")
-- -- Input:ListenToButton("release", InputHandSecondary, DIGITAL_INPUT_FIRE, nil, function ()
-- --             print("RELEASE FIRE")
-- --         end, "RapidfireShooting2")

function base:OnReady(readyType)
    AkimboWeapon.OnReady(self, readyType)

    self:Delay(function()
        self:SetGraphParameterBool("b_AkimboDisableFriendly", true)
    end, 0.1)
end

---
---Shoots the akimbo pistol.
---
function base:Shoot()
    print("SHOOT")
    if Time() > self.__readyShootTime then
        print("Shooting akimbo smg")
        self:SetGraphParameterBool("b_ShootingAkimbo", true)
        Input:ListenToButton("release", InputHandSecondary, DIGITAL_INPUT_MENU_INTERACT, nil, function ()
            print("Stopped Shooting akimbo smg")
            self:SetGraphParameterBool("b_ShootingAkimbo", false)
            self:SetContextThink("RapidfireShooting", nil, 0)
            Input:StopListeningByContext(self:GetEntityIndex() .. "RapidfireShooting")
        end, self:GetEntityIndex() .. "RapidfireShooting")

        self:SetContextThink("RapidfireShooting", function()
            if self:IsEquipped() then
                self:EntFire("ForceFire")
                self.__lastShootTime = Time()
            end
            return Convars:GetFloat("vr_rapidfire_rof")
        end, 0)
    end
end

---
---Checks if this akimbo pistol has a specific weapon upgrade.
---
---@param upgrade PlayerPistolUpgrades
---@return boolean
function base:HasUpgrade(upgrade)
    if vlua.find(Player:GetRapidfireUpgrades(self), upgrade) then
        return true
    end
    return false
end

-- function base:UpdateInput()
--     -- Call super function to inherit inputs
--     AkimboWeapon.UpdateInput(self)

--     ---Eject
--     Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_ARM_GRENADE, 1, function (context, params)
--         if self:IsEquipped() then
--             self:EjectClip()
--         end
--     end, self)

--     ---Release Slide
--     Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_TOGGLE_MENU, 1, function (context, params)
--         if self:IsEquipped() then
--             self:ReleaseSlide()
--         end
--     end, self)

--     ---Burst Fire
--     Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_TOGGLE_MENU, 2, function (context, params)
--         if self:IsEquipped() then
--             self:ToggleBurstFire()
--         end
--     end, self)
-- end

-- ---Main entity think function. Think state is saved between loads
-- function base:Think()

--     local trigger = Player:GetAnalogActionPositionForHand(Player.SecondaryHand.Literal, 1)
--     self:SetGraphParameterFloat("f_Trigger", trigger.x)

--     local item = Player.PrimaryHand.ItemHeld
--     if item and item:GetClassname() == "item_hlvr_clip_energygun" then
--         if VectorDistance(
--             Player.PrimaryHand:GetOrigin(),
--             self:GetAttachmentNameOrigin("vr_interact_clip")
--         ) < Convars:GetFloat("vr_energygun_clip_grab_dist") then
--             self:InsertClip(item)
--         end
--     end

--     return 0
-- end

--Used for classes not attached directly to entities
return base