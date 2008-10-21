-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text French Localization
-- Author: Mik
-- French Translation by: Calthas
-------------------------------------------------------------------------------

-- Don't do anything if the locale isn't French.
if (GetLocale() ~= "frFR") then return; end

-- Local reference for faster access.
local L = MikSBT.translations;

-------------------------------------------------------------------------------
-- French localization
-------------------------------------------------------------------------------

------------------------------
-- Fonts
------------------------------

L.FONT_FILES = {
 ["MSBT Adventure"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\adventure.ttf",
 ["MSBT Bazooka"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\bazooka.ttf",
 ["MSBT Cooline"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\cooline.ttf",
 ["MSBT Diogenes"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\diogenes.ttf",
 ["MSBT Ginko"]			= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\ginko.ttf",
 ["MSBT Heroic"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\heroic.ttf",
 ["MSBT Porky"]			= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\porky.ttf",
 ["MSBT Talisman"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\talisman.ttf",
 ["MSBT Transformers"]	= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\transformers.ttf",
 ["MSBT Yellowjacket"]	= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\yellowjacket.ttf",
}

L.DEFAULT_FONT_NAME = "MSBT Porky";


------------------------------
-- Commands
------------------------------

L.COMMAND_USAGE = {
 "Usage: " .. MikSBT.COMMAND .. " <commande> [params]",
 " Commande:",
 "  " .. L.COMMAND_RESET .. " - Restaure les param\195\168tres par d\195\169faut.",
 "  " .. L.COMMAND_DISABLE .. " - D\195\169sactive l'addon.",
 "  " .. L.COMMAND_ENABLE .. " - Active l'addon.",
 "  " .. L.COMMAND_SHOWVER .. " - Affiche la version actuelle.",
 "  " .. L.COMMAND_HELP .. " - Affiche l'aide des commandes.",
}


------------------------------
-- Output messages
------------------------------

--L.MSG_ICON_MODULE_WARNING	= "WARNING: The MSBTIcons module is no longer required. Remove it from your AddOns folder to avoid wasting memory.";
--L.MSG_SM_MODULE_WARNING		= "WARNING: The MSBTSharedMedia module is no longer required.  Remove it from your AddOns folder.";
L.MSG_DISABLE				= "Addon d\195\169sactiv\195\169.";
L.MSG_ENABLE				= "Addon activ\195\169.";
L.MSG_PROFILE_RESET			= "Profil r\195\169initialis\195\169";
L.MSG_HITS					= "Coups";
--L.MSG_CRIT					= "Crit";
--L.MSG_CRITS					= "Crits";
L.MSG_MULTIPLE_TARGETS		= "Multiples";
L.MSG_READY_NOW				= "Disponible";


------------------------------
-- Scroll area messages
------------------------------

L.MSG_INCOMING			= "Entrant";
L.MSG_OUTGOING			= "Sortant";
L.MSG_NOTIFICATION		= "Alertes";
L.MSG_STATIC			= "Statique";


---------------------------------------
-- Master profile event output messages
---------------------------------------

--L.MSG_COMBAT					= "Combat";
L.MSG_DISPEL					= "Dissiper";
--L.MSG_CP						= "CP";
--L.CP_FULL						= "Finish It";
L.MSG_KILLING_BLOW				= "Coup Fatal";
L.MSG_TRIGGER_LOW_HEALTH		= "Vie Faible";
L.MSG_TRIGGER_LOW_MANA			= "Mana Faible";
L.MSG_TRIGGER_LOW_PET_HEALTH	= "Vie du fam faible";