-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Triggers
-- Author: Mik
-------------------------------------------------------------------------------

-- Create module and set its name.
local module = {};
local moduleName = "Triggers";
MikSBT[moduleName] = module;


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

-- Main Trigger Events.
local MAINEVENT_HEALTH				= "Health";
local MAINEVENT_MANA				= "Mana";
local MAINEVENT_ENERGY				= "Energy";
local MAINEVENT_RAGE				= "Rage";
local MAINEVENT_CRIT				= "Crit";
local MAINEVENT_BLOCK				= "Block";
local MAINEVENT_DODGE				= "Dodge";
local MAINEVENT_PARRY				= "Parry";
local MAINEVENT_BUFF_APP			= "BuffApplication";
local MAINEVENT_BUFF_FADE			= "BuffFade";
local MAINEVENT_DEBUFF_APP			= "DebuffApplication";
local MAINEVENT_DEBUFF_FADE			= "DebuffFade";
local MAINEVENT_CAST_START			= "CastStart";
local MAINEVENT_KILLING_BLOW		= "KillingBlow";

-- Trigger Exceptions.
local EXCEPTION_BUFF_ACTIVE			= "BuffActive";
local EXCEPTION_INSUFFICIENT_POWER	= "InsufficientPower";
local EXCEPTION_INSUFFICIENT_CP		= "InsufficientComboPoints";
local EXCEPTION_NOT_IN_ARENA		= "NotInArena";
local EXCEPTION_NOT_IN_PVP_ZONE		= "NotInPvPZone";
local EXCEPTION_RECENTLY_FIRED		= "RecentlyFired";
local EXCEPTION_SKILL_UNAVAILABLE	= "SkillUnavailable";
local EXCEPTION_TRIVIAL_TARGET		= "TrivialTarget";
local EXCEPTION_WARRIOR_STANCE		= "WarriorStance";

-- Power types.
local POWERTYPE_MANA = 0;
local POWERTYPE_RAGE = 1;
local POWERTYPE_ENERGY = 3;


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Holds dynamically created frame for receiving events.
local eventFrame;

-- Holds the player's name, GUID, and  class.
local playerName, playerGUID, playerClass;
local targetGUID, focusGUID;

-- Hold the events the triggers use.
local listenEvents = {};

-- Holds triggers in a format optimized for searching.
local categorizedTriggers = {};
local triggerExceptions = {};

-- Information about triggers used for condition checking.
local lastPercentages = {};
local lastPowerTypes = {};
local firedTimes = {};
local fireTriggers = {};

-- Hold buffs and debuffs that should be suppressed since there is a trigger for them.
local triggerSuppressions = {};


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to certain MSBT modules for faster access.
local MSBTProfiles = MikSBT.Profiles;
local MSBTParser = MikSBT.Parser;

-- Local references to certain constants and variables for faster access.
local TARGET_TARGET = MSBTParser.TARGET_TARGET;
local TARGET_FOCUS = MSBTParser.TARGET_FOCUS;
local REACTION_HOSTILE = bit.bor(MSBTParser.REACTION_HOSTILE, MSBTParser.REACTION_NEUTRAL);

local currentBuffs = MSBTParser.currentAuras.buffs;
local unitMap = MSBTParser.unitMap;

-- Get local references to certain functions for faster access.
local string_find = string.find;
local string_gsub = string.gsub;
local string_gmatch = string.gmatch;
local Print = MikSBT.Print;
local EraseTable = MikSBT.EraseTable;
local DisplayEvent = MikSBT.Animations.DisplayEvent;
local TestFlagsAny = MSBTParser.TestFlagsAny;
local TestFlagsAll = MSBTParser.TestFlagsAll;


-------------------------------------------------------------------------------
-- Trigger utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Converts a string representation of a number, boolean, or nil to its
-- corresponding type.
-- ****************************************************************************
local function ConvertType(value)
 if (type(value) == "string") then
  if (value == "true") then return true; end
  if (value == "false") then return false; end
  if (tonumber(value)) then return tonumber(value); end
  if (value == "nil") then return nil; end
 end
 
 return value;
end


