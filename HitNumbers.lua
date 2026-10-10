-- HitNumbers: retail-style floating combat numbers.
-- Damage and heals pop up over the nameplate of whoever they landed on; anything that
-- lands on you floats above your character. Needs two OctoWoW launcher mods:
--   nampower   - SPELL_DAMAGE_EVENT_*, AUTO_ATTACK_*, SPELL_HEAL_* events carrying GUIDs
--   ClassicAPI - NAME_PLATE_UNIT_ADDED/REMOVED and C_NamePlate.GetNamePlateForUnit

local DB
local FONT = "Fonts\\FRIZQT__.TTF"
local DURATION = 1.4
local POOL_MAX = 40

local DEFAULTS = {
  enabled = true,
  scale = 1,
  selfY = 60,     -- how far above screen centre your own numbers float
  onSelf = false, -- numbers on yourself (Blizzard combat text already shows these)
  pet = true,     -- your pet's damage
}

local SCHOOL = {
  [0] = { 1, 1, 1 },        -- physical
  [1] = { 1, 0.9, 0.5 },    -- holy
  [2] = { 1, 0.5, 0.15 },   -- fire
  [3] = { 0.45, 1, 0.3 },   -- nature
  [4] = { 0.5, 0.85, 1 },   -- frost
  [5] = { 0.7, 0.45, 1 },   -- shadow
  [6] = { 1, 0.5, 1 },      -- arcane
}
local HEAL = { 0.2, 1, 0.2 }
local TAKEN = { 1, 0.25, 0.25 }
local PET = { 0.75, 0.75, 0.75 }
local MISS = { 0.75, 0.75, 0.75 }

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100HitNumbers|r: " .. msg)
end

-- nampower and UnitGUID don't always agree on case/padding, so compare a stripped form
local function Norm(guid)
  if not guid or guid == "" then
    return nil
  end
  guid = string.upper(guid)
  guid = string.gsub(guid, "^0X", "")
  guid = string.gsub(guid, "^0+", "")
  return guid
end

local function Has(value, flag)
  return math.mod(math.floor((tonumber(value) or 0) / flag), 2) == 1
end

-- [[ nameplate tracking ]] --
local plates = {}      -- normalized guid -> nameplate frame
local playerGuid, petGuid

local function SafeGuid(unit)
  if not UnitGUID then
    return nil
  end
  local ok, guid = pcall(UnitGUID, unit)
  return ok and guid or nil
end

local function PlateFor(raw)
  local guid = Norm(raw)
  local plate = plates[guid]
  if plate and plate:IsVisible() then
    return plate
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return nil
  end
  if guid == Norm(SafeGuid("target")) then
    plate = C_NamePlate.GetNamePlateForUnit("target")
  else
    -- SuperWoW lets a GUID stand in for a unit token
    local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, raw)
    plate = ok and p or nil
  end
  if plate and plate:IsVisible() then
    plates[guid] = plate
    return plate
  end
end

-- the number sits on pfUI's health bar when pfUI owns the plate
local function PlateAnchor(plate)
  if plate.nameplate and plate.nameplate.health and plate.nameplate.health:IsVisible() then
    return plate.nameplate.health
  end
  return plate.nameplate or plate
end

-- [[ floaters ]] --
local pool, active = {}, {}

local function Release(f)
  f:Hide()
  f:SetScript("OnUpdate", nil)
  f.anchor = nil
  for i, a in ipairs(active) do
    if a == f then
      table.remove(active, i)
      break
    end
  end
  table.insert(pool, f)
end

local function Animate(f, elapsed)
  f.age = f.age + elapsed
  local t = f.age / DURATION
  if t >= 1 then
    Release(f)
    return
  end

  -- crits punch in big, settle, then drift up slower than normal hits
  local pop = 1
  if f.crit then
    if f.age < 0.1 then
      pop = 1 + 1.3 * (f.age / 0.1)
    elseif f.age < 0.25 then
      pop = 2.3 - 0.8 * ((f.age - 0.1) / 0.15)
    else
      pop = 1.5
    end
  end
  local scale = pop * f.size * DB.scale
  local rise = (f.crit and 35 or 75) * t
  local alpha = t < 0.6 and 1 or 1 - (t - 0.6) / 0.4

  f:SetScale(scale)
  f:SetAlpha(alpha)
  f:ClearAllPoints()
  f:SetPoint("BOTTOM", f.anchor, f.relPoint, (f.ox + f.dx) / scale, (f.oy + f.dy + rise) / scale)
end

local function OnUpdate()
  Animate(this, arg1)
end

