-- author : BeerShigachi
-- date : 18 May 2024
-- version : 1.1.0


if reframework.get_commit_count() < 1645 then
	re.msg("SwiftCast - Spellhold Every Spell: Your REFramework is older version.\n If the mod does not work, Get version `REF Nightly 913` from\nhttps://github.com/praydog/REFramework-nightly/releases")
end

local _character_manager
local function GetCharacterManager()
    if not _character_manager then
        _character_manager = sdk.get_managed_singleton("app.CharacterManager")
    end
	return _character_manager
end

-- local function _get_component(value, func, name)
--     if not value then
--         local this_ = func()
--         if this_ then
--             value = this_:call(name)
--         end
--     end
--     return value
-- end

local _player_chara
local function GetManualPlayer()
    if not _player_chara then
        local characterManager = GetCharacterManager()
        if characterManager then
            _player_chara = characterManager:get_ManualPlayer()
        end
    end
    return _player_chara
end


-- _player_chara:get_GameObject():get_Transform()
local function get_skill_mapping(type)
    local type_ = sdk.find_type_definition(type)
    local fields = type_:get_fields()
    local skill_mapping = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local raw_value = field:get_data(nil)
            if raw_value ~= nil then
                local name = field:get_name()
                skill_mapping[name] = raw_value
            end
        end
    end

    return skill_mapping
end

local skills_mapping = get_skill_mapping("app.HumanCustomSkillID")

local mage_spells = {}
for name, skillID in pairs(skills_mapping) do
    if (skillID >= 24 and skillID <= 37 or skillID >= 62 and skillID <= 69) and skillID ~= 27 then
        mage_spells[name] = skillID
    end
end


local mage_spell_names = {}
for name, _ in pairs(mage_spells) do
    table.insert(mage_spell_names, name)
end
table.sort(mage_spell_names)

local current_skill = 0
local chosen_spell_name
local chosen_spell_id
local buffer = 2.0 -- default value
re.on_draw_ui(function()
    if imgui.tree_node("Swiftcast") then
        imgui.text("Swiftcast")
        if imgui.button("Reset") then
            current_skill = 0
        end

        local changed_, new_ = imgui.drag_float("Hold time", buffer, 0.01, 0.1, 20, "%.2f seconds")
        if changed_ then
            buffer = new_
        end


        local changed, new_thing = imgui.combo("List of spells", current_skill, mage_spell_names)
        if changed then
            current_skill = new_thing
            chosen_spell_name = mage_spell_names[current_skill]
            chosen_spell_id = mage_spells[chosen_spell_name]
            print(chosen_spell_name, "skillID", chosen_spell_id)
        end
        imgui.tree_pop()
    end
    
end)

local timer = os.clock()
local elapsed_time_ = 0.0
local ready_to_stock = false
local origial_weapon_job
sdk.hook(sdk.find_type_definition("app.Job06ActionController"):get_method("update()"),
function (args)
    local this = sdk.to_managed_object(args[2])
    if this["Chara"] == _player_chara then
        local this_magic_user_context = this["<JobMagicUserActionContext>k__BackingField"]
        local this_human = this["Human"]
        local this_track = this_human["Track"]
        if this_track["Skill"] and not this_track["EvasionBuffer"] then
            elapsed_time_ = 0.0
            ready_to_stock = false
            return
        end
        local this_spell_stock_controller = this_human["<SpellStockCtrl>k__BackingField"]
        local this_weapon = this_spell_stock_controller["Weapon"]
        local this_job = this_human["<JobContext>k__BackingField"]["CurrentJob"]
        if this_weapon == nil then return end
        if origial_weapon_job == nil then
            origial_weapon_job = this_weapon["Job"]
        end
        if current_skill == 0 and origial_weapon_job ~= nil then
            if this_job == 6 or this_job == 3 then
            elseif this_job == 10 then
                this_weapon["Job"] = origial_weapon_job
                this_magic_user_context["WeaponJob"] = origial_weapon_job
            end
            this_magic_user_context["StockedSpellJob06"] = 0
            this_magic_user_context["StockedSpellJob03"] = 0
            return
        end
        if origial_weapon_job == nil then
            origial_weapon_job = this_weapon["Job"]
        end
        if ready_to_stock  then
            local current_freme = os.clock()
            local deltatime = current_freme - timer
            elapsed_time_ = elapsed_time_ + deltatime
            timer = current_freme
        else
            elapsed_time_ = 0.0
            timer = os.clock()
        end
        if elapsed_time_ > buffer and not this_spell_stock_controller["<IsReadyStockedSpellCast>k__BackingField"] and not this_spell_stock_controller["IsEffectStarted"] then
            if chosen_spell_id == 24 or chosen_spell_id == 26 or chosen_spell_id == 25 then
                this_weapon["Job"] = origial_weapon_job
                this_magic_user_context["WeaponJob"] = origial_weapon_job
                if origial_weapon_job == 3 then
                    this_magic_user_context["StockedSpellJob03"] = chosen_spell_id
                elseif origial_weapon_job == 6 then
                    this_magic_user_context["StockedSpellJob06"] = chosen_spell_id
                end
           
            else
                if chosen_spell_id < 40 then
                    -- mage
                    this_weapon["Job"] = 3
                    this_magic_user_context["WeaponJob"] = 3
                    this_magic_user_context["StockedSpellJob03"] = chosen_spell_id
                elseif chosen_spell_id > 40 then
                    -- sorcerer
                    this_weapon["Job"] = 6
                    this_magic_user_context["WeaponJob"] = 6
                    this_magic_user_context["StockedSpellJob06"] = chosen_spell_id
                end
            end
            ready_to_stock = false
            -- print("stock spell", chosen_spell_id, this_weapon["Job"], this_magic_user_context["StockedSpellJob03"])
        elseif ready_to_stock == false and this_spell_stock_controller["IsEffectStarted"] ~= nil and this_spell_stock_controller["<IsReadyStockedSpellCast>k__BackingField"] ~= nil and this_spell_stock_controller["IsReadyEffectActive"] ~= nil then
            this_weapon["Job"] = origial_weapon_job
            this_magic_user_context["WeaponJob"] = origial_weapon_job
            this_magic_user_context["StockedSpellJob06"] = 0
            this_magic_user_context["StockedSpellJob03"] = 0
        end
    end
end,
function (rtval)
    return rtval
end)


sdk.hook(sdk.find_type_definition("app.HumanSkillContext"):get_method("isCustomSkillEnable"),
function (args)
    local this = sdk.to_managed_object(args[2])
    if _player_chara == nil then return end
    if this == _player_chara["<Human>k__BackingField"]["<SkillContext>k__BackingField"] then
        ready_to_stock = true
    end
end,
function (rtval)
    return rtval
end)

sdk.hook(sdk.find_type_definition("app.JobContext"):get_method("setJobChanged(app.Character.JobEnum)"),
    function ()
        -- specify chara  here.
        origial_weapon_job = nil
    end,
    function (rtval)
        return rtval
    end)

local function init_()
    _player_chara = nil
    _player_chara = GetManualPlayer()
    elapsed_time_ = 0.0
    ready_to_stock = false
end

init_()

re.on_script_reset(function ()
    init_()
end)

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function(rtval)
        init_()
        return rtval
    end
)
