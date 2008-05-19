-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Parser
-- Author: Mik
-------------------------------------------------------------------------------

-- Create module and set its name.
local module = {};
local moduleName = "Parser";
MikSBT[moduleName] = module;


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

-- Bit flags.
local AFFILIATION_MINE		= 0x00000001;
local AFFILIATION_PARTY		= 0X00000002;
local AFFILIATION_RAID		= 0X00000004;
local AFFILIATION_OUTSIDER	= 0X00000008;
local REACTION_FRIENDLY		= 0x00000010;
local REACTION_NEUTRAL		= 0x00000020;
local REACTION_HOSTILE		= 0x00000040;
local CONTROL_HUMAN			= 0x00000100;
local CONTROL_SERVER		= 0x00000200;
local UNITTYPE_PLAYER		= 0x00000400;
local UNITTYPE_NPC			= 0x00000800;
local UNITTYPE_PET			= 0x00001000;
local UNITTYPE_GUARDIAN		= 0x00002000;
local UNITTYPE_OBJECT		= 0x00004000;
local TARGET_TARGET			= 0x00010000;
local TARGET_FOCUS			= 0x00020000;
local OBJECT_NONE			= 0x80000000;

-- Value when there is no GUID.
local GUID_NONE				= "0x0000000000000000";

-- The maximum number of buffs and debuffs that can be on a unit.
local MAX_BUFFS = 16;
local MAX_DEBUFFS = 40;

-- Aura types.
local AURA_TYPE_BUFF = "BUFF";
local AURA_TYPE_DEBUFF = "DEBUFF";

-- Update timings.
local UNIT_MAP_UPDATE_DELAY = 0.2;
local PET_UPDATE_DELAY = 1;
local REFLECT_HOLD_TIME = 3;

-- Commonly used flag combinations.
local FLAGS_ME			= bit.bor(AFFILIATION_MINE, REACTION_FRIENDLY, CONTROL_HUMAN, UNITTYPE_PLAYER);
local FLAGS_MY_GUARDIAN	= bit.bor(AFFILIATION_MINE, REACTION_FRIENDLY, CONTROL_HUMAN, UNITTYPE_GUARDIAN);


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Dynamically created frames for receiving events and tooltip info.
local eventFrame;

-- Name and GUID of the player.
local playerName;
local playerGUID;

-- Used for timing between updates.
local lastUnitMapUpdate = 0;
local lastPetMapUpdate = 0;

-- Whether or not values that need to be updated after a delay are stale.
local isUnitMapStale;
local isPetMapStale;

-- Map of names to unit ids.
local unitMap = {};
local petMap = {};

-- Information about buffs and debuffs.
local recentAuras = {};
local currentAuras = {buffs = {}, debuffs = {}};
local savedAuras = {buffs = {}, debuffs = {}};
local aurasInitialized;

-- Map of data to capture and set for combat log events.
local captureMaps;

-- Events to parse even if the source or recipient is not the player or pet.
local fullParseEvents;

-- Information about global strings for CHAT_MSG_X events.
local searchMap;
local searchCaptureMaps;
local rareWords = {};
local searchPatterns = {};
local captureOrders = {};

-- Captured and parsed event data.
local captureTable = {};
local parserEvent = {};

-- List of functions to call when an event occurs.
local handlers = {};

-- Holds information about reflected skills to track how much was reflected.
local reflectedSkills = {};
local reflectedTimes = {};


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to certain functions for faster access.
local string_find = string.find;
local string_gmatch = string.gmatch;
local string_gsub = string.gsub;
local string_len = string.len;
local bit_band = bit.band;
local Print = MikSBT.Print;
local EraseTable = MikSBT.EraseTable;


-------------------------------------------------------------------------------
-- Utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Registers a function to be called when an event occurs.
-- ****************************************************************************
local function RegisterHandler(handler)
 handlers[handler] = true;
end

-- ****************************************************************************
-- Unregisters a previously registered function.
-- ****************************************************************************
local function UnregisterHandler(handler)
 handlers[handler] = nil;
end


-- ****************************************************************************
-- Tests if any of the bits in the passed testFlags are set in the unit flags.
-- ****************************************************************************
local function TestFlagsAny(unitFlags, testFlags)
 if (bit_band(unitFlags, testFlags) > 0) then return true; end 
end


-- ****************************************************************************
-- Tests if all of the passed testFlags are set in the unit flags.
-- ****************************************************************************
local function TestFlagsAll(unitFlags, testFlags)
 if (bit_band(unitFlags, testFlags) == testFlags) then return true; end
end


-- ****************************************************************************
-- Sends the parser event to the registered handlers.
-- ****************************************************************************
local function SendParserEvent()
 for handler in pairs(handlers) do
  local success, ret = pcall(handler, parserEvent);
  if (not success) then geterrorhandler()(ret); end
 end
