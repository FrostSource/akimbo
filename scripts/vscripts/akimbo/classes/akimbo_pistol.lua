if thisEntity then
    -- Inherit this script if attached to entity
    -- Will also load the script at the same time if needed
    inherit(GetScriptFile())
    return
end

---
---Akimbo Pistol
---
---An akimbo pistol is an `hlvr_weapon_energygun` that can be equipped in the player's secondary hand.
---
---@class AkimboPistol : AkimboWeapon
local base = entity("AkimboPistol", "AkimboWeapon")

---
---Is burst fire enabled?
---
---@type boolean
base.isBurstFireEnabled = false
--Assume burst fire is disabled by default

---
---Returns the `item_hlvr_clip_energygun` entity inside the pistol if it exists.
---
---@return EntityHandle?
function base:GetClip()
    return self:GetChild("item_hlvr_clip_energygun")
end

---
---Checks if the pistol has a clip inserted into it.
---
---@return boolean
function base:HasClip()
    return IsValidEntity(self:GetClip())
end

---
---Ejects the clip (magazine) from the pistol.
---
---@param force? boolean # Eject the clip even if the pistol is not equipped
function base:EjectClip(force)
    local clip = self:GetClip()
    if (self:IsEquipped() or force) and clip then
        clip:SetModel("models/weapons/vr_alyxgun/vr_alyxgun_clip.vmdl")
        self:SetGraphParameterBool("b_ReloadPressedAkimbo", true)
    end
end

---
---Inserts a clip (magazine) entity into the pistol.
---
---@param clip EntityHandle # The `item_hlvr_clip_energygun` entity to insert
function base:InsertClip(clip)
    UpdateWeaponModelForHand(clip, not Convars:GetBool("hlvr_left_hand_primary"))
    self:EntFire("HandInteractionSucceeded", "0", 0, Player, clip)
end

---
---Checks if the pistol has the burst fire upgrade.
---
---@return boolean
function base:HasBurstFireUpgrade()
    return IsValidEntity(self:GetChild("hlvr_weapon_upgrade_burst_fire"))
end

---
---Checks if the pistol is in burst fire mode.
---
---@return boolean
function base:IsBurstFireEnabled()
    return self.isBurstFireEnabled
end

---
---Toggles the burst fire mode of the pistol.
---
---Unfortunately toggling on the main weapon will also toggle this weapon.
---AnimGraph will need to be edited to override this behavior.
---
function base:ToggleBurstFire()
    if self.isEquipped and self:HasBurstFireUpgrade() then
        self:SetGraphParameterBool("b_SelectorPressedAkimbo", true)
        self.isBurstFireEnabled = not self.isBurstFireEnabled
    end
end

---
---Checks if the slide of the pistol is locked back due to being out of ammo.
---
---@return boolean
function base:IsSlideLocked()
    local slide = self:GetFirstChildWithClassname("hlvr_slide_interactable")
    if slide then
        return slide:GetCycle() >= 0.8
    end

    return false
end

---
---Releases the slide of the pistol and chambers a bullet if a magazine is inserted.
---
---@param force? boolean # If true, release slide even if there is no magazine.
function base:ReleaseSlide(force)
    if self:IsSlideLocked() then
        if force or (self:IsEquipped() and PistolHasClipWithAmmo(self)) then
            self:SetGraphParameterBool("b_ReleaseSlideAkimbo", true)
            self:Attribute_SetIntValue("HasClipWithAmmo", 0)
        end
    end
end

---
---Shoots the akimbo pistol.
---
function base:Shoot()
    if Time() > self.__readyShootTime then
        if self:IsBurstFireEnabled() then
            -- Testing seems to indicate around 0.4s
            -- Unsure of real calculation but this gives 0.385s
            self.__readyShootTime = Time() + Convars:GetFloat("vr_energygun_rof") + Convars:GetFloat("vr_energygun_burstfire_rof") * 3
        else
            self.__readyShootTime = Time() + Convars:GetFloat("vr_energygun_rof")
        end

        self.__lastShootTime = Time()

        self:EntFire("ForceFire")
    end
end

---
---Checks if this akimbo pistol has a specific weapon upgrade.
---
---@param upgrade PlayerPistolUpgrades
---@return boolean
function base:HasUpgrade(upgrade)
    if vlua.find(Player:GetPistolUpgrades(self), upgrade) then
        return true
    end
    return false
end

function base:UpdateInput()
    -- Call super function to inherit inputs
    AkimboWeapon.UpdateInput(self)

    ---Eject
    Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_ARM_GRENADE, 1, function (context, params)
        if self:IsEquipped() then
            self:EjectClip()
        end
    end, self)

    ---Release Slide
    Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_TOGGLE_MENU, 1, function (context, params)
        if self:IsEquipped() then
            self:ReleaseSlide()
        end
    end, self)

    ---Burst Fire
    Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_TOGGLE_MENU, 2, function (context, params)
        if self:IsEquipped() then
            self:ToggleBurstFire()
        end
    end, self)
end

---Main entity think function. Think state is saved between loads
function base:Think()

    local trigger = Player:GetAnalogActionPositionForHand(Player.SecondaryHand.Literal, 1)
    self:SetGraphParameterFloat("f_Trigger", trigger.x)

    local item = Player.PrimaryHand.ItemHeld
    if item and item:GetClassname() == "item_hlvr_clip_energygun" then
        if VectorDistance(
            Player.PrimaryHand:GetOrigin(),
            self:GetAttachmentNameOrigin("vr_interact_clip")
        ) < Convars:GetFloat("vr_energygun_clip_grab_dist") then
            self:InsertClip(item)
        end
    end

    return 0
end

--Used for classes not attached directly to entities
return base