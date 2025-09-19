local M = {}

local function getBulletCount(api)
    return (api:hasAmmoInBarrel() and 1 or 0) + api:getAmmoAmount()
end

function M.shoot(api)
    api:shootOnce(true)
end

function M.start_bolt(api)
    -- Return true to start ticking, since there are nothing needed to be check
    return true
end

function M.tick_bolt(api)
    -- Get total bolt time from script parameter in gun data
    local total_bolt_time = api:getScriptParams().bolt_time * 1000
    if (total_bolt_time == nil) then
        return false
    end
    if (api:getBoltTime() < total_bolt_time) then
        -- Bolt time less than total means we need to keep ticking, return true
        return true
    else
        -- Bolt time greater than total means that the bullet
        -- needs to be put from the magazine into the barrel, and then return false to end ticking.
        if (api:removeAmmoFromMagazine(1) ~= 0) then
            api:setAmmoInBarrel(true);
        end
        return false
    end
end

function M.start_reload(api)
    -- Initialize cache that will be used in reload ticking
    local cache = {
        reloaded_count = 0,
        needed_count = api:getNeededAmmoAmount(),
        is_tactical = api:getReloadStateType() == TACTICAL_RELOAD_FEEDING,
        interrupted_time = -1,
    }
    if(api:hasAmmoInBarrel())then
        cache.needed_count = cache.needed_count - 1
    end
    api:cacheScriptData(cache)
    -- Return true to start ticking
    return true
end

local function getReloadTimingFromParam(param)
    -- Need to convert time from seconds to milliseconds
    local intro_empty = param.intro_empty * 1000
    local intro_1round = param.intro_1round * 1000
    local intro_2round = param.intro_2round * 1000
    local load = param.load * 1000
    local load_2round = param.load_2round * 1000
    local ending = param.ending * 1000
    local load_feed = param.load * 1000
    local load_2round_feed = param.load_2round * 1000
    local ending_feed = param.ending_feed * 1000
    -- Check if any timing is nil
    if (intro_empty == nil or intro_1round == nil or intro_2round == nil or load == nil or load_2round == nil or ending == nil or load_feed == nil or load_2round_feed == nil or ending_feed == nil) then
        return nil
    end
    return intro_empty, intro_1round, intro_2round, load, load_2round, ending, load_feed, load_2round_feed, ending_feed
end

function M.tick_reload(api)
    -- Get all timings from script parameter in gun data
    local param = api:getScriptParams();
    local intro_empty, intro_1round, intro_2round, load, load_2round, ending, load_feed, load_2round_feed, ending_feed = getReloadTimingFromParam(param)
    -- Get reload time (The time from the start of reloading to the current time) from api
    local reload_time = api:getReloadTime()
    -- Get cache from api, it will be used to count loaded ammo, mark reload interruptions, etc.
    local cache = api:getCachedScriptData()
    local interrupted_time = cache.interrupted_time
    -- Handle interrupting reload
    if (cache.interrupted_time ~= -1) then
        local int_time = reload_time - cache.interrupted_time
        if (not cache.is_tactical) then
            if (int_time > ending_feed) then
                if(not api:hasAmmoInBarrel() and api:removeAmmoFromMagazine(1) ~= 0) then
                    api:setAmmoInBarrel(true);
                end
            end
            if(int_time >= ending) then
               return NOT_RELOADING, -1
            else
               return EMPTY_RELOAD_FINISHING, ending - int_time
            end
        else
            if(int_time >= ending) then
               return NOT_RELOADING, -1
            else
                return TACTICAL_RELOAD_FINISHING, ending - int_time
            end
        end
    else
        if (not api:hasAmmoToConsume()) then
            interrupted_time = api:getReloadTime()
        end
    end

    local reloaded_count = cache.reloaded_count;

    if (reloaded_count >= 0) then
        local base_time = intro_empty
        if (not cache.is_tactical) then
            base_time = intro_empty + load_feed
        elseif(getBulletCount(api) == 1) then
            base_time = intro_1round + load_feed
        else
            base_time = intro_2round + load_2round_feed
        end
        if(base_time < reload_time) then
            if (reloaded_count ~= cache.needed_count) then
                reloaded_count = cache.needed_count
                api:consumeAmmoFromPlayer(cache.needed_count)
                api:putAmmoInMagazine(cache.needed_count)
            end
        end
    end

    -- Write back cache
    if (reloaded_count >= cache.needed_count) then
        if (not cache.is_tactical or getBulletCount(api) == 1) then
            interrupted_time = api:getReloadTime() - load_feed + load
        else
            interrupted_time = api:getReloadTime() - load_2round_feed + load_2round
        end
    end
    cache.interrupted_time = interrupted_time
    cache.reloaded_count = reloaded_count
    api:cacheScriptData(cache)
    -- return reloadstate
    local total_time = 0
    if (not cache.is_tactical) then
        total_time = intro_empty + load
        return EMPTY_RELOAD_FEEDING, total_time - reload_time
    elseif(getBulletCount(api) == 1) then
        total_time = intro_1round + load
        return TACTICAL_RELOAD_FEEDING, total_time - reload_time
    else
        total_time = intro_2round + load_2round
        return TACTICAL_RELOAD_FEEDING, total_time - reload_time
    end
end

function M.interrupt_reload(api)
    local cache = api:getCachedScriptData()
    if (cache ~= nil and cache.interrupted_time == -1) then
        cache.interrupted_time = api:getReloadTime()
    end
end

return M