end


-- ****************************************************************************
-- Compares two global strings so the most specific one comes first.  This
-- prevents incorrectly capturing information for certain events.
-- ****************************************************************************
local function GlobalStringCompareFunc(globalStringNameOne, globalStringNameTwo)
 -- Get the global string for the passed names.
 local globalStringOne = _G[globalStringNameOne];
 local globalStringTwo = _G[globalStringNameTwo];

 local gsOneStripped = string_gsub(globalStringOne, "%%%d?%$?[sd]", "");
 local gsTwoStripped = string_gsub(globalStringTwo, "%%%d?%$?[sd]", "");

 -- Check if the stripped global strings are the same length.
 if (string_len(gsOneStripped) == string_len(gsTwoStripped)) then
  -- Count the number of captures in each string.
  local numCapturesOne = 0;
  for _ in string_gmatch(globalStringOne, "%%%d?%$?[sd]") do
   numCapturesOne = numCapturesOne + 1;
  end

  local numCapturesTwo = 0;
  for _ in string_gmatch(globalStringTwo, "%%%d?%$?[sd]") do
   numCapturesTwo = numCapturesTwo + 1;
  end
  
  -- Return the global string with the least captures.
  return numCapturesOne < numCapturesTwo;

 else
  -- Return the longest global string.
  return string_len(gsOneStripped) > string_len(gsTwoStripped);
 end
end


-- ****************************************************************************
-- Converts the passed global string into a lua search pattern with a capture
-- order table and stores the results so any requests to convert the same
-- global string will just return the cached one.
-- ****************************************************************************
local function ConvertGlobalString(globalStringName)
 -- Don't do anything if the passed global string does not exist.
 local globalString = _G[globalStringName];
 if (globalString == nil) then return; end

 -- Return the cached conversion if it has already been converted.
 if (searchPatterns[globalStringName]) then
  return searchPatterns[globalStringName], captureOrders[globalStringName];
 end

 -- Hold the capture order.
 local captureOrder;
 local numCaptures = 0;

 -- Escape lua magic chars.
 local searchPattern = string.gsub(globalString, "([%^%(%)%.%[%]%*%+%-%?])", "%%%1");

 -- Loop through each capture and setup the capture order.
 for captureIndex in string_gmatch(searchPattern, "%%(%d)%$[sd]") do
  if (not captureOrder) then captureOrder = {}; end
  numCaptures = numCaptures + 1;
  captureOrder[tonumber(captureIndex)] = numCaptures;
 end
 
 -- Convert %1$s / %s to (.+) and %1$d / %d to (%d+).
 searchPattern = string.gsub(searchPattern, "%%%d?%$?s", "(.+)");
 searchPattern = string.gsub(searchPattern, "%%%d?%$?d", "(%%d+)");

 -- Escape any remaining $ chars.
 searchPattern = string.gsub(searchPattern, "%$", "%%$");
 
 -- Cache the converted pattern and capture order.
 searchPatterns[globalStringName] = searchPattern;
 captureOrders[globalStringName] = captureOrder;

 -- Return the converted global string.
 return searchPattern, captureOrder;
end


-- ****************************************************************************
-- Fills in the capture table with the captured data if a match is found.
-- ****************************************************************************
local function CaptureData(matchStart, matchEnd, c1, c2, c3, c4, c5, c6, c7, c8, c9)
 -- Check if a match was found.
 if (matchStart) then
  captureTable[1] = c1;
  captureTable[2] = c2;
  captureTable[3] = c3;
  captureTable[4] = c4;
  captureTable[5] = c5;
  captureTable[6] = c6;
  captureTable[7] = c7;
  captureTable[8] = c8;
  captureTable[9] = c9;

  -- Return the last position of the match.
  return matchEnd;
 end

 -- Don't return anything since no match was found.
 return nil;
end


-- ****************************************************************************
-- Reorders the capture table according to the passed capture order.
-- ****************************************************************************
local function ReorderCaptures(capOrder)
 local t = captureTable;
 
 t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9] = 
 t[capOrder[1]], t[capOrder[2]], t[capOrder[3]], t[capOrder[4]], t[capOrder[5]], t[capOrder[6]],
 t[capOrder[7]], t[capOrder[8]], t[capOrder[9]];
end


