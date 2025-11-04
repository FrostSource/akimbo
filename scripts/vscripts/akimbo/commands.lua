local PlayerData = require "alyxlib.player.data"

---@return AkimboWeapon
function CreateAkimboWeapon(baseName, entityClass, scriptPath)
    local name = baseName
    if Entities:FindByName(nil, name) then
        name = DoUniqueString(name)
    end
    return SpawnEntityFromTableSynchronous(entityClass, {
        targetname = name,
	    set_spawn_ammo = "10",
        vscripts = scriptPath
    })--[[@as AkimboWeapon]]
end

---@return AkimboPistol
function CreateAkimboPistol()
    return CreateAkimboWeapon("akimbo_pistol", "hlvr_weapon_energygun", "akimbo/classes/akimbo_pistol")--[[@as AkimboPistol]]
end

---@return AkimboRapidfire
function CreateAkimboRapidfire()
    return CreateAkimboWeapon("akimbo_smg", "hlvr_weapon_rapidfire", "akimbo/classes/akimbo_rapidfire")--[[@as AkimboRapidfire]]
end

local AkimboWeaponConfigs = {
    pistol = {
        baseName = "akimbo_pistol",
        entityClass = "hlvr_weapon_energygun",
        scriptClass = "AkimboPistol",
        scriptPath = "akimbo/classes/akimbo_pistol",
        itemField = "energygun",
        cmdUpgrade = "akimbo_pistol_grant_upgrade",
        cmdUpgradeBase = "hlvr_energygun_grant_upgrade",
        upgradeGetter = CBasePlayer.GetPistolUpgrades,
        upgradeOptions = {
            pistol_upgrade_laser_sight =   {name="Laser Sight",   id="0"},
            pistol_upgrade_reflex_sight =  {name="Reflex Sight",  id="1"},
            pistol_upgrade_bullet_hopper = {name="Bullet Hopper", id="2"},
            pistol_upgrade_burst_fire =    {name="Burst Fire",    id="3"},
        }
    },

    smg = {
        baseName = "akimbo_smg",
        entityClass = "hlvr_weapon_rapidfire",
        scriptClass = "AkimboRapidfire",
        scriptPath = "akimbo/classes/akimbo_rapidfire",
        itemField = "rapidfire",
        cmdUpgrade = "akimbo_smg_grant_upgrade",
        cmdUpgradeBase = "hlvr_rapidfire_grant_upgrade",
        upgradeGetter = CBasePlayer.GetRapidfireUpgrades,
        upgradeOptions = {
            rapidfire_upgrade_reflex_sight      = {name="Reflex Sight",       id="4"},
            rapidfire_upgrade_laser_sight       = {name="Laser Sight",        id="5"},
            rapidfire_upgrade_extended_magazine = {name="Extended Magazine",  id="6"},
        }
    },
}

---@param weaponType "pistol" | "smg" | "shotgun"
---@param upgrades PlayerWeaponUpgrades[]
---@param onUpgraded fun(newWeapon: AkimboWeapon)?
function CreateAkimboWeaponWithUpgrades(weaponType, upgrades, onUpgraded)
    local cfg = AkimboWeaponConfigs[weaponType]
    if not cfg then error("Unknown weapon type: " .. tostring(weaponType)) end

    local prevEquip = Player.PreviouslyEquipped
    local currentWeapon = Player.Items.weapons[cfg.itemField]
    if currentWeapon then
        PlayerData.PauseWeaponStateSync()
        Player.PrimaryHand:RemoveHandAttachmentByHandle(currentWeapon)
    end

    local newWeapon = CreateAkimboWeapon(cfg.baseName, cfg.entityClass, cfg.scriptPath)
    newWeapon:DisableAttachmentLogic()
    Player.PrimaryHand:AddHandAttachment(newWeapon)
    PlayerData.ResumeWeaponStateSync()

    local upgradeCount = 0
    for _, upgrade in ipairs(upgrades) do
        if cfg.upgradeOptions[upgrade] then upgradeCount = upgradeCount + 1 end
    end

    local upgradesHeard = 0
    local eventListener
    eventListener = ListenToGameEvent("player_upgraded_weapon", function()
        upgradesHeard = upgradesHeard + 1
        if upgradesHeard < upgradeCount then return end

        if onUpgraded then
            StopListeningToGameEvent(eventListener)
            PlayerData.PauseWeaponStateSync()
            Player.PrimaryHand:RemoveHandAttachmentByHandle(newWeapon)
            Player.PrimaryHand:AddHandAttachment(currentWeapon)
            PlayerData.ResumeWeaponStateSync()
            Player.PreviouslyEquipped = prevEquip
            Player.Items.weapons[cfg.itemField] = currentWeapon
            newWeapon:EnableAttachmentLogic()
            onUpgraded(newWeapon)
        end
    end, nil)

    for _, upgrade in ipairs(upgrades) do
        if cfg.upgradeOptions[upgrade] then
            SendToConsole(cfg.cmdUpgradeBase .. " " .. cfg.upgradeOptions[upgrade].id)
        end
    end

    return newWeapon
