local M = {}

function M.shoot(api)
    api:shootOnce(true)
end

function M.start_reload(api)
    -- Get the cached data, ensure it's not nil
    local cache = api:getCachedScriptData()

    -- If cache is nil, initialize it to an empty table
    if cache == nil then
        cache = {}
    end

    cache.reloaded_count = 0
    cache.needed_count = api:getNeededAmmoAmount()
    cache.is_tactical = api:getReloadStateType() == TACTICAL_RELOAD_FEEDING
    cache.interrupted_time = -1
    if (cache.vacancy == nil) then
        cache.vacancy = false
    elseif (not cache.is_tactical and api:getFireMode() == AUTO) then
        cache.vacancy = true
    end

    api:cacheScriptData(cache)
    return true
end

local function getReloadTimingFromParam(param)
    -- Need to convert time from seconds to milliseconds
    local intro = param.intro * 1000
    local intro_empty = param.intro_empty * 1000
    local loop = param.loop * 1000
    local ending = param.ending * 1000
    local loop_feed = param.loop_feed * 1000

    local fanning_intro = param.fanning_intro * 1000
    local fanning_intro_empty = param.fanning_intro_empty * 1000
    local fanning_loop = param.fanning_loop * 1000
    local fanning_loop_empty = param.fanning_loop_empty * 1000
    local fanning_ending = param.fanning_ending * 1000
    local fanning_loop_feed = param.fanning_loop_feed * 1000
    local fanning_loop_empty_feed = param.fanning_loop_empty_feed * 1000
    -- Check if any timing is nil
    if (intro == nil or intro_empty == nil or loop == nil or ending == nil or loop_feed == nil or
    fanning_intro == nil or fanning_intro_empty == nil or fanning_loop == nil or fanning_loop_empty == nil or
    fanning_ending == nil or fanning_loop_feed == nil or fanning_loop_empty_feed == nil
    ) then
        return nil
    end
    return intro, intro_empty, loop, ending, loop_feed,
    fanning_intro, fanning_intro_empty, fanning_loop, fanning_loop_empty, fanning_ending, fanning_loop_feed, fanning_loop_empty_feed
end

function M.tick_reload(api)
    -- Get all timings from script parameter in gun data
    local param = api:getScriptParams();
    local intro, intro_empty, loop, ending, loop_feed, fanning_intro, fanning_intro_empty, fanning_loop, fanning_loop_empty, fanning_ending, fanning_loop_feed, fanning_loop_empty_feed = getReloadTimingFromParam(param)
    -- Get reload time (The time from the start of reloading to the current time) from api
    local reload_time = api:getReloadTime()
    -- Get cache from api, it will be used to count loaded ammo, mark reload interruptions, etc.
    local cache = api:getCachedScriptData()
    local interrupted_time = cache.interrupted_time
    -- Handle interrupting reload
    if (interrupted_time ~= -1) then
        local int_time = reload_time - interrupted_time
        if (int_time >= ending) then
            return NOT_RELOADING, -1
        else
            if (cache.is_tactical) then
                return TACTICAL_RELOAD_FINISHING, ending - int_time
            else
                return EMPTY_RELOAD_FINISHING, ending - int_time
            end
        end
    else
        -- if there is no ammo to consume, interrupt reloading
        if (not api:hasAmmoToConsume()) then
            interrupted_time = api:getReloadTime()
        end
    end

    local reloaded_count = cache.reloaded_count;

    -- Load the ammo into the magazine one by one

    if (api:getFireMode() == SEMI) then
        if (reloaded_count >= 0) then
            local base_time = reloaded_count * loop + loop_feed
            if (not cache.is_tactical) then
                base_time = base_time + intro_empty
            else
                base_time = base_time + intro
            end
            while (base_time < reload_time) do
                if (reloaded_count > cache.needed_count) then
                    break
                end
                reloaded_count = reloaded_count + 1
                base_time = base_time + loop
                api:consumeAmmoFromPlayer(1)
                api:putAmmoInMagazine(1)
            end
        end
    else
        if (reloaded_count >= 0) then
            local base_time = 0
            if (not cache.is_tactical) then
                base_time = reloaded_count * fanning_loop_empty + fanning_loop_empty_feed + fanning_intro_empty
            elseif(cache.vacancy) then
                base_time = reloaded_count * fanning_loop_empty + fanning_loop_empty_feed + fanning_intro
            else
                base_time = reloaded_count * fanning_loop + fanning_loop_feed + fanning_intro
            end
            while (base_time < reload_time) do
                if (reloaded_count > cache.needed_count) then
                    break
                end
                reloaded_count = reloaded_count + 1
                if(not cache.is_tactical or cache.vacancy) then
                    base_time = base_time + fanning_loop_empty
                else
                    base_time = base_time + fanning_loop
                end
                api:consumeAmmoFromPlayer(1)
                api:putAmmoInMagazine(1)
            end
        end
    end
    -- Write back cache
    if (reloaded_count >= cache.needed_count) then
        cache.vacancy = false
        interrupted_time = api:getReloadTime() - loop_feed + loop
    end
    cache.interrupted_time = interrupted_time
    cache.reloaded_count = reloaded_count
    api:cacheScriptData(cache)
    -- return reloadstate
    local total_time = cache.needed_count * loop
    if (api:getFireMode() == SEMI) then
        if (not cache.is_tactical) then
            total_time = total_time + intro_empty
            return EMPTY_RELOAD_FEEDING, total_time - reload_time
        else
            total_time = total_time + intro
            return TACTICAL_RELOAD_FEEDING, total_time - reload_time
        end
    else
        if (not cache.is_tactical) then
            total_time = cache.needed_count * fanning_loop_empty + fanning_intro_empty
            return EMPTY_RELOAD_FEEDING, total_time - reload_time
        elseif(cache.vacancy)then
            total_time = cache.needed_count * fanning_loop_empty + fanning_intro
            return EMPTY_RELOAD_FEEDING, total_time - reload_time
        else
            total_time = cache.needed_count * fanning_loop + fanning_intro
            return TACTICAL_RELOAD_FEEDING, total_time - reload_time
        end
    end
end

function M.interrupt_reload(api)
    local cache = api:getCachedScriptData()
    if (cache ~= nil and cache.interrupted_time == -1) then
        cache.interrupted_time = api:getReloadTime()
    end
end

return M