-- ****************************************************************************
-- Parses the CHAT_MSG_X search style events.
-- ****************************************************************************
local function ParseSearchMessage(event, combatMessage)
 -- Leave if there is no map of global strings to search for the event.
 if (not searchMap[event]) then return; end

 -- Loop through all of the global strings to search for the event.
 for _, globalStringName in pairs(searchMap[event]) do
  -- Make sure the capture map for the global string exists.
  local captureMap = searchCaptureMaps[globalStringName];
  if (captureMap) then
   -- First, check if there is a rare word for the global string and it is in the combat
   -- message since a plain text search is faster than doing a full regular expression search.
   if (not rareWords[globalStringName] or string_find(combatMessage, rareWords[globalStringName], 1, true)) then
    -- Get capture data.
    local matchEnd = CaptureData(string_find(combatMessage, searchPatterns[globalStringName]));
  

    -- Check if a match was found. 
    if (matchEnd) then
     -- Check if there is a capture order for the global string and reorder the data accordingly.
     if (captureOrders[globalStringName]) then ReorderCaptures(captureOrders[globalStringName]); end

     -- Erase the parser event table..
     for key in pairs(parserEvent) do parserEvent[key] = nil; end

     -- Populate fields that exist for all events.
     parserEvent.sourceGUID = GUID_NONE;
     parserEvent.sourceFlags = OBJECT_NONE;
     parserEvent.recipientGUID = playerGUID;
     parserEvent.recipientName = playerName;
     parserEvent.recipientFlags = FLAGS_ME;
     parserEvent.recipientUnit = "player";

     -- Map the captured arguments into the parser event table.
     for argumentNum, fieldName in ipairs(captureMap) do
      parserEvent[fieldName] = captureTable[argumentNum];
     end

     -- Copy any additional fields from the capture map into the parser event table.
     for fieldName, fieldValue in pairs(captureMap) do
      if(type(fieldName) == "string") then parserEvent[fieldName] = fieldValue; end
     end

     -- Send the event.
     SendParserEvent();
     return;
    end -- Match found.
   end -- Fast plain search.
  end -- Capture map is valid.
 end -- Loop through global strings to search. 
end


-- ****************************************************************************
-- Parses the parameter style events going to the combat log.
-- ****************************************************************************
local function ParseLogMessage(timestamp, event, sourceGUID, sourceName, sourceFlags, recipientGUID, recipientName, recipientFlags, ...)
 -- Make sure the capture map for the event exists.
 local captureMap = captureMaps[event];
 if (not captureMap) then return; end

 -- Look for spells the player reflected and make the damage belong to the player.
 if (sourceGUID == recipientGUID and reflectedTimes[recipientGUID] and event == "SPELL_DAMAGE") then
  local skillID = ...;
  if (skillID == reflectedSkills[recipientGUID]) then
   -- Clear the reflected skill entries.
   reflectedTimes[recipientGUID] = nil;
   reflectedSkills[recipientGUID] = nil;

   -- Change the source to the player.
   sourceGUID = playerGUID;
   sourceName = playerName;
   sourceFlags = FLAGS_ME;
  end
 end

 -- Attempt to figure out the source and recipient unitIDs.
 local sourceUnit = unitMap[sourceGUID] or petMap[sourceGUID];
 local recipientUnit = unitMap[recipientGUID] or petMap[recipientGUID];

 -- Treat player guardians like pets. 
 if (not sourceUnit and TestFlagsAll(sourceFlags, FLAGS_MY_GUARDIAN)) then sourceUnit = "pet"; end
 if (not recipientUnit and TestFlagsAll(recipientFlags, FLAGS_MY_GUARDIAN)) then recipientUnit = "pet"; end

 -- Ignore the event if it is not one that should be fully parsed and it doesn't pertain to the player
 -- or pet.  This is done to avoid wasting time parsing events that won't be used like damage that other
 -- players are doing.
 if (not fullParseEvents[event] and sourceUnit ~= "player" and sourceUnit ~= "pet" and
     recipientUnit ~= "player" and recipientUnit ~= "pet") then
  return;
 end

 -- Erase the parser event table.
 for k in pairs(parserEvent) do parserEvent[k] = nil; end

 -- Populate fields that exist for all events.
 parserEvent.sourceGUID = sourceGUID;
 parserEvent.sourceName = sourceName;
 parserEvent.sourceFlags = sourceFlags;
 parserEvent.recipientGUID = recipientGUID;
 parserEvent.recipientName = recipientName;
 parserEvent.recipientFlags = recipientFlags; 
 parserEvent.sourceUnit = sourceUnit;
 parserEvent.recipientUnit = recipientUnit;
 

 -- Map the local arguments into the parser event table.
 for argumentNum, fieldName in ipairs(captureMap) do
  parserEvent[fieldName] = select(argumentNum, ...);
 end

 -- Copy any additional fields from the capture map into the parser event table.
 for fieldName, fieldValue in pairs(captureMap) do
  if(type(fieldName) == "string") then parserEvent[fieldName] = fieldValue; end
 end

 -- Add new auras parsed from the combat log to a list of recent auras so they are not
 -- duplicated by the aura change event.
 local eventType = parserEvent.eventType;
 if (eventType == "aura" and recipientUnit == "player") then
  local skillName = parserEvent.skillName;
  if (skillName) then recentAuras[skillName] = true; end

 -- Calculate the overhealing on the healed unit if unit is in the party/raid.
 elseif (eventType == "heal" and recipientUnit) then
  -- Get the unit ID of the recipient.
  local healthMissing = UnitHealthMax(recipientUnit) - UnitHealth(recipientUnit);
  local overhealAmount = parserEvent.amount - healthMissing;

  -- Populate the overheal amount if any occurred.
  if (overhealAmount > 0) then parserEvent.overhealAmount = overhealAmount; end 

 -- Track reflected skills.
 elseif (eventType == "miss" and parserEvent.missType == "REFLECT" and recipientUnit == "player") then
  -- Clean up old entries.
  for guid, reflectTime in pairs(reflectedTimes) do
   if (timestamp - reflectTime > REFLECT_HOLD_TIME) then
    reflectedTimes[guid] = nil;
    reflectedSkills[guid] = nil;
   end
  end

  -- Save the time of the reflect and the reflected skillID.
  reflectedTimes[sourceGUID] = timestamp;
  reflectedSkills[sourceGUID] = parserEvent.skillID;

  -- Ignore the reflect until the amount can be obtained.
  return;
 end

 -- Send the event.
 SendParserEvent();