local function Spawn(anchor, relPoint, ox, oy, text, color, crit, size)
  local f = table.remove(pool)
  if not f then
    if table.getn(active) >= POOL_MAX then
      f = active[1]
      Release(f)
      f = table.remove(pool)
    else
      f = CreateFrame("Frame", nil, UIParent)
      f:SetFrameStrata("HIGH")
      f:SetWidth(240)
      f:SetHeight(48)
      f.text = f:CreateFontString(nil, "OVERLAY")
      f.text:SetPoint("BOTTOM", 0, 0)
      f.text:SetFont(FONT, 24, "OUTLINE")
      f.text:SetShadowOffset(1, -1)
      f.text:SetShadowColor(0, 0, 0, 0.8)
    end
  end

  f.anchor = anchor
  f.relPoint = relPoint
  f.ox, f.oy = ox, oy
  f.dx = crit and 0 or math.random(-40, 40)
  f.dy = crit and 0 or math.random(0, 14)
  f.crit = crit
  f.size = size or 1
  f.age = 0
  f.text:SetText(tostring(text))
  f.text:SetTextColor(color[1], color[2], color[3])
  f:SetScript("OnUpdate", OnUpdate)
  table.insert(active, f)
  f:Show()
  -- place it once now so it doesn't flash at the old spot for a frame
  Animate(f, 0)
end

-- [[ where a number goes ]] --
local function ShowOnSelf(text, color, crit, size, force)
  if not DB.enabled or not (DB.onSelf or force) then
    return
  end
  Spawn(UIParent, "CENTER", 0, DB.selfY, text, color, crit, size)
end

local function ShowOn(raw, text, color, crit, size)
  if not DB.enabled or not raw then
    return
  end
  if Norm(raw) == playerGuid then
    ShowOnSelf(text, color, crit, size)
    return
  end
  local plate = PlateFor(raw)
  if plate then
    Spawn(PlateAnchor(plate), "TOP", 0, 10, text, color, crit, size)
  elseif Norm(raw) == Norm(SafeGuid("target")) then
    -- target with nameplates off: still give feedback, higher up than your own numbers
    Spawn(UIParent, "CENTER", 0, DB.selfY + 140, text, color, crit, size)
  end
end

local function AutoAttackText(damage, hitInfo, victimState)
  if Has(hitInfo, 16) then
    return "Miss", MISS
  elseif victimState == 2 then
    return "Dodge", MISS
  elseif victimState == 3 then
    return "Parry", MISS
  elseif (tonumber(damage) or 0) == 0 then
    if victimState == 5 then
      return "Block", MISS
    elseif Has(hitInfo, 32) then
      return "Absorb", MISS
    elseif Has(hitInfo, 64) then
      return "Resist", MISS
    end
    return nil
  end
end

-- [[ events ]] --
local events = CreateFrame("Frame")

local COMBAT_EVENTS = {
  "SPELL_DAMAGE_EVENT_SELF", "SPELL_DAMAGE_EVENT_OTHER",
  "AUTO_ATTACK_SELF", "AUTO_ATTACK_OTHER",
  "SPELL_HEAL_BY_SELF", "SPELL_HEAL_ON_SELF",
}

