-- 脚本的位置是 "{命名空间}:{路径}"，那么 require 的格式为 "{命名空间}_{路径}"
-- 注意！require 取得的内容不应该被修改，应仅调用
local default = require("hamster_lebel1886_state_machine")
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local MAIN_TRACK = default.MAIN_TRACK
local main_track_states = default.main_track_states

local idle_state = setmetatable({}, {__index = main_track_states.idle})

local reload_state = setmetatable({}, {__index = main_track_states.reload})

local function isNoAmmo(context)
    return (not context:hasBulletInBarrel()) and (context:getAmmoCount() <= 0)
end

function idle_state.transition(this, context, input)
    if (input == INPUT_RELOAD) then
        return this.main_track_states.reload
    end
    return main_track_states.idle.transition(this, context, input)
end

-- 并初始化 需要的弹药数、已装填的弹药数。这决定了后续的 'loop' 动画进行几次循环。
function reload_state.entry(this, context)
    if (isNoAmmo(context)) then
        main_track_states.reload.emptyload = 1
        context:runAnimation("reload_start_empty", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    else
        context:runAnimation("reload_start", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    end
    main_track_states.reload.need_ammo = context:getMaxAmmoCount() - context:getAmmoCount()
    main_track_states.reload.loaded_ammo = 0
end

function reload_state.update(this, context)
    if (main_track_states.reload.loaded_ammo > main_track_states.reload.need_ammo or not context:hasAmmoToConsume()) then
        context:trigger(main_track_states.reload.retreat)
    else
        local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
        -- 等待 intro 结束，然后循环播放 loop 动画
        if(context:isHolding(track)) then
            if(main_track_states.reload.emptyload == 1) then
                if(main_track_states.reload.loaded_ammo == 0) then
                    context:runAnimation("reload_loop_start", track, false, PLAY_ONCE_HOLD, 0.2)
                elseif(main_track_states.reload.loaded_ammo == main_track_states.reload.need_ammo - 1) then
                    context:runAnimation("reload_loop_end", track, false, PLAY_ONCE_HOLD, 0.2)
                else
                    context:runAnimation("reload_loop", track, false, PLAY_ONCE_HOLD, 0.2)
                end
                main_track_states.reload.loaded_ammo = main_track_states.reload.loaded_ammo + 1
            else
                context:runAnimation("reload_loop", track, false, PLAY_ONCE_HOLD, 0.2)
                main_track_states.reload.loaded_ammo = main_track_states.reload.loaded_ammo + 1
            end
        end
    end
end

function reload_state.transition(this, context, input)
    if (input == main_track_states.reload.retreat or input == INPUT_CANCEL_RELOAD) then
        if(main_track_states.reload.emptyload == 1) then
            context:runAnimation("reload_end_empty", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
            main_track_states.reload.emptyload = 0
        else
            context:runAnimation("reload_end", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
        end
        return main_track_states.idle
    end
    return this.main_track_states.idle.transition(this, context, input)
end

local M = setmetatable({
    main_track_states = setmetatable({
        idle = idle_state,
        reload = reload_state
    }, {__index = main_track_states})
}, {__index = default})
-- 先调用父级状态机的初始化函数，然后进行自己的初始化
function M:initialize(context)
    default.initialize(self, context)
end
-- 导出状态机
return M