end


-------------------------------------------------------------------------------
-- Startup utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Creates a list of events that will be fully parsed even if they event
-- doesn't pertain to the player or player's pet.
-- ****************************************************************************
local function CreateFullParseList()
 fullParseEvents = {
  SPELL_AURA_APPLIED = true,
  SPELL_AURA_REMOVED = true,
  SPELL_AURA_APPLIED_DOSE = true,
  SPELL_AURA_REMOVED_DOSE = true,
  SPELL_CAST_START = true,
 };
end


-- ****************************************************************************
-- Creates a map of global strings to search for CHAT_MSG_X events.
-- ****************************************************************************
local function CreateSearchMap()
 searchMap = {
  -- Honor Gains.
  CHAT_MSG_COMBAT_HONOR_GAIN = {"COMBATLOG_HONORGAIN", "COMBATLOG_HONORAWARD"},

  -- Reputation Gains/Losses.
  CHAT_MSG_COMBAT_FACTION_CHANGE = {"FACTION_STANDING_INCREASED", "FACTION_STANDING_DECREASED"},

  -- Skill Gains.
  CHAT_MSG_SKILL = {"SKILL_RANK_UP"},

  -- Experience Gains.
  CHAT_MSG_COMBAT_XP_GAIN = {"COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED"},

  -- Looted Items.
  CHAT_MSG_LOOT = {
   "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
   "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF"
  },
  
  -- Money.
  CHAT_MSG_MONEY = {"YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT"},
 };


 -- Loop through each of the events.
 for event, map in pairs(searchMap) do
  -- Remove invalid global strings.
  for i = #map, 1, -1 do
   if (not _G[map[i]]) then table.remove(map, i); end
  end

  -- Sort the global strings from most to least specific.
  table.sort(map, GlobalStringCompareFunc);
 end
end


-- ****************************************************************************
-- Creates a map of data to capture for supported global strings.
-- ****************************************************************************
local function CreateSearchCaptureMaps()
 searchCaptureMaps = {
  -- Honor events.
  COMBATLOG_HONORAWARD = {eventType = "honor", "amount"},
  COMBATLOG_HONORGAIN = {eventType = "honor", "sourceName", "sourceRank", "amount"},

  -- Experience events.
  COMBATLOG_XPGAIN_FIRSTPERSON = {eventType = "experience", "sourceName", "amount"},
  COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = {eventType = "experience", "amount"},

  -- Reputation events.
  FACTION_STANDING_DECREASED = {eventType = "reputation", isLoss = true, "factionName", "amount"},
  FACTION_STANDING_INCREASED = {eventType = "reputation", "factionName", "amount"},

  -- Proficiency events.
  SKILL_RANK_UP = {eventType = "proficiency", "skillName", "amount"},

  -- Loot events.
  LOOT_ITEM_CREATED_SELF = {eventType = "loot", "itemLink", "amount"},
  LOOT_MONEY_SPLIT = {eventType = "loot", isMoney = true, "moneyString"},
 };

 searchCaptureMaps["LOOT_ITEM_CREATED_SELF_MULTIPLE"] = searchCaptureMaps["LOOT_ITEM_CREATED_SELF"];
 searchCaptureMaps["LOOT_ITEM_PUSHED_SELF"] = searchCaptureMaps["LOOT_ITEM_CREATED_SELF"];
 searchCaptureMaps["LOOT_ITEM_PUSHED_SELF_MULTIPLE"] = searchCaptureMaps["LOOT_ITEM_CREATED_SELF"];
 searchCaptureMaps["LOOT_ITEM_SELF"] = searchCaptureMaps["LOOT_ITEM_CREATED_SELF"];
 searchCaptureMaps["LOOT_ITEM_SELF_MULTIPLE"] = searchCaptureMaps["LOOT_ITEM_CREATED_SELF"];
 searchCaptureMaps["YOU_LOOT_MONEY"] = searchCaptureMaps["LOOT_MONEY_SPLIT"];

 -- Print an error message for each global string that isn't found and remove it from the map.
 for globalStringName in pairs(searchCaptureMaps) do
  if (not _G[globalStringName]) then
   Print("Unable to find global string: " .. globalStringName, 1, 0, 0);
   searchCaptureMaps[globalStringName] = nil;
  end
 end
