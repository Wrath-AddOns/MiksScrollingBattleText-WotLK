-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Localization
-- Author: Mik
-------------------------------------------------------------------------------

-- Create module and set its name.
local module = {};
local moduleName = "Locale";
MikSBT[moduleName] = module;

-- Local reference for uniformity with localization files.
local MSBTLocale = module;


-------------------------------------------------------------------------------
-- English localization (Default)
-------------------------------------------------------------------------------

------------------------------
-- Commands
------------------------------
MSBTLocale.COMMAND_RESET	= "reset";
MSBTLocale.COMMAND_DISABLE	= "disable";
MSBTLocale.COMMAND_ENABLE	= "enable";
MSBTLocale.COMMAND_SHOWVER	= "version";
MSBTLocale.COMMAND_HELP		= "help";

MSBTLocale.COMMAND_USAGE = {
 "Usage: " .. MikSBT.COMMAND .. " <command> [params]",
 " Commands:",
 "  " .. MSBTLocale.COMMAND_RESET .. " - Reset the current profile to the default settings.",
 "  " .. MSBTLocale.COMMAND_DISABLE .. " - Disables the mod.",
 "  " .. MSBTLocale.COMMAND_ENABLE .. " - Enables the mod.",
 "  " .. MSBTLocale.COMMAND_SHOWVER .. " - Shows the current version.",
 "  " .. MSBTLocale.COMMAND_HELP .. " - Show the command usage.",
};


------------------------------
-- Output messages
------------------------------

MSBTLocale.MSG_ICON_MODULE_WARNING		= "WARNING: The MSBTIcons module is no longer required. Remove it from your AddOns folder to avoid wasting memory.";
--MSBTLocale.MSG_SEARCH_ENABLE			= "Event search mode enabled.  Searching for: ";
--MSBTLocale.MSG_SEARCH_DISABLE			= "Event search mode disabled.";
MSBTLocale.MSG_DISABLE					= "Mod disabled.";
MSBTLocale.MSG_ENABLE					= "Mod enabled.";
MSBTLocale.MSG_PROFILE_RESET			= "Profile Reset";
MSBTLocale.MSG_HITS						= "Hits";
MSBTLocale.MSG_CRIT						= "Crit";
MSBTLocale.MSG_CRITS					= "Crits";
MSBTLocale.MSG_MULTIPLE_TARGETS			= "Multiple";
MSBTLocale.MSG_READY_NOW				= "Ready Now";


------------------------------
-- Scroll area names
------------------------------

MSBTLocale.MSG_INCOMING			= "Incoming";
MSBTLocale.MSG_OUTGOING			= "Outgoing";
MSBTLocale.MSG_NOTIFICATION		= "Notification";
MSBTLocale.MSG_STATIC			= "Static";


----------------------------------------
-- Master profile event output messages
----------------------------------------

MSBTLocale.MSG_COMBAT					= "Combat";
MSBTLocale.MSG_DISPEL					= "Dispel";
MSBTLocale.MSG_CP						= "CP";
MSBTLocale.MSG_CP_FULL					= "Finish It";
MSBTLocale.MSG_KILLING_BLOW				= "Killing Blow";
MSBTLocale.MSG_TRIGGER_LOW_HEALTH		= "Low Health";
MSBTLocale.MSG_TRIGGER_LOW_MANA			= "Low Mana";
MSBTLocale.MSG_TRIGGER_LOW_PET_HEALTH	= "Low Pet Health";