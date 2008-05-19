-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text German Localization
-- Author: Mik
-- German Translation by: Farook
-------------------------------------------------------------------------------

-- Don't do anything if the locale isn't German.
if (GetLocale() ~= "deDE") then return; end

-------------------------------------------------------------------------------
-- German localization
-------------------------------------------------------------------------------

-- Local reference for faster access.
local MSBTLocale = MikSBT.Locale;


MSBTLocale.COMMAND_USAGE = {
 "Usage: " .. MikSBT.COMMAND .. " <befehle> [params]",
 " Befehle:",
 "  " .. MSBTLocale.COMMAND_RESET .. " - Das aktuelle Profil auf Standardwerte zur\195\188cksetzen.",
 "  " .. MSBTLocale.COMMAND_DISABLE .. " - Das Addon deaktivieren.",
 "  " .. MSBTLocale.COMMAND_ENABLE .. " - Das Addon aktivieren.",
 "  " .. MSBTLocale.COMMAND_SHOWVER .. " - Zeigt die aktuelle Version an.",
 "  " .. MSBTLocale.COMMAND_HELP .. " - Hilfe anzeigen.",
};


------------------------------
-- Output messages
------------------------------

MSBTLocale.MSG_SEARCH_ENABLE			= "Event-Suchmodus aktiviert. Suche nach: ";
MSBTLocale.MSG_SEARCH_DISABLE			= "Event-Suchmodus deaktiviert.";
MSBTLocale.MSG_DISABLE					= "Addon deaktiviert.";
MSBTLocale.MSG_ENABLE					= "Addon aktiviert.";
MSBTLocale.MSG_PROFILE_RESET			= "Profil zur\195\188cksetzen";
MSBTLocale.MSG_HITS						= "Treffer";
--MSBTLocale.MSG_CRIT					= "Crit";
--MSBTLocale.MSG_CRITS					= "Crits";
MSBTLocale.MSG_MULTIPLE_TARGETS			= "Mehrere";
MSBTLocale.MSG_READY_NOW				= "Vorhanden";


------------------------------
-- Scroll area messages
------------------------------

MSBTLocale.MSG_INCOMING			= "Eingehend";
MSBTLocale.MSG_OUTGOING			= "Ausgehend";
MSBTLocale.MSG_NOTIFICATION		= "Benachrichtigung";
MSBTLocale.MSG_STATIC			= "Statisch";


---------------------------------------
-- Master profile event output messages
---------------------------------------

MSBTLocale.MSG_COMBAT					= "Kampf";
MSBTLocale.MSG_DISPEL					= "Zerstreuen";
--MSBTLocale.MSG_CP						= "CP";
MSBTLocale.MSG_CP_FULL					= "Alle Combo-Punkte";
MSBTLocale.MSG_KILLING_BLOW				= "Todessto\195\159";
MSBTLocale.MSG_TRIGGER_LOW_HEALTH		= "Gesundheit Niedrig";
MSBTLocale.MSG_TRIGGER_LOW_MANA			= "Mana Niedrig";
MSBTLocale.MSG_TRIGGER_LOW_PET_HEALTH	= "Begleiter Gesundheit Niedrig";