end


-- ****************************************************************************
-- Finds the rarest word for each global string.
-- ****************************************************************************
local function FindRareWords()
 -- Hold the number of times each word appears in all the global strings.
 local wordCounts = {};

 -- Loop through all of the supported global strings.
 for globalStringName in pairs(searchCaptureMaps) do
  -- Strip out all of the formatting codes.
  local strippedGS = string.gsub(_G[globalStringName], "%%%d?%$?[sd]", "");

  -- Count how many times each word appears in the global string.
  for word in string_gmatch(strippedGS, "%w+") do
   wordCounts[word] = (wordCounts[word] or 0) + 1;
  end
 end


 -- Loop through all of the supported global strings.
 for globalStringName in pairs(searchCaptureMaps) do
  local leastSeen, rarestWord;

  -- Strip out all of the formatting codes.
  local strippedGS = string.gsub(_G[globalStringName], "%%%d?%$?[sd]", "");

  -- Find the rarest word in the global string.
  for word in string_gmatch(strippedGS, "%w+") do
   if (not leastSeen or wordCounts[word] < leastSeen) then
    leastSeen = wordCounts[word];
    rarestWord = word;
   end
  end

  -- Set the rarest word.
  rareWords[globalStringName] = rarestWord;
 end
end


-- ****************************************************************************
-- Validates rare words to make sure there are no oddities caused by various
-- languages. 
-- ****************************************************************************
local function ValidateRareWords()
 -- Loop through all of the global strings there is a rare word entry for.
 for globalStringName, rareWord in pairs(rareWords) do
  -- Remove the entry if the rare word isn't found in the associated global string.
  if (not string_find(_G[globalStringName], rareWord, 1, true)) then
   rareWords[globalStringName] = nil;
  end
 end
end


-- ****************************************************************************
-- Converts all of the supported global strings.
-- ****************************************************************************
local function ConvertGlobalStrings()
 -- Loop through all of the global string capture maps.
 for globalStringName in pairs(searchCaptureMaps) do
  -- Get the global string converted to a lua search pattern and prepend an anchor to
  -- speed up searching.
  searchPatterns[globalStringName] = "^" .. ConvertGlobalString(globalStringName);
 end
end


