-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Simplified Chinese Localization
-- Author: Mik
-- Simplified Chinese Translation by: elafor,hscui
-------------------------------------------------------------------------------

-- Don't do anything if the locale isn't Simplified Chinese.
if (GetLocale() ~= "zhCN") then return; end

-------------------------------------------------------------------------------
-- Simplified Chinese localization
-------------------------------------------------------------------------------

-- Local reference for faster access.
local MSBTLocale = MikSBT.Locale;

MSBTLocale.COMMAND_USAGE = {
 "使用方法: " .. MikSBT.COMMAND .. " <命令> [参数]",
 " 命令:",
 "  " .. MSBTLocale.COMMAND_RESET .. " - 重置",
 "  " .. MSBTLocale.COMMAND_DISABLE .. " - 禁用",
 "  " .. MSBTLocale.COMMAND_ENABLE .. " - 启用",
 "  " .. MSBTLocale.COMMAND_SHOWVER .. " - 显示当前版本",
 "  " .. MSBTLocale.COMMAND_HELP .. " - 帮助",
};


------------------------------
-- Output messages
------------------------------

MSBTLocale.MSG_SEARCH_ENABLE			= "事件搜索模式开启.  搜索: ";
MSBTLocale.MSG_SEARCH_DISABLE			= "事件搜索模式关闭.";
MSBTLocale.MSG_DISABLE					= "禁用插件.";
MSBTLocale.MSG_ENABLE					= "启用插件.";
MSBTLocale.MSG_PROFILE_RESET			= "重置配置";
MSBTLocale.MSG_HITS						= "击中";
MSBTLocale.MSG_CRIT					    = "爆击";
MSBTLocale.MSG_CRITS					= "爆击";
MSBTLocale.MSG_MULTIPLE_TARGETS			= "多个目标";
MSBTLocale.MSG_READY_NOW				= "准备完毕";


------------------------------
-- Scroll area messages
------------------------------

MSBTLocale.MSG_INCOMING			= "承受伤害";
MSBTLocale.MSG_OUTGOING			= "输出伤害";
MSBTLocale.MSG_NOTIFICATION		= "通告信息";
MSBTLocale.MSG_STATIC			= "静态信息";


---------------------------------------
-- Master profile event output messages
---------------------------------------

MSBTLocale.MSG_COMBAT					= "战斗";
--MSBTLocale.MSG_DISPEL					= "Dispel";
MSBTLocale.MSG_CP						= "连击点";
MSBTLocale.MSG_FINISH_IT				= "终结技";
MSBTLocale.MSG_KILLING_BLOW				= "击杀";
MSBTLocale.MSG_TRIGGER_LOW_HEALTH		= "生命值低";
MSBTLocale.MSG_TRIGGER_LOW_MANA			= "魔法值低";
MSBTLocale.MSG_TRIGGER_LOW_PET_HEALTH	= "宠物生命值低";