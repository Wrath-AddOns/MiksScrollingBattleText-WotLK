-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text French Localization
-- Author: Mik
-- French Translation by: Calthas
-------------------------------------------------------------------------------

-- Don't do anything if the locale isn't French.
if (GetLocale() ~= "frFR") then return; end

-------------------------------------------------------------------------------
-- French localization
-------------------------------------------------------------------------------

-- Local reference for faster access.
local MSBTLocale = MikSBT.Locale;


MSBTLocale.COMMAND_USAGE = {
 "Usage: " .. MikSBT.COMMAND .. " <commande> [params]",
 " Commande:",
 "  " .. MSBTLocale.COMMAND_RESET .. " - Restaure les param\195\168tres par d\195\169faut.",
 "  " .. MSBTLocale.COMMAND_DISABLE .. " - D\195\169sactive l'addon.",
 "  " .. MSBTLocale.COMMAND_ENABLE .. " - Active l'addon.",
 "  " .. MSBTLocale.COMMAND_SHOWVER .. " - Affiche la version actuelle.",
 "  " .. MSBTLocale.COMMAND_HELP .. " - Affiche l'aide des commandes.",
};


------------------------------
-- Output messages
------------------------------

MSBTLocale.MSG_SEARCH_ENABLE			= "Mode de recherche d'\195\169v\195\168nements activ\195\169e. Recherche de: ";
MSBTLocale.MSG_SEARCH_DISABLE			= "Mode de recherche d'\195\169v\195\168nements d\195\169sactiv\195\169e.";
MSBTLocale.MSG_DISABLE					= "Addon d\195\169sactiv\195\169.";
MSBTLocale.MSG_ENABLE					= "Addon activ\195\169.";
MSBTLocale.MSG_PROFILE_RESET			= "Profil r\195\169initialis\195\169";
MSBTLocale.MSG_HITS						= "Coups";
--MSBTLocale.MSG_CRIT					= "Crit";
--MSBTLocale.MSG_CRITS					= "Crits";
MSBTLocale.MSG_MULTIPLE_TARGETS			= "Multiples";
MSBTLocale.MSG_READY_NOW				= "Disponible";


------------------------------
-- Scroll area messages
------------------------------

MSBTLocale.MSG_INCOMING			= "Entrant";
MSBTLocale.MSG_OUTGOING			= "Sortant";
MSBTLocale.MSG_NOTIFICATION		= "Alertes";
MSBTLocale.MSG_STATIC			= "Statique";


---------------------------------------
-- Master profile event output messages
---------------------------------------

--MSBTLocale.MSG_COMBAT					= "Combat";
MSBTLocale.MSG_DISPEL					= "Dissiper";
--MSBTLocale.MSG_CP						= "CP";
--MSBTLocale.CP_FULL					= "Finish It";
MSBTLocale.MSG_KILLING_BLOW				= "Coup Fatal";
MSBTLocale.MSG_TRIGGER_LOW_HEALTH		= "Vie Faible";
MSBTLocale.MSG_TRIGGER_LOW_MANA			= "Mana Faible";
MSBTLocale.MSG_TRIGGER_LOW_PET_HEALTH	= "Vie du fam faible";