-- ****************************************************************************
-- Creates a map of fields to capture for each combat log event.
-- ****************************************************************************
local function CreateCaptureMaps()
 captureMaps = {
  -- Damage events.
  SWING_DAMAGE = {eventType = "damage", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},
  RANGE_DAMAGE = {eventType = "damage", isRange = true, "skillID", "skillName", "skillSchool", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},
  SPELL_DAMAGE = {eventType = "damage", "skillID", "skillName", "skillSchool", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},
  SPELL_PERIODIC_DAMAGE = {eventType = "damage", isDoT = true, "skillID", "skillName", "skillSchool", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},
  DAMAGE_SPLIT = {eventType = "damage", "skillID", "skillName", "skillSchool", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},
  DAMAGE_SHIELD = {eventType = "damage", isDamageShield = true, "skillID", "skillName", "skillSchool", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},

  -- Miss events.
  SWING_MISSED = {eventType = "miss", "missType"},
  RANGE_MISSED = {eventType = "miss", isRange = true, "skillID", "skillName", "skillSchool", "missType"},
  SPELL_MISSED = {eventType = "miss", "skillID", "skillName", "skillSchool", "missType"},
  SPELL_DISPEL_FAILED = {eventType = "miss", missType = "RESIST", "skillID", "skillName", "skillSchool", "extraSkillID", "extraSkillName", "extraSkillSchool"},
  DAMAGE_SHIELD_MISS = {eventType = "miss", isDamageShield = true, "skillID", "skillName", "skillSchool", "missType"},

  -- Heal events.
  SPELL_HEAL = {eventType = "heal", "skillID", "skillName", "skillSchool", "amount", "isCrit"},
  SPELL_PERIODIC_HEAL = {eventType = "heal", isHoT = true, "skillID", "skillName", "skillSchool", "amount", "isCrit"},
  
  -- Environmental events.
  ENVIRONMENTAL_DAMAGE = {eventType = "environmental", "hazardType", "amount", "damageType", "resistAmount", "blockAmount", "absorbAmount", "isCrit", "isGlancing", "isCrushing"},

  -- Power events.
  SPELL_ENERGIZE = {eventType = "power", isGain = true, "skillID", "skillName", "skillSchool", "amount", "powerType"},
  SPELL_DRAIN = {eventType = "power", isDrain = true, "skillID", "skillName", "skillSchool", "amount", "powerType", "extraAmount"},
  SPELL_LEECH = {eventType = "power", isLeech = true, "skillID", "skillName", "skillSchool", "amount", "powerType", "extraAmount"},

  -- Interrupt events.
  SPELL_INTERRUPT = {eventType = "interrupt", "skillID", "skillName", "skillSchool", "extraSkillID", "extraSkillName", "extraSkillSchool"},
  
  -- Aura events.
  SPELL_AURA_APPLIED = {eventType = "aura", "skillID", "skillName", "skillSchool", "auraType", "amount"},
  SPELL_AURA_REMOVED = {eventType = "aura", isFade = true, "skillID", "skillName", "skillSchool", "auraType", "amount"},

  -- Enchant events.
  ENCHANT_APPLIED = {eventType = "enchant", "skillName", "itemID", "itemName"},
  ENCHANT_REMOVED = {eventType = "enchant", isFade = true, "skillName", "itemID", "itemName"},
  
  -- Dispel events.
  SPELL_AURA_DISPELLED = {eventType = "dispel", "skillID", "skillName", "skillSchool", "extraSkillID", "extraSkillName", "extraSkillSchool", "auraType"},

  -- Cast events.
  SPELL_CAST_START = {eventType = "cast", "skillID", "skillName", "skillSchool"},

  -- Kill events.
  PARTY_KILL = {eventType = "kill"},
  
  -- Extra Attack events.
  SPELL_EXTRA_ATTACKS = {eventType = "extraattacks", "skillID", "skillName", "skillSchool", "amount"},
 };

 captureMaps["SPELL_PERIODIC_MISSED"] = captureMaps["SPELL_MISSED"];
 captureMaps["SPELL_PERIODIC_ENERGIZE"] = captureMaps["SPELL_ENERGIZE"];
 captureMaps["SPELL_PERIODIC_DRAIN"] = captureMaps["SPELL_DRAIN"];
 captureMaps["SPELL_PERIODIC_LEECH"] = captureMaps["SPELL_LEECH"];
 captureMaps["SPELL_AURA_STOLEN"] = captureMaps["SPELL_AURA_DISPELLED"];
 captureMaps["SPELL_AURA_APPLIED_DOSE"] = captureMaps["SPELL_AURA_APPLIED"];
 captureMaps["SPELL_AURA_REMOVED_DOSE"] = captureMaps["SPELL_AURA_REMOVED"];
end


-------------------------------------------------------------------------------
-- Aura functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Populates the current auras table with current buff and debuff information.
-- ****************************************************************************
local function PopulateCurrentBuffsAndDebuffs()
 -- Erase the old current aura buffs and debuffs.
 EraseTable(currentAuras.buffs);
 EraseTable(currentAuras.debuffs);

 -- Loop through all of the buffs and add the name to the buffs table.
 local buffName, buffTexture;
 for buffIndex = 1, MAX_BUFFS do
  buffName, _, buffTexture = UnitBuff("player", buffIndex);
  if (not buffName) then break; end
  currentAuras.buffs[buffName] = buffTexture;
 end

 -- Loop through all of the debuffs and add the name to the debuffs table.
 for buffIndex = 1, MAX_DEBUFFS do
  buffName, _, buffTexture = UnitDebuff("player", buffIndex);
  if (not buffName) then break; end
  currentAuras.debuffs[buffName] = buffTexture;
 end
end


-- ****************************************************************************
-- Populates the parser event data table for an aura change or the passed type.
-- ****************************************************************************
local function DoAuraChange(tableName, auraType)
 -- Loop through all of the saved auras for the passed buff table to check for those that have faded.
 for buffName, buffTexture in pairs(savedAuras[tableName]) do
  if (not currentAuras[tableName][buffName]) then
   savedAuras[tableName][buffName] = nil;
   -- Ignore the fade if it was already seen via the combat log.
   if (not recentAuras[buffName]) then
    EraseTable(parserEvent);
    parserEvent.sourceGUID = GUID_NONE;
    parserEvent.sourceFlags = OBJECT_NONE;
    parserEvent.recipientName = playerName;
    parserEvent.recipientFlags = FLAGS_ME;
    parserEvent.recipientUnit = "player";
    parserEvent.eventType = "aura";
    parserEvent.isFade = true;
    parserEvent.auraType = auraType;
    parserEvent.skillName = buffName;
	parserEvent.skillTexture = buffTexture;
    SendParserEvent();
   end
   recentAuras[buffName] = nil;
  end
 end

 -- Loop through all of the current auras for the passed buff table to check for those that have been gained.
 for buffName, buffTexture in pairs(currentAuras[tableName]) do
  if (not savedAuras[tableName][buffName]) then
   savedAuras[tableName][buffName] = buffTexture;
   -- Ignore the gain if it was already seen via the combat log.
   if (not recentAuras[buffName]) then 
    EraseTable(parserEvent);
    parserEvent.sourceGUID = GUID_NONE;
    parserEvent.sourceFlags = OBJECT_NONE;
    parserEvent.recipientName = playerName;
    parserEvent.recipientFlags = FLAGS_ME;
    parserEvent.recipientUnit = "player";
    parserEvent.eventType = "aura";
    parserEvent.auraType = auraType;
    parserEvent.skillName = buffName;
	parserEvent.skillTexture = buffTexture;
    SendParserEvent();
   end
  end
 end
