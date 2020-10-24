local _NAME = "LibDatabaseOptions"
local _VERSION = "1.0.0"
local _LICENSE = [[
    MIT License

    Copyright (c) 2020 Jayrgo

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

assert(LibMan1, format("%s requires LibMan-1.x.x.", _NAME))
assert(LibMan1:Exists("LibMixin", 1), format("%s requires LibMixin-1.x.x.", _NAME))

local Lib --[[ , oldVersion ]] = LibMan1:New(_NAME, _VERSION, "_LICENSE", _LICENSE)
if not Lib then return end

local L = {
    PROFILES = "Profiles",
    COPY_FROM = "Copy From",
    CURRENT = "Current",
    DELETE = DELETE,
    LAST_CONFIGURATION_CHANGE = "Last configuration change at",
    NEW = NEW,
}

if GetLocale() == "deDE" then
    L.PROFILES = "Profile"
    L.COPY_FROM = "Kopiere von"
    L.CURRENT = "Aktuell"
    L.LAST_CONFIGURATION_CHANGE = "Letzte Konfigurationsänderung um"
end

---@class OptionHandler
local OptionHandlerMixin = {}

---@param info table
---@return string
function OptionHandlerMixin:GetProfile(info) return self.db:GetProfile() end

---@param info table
---@param value string
function OptionHandlerMixin:SetProfile(info, value) if value then self.db:SetProfile(value) end end

local DEFAULT_PROFILES = {
    [UnitName("player") .. " - " .. GetRealmName()] = UnitName("player") .. " - " .. GetRealmName(),
    [GetRealmName()] = GetRealmName(),
    [UnitFactionGroup("player")] = select(2, UnitFactionGroup("player")),
    [select(2, UnitRace("player"))] = UnitRace("player"),
    [select(2, UnitClass("player"))] = UnitClass("player"),
}

---@param info table
---@return table
function OptionHandlerMixin:GetCurrentProfiles(info)
    local profiles = self.db:GetProfiles()
    for i = 1, #profiles do
        local profile = profiles[i]
        profiles[profile] = profile
        profiles[i] = nil
    end
    for k, v in pairs(DEFAULT_PROFILES) do profiles[k] = v end
    return profiles
end

---@param info table
---@return table
function OptionHandlerMixin:GetProfiles(info)
    local profiles = self.db:GetProfiles()
    local currentProfile = self.db:GetProfile()
    for i = 1, #profiles do
        local profile = profiles[i]
        profiles[profile] = profile ~= currentProfile and
                                (DEFAULT_PROFILES[profile] and DEFAULT_PROFILES[profile] or profile) or nil
        profiles[i] = nil
    end
    return profiles
end

---@param info table
---@param value string
function OptionHandlerMixin:CopyProfile(info, value) if value then self.db:CopyProfile(value) end end

---@param info table
---@param value string
function OptionHandlerMixin:DeleteProfile(info, value) if value then self.db:DeleteProfile(value) end end

---@param info table
function OptionHandlerMixin:ResetProfile(info) self.db:ResetProfile(self.db:GetProfile()) end

---@param info table
---@return string
function OptionHandlerMixin:LastChange(info) return "|cffffffff" .. self.db:GetLastChange() .. "|r" end

Lib.handlers = Lib.handlers or {}
local handlers = Lib.handlers

local LibMixin = LibMan1:Get("LibMixin", 1)
for k, v in pairs(handlers) do LibMixin:Mixin(v, OptionHandlerMixin) end -- upgrade

---@param db Database
---@return OptionHandler
local function getOptionHandler(db)
    ---@type OptionHandler
    local handler = handlers[db] or LibMixin:Mixin({db = db}, OptionHandlerMixin)
    handlers[db] = handler
    return handler
end

local strtrim = strtrim

---@param arg table
---@param value string
---@return string
local function onSet(arg, value) return strtrim(value) end

local strlen = strlen

---@param arg table
---@param value string
---@return boolean
local function validate(arg, value) return strlen(value) > 0 end

local OPTION_LIST = {
    {type = "select", text = L.CURRENT, get = "GetProfile", set = "SetProfile", values = "GetCurrentProfiles"},
    {type = "string", text = L.NEW, set = "SetProfile", onSet = onSet, validate = validate},
    {type = "select", text = L.COPY_FROM, set = "CopyProfile", values = "GetProfiles"},
    {type = "select", text = L.DELETE, set = "DeleteProfile", values = "GetProfiles"},
    --[[ {type = "function", text = L.RESET, func = "ResetProfile"}, ]]
    {type = "string", text = L.LAST_CONFIGURATION_CHANGE, get = "LastChange", isReadOnly = true, justifyH = "RIGHT"},
}

local error = error
local format = format
local tostring = tostring
local type = type
local LibOptions = LibMan1:Get("LibOptions", 1)

---@param db Database
---@param parent string
---@return table
function Lib:New(db, parent)
    if type(db) ~= "table" then
        error(format("Usage: %s:New(db[, parent]): 'db' - table expected got %s", tostring(Lib), type(db)), 2)
    end
    if parent then
        if type(parent) ~= "string" then
            error(format("Usage: %s:New(db[, parent]): 'parent' - string expected got %s", tostring(Lib), type(parent)),
                  2)
        end
        local optionList = {handler = getOptionHandler(db)}
        for i = 1, #OPTION_LIST do optionList[i] = OPTION_LIST[i] end
        LibOptions:New(L.PROFILES, parent, optionList)
    else
        return {type = "header", text = L.PROFILES, handler = getOptionHandler(db), optionList = OPTION_LIST}
    end
end
setmetatable(Lib, {__call = Lib.New})

---@type table<Database, function[]>
Lib.optionsFuncs = Lib.optionsFuncs or {}
local optionsFuncs = Lib.optionsFuncs

---@type table<Database, function[]>
Lib.globalOptionsFuncs = Lib.globalOptionsFuncs or {}
local globalOptionsFuncs = Lib.globalOptionsFuncs

local select = select
local unpack = unpack

---@param db Database
---@param global boolean
---@return function
---@return function
---@return function
function Lib:GetOptionFunctions(db, global)
    if type(db) ~= "table" then
        error(
            format("Usage: %s:GetOptionFunctions(db[, global]): 'db' - table expected got %s", tostring(Lib), type(db)),
            2)
    end

    local tbl = global and globalOptionsFuncs or optionsFuncs
    if not tbl[db] then
        tbl[db] = {
            function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                elseif info.type == "color" then
                    local color
                    if global then
                        color = db:GetGlobal(unpack(info, 1, #info))
                    else
                        color = db:Get(unpack(info, 1, #info))
                    end
                    return color.r, color.g, color.b, info.hasAlpha and color.a
                end
                if global then
                    return db:GetGlobal(unpack(info, 1, #info))
                else
                    return db:Get(unpack(info, 1, #info))
                end
            end,
            function(info, ...)
                if info.type == "select" and info.isMulti then
                    info[#info + 1] = ...
                    if global then
                        db:SetGlobal(select(2, ...), unpack(info, 1, #info))
                    else
                        db:Set(select(2, ...), unpack(info, 1, #info))
                    end
                elseif info.type == "color" then
                    local r, g, b, a = ...

                    info[#info + 1] = "r"
                    if global then
                        db:SetGlobal(r, unpack(info, 1, #info))
                    else
                        db:Set(r, unpack(info, 1, #info))
                    end

                    info[#info] = "g"
                    if global then
                        db:SetGlobal(g, unpack(info, 1, #info))
                    else
                        db:Set(g, unpack(info, 1, #info))
                    end

                    info[#info] = "b"
                    if global then
                        db:SetGlobal(b, unpack(info, 1, #info))
                    else
                        db:Set(b, unpack(info, 1, #info))
                    end

                    if info.hasAlpha then
                        info[#info] = "a"
                        if global then
                            db:SetGlobal(a, unpack(info, 1, #info))
                        else
                            db:Set(a, unpack(info, 1, #info))
                        end
                    end
                else
                    if global then
                        db:SetGlobal(..., unpack(info, 1, #info))
                    else
                        db:Set(..., unpack(info, 1, #info))
                    end
                end
            end,
            function(info, ...)
                if info.type == "select" and info.isMulti then
                elseif info.type == "color" then
                    local color
                    if global then
                        color = db:GetGlobalDefault(unpack(info, 1, #info))
                    else
                        color = db:GetDefault(unpack(info, 1, #info))
                    end
                    if info.hasAlpha then
                        return color.r, color.g, color.b, color.a
                    else
                        return color.r, color.g, color.b
                    end
                else
                    if global then
                        return db:GetGlobal(unpack(info, 1, #info))
                    else
                        return db:GetDefault(unpack(info, 1, #info))
                    end
                end
            end,
        }
    end

    return unpack(tbl[db])
end