-- ****************************************************************************
-- Categorizes the passed trigger if it is not disabled and it applies to the 
-- current player's class.  Also tracks the events the trigger uses so the 
-- only events that are received are those needed by the active triggers.
-- ****************************************************************************
local function CategorizeTrigger(triggerSettings)
 -- Don't register the trigger if it is disabled, not for the current class,
 -- or there aren't any main events. 
 if (triggerSettings.disabled) then return; end
 if (triggerSettings.classes and not string_find(triggerSettings.classes, playerClass, nil, 1)) then return; end 
 if (not triggerSettings.mainEvents) then return; end

 -- Loop through the main events for the trigger. 
 local eventConditions, conditions;
 for mainEvent, conditionsString in string.gmatch(triggerSettings.mainEvents .. "&&", "(.-)%[(.-)%]&&") do
  -- Loop through the conditions for the event and populate the settings into a conditions table.
  conditions = {triggerSettings = triggerSettings};
  for conditionName, conditionValue in string.gmatch(conditionsString .. ";;", "(.-)=(.-);;") do
   conditions[conditionName] = ConvertType(conditionValue);
  end

  -- Create a table to hold an array of the triggers for the main event if there isn't already one for it. 
  if (not categorizedTriggers[mainEvent]) then categorizedTriggers[mainEvent] = {}; end
  eventConditions = categorizedTriggers[mainEvent];

  -- Add the conditions table categorized by main event.
  eventConditions[#eventConditions+1] = conditions;

  -- Health.
  if (mainEvent == MAINEVENT_HEALTH) then
   listenEvents["UNIT_HEALTH"] = true;

  -- Mana.
  elseif (mainEvent == MAINEVENT_MANA) then
   listenEvents["UNIT_MANA"] = true;

  -- Energy.
  elseif (mainEvent == MAINEVENT_ENERGY) then
   listenEvents["UNIT_ENERGY"] = true;

  -- Rage.
  elseif (mainEvent == MAINEVENT_RAGE) then
   listenEvents["UNIT_RAGE"] = true;

  -- Buff and debuff gains.
  elseif (mainEvent == MAINEVENT_BUFF_APP or
          mainEvent == MAINEVENT_DEBUFF_APP) then

   -- Add player buff/debuff names to the trigger suppressions list.
   if (conditions.unit == "player" and conditions.effect and conditions.amount == 1) then triggerSuppressions[conditions.effect] = true; end
  end
 end -- Loop through conditions.

 -- Leave the function if there are no exceptions for the trigger. 
 if (not triggerSettings.exceptions) then return; end

 -- Create a table to hold an array of the exceptions if there isn't already one for it. 
 if (not triggerExceptions[triggerSettings]) then triggerExceptions[triggerSettings] = {}; end
 local exceptions = triggerExceptions[triggerSettings];

 -- Loop through the exceptions for the trigger.
 for exceptionType, exceptionConditions in string_gmatch(triggerSettings.exceptions .. "&&", "(.-)%[(.-)%]&&") do
  -- Loop through the conditions for the exception and populate the settings into a conditions table.
  conditions = {exceptionType = exceptionType};
  for conditionName, conditionValue in string.gmatch(exceptionConditions .. ";;", "(.-)=(.-);;") do
   conditions[conditionName] = ConvertType(conditionValue);
  end

  -- Add the conditions to the list of exceptions for the trigger.
  exceptions[#exceptions+1] = conditions;
 end
end


-- ****************************************************************************
-- Update the categorized triggers table that is used for optimized searching.
-- ****************************************************************************
local function UpdateTriggers()
 -- Unregister all of the events from the event frame.
 eventFrame:UnregisterAllEvents();

 -- Erase the listen events table.
 EraseTable(listenEvents);

 -- Loop through all of the categorized trigger arrays and erase them.
 for mainEvent in pairs(categorizedTriggers) do
  EraseTable(categorizedTriggers[mainEvent]);
 end

 -- Erase the trigger exceptions array.
 EraseTable(triggerExceptions);

 -- Categorize triggers from the current profile.
 local currentProfileTriggers = rawget(MSBTProfiles.currentProfile, "triggers");
 if (currentProfileTriggers) then
  for triggerKey, triggerSettings in pairs(currentProfileTriggers) do
   if (triggerSettings) then CategorizeTrigger(triggerSettings); end
  end
 end
 
 -- Categorize triggers available in the master profile that aren't in the current profile. 
 for triggerKey, triggerSettings in pairs(MSBTProfiles.masterProfile.triggers) do
  if (not currentProfileTriggers or rawget(currentProfileTriggers, triggerKey) == nil) then
   CategorizeTrigger(triggerSettings);
  end
 end
 
 -- Register all of the events the triggers use.
 for event in pairs(listenEvents) do
  eventFrame:RegisterEvent(event);
 end
end


-- ****************************************************************************
-- Displays the passed trigger settings.
-- ****************************************************************************
local function DisplayTrigger(triggerSettings, sourceName, recipientName, effectTexture, ...)
 -- Get the trigger message and icon skill.
 local message = triggerSettings.message;
 local iconSkill = triggerSettings.iconSkill;
 
 -- Substitute the source and recipient names if there are any. 
 if (sourceName) then message = string_gsub(message, "%%n", sourceName); end
 if (recipientName) then message = string_gsub(message, "%%r", recipientName); end

 -- Loop through all of the arguments replacing any %i codes with the corresponding
 -- arguments.
 for i = 1, select("#", ...) do
  local value = select(i, ...);
  if (value) then message = string_gsub(message, "%%" .. i, tostring(value)); end
  if (type(iconSkill) == "string") then iconSkill = string_gsub(iconSkill, "%%" .. i, tostring(value)); end
 end

 -- Override the texture if there is an icon skill for the trigger.
 if (iconSkill) then _, _, effectTexture = GetSpellInfo(iconSkill); end

 -- Display the trigger event.
 DisplayEvent(triggerSettings, message, effectTexture);
end


-- ****************************************************************************
-- Tests if the passed unit based conditions are satisfied.
-- ****************************************************************************
local function TestUnitConditions(eventConditions, testUnit, testFlags)
 -- Hostile check.
 if (eventConditions.hostile and not TestFlagsAny(testFlags, REACTION_HOSTILE)) then return false; end

 -- Any.
 local conditionUnit = eventConditions.unit;
 if (conditionUnit == "any") then return true; end

 -- Player.
 if (conditionUnit == "player" and testUnit == "player") then return true; end

 -- Target.
 if (conditionUnit == "target" and TestFlagsAny(testFlags, TARGET_TARGET)) then return true; end
 
 -- Focus.
 if (conditionUnit == "focus" and TestFlagsAny(testFlags, TARGET_FOCUS)) then return true; end
end


-------------------------------------------------------------------------------
-- Trigger condition functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Returns whether or not the passed spell name is unavailable.
-- ****************************************************************************
local function IsSpellUnavailable(spellName)
 -- Pass if there is no skill to check.
 if (not spellName or spellName == "") then return true; end

 -- Pass if the spell isn't known.
 if (not GetSpellInfo(spellName)) then return true; end

 -- Pass check if the spell is cooling down (but ignore the global cooldown).
 local start, duration = GetSpellCooldown(spellName);
 if (start > 0 and duration > 1.5) then return true; end
end


-- ****************************************************************************
-- Returns true if any of the exceptions for the passed trigger settings are
-- true.
-- ****************************************************************************
local function IsTriggerExcluded(triggerSettings)
 -- Trigger is not excluded if there are no exceptions.
 if (not triggerExceptions[triggerSettings]) then return; end

 -- Holds whether or not the trigger is excluded.
 local isExcluded;
 
 -- Holds whether or not the trigger has a recently fired exception.
 local hasRecentlyFired;

 local exceptionType;
 for _, exceptionConditions in pairs(triggerExceptions[triggerSettings]) do
  exceptionType = exceptionConditions.exceptionType;
  
  -- Buff Active.
  if (exceptionType == EXCEPTION_BUFF_ACTIVE) then
   if (currentBuffs[exceptionConditions.effect]) then isExcluded = true; end
   
  -- Insufficient Power.
  elseif (exceptionType == EXCEPTION_INSUFFICIENT_POWER) then
   if (UnitMana("player") < exceptionConditions.amount) then isExcluded = true; end

  -- Insufficient Combo Points.
  elseif (exceptionType == EXCEPTION_INSUFFICIENT_CP) then
   if (GetComboPoints() < exceptionConditions.amount) then isExcluded = true; end

  -- Not In Arena.
  elseif (exceptionType == EXCEPTION_NOT_IN_ARENA) then
   local _, zoneType = IsInInstance();
   if (zoneType ~= "arena") then isExcluded = true; end

  -- Not In PvP Zone.
  elseif (exceptionType == EXCEPTION_NOT_IN_PVP_ZONE) then
   local _, zoneType = IsInInstance();
   if (zoneType ~= "arena" and zoneType ~= "pvp") then isExcluded = true; end

  -- Recently Fired.
  elseif (exceptionType == EXCEPTION_RECENTLY_FIRED) then
   hasRecentlyFired = true;
   local lastFired = firedTimes[triggerSettings] or 0;
   if ((GetTime() - lastFired) <= exceptionConditions.duration) then isExcluded = true; end

  -- Skill Unavailable.
  elseif (exceptionType == EXCEPTION_SKILL_UNAVAILABLE) then
   if (IsSpellUnavailable(exceptionConditions.effect)) then isExcluded = true; end

  -- Trivial Target.
  elseif (exceptionType == EXCEPTION_TRIVIAL_TARGET) then
   if (UnitIsTrivial("target")) then isExcluded = true; end

  -- Warrior Stance.
  elseif (exceptionType == EXCEPTION_WARRIOR_STANCE) then
   if (playerClass == "WARRIOR" and (GetShapeshiftForm(true) == exceptionConditions.stance)) then
    isExcluded = true;
   end
  end

  -- Reverse the result if the reverse logic flag is set.
  if (exceptionConditions.reversed) then isExcluded = not isExcluded; end
  if (isExcluded) then return true; end
 end

 -- Set the current time as the last time the trigger was fired if the the trigger
 -- has a recently fired exception.
 if (hasRecentlyFired) then firedTimes[triggerSettings] = GetTime(); end
end


-- ****************************************************************************
-- Fires triggers that have threshold conditions which are satisfied.
-- ****************************************************************************
local function FireThresholdTriggers(unit, mainEvent, currentAmount, maxAmount, powerType)
 -- Ignore the event if it isn't one of the supported units.
 if (unit ~= "player" and unit ~= "target" and unit ~= "pet" and unit ~= "focus") then return; end

 -- Calculate current last percentages.
 local currentPercentage = currentAmount / maxAmount;
 local percentageKey = unit .. mainEvent;
 local lastPercentage = lastPercentages[percentageKey];

 -- Ignore thresholds on death and power type changes.
 if (not lastPercentage) then lastPercentages[percentageKey] = currentPercentage; return; end
 if (powerType and powerType ~= UnitPowerType(unit) or UnitIsDeadOrGhost(unit)) then lastPercentages[percentageKey] = nil; return; end 

 -- Clear the list of triggers to fire. 
 EraseTable(fireTriggers);

 -- Loop through conditions and test the ones that apply to the affected unit.
 local threshold;
 for _, eventConditions in pairs(categorizedTriggers[mainEvent]) do
  if (eventConditions.unit == unit and (not eventConditions.hostile or UnitIsEnemy("player", unit))) then
   threshold = eventConditions.threshold / 100;
   
   -- Rising threshold.    
   if (eventConditions.direction == "rising") then
    if (currentPercentage > threshold and lastPercentage <= threshold) then
     fireTriggers[eventConditions.triggerSettings] = true;
    end

   -- Declining threshold.
   else
    if (currentPercentage < threshold and lastPercentage >= threshold) then
     fireTriggers[eventConditions.triggerSettings] = true;
    end
   end -- Rising check. 
  end -- Applies to unit.
 end -- Conditions loop.
 
 -- Display the fired triggers if none of the exceptions are true.
 local recipientName = UnitName(unit);
 for triggerSettings in pairs(fireTriggers) do
  if (not IsTriggerExcluded(triggerSettings)) then
   DisplayTrigger(triggerSettings, nil, recipientName, nil, currentAmount);
  end
 end

 -- Update the last percentage for the unit.
 lastPercentages[percentageKey] = currentPercentage;
end


-- ****************************************************************************
-- Fires triggers that have incoming/outgoing conditions which are satisfied.
-- ****************************************************************************
local function FireInOutTriggers(mainEvent, parserEvent)
 -- Ignore the event if there are no triggers to search for it.
 if (not categorizedTriggers[mainEvent]) then return; end

 -- Get local copies for faster access.
 local recipientUnit = parserEvent.recipientUnit;
 local sourceUnit = parserEvent.sourceUnit;

 -- Clear the list of triggers to fire. 
 EraseTable(fireTriggers);
 
 -- Loop through conditions and fire the ones that apply to the affected unit.
 for _, eventConditions in pairs(categorizedTriggers[mainEvent]) do
  if (recipientUnit == "player" and eventConditions.direction == "incoming" or
      sourceUnit == "player" and eventConditions.direction == "outgoing") then
   fireTriggers[eventConditions.triggerSettings] = true;
  end
 end 

 -- Get the texture for the event any display triggers that meet all conditions if there are any.
 if (next(fireTriggers)) then
  local effectTexture;
  if (parserEvent.skillID) then _, _, effectTexture = GetSpellInfo(parserEvent.skillID); end

  -- Display the fired triggers if none of the exceptions are true.
  local sourceName = parserEvent.sourceName;
  local recipientName = parserEvent.recipientName;
  local skillName = parserEvent.skillName or "";
  for triggerSettings in pairs(fireTriggers) do
   if (not IsTriggerExcluded(triggerSettings)) then
    DisplayTrigger(triggerSettings, sourceName, recipientName, effectTexture, skillName);
   end
  end
 end
end


-- ****************************************************************************
-- Fires triggers that have aura conditions which are satisfied.
-- ****************************************************************************
local function FireAuraTriggers(mainEvent, parserEvent)
 -- Ignore the event if there are no triggers to search for it.
 if (not categorizedTriggers[mainEvent]) then return; end
 
 -- Get local copies for faster access.
 local skillName = parserEvent.skillName;
 local recipientUnit = parserEvent.recipientUnit;
 local recipientFlags = parserEvent.recipientFlags;
 local amount = parserEvent.amount or 1;

 -- Clear the list of triggers to fire. 
 EraseTable(fireTriggers);

 -- Loop through conditions and test the conditions.
 local conditionAmount;
 for _, eventConditions in pairs(categorizedTriggers[mainEvent]) do
  conditionAmount = eventConditions.amount;
  if (eventConditions.effect == skillName and
      TestUnitConditions(eventConditions, recipientUnit, recipientFlags) and
      (not conditionAmount or conditionAmount == amount)) then
   fireTriggers[eventConditions.triggerSettings] = true;
  end
 end 

 -- Get the texture for the event any display triggers that meet all conditions if there are any.
 if (next(fireTriggers)) then
  local effectTexture = parserEvent.skillTexture;
  if (not effectTexture and parserEvent.skillID) then _, _, effectTexture = GetSpellInfo(parserEvent.skillID); end

  -- Display the fired triggers if none of the exceptions are true.
  local recipientName = parserEvent.recipientName;
  for triggerSettings in pairs(fireTriggers) do
   if (not IsTriggerExcluded(triggerSettings)) then
    DisplayTrigger(triggerSettings, nil, recipientName, effectTexture, skillName, amount);
   end
  end
 end
end


-- ****************************************************************************
-- Fires triggers that have cast conditions which are satisfied.
-- ****************************************************************************
local function FireCastTriggers(mainEvent, parserEvent)
 -- Ignore the event if there are no triggers to search for it.
 if (not categorizedTriggers[mainEvent]) then return; end
 
 -- Get local copies for faster access.
 local skillName = parserEvent.skillName;
 local sourceUnit = parserEvent.sourceUnit;
 local sourceFlags = parserEvent.sourceFlags;
 
 -- Clear the list of triggers to fire. 
 EraseTable(fireTriggers);

 -- Loop through conditions and test the conditions.
 for _, eventConditions in pairs(categorizedTriggers[mainEvent]) do
  if (eventConditions.effect == skillName and
      TestUnitConditions(eventConditions, sourceUnit, sourceFlags)) then
   fireTriggers[eventConditions.triggerSettings] = true;
  end
 end 

 -- Get the texture for the event any display triggers that meet all conditions if there are any.
 if (next(fireTriggers)) then
  local effectTexture = parserEvent.skillTexture;
  if (not effectTexture and parserEvent.skillID) then _, _, effectTexture = GetSpellInfo(parserEvent.skillID); end

  -- Display the fired triggers if none of the exceptions are true.
  local sourceName = parserEvent.sourceName;
  for triggerSettings in pairs(fireTriggers) do
   if (not IsTriggerExcluded(triggerSettings)) then
    DisplayTrigger(triggerSettings, sourceName, nil, effectTexture, skillName);
   end
  end
 end
end


-- ****************************************************************************
-- Fires triggers for the passed condition type.
-- ****************************************************************************
local function FireBasicTriggers(mainEvent, parserEvent)
 -- Ignore the event if there are no triggers for it.
 if (not categorizedTriggers[mainEvent]) then return; end

 -- Clear the list of triggers to fire. 
 EraseTable(fireTriggers);

 -- Loop through conditions and test the ones that apply to the affected unit.
 for _, eventConditions in pairs(categorizedTriggers[mainEvent]) do
  fireTriggers[eventConditions.triggerSettings] = true;
 end
 
 -- Display the fired triggers if none of the exceptions are true.
 local sourceName = parserEvent.sourceName;
 local recipientName = parserEvent.recipientName;
 for triggerSettings in pairs(fireTriggers) do
  if (not IsTriggerExcluded(triggerSettings)) then
   DisplayTrigger(triggerSettings, sourceName, recipientName);
  end
 end
end


-------------------------------------------------------------------------------
-- Initialization and event handlers.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Handle parser events.
-- ****************************************************************************
local function ParserEventsHandler(parserEvent)
 local eventType = parserEvent.eventType;
 -- Crit.
 if (eventType == "damage") then
  if (parserEvent.isCrit) then FireInOutTriggers(MAINEVENT_CRIT, parserEvent); end

 -- Miss.
 elseif (eventType == "miss") then
  -- Block.
  if (parserEvent.missType == "BLOCK") then
   FireInOutTriggers(MAINEVENT_BLOCK, parserEvent);

  -- Dodge.
  elseif (parserEvent.missType == "DODGE") then
   FireInOutTriggers(MAINEVENT_DODGE, parserEvent);

  -- Miss.
  elseif (parserEvent.missType == "PARRY") then
   FireInOutTriggers(MAINEVENT_PARRY, parserEvent);
  end

 -- Aura.
 elseif (eventType == "aura") then
  local mainEvent = (parserEvent.auraType == "BUFF") and "Buff" or "Debuff";
  if (parserEvent.isFade) then
   mainEvent = mainEvent .. "Fade";
  else
   mainEvent = mainEvent .. "Application";
  end
  FireAuraTriggers(mainEvent, parserEvent);

 -- Cast.
 elseif (eventType == "cast") then
  FireCastTriggers(MAINEVENT_CAST_START, parserEvent);

 -- Kill.
 elseif (eventType == "kill") then
  if (parserEvent.sourceUnit == "player") then FireBasicTriggers(MAINEVENT_KILLING_BLOW, parserEvent); end
 end -- Check eventType.
end


-- ****************************************************************************
-- Called when the registered events occur.
-- ****************************************************************************
local function OnEvent(this, event, arg1, ...)
 -- Health.
 if (event == "UNIT_HEALTH") then
  FireThresholdTriggers(arg1, MAINEVENT_HEALTH, UnitHealth(arg1), UnitHealthMax(arg1));

 -- Mana.
 elseif (event == "UNIT_MANA") then
  FireThresholdTriggers(arg1, MAINEVENT_MANA, UnitMana(arg1), UnitManaMax(arg1), POWERTYPE_MANA);

 -- Energy.
 elseif (event == "UNIT_ENERGY") then
  FireThresholdTriggers(arg1, MAINEVENT_ENERGY, UnitMana(arg1), UnitManaMax(arg1), POWERTYPE_ENERGY);

 -- Rage.
 elseif (event == "UNIT_RAGE") then
  FireThresholdTriggers(arg1, MAINEVENT_RAGE, UnitMana(arg1), UnitManaMax(arg1), POWERTYPE_RAGE);

 end -- Event types.
end


-- ****************************************************************************
-- Enables the trigger parsing.
-- ****************************************************************************
local function Enable()
 -- Register events the triggers use that aren't covered by the parser.
 for event in pairs(listenEvents) do
  eventFrame:RegisterEvent(event);
 end

 -- Register the parser events handler.
 MSBTParser.RegisterHandler(ParserEventsHandler);
end


-- ****************************************************************************
-- Disables the trigger parsing.
-- ****************************************************************************
local function Disable()
 -- Unregister all of the events from the event frame.
 eventFrame:UnregisterAllEvents();

 -- Unregister the parser events handler.
 MSBTParser.UnregisterHandler(ParserEventsHandler);
end


-- ****************************************************************************
-- Called when the module is loaded.
-- ****************************************************************************
local function OnLoad()
 -- Get the player's name and class.
 playerName = UnitName("player");
 playerGUID = UnitGUID("player");
 _, playerClass = UnitClass("player");

 -- Create a frame to receive events.
 eventFrame = CreateFrame("Frame");
 eventFrame:Hide();
 eventFrame:SetScript("OnEvent", OnEvent);
end




-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- Protected Variables.
module.triggerSuppressions = triggerSuppressions;

-- Protected Functions.
module.ConvertType			= ConvertType;
module.UpdateTriggers		= UpdateTriggers;
module.Enable				= Enable;
module.Disable				= Disable;


-------------------------------------------------------------------------------
-- Load.
-------------------------------------------------------------------------------

OnLoad();