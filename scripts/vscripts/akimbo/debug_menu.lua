local category = "akimbo"

DebugMenu:AddCategory(category, "Akimbo")

DebugMenu:AddButton(category, "give_pistol", "Give Akimbo Pistol", "akimbo_give_pistol")

DebugMenu:AddLabel(category, "pistol_upgrades", "Pistol Upgrades")
DebugMenu:AddButton(category, "pistol_upgrade_laser", "Laser Sight", "akimbo_pistol_grant_upgrade 0")
DebugMenu:AddButton(category, "pistol_upgrade_reflex", "Reflex Sight", "akimbo_pistol_grant_upgrade 1")
DebugMenu:AddButton(category, "pistol_upgrade_hopper", "Bullet Hopper", "akimbo_pistol_grant_upgrade 2")
DebugMenu:AddButton(category, "pistol_upgrade_burst", "Burst Fire", "akimbo_pistol_grant_upgrade 3")

DebugMenu:AddSeparator(category, "", "Experimental")
DebugMenu:AddLabel(category, "experimental", "!! EXPECT CRASHES !!")

DebugMenu:AddButton(category, "give_smg", "Give Akimbo SMG", "akimbo_give_smg")
DebugMenu:AddButton(category, "smg_upgrade_reflex", "Reflex Sight", "akimbo_smg_grant_upgrade 4")
DebugMenu:AddButton(category, "smg_upgrade_laser", "Laser Sight", "akimbo_smg_grant_upgrade 5")
DebugMenu:AddButton(category, "smg_upgrade_mag", "Extended Magazine", "akimbo_smg_grant_upgrade 6")