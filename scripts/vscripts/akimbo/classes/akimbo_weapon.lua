if thisEntity then
    -- Inherit this script if attached to entity
    -- Will also load the script at the same time if needed
    inherit(GetScriptFile())
    return
end

local PlayerData = require "alyxlib.player.data"

---
---Updates the entity's model to use left or right hand model version.
---
---Assumes left hand models are named identically with "_lhand" at the end.
---
---@param entity EntityHandle
---@param useLeftHand boolean
function UpdateWeaponModelForHand(entity, useLeftHand)
    local modifier = "_lhand"
    local ext = ".vmdl"

    local model = entity:GetModelName()
    if model == "" then return end
    if model == "models/weapons/vr_alyxgun/vr_alyxgun_bullet.vmdl" then return end

    if useLeftHand then
        if not model:match(modifier .. "%.vmdl$") then
            local replaced = model:gsub("%.vmdl$", modifier .. ext)
            entity:SetModel(replaced)
        end
    else
        local replaced = model:gsub(modifier .. "%.vmdl$", ext)
        entity:SetModel(replaced)
    end
end

---
---The currently equipped `AkimboWeapon` in the secondary hand.
---
---@type AkimboWeapon?
CurrentAkimboWeapon = nil

---@class AkimboWeapon : EntityClass
local base = entity("AkimboWeapon")
AkimboWeapon = base

---
---Is the akimbo weapon currently equipped?
---
---@type boolean
base.isEquipped = false

---
---The last server time the akimbo pistol was shot.
---
---@protected
base.__lastShootTime = 0

---
---The next server time the akimbo pistol can be shot.
---
---@protected
base.__readyShootTime = 0

---@param readyType OnReadyType
function base:OnReady(readyType)
    if readyType ~= READY_NORMAL then
        if self:IsEquipped() then
            self:Unequip()
            self:Equip()
        end
    end
end

function base:HandleAttachToHand()
    self:UpdateModelsForHand(not Convars:GetBool("hlvr_left_hand_primary"))

    self.isEquipped = true

    if self.Think then
        self:ResumeThink()
    end

    self:SetGraphParameterBool("b_IsWorldItem", true)
    self:Delay(function()
        self:SetGraphParameterBool("b_IsWorldItem", false)
    end, 0.1)

    self:UpdateInput()

    DoEntFire("akimbo_playerproxy", "SetCanAttackDisable", "", 0, self, self)
end

---
---Attaches the akimbo weapon to the player's secondary hand.
---
function base:Equip()

    if self:GetMoveParent() ~= nil then
        self:SetParent(nil, nil)
    end

    -- Move weapon to secondary hand for weapon_switch accuracy
    local offset = PlayerData.GetDefaultWeaponOffset(self:GetClassname(), Player.SecondaryHand)
    self:SetOrigin(Player.SecondaryHand:TransformPointEntityToWorld(offset))

    Player.SecondaryHand:AddHandAttachment(self)

    self:SetRenderingEnabled(true)

    CurrentAkimboWeapon = self
    self.isEquipped = true
end

---
---Triggers logic required when detaching the akimbo pistol from the player's hand.
---Does not actually remove the akimbo pistol from the player's hand.
---
function base:HandleDetachFromHand()
    self.isEquipped = false
    self:PauseThink()

    Input:StopListeningByContext(self)

    if self:IsInCraftingStation() then
        self:TurnIntoWorldItem(true)
    end

    DoEntFire("akimbo_playerproxy", "SetCanAttackEnable", "", 0, self, self)
end

---
---Unequips the akimbo weapon from the player's secondary hand.
---
---@param dontMove? boolean # If `true`, the akimbo weapon will not be moved far away
function base:Unequip(dontMove)
    if not self.isEquipped then
        return
    end

    Player.SecondaryHand:RemoveHandAttachmentByHandle(self)

    Input:StopListeningByContext(self)

    self.isEquipped = false
    self:SetRenderingEnabled(false)

    if not dontMove then
        self:SetOrigin(Vector(-10000, -10000, -10000)) -- where is a good place?
    end
end

---
---Turns the akimbo weapon into a world item by parenting it to a proxy physics object.
---
---For situations where the weapon must not have its parent changed, set `fixed` to true.
---
---Does not actually remove the akimbo weapon from the player's hand.
---
---@param fixed? boolean # If true, the proxy physics object will be parented to the weapon.
function base:TurnIntoWorldItem(fixed)
    local proxy = SpawnEntityFromTableSynchronous("prop_animinteractable", {
        targetname = self:GetName() .. "_physics_proxy",
        origin = self:GetOrigin(),
        angles = self:GetAngles(),
        model = self:GetModelName(),

	    InteractionBoneName = "weapon_bone",
        BehaveAsPropPhysics = (not fixed),
        AddToSpatialPartition = "0"
    })

    proxy:SetRenderingEnabled(false)
    local output = vlua.select(fixed, "OnInteractStart", "OnPlayerUse")
    proxy:RedirectOutputFunc(output, function()
        -- print("Player picked up akimbo weapon proxy", output)
        self:SetParent(nil, nil)
        proxy:Kill()
        self:Equip()
    end)

    if fixed then
        proxy:FollowEntity(self, false)
    else
        self:FollowEntity(proxy, false)
    end