end

for weaponType, cfg in pairs(AkimboWeaponConfigs) do
    Convars:RegisterCommand(cfg.cmdUpgrade, function(_, upgrade)
        if upgrade == nil then
            Msg("usage " .. cfg.cmdUpgrade .. " X\n")
            for id, opt in pairs(cfg.upgradeOptions) do
                Msg(id .. " : " .. opt.name .. "\n")
            end
            return
        end

        local upgradeKey = TableFindKey(cfg.upgradeOptions, function(opt) return opt.id == upgrade end)
        local upgradeOption = cfg.upgradeOptions[upgradeKey]
        if not upgradeOption then
            Warning("Invalid upgrade id\n")
            Msg("usage " .. cfg.cmdUpgrade .. " X\n")
            for id, opt in pairs(cfg.upgradeOptions) do
                Msg(id .. " : " .. opt.name .. "\n")
            end
            return
        end

        if not CurrentAkimboWeapon or not isinstance(CurrentAkimboWeapon, cfg.scriptClass) then
            Msg("No akimbo " .. weaponType .. " equipped, use akimbo_give_" .. weaponType .. " first\n")
            return
        end

        local currentAkimbo = CurrentAkimboWeapon
        local currentUpgrades = cfg.upgradeGetter(Player, currentAkimbo)
        if vlua.find(currentUpgrades, upgradeKey) then
            Msg("Akimbo " .. weaponType .. " already has " .. upgradeOption.name:lower() .. "\n")
            return
        end

        table.insert(currentUpgrades, upgradeKey)

        CreateAkimboWeaponWithUpgrades(weaponType, currentUpgrades, function(newAkimboWeapon)
            if currentAkimbo and currentAkimbo:IsEquipped() then
                currentAkimbo:Unequip()
                currentAkimbo:Kill()
            end

                newAkimboWeapon:Equip()
        end)
    end, "Grants an akimbo " .. weaponType .. " upgrade", FCVAR_NONE)

    Convars:RegisterCommand("akimbo_give_" .. weaponType, function()
        if CurrentAkimboWeapon and isinstance(CurrentAkimboWeapon, cfg.scriptClass) then
            Msg("Akimbo " .. weaponType .. " already exists\n")
            return
        end

        local newAkimboWeapon = CreateAkimboWeapon(cfg.baseName, cfg.entityClass, cfg.scriptPath)

        if CurrentAkimboWeapon and CurrentAkimboWeapon:IsEquipped() then
            print("Unequipping other akimbo pistol!", entstr(CurrentAkimboWeapon))
            PlayerData.PauseWeaponStateSync()
            CurrentAkimboWeapon:Unequip()
            CurrentAkimboWeapon:Kill()
            PlayerData.ResumeWeaponStateSync()
        end

        devprint("Equipping akimbo " .. weaponType)
        newAkimboWeapon:Equip()
    end, "Gives an akimbo " .. weaponType .. " to the player", FCVAR_NONE)
end

Convars:RegisterCommand("akimbo_return_to_hand", function (cmd)
    local weapon = CurrentAkimboWeapon

    if not weapon then
        for _, pistol in ipairs(Entities:FindAllByClassname("hlvr_weapon_energygun")) do
            if isinstance(pistol, "AkimboWeapon") then
                ---@cast pistol AkimboWeapon
                weapon = pistol
                break
            end
        end
    end

    if not weapon then
        warn("No akimbo weapon found\n")
        return
    end

    weapon:Unequip()
    weapon:Equip()
end, "Returns the akimbo weapon to the player's hand", FCVAR_NONE)