local function Setup()
  HitNumbersDB = HitNumbersDB or {}
  DB = HitNumbersDB
  for k, v in pairs(DEFAULTS) do
    if DB[k] == nil then
      DB[k] = v
    end
  end

  -- pfUI's combat font, unless it's the invisible one people pick to hide combat text
  local combat = pfUI and pfUI.font_combat
  if combat and not string.find(combat, "AdobeBlank") then
    FONT = combat
  end

  -- nampower ships these off by default; they're what feeds us
  for _, cvar in ipairs({ "NP_EnableAutoAttackEvents", "NP_EnableSpellHealEvents" }) do
    pcall(SetCVar, cvar, "1")
  end

  local missing = {}
  for _, e in ipairs(COMBAT_EVENTS) do
    if not pcall(events.RegisterEvent, events, e) then
      table.insert(missing, e)
    end
  end
  if table.getn(missing) > 0 then
    Print("nampower events missing (" .. table.concat(missing, ", ") .. "). Is nampower enabled in the launcher?")
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    Print("C_NamePlate not found, so numbers can't follow nameplates. Is ClassicAPI enabled?")
  end
  pcall(events.RegisterEvent, events, "NAME_PLATE_UNIT_ADDED")
  pcall(events.RegisterEvent, events, "NAME_PLATE_UNIT_REMOVED")
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_PET")
events:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "HitNumbers" then
      Setup()
    end
    return
  end
  if not DB then
    return
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
    playerGuid = Norm(SafeGuid("player"))
    petGuid = Norm(SafeGuid("pet"))

  elseif event == "NAME_PLATE_UNIT_ADDED" then
    local guid = Norm(SafeGuid(arg1))
    if guid then
      plates[guid] = C_NamePlate.GetNamePlateForUnit(arg1)
    end

  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local guid = Norm(SafeGuid(arg1))
    local plate = guid and plates[guid]
    if plate then
      plates[guid] = nil
      -- the frame gets reused for another unit, so drop anything riding on it
      local anchor = PlateAnchor(plate)
      for i = table.getn(active), 1, -1 do
        local f = active[i]
        if f.anchor == anchor or f.anchor == plate or f.anchor == plate.nameplate then
          Release(f)
        end
      end
    end

  elseif event == "SPELL_DAMAGE_EVENT_SELF" then
    -- targetGuid, casterGuid, spellId, amount, mitigation, hitInfo, school
    local amount = tonumber(arg4) or 0
    if amount > 0 then
      ShowOn(arg1, amount, SCHOOL[tonumber(arg7) or 0] or SCHOOL[0], Has(arg6, 2))
    end

  elseif event == "SPELL_DAMAGE_EVENT_OTHER" then
    local amount = tonumber(arg4) or 0
    if amount <= 0 then
      return
    end
    if Norm(arg1) == playerGuid then
      ShowOnSelf(amount, TAKEN, Has(arg6, 2), 0.8)
    elseif DB.pet and petGuid and Norm(arg2) == petGuid then
      ShowOn(arg1, amount, PET, Has(arg6, 2), 0.75)
    end

  elseif event == "AUTO_ATTACK_SELF" then
    -- attackerGuid, targetGuid, damage, hitInfo, victimState, subDamageCount, blocked, absorbed, resisted
    local label, color = AutoAttackText(arg3, arg4, tonumber(arg5))
    if label then
      ShowOn(arg2, label, color, false, 0.8)
    elseif (tonumber(arg3) or 0) > 0 then
      ShowOn(arg2, arg3, SCHOOL[0], Has(arg4, 128), Has(arg4, 16384) and 0.8 or 1)
    end

  elseif event == "AUTO_ATTACK_OTHER" then
    local victim, attacker = Norm(arg2), Norm(arg1)
    if victim == playerGuid then
      local label, color = AutoAttackText(arg3, arg4, tonumber(arg5))
      if label then
        ShowOnSelf(label, color, false, 0.7)
      elseif (tonumber(arg3) or 0) > 0 then
        ShowOnSelf(arg3, TAKEN, Has(arg4, 128), 0.8)
      end
    elseif DB.pet and petGuid and attacker == petGuid and (tonumber(arg3) or 0) > 0 then
      ShowOn(arg2, arg3, PET, Has(arg4, 128), 0.75)
    end

  elseif event == "SPELL_HEAL_BY_SELF" then
    -- targetGuid, casterGuid, spellId, amount, critical, periodic
    local amount = tonumber(arg4) or 0
    if amount > 0 then
      ShowOn(arg1, "+" .. amount, HEAL, tonumber(arg5) == 1, tonumber(arg6) == 1 and 0.75 or 1)
    end

  elseif event == "SPELL_HEAL_ON_SELF" then
    -- your own heals on yourself already came through SPELL_HEAL_BY_SELF
    local amount = tonumber(arg4) or 0
    if amount > 0 and Norm(arg2) ~= playerGuid then
      ShowOnSelf("+" .. amount, HEAL, tonumber(arg5) == 1, tonumber(arg6) == 1 and 0.65 or 0.85)
    end
  end
end)

-- [[ slash command ]] --
local function Toggle(key, label)
  DB[key] = not DB[key]
  Print(label .. " " .. (DB[key] and "on" or "off"))
end

SLASH_HITNUMBERS1 = "/hn"
SLASH_HITNUMBERS2 = "/hitnumbers"
SlashCmdList["HITNUMBERS"] = function(msg)
  local _, _, cmd, rest = string.find(string.lower(msg or ""), "^(%S*)%s*(.-)$")
  if cmd == "test" then
    local target = SafeGuid("target")
    if target then
      ShowOn(target, 123, SCHOOL[0], false)
      ShowOn(target, 456, SCHOOL[1], true)
      ShowOn(target, "Dodge", MISS, false, 0.8)
    else
      Print("target something with its nameplate showing to test numbers over it")
    end
    ShowOnSelf("+250", HEAL, false, 1, true)
    ShowOnSelf(42, TAKEN, false, 0.8, true)
  elseif cmd == "on" or cmd == "off" then
    DB.enabled = cmd == "on"
    Print(DB.enabled and "on" or "off")
  elseif cmd == "scale" and tonumber(rest) then
    DB.scale = math.max(0.5, math.min(3, tonumber(rest)))
    Print("scale " .. DB.scale)
  elseif cmd == "self" and tonumber(rest) then
    DB.selfY = tonumber(rest)
    Print("your own numbers now float " .. DB.selfY .. " above screen centre")
  elseif cmd == "me" then
    Toggle("onSelf", "numbers on yourself")
  elseif cmd == "pet" then
    Toggle("pet", "pet damage")
  else
    Print("/hn test  show sample numbers")
    Print("/hn on | off")
    Print("/hn scale <0.5-3>  size of the numbers (now " .. DB.scale .. ")")
    Print("/hn self <pixels>  height of your own numbers (now " .. DB.selfY .. ")")
    Print("/hn me  toggle numbers on yourself (now " .. (DB.onSelf and "on" or "off") .. ")")
    Print("/hn pet  toggle pet damage")
  end
end

-- update notices (version.lua)
if SnapVersions then SnapVersions.Register("HitNumbers") end
