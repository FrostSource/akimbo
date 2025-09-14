local PlayerData = require "alyxlib.player.data"

---@return AkimboWeapon
function CreateAkimboPistol()
    local name = "akimbo_pistol"
    if Entities:FindByName(nil, name) then
        name = DoUniqueString(name)
    end
    return SpawnEntityFromTableSynchronous("hlvr_weapon_energygun", {
        targetname = name,
	    set_spawn_ammo = "10",
        vscripts = "akimbo/classes/akimbo_pistol"
    })--[[@as AkimboWeapon]]
end

function CreateAkimboPistolWithUpgrades(laser, reflex, hopper, burstfire, onUpgraded)
    local prevEquip = Player.PreviouslyEquipped
    local currentPistol = Player.Items.weapons.energygun
    if currentPistol then
        PlayerData.PauseWeaponStateSync()
        Player.PrimaryHand:RemoveHandAttachmentByHandle(currentPistol)
    end

    local newPistol = CreateAkimboPistol()
    newPistol:DisableAttachmentLogic()

    Player.PrimaryHand:AddHandAttachment(newPistol)
    PlayerData.ResumeWeaponStateSync()

    local upgradeCount =
        (laser     and 1 or 0) +
        (reflex    and 1 or 0) +
        (hopper    and 1 or 0) +
        (burstfire and 1 or 0)

    local upgradesHeard = 0

    local eventListener
    eventListener = ListenToGameEvent("player_upgraded_weapon", function (params)
        -- print("Upgrade!", upgradesHeard, "->", upgradesHeard+1, upgradeCount)
        upgradesHeard = upgradesHeard + 1

        if upgradesHeard < upgradeCount then return end

        if onUpgraded then
            print("Upgrade finished")
            StopListeningToGameEvent(eventListener)

            PlayerData.PauseWeaponStateSync()
            Player.PrimaryHand:RemoveHandAttachmentByHandle(newPistol)
            Player.PrimaryHand:AddHandAttachment(currentPistol)
            PlayerData.ResumeWeaponStateSync()

            Player.PreviouslyEquipped = prevEquip
            Player.Items.weapons.energygun = currentPistol
            newPistol:EnableAttachmentLogic()

            onUpgraded(newPistol)
        end
    end, nil)

    if laser then SendToConsole("hlvr_energygun_grant_upgrade 0") end
    if reflex then SendToConsole("hlvr_energygun_grant_upgrade 1") end
    if hopper then SendToConsole("hlvr_energygun_grant_upgrade 2") end
    if burstfire then SendToConsole("hlvr_energygun_grant_upgrade 3") end

    return newPistol
end

Convars:RegisterCommand("akimbo_pistol_grant_upgrade", function (cmd, upgrade)
    if upgrade == nil then
        Msg("usage akimbo_pistol_grant_upgrade X\n0 : Laser Sight\n1 : Reflex Sight\n2 : Bullet Hopper\n3 : Burst Fire\n")
        return
    end

    if not CurrentAkimboWeapon then
        Msg("No akimbo pistol equipped, use akimbo_give_pistol first\n")
        return
    end

    local currentAkimboPistol = CurrentAkimboWeapon
    local currentUpgrades = {}
    if currentAkimboPistol then
        currentUpgrades = Player:GetPistolUpgrades(currentAkimboPistol)

        if upgrade == "0" and vlua.find(currentUpgrades, "pistol_upgrade_laser_sight") then Msg("Akimbo pistol already has laser sight\n") return end
        if upgrade == "1" and vlua.find(currentUpgrades, "pistol_upgrade_reflex_sight") then Msg("Akimbo pistol already has reflex sight\n") return end
        if upgrade == "2" and vlua.find(currentUpgrades, "pistol_upgrade_bullet_hopper") then Msg("Akimbo pistol already has bullet hopper\n") return end
        if upgrade == "3" and vlua.find(currentUpgrades, "pistol_upgrade_burst_fire") then Msg("Akimbo pistol already has burst fire\n") return end
    end

    if upgrade == "0" then table.insert(currentUpgrades, "pistol_upgrade_laser_sight")
    elseif upgrade == "1" then table.insert(currentUpgrades, "pistol_upgrade_reflex_sight")
    elseif upgrade == "2" then table.insert(currentUpgrades, "pistol_upgrade_bullet_hopper")
    elseif upgrade == "3" then table.insert(currentUpgrades, "pistol_upgrade_burst_fire")
    else
        Msg("usage hlvr_energygun_grant_upgrade X\n0 : Laser Sight\n1 : Reflex Sight\n2 : Bullet Hopper\n3 : Burst Fire\n")
        return
    end

    CreateAkimboPistolWithUpgrades(
        vlua.find(currentUpgrades, "pistol_upgrade_laser_sight"),
        vlua.find(currentUpgrades, "pistol_upgrade_reflex_sight"),
        vlua.find(currentUpgrades, "pistol_upgrade_bullet_hopper"),
        vlua.find(currentUpgrades, "pistol_upgrade_burst_fire"),

        function(newPistol)
            if currentAkimboPistol and currentAkimboPistol:IsEquipped() then
                currentAkimboPistol:Unequip()
                currentAkimboPistol:Kill()
            end

            newPistol:Equip()
        end
    )
end, "0=laser, 1=reflex, 2=hopper, 3=burstfire", FCVAR_NONE)

Convars:RegisterCommand("akimbo_give_pistol", function (cmd)
    if CurrentAkimboWeapon then
        Msg("Akimbo pistol already exists\n")
        return
    end

    local newPistol = CreateAkimboPistol()
    Player.SecondaryHand:Drop()
    newPistol:Equip()
end, "Gives an akimbo pistol to the player", FCVAR_NONE)

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