end

---
---Checks if the akimbo weapon is currently equipped.
---
---@return boolean
function base:IsEquipped()
    return self.isEquipped
end

---
---Shoots the akimbo weapon.
---
---This should be overridden by child classes.
---
function base:Shoot()
    if Time() > self.__readyShootTime then
        self.__lastShootTime = Time()

        self:EntFire("ForceFire")
    end
end

---
---Check if this akimbo weapon has a specific weapon upgrade.
---
---Ideally this should be overridden by child classes.
---
---@param upgrade PlayerPistolUpgrades|PlayerRapidfireUpgrades|PlayerShotgunUpgrades
---@return boolean
function base:HasUpgrade(upgrade)
    if vlua.find(self:GetPistolUpgrades(self), upgrade) then
        return true
    elseif vlua.find(self:GetRapidfireUpgrades(self), upgrade) then
        return true
    elseif vlua.find(self:GetShotgunUpgrades(self), upgrade) then
        return true
    end
    return false
end

---
---Check if this akimbo weapon is inside a crafting station cradle.
---
---@return boolean
function base:IsInCraftingStation()
    return self:GetMoveParent() and (self:GetMoveParent():GetClassname() == "prop_hlvr_crafting_station_console")
end

---
---Updates the models for the akimbo weapon based on the player's secondary hand.
---
---@param useLeftHand? boolean # If true, the left hand models will be used. If omitted, the value will be inferred automatically.
function base:UpdateModelsForHand(useLeftHand)
    if useLeftHand == nil then
        useLeftHand = not Convars:GetBool("hlvr_left_hand_primary")
    end

    UpdateWeaponModelForHand(self, useLeftHand)

    if self:HasUpgrade("pistol_upgrade_laser_sight") then
        self:SetBodygroupByName("trigger_guard", 0)
    else
        self:SetBodygroupByName("trigger_guard", 1)
    end

    for child in self:IterateChildren() do
        if child.GetModelName and child.SetModel then
            UpdateWeaponModelForHand(child, useLeftHand)
        end

        if child:GetClassname() == "item_hlvr_clip_energygun" then
            if useLeftHand then
                child:SetLocalOrigin(Vector(0.000031, -2.804016, -1.806580))
                child:SetLocalAngles(-70.998123, -89.996536, 179.997528)
            else
                child:SetLocalOrigin(Vector(0.000031, 2.803989, -1.806580))
                child:SetLocalAngles(-70.998108, 89.996521, -179.997513)
            end
        end
    end
end

---Called automatically on spawn
---@param spawnkeys CScriptKeyValues
function base:OnSpawn(spawnkeys)
    if not Entities:FindByName(nil, "akimbo_playerproxy") then
        SpawnEntityFromTableSynchronous("logic_playerproxy", {
            targetname = "akimbo_playerproxy"
        })
    end

    self:EnableAttachmentLogic()
end

---
---Enables logic for the akimbo weapon that fires when attached to or detached from a hand.
---
function base:EnableAttachmentLogic()
    self:DisableAttachmentLogic()
    self:RedirectOutput("OnAttachedToHand", "HandleAttachToHand", self)
    self:RedirectOutput("OnDetachedFromHand", "HandleDetachFromHand", self)
end

---
---Disables logic for the akimbo weapon that fires when attached to or detached from a hand.
---
function base:DisableAttachmentLogic()
    self:DisconnectRedirectedOutput("OnAttachedToHand", "HandleAttachToHand", self)
    self:DisconnectRedirectedOutput("OnDetachedFromHand", "HandleDetachFromHand", self)
end

---
---Updates the akimbo weapon's input.
---
---This should be overridden by child classes.
---
---If the shooting logic does not need to be changed,
---use the following line at the top of your overridden function:
---
---    AkimboWeapon.UpdateInput(self)
---
function base:UpdateInput()
    Input:StopListeningByContext(self)

    ---Shoot
    Input:ListenToButton("press", InputHandSecondary, DIGITAL_INPUT_MENU_INTERACT, 1, function (context, params)
        if self:IsEquipped() then
            self:Shoot()
        end
    end, self)

end

--Used for classes not attached directly to entities
return base