end


-- ****************************************************************************
-- Initializes the current auras.
-- ****************************************************************************
local function InitAuras()
 -- Populate the current buffs and debuffs.
 PopulateCurrentBuffsAndDebuffs();

 -- Save the current auras as the initial state.
 for tableName in pairs(currentAuras) do
  for buffName, buffTexture in pairs(currentAuras[tableName]) do
   savedAuras[tableName][buffName] = buffTexture;
  end
 end
 
 -- Set the auras initialized flag.
 aurasInitialized = true;
end


-------------------------------------------------------------------------------
-- Event handlers.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when there is information that needs to be obtained after a delay.
-- ****************************************************************************
local function OnUpdateDelayedInfo(this, elapsed)
 -- Check if the unit map needs to be updated after a delay.
 if (isUnitMapStale) then
  -- Increment the amount of time passed since the last update.
  lastUnitMapUpdate = lastUnitMapUpdate + elapsed;

  -- Check if it's time for an update.
  if (lastUnitMapUpdate >= UNIT_MAP_UPDATE_DELAY) then
   -- Update the player GUID if it isn't known yet and verify it's now known.
   if (not playerGUID) then playerGUID = UnitGUID("player"); end
   if (playerGUID) then
    -- Erase the unit map table.
    for key in pairs(unitMap) do unitMap[key] = nil; end

    -- Check if there are raid members.
    local numRaidMembers = GetNumRaidMembers();
    if (numRaidMembers > 0) then
     -- Loop through all of the raid members and add them.
     for i = 1, numRaidMembers do
      local unitID = "raid" .. i;
      unitMap[UnitGUID(unitID)] = unitID;
     end
    else
     -- Loop through all of the party members and add them.
     for i = 1, GetNumPartyMembers() do
      local unitID = "party" .. i;
	  unitMap[UnitGUID(unitID)] = unitID;
     end
    end

    -- Add the player.
    unitMap[playerGUID] = "player";
   
    -- Clear the unit map stale flag.
    isUnitMapStale = false;
   end

   -- Reset the time since last update.
   lastUnitMapUpdate = 0;
  end
 end -- Unit map is stale.

 -- Check if the pet map needs to be updated after a delay.
 if (isPetMapStale) then
  -- Increment the amount of time passed since the last update.
  lastPetMapUpdate = lastPetMapUpdate + elapsed;
  
  -- Check if it's time for an update.
  if (lastPetMapUpdate >= PET_UPDATE_DELAY) then
   -- Verify the player's pet is not in an unknown state if there is one.
   local petName = UnitName("pet");
   if (not petName or petName ~= UNKNOWN) then
    -- Erase the pet map table.
    for key in pairs(petMap) do petMap[key] = nil; end

    -- Check if there are raid members.
    local numRaidMembers = GetNumRaidMembers();
     if (numRaidMembers > 0) then
      -- Loop through all of the raid members and add their pets.
      for i = 1, numRaidMembers do
      local unitID = "raidpet" .. i;
	  if (UnitExists(unitID)) then petMap[UnitGUID(unitID)] = unitID; end
     end
    else
     -- Loop through all of the party members and add them.
     for i = 1, GetNumPartyMembers() do
      local unitID = "partypet" .. i;
	  if (UnitExists(unitID)) then petMap[UnitGUID(unitID)] = unitID; end
     end
    end

    -- Add the player's pet if there is one.
	if (petName) then petMap[UnitGUID("pet")] = "pet"; end

    -- Clear the pet map stale flag.
    isPetMapStale = false;
   end -- Pet in known state.

   -- Reset the time since last update.
   lastPetMapUpdate = 0;
  end
 end -- Pet map is stale.

 -- Stop receiving updates if no more data needs to be updated.
 if (not isUnitMapStale and not isPetMapStale) then this:Hide(); end
end


-- ****************************************************************************
-- Called when the events the parser registered for occur.
-- ****************************************************************************
local function OnEvent(this, event, arg1, arg2, ...)
 if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
  ParseLogMessage(arg1, arg2, ...);
 elseif (event == "PLAYER_AURAS_CHANGED") then
  -- Initialize the auras if they haven't already been.
  if (not aurasInitialized) then
   InitAuras();
   return;
  end

  -- Populate the current buffs and debuffs.
  PopulateCurrentBuffsAndDebuffs();

  -- Send events for buff and debuff changes.
  DoAuraChange("buffs", AURA_TYPE_BUFF);
  DoAuraChange("debuffs", AURA_TYPE_DEBUFF);

 -- Party/Raid changes
 elseif (event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE") then
  -- Set the unit map stale flag and schedule the unit map to be updated after a short delay.
  isUnitMapStale = true;
  eventFrame:Show();

 -- Pet changes
 elseif (event == "UNIT_PET") then
  isPetMapStale = true;
  eventFrame:Show();

 -- Chat message combat events.
 else
  ParseSearchMessage(event, arg1);
 end
end


-- ****************************************************************************
-- Enables parsing.
-- ****************************************************************************
local function Enable()
 -- Register for parameter style events going to the combat log.
 eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
 
 -- Register CHAT_MSG_X search style events.
 for event in pairs(searchMap) do
  eventFrame:RegisterEvent(event);
 end

 -- Register additional events for aura and overheal processing.
 eventFrame:RegisterEvent("PLAYER_AURAS_CHANGED");
 eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
 eventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
 eventFrame:RegisterEvent("UNIT_PET"); 

 -- Update the unit map and current pet information.
 isUnitMapStale = true;
 isPetNameStale = true;

 -- Start receiving updates.
 eventFrame:Show();
end


-- ****************************************************************************
-- Disables the parsing.
-- ****************************************************************************
local function Disable()
 -- Stop receiving updates.
 eventFrame:Hide();
 eventFrame:UnregisterAllEvents();
 
 -- Erase the saved and recent aura tables.
 EraseTable(recentAuras);
 EraseTable(savedAuras.buffs);
 EraseTable(savedAuras.debuffs)
 aurasInitialized = nil;
 
 -- Erase the reflected skill tables.
 EraseTable(reflectedTimes);
 EraseTable(reflectedSkills);
end


-- ****************************************************************************
-- Called when the parser is loaded.
-- ****************************************************************************
local function OnLoad()
 -- Create a frame to receive events.
 eventFrame = CreateFrame("Frame");
 eventFrame:Hide();
 eventFrame:SetScript("OnEvent", OnEvent);
 eventFrame:SetScript("OnUpdate", OnUpdateDelayedInfo);

 -- Get the name and GUID of the player.
 playerName = UnitName("player");
 playerGUID = UnitGUID("player");
 
 -- Create various maps.
 CreateSearchMap();
 CreateSearchCaptureMaps();
 CreateCaptureMaps();
 
 -- Create the list of events that should be fully parsed.
 CreateFullParseList();

 -- Find the rarest word for each supported global string.
 FindRareWords();
 ValidateRareWords();

 -- Convert the supported global strings into lua search patterns.
 ConvertGlobalStrings();
end




-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- Protected Constants.
module.AFFILIATION_MINE		= AFFILIATION_MINE;
module.AFFILIATION_PARTY	= AFFILIATION_PARTY;
module.AFFILIATION_RAID		= AFFILIATION_RAID;
module.AFFILIATION_OUTSIDER	= AFFILIATION_OUTSIDER;
module.REACTION_FRIENDLY	= REACTION_FRIENDLY;
module.REACTION_NEUTRAL		= REACTION_NEUTRAL;
module.REACTION_HOSTILE		= REACTION_HOSTILE;
module.CONTROL_HUMAN		= CONTROL_HUMAN;
module.CONTROL_SERVER		= CONTROL_SERVER;
module.UNITTYPE_PLAYER		= UNITTYPE_PLAYER;
module.UNITTYPE_NPC			= UNITTYPE_NPC;
module.UNITTYPE_PET			= UNITTYPE_PET;
module.UNITTYPE_GUARDIAN	= UNITTYPE_GUARDIAN;
module.UNITTYPE_OBJECT		= UNITTYPE_OBJECT;
module.TARGET_TARGET		= TARGET_TARGET;
module.TARGET_FOCUS			= TARGET_FOCUS;
module.OBJECT_NONE			= OBJECT_NONE;

-- Protected Variables.
module.currentAuras = currentAuras;
module.unitMap = unitMap;

-- Protected Functions.
module.RegisterHandler				= RegisterHandler;
module.UnregisterHandler			= UnregisterHandler;
module.TestFlagsAny					= TestFlagsAny;
module.TestFlagsAll					= TestFlagsAll;
module.Enable						= Enable;
module.Disable						= Disable;


-------------------------------------------------------------------------------
-- Load.
-------------------------------------------------------------------------------

OnLoad();