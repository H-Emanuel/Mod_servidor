local M = {}

-- 尝试开火射击时调用
function M.shoot(api)
    local shoot_delay = api:getScriptParams().shoot_delay * 1000
    local cache = api:getCachedScriptData()
    if (cache == nil) then
        cache = {
            shoot_mode = api:getFireMode() == SEMI and 1 or 0
        }
    end

    if (api:getFireMode() == SEMI) then
        shoot_delay = 0
    else
        if (cache.shoot_mode == 1) then
            shoot_delay = 0
        else
            shoot_delay = api:getScriptParams().shoot_delay * 1000
        end
    end
    -- 将执行射击的部分委托为一次性的延时任务，从而达到延迟开火的目的
    api:safeAsyncTask(function ()
        api:shootOnce(true)
        return false
    end,shoot_delay,0,1)

    if (api:getFireMode() == SEMI) then
        cache.shoot_mode = 1
    else
        cache.shoot_mode = 0
    end
end

function M.start_reload(api)
    -- Get the cached data, ensure it's not nil
    local cache = api:getCachedScriptData()

    -- If cache is nil, initialize it to an empty table
    if cache == nil then
        cache = {}
    end

    -- Ensure 'vacancy' is set if not already present
    if (cache.vacancy == nil) then
        cache.vacancy = 0
    end

    -- Update other cache values (but keep existing 'vacancy' if present)
    cache.reloaded_count = 0
    cache.reloaded_vacancy = 0
    cache.needed_count = api:getMagExtentLevel() == 1 and 6 or api:getNeededAmmoAmount()
    cache.is_tactical = api:getReloadStateType() == TACTICAL_RELOAD_FEEDING
    cache.interrupted_time = -1
    cache.vacancyReloadTime = -1

    -- Cache the modified data
    api:cacheScriptData(cache)

    -- Return true to start ticking
    return true
end

local function getReloadTimingFromParam(param)
    -- Need to convert time from seconds to milliseconds
    local intro = param.intro * 1000
    local intro_empty = param.intro_empty * 1000
    local loop = param.loop * 1000
    local loop_empty = param.loop_empty * 1000
    local ending = param.ending * 1000
    local ending_empty = param.ending_empty * 1000
    local loop_feed = param.loop_feed * 1000
    local loop_empty_feed = param.loop_empty_feed * 1000
    local loader = param.loader * 1000
    local loader_feed = param.loader_feed * 1000
    -- Check if any timing is nil
    if (intro == nil or intro_empty == nil or loop == nil or loop_empty == nil or ending == nil or ending_empty == nil or loop_feed == nil or loop_empty_feed == nil or loader == nil or loader_feed == nil) then
        return nil
    end
    return intro, intro_empty, loop, loop_empty, ending, ending_empty, loop_feed, loop_empty_feed, loader, loader_feed
end

function M.tick_reload(api)
    -- Get all timings from script parameter in gun data
    local param = api:getScriptParams();
    local intro, intro_empty, loop, loop_empty, ending, ending_empty, loop_feed, loop_empty_feed, loader, loader_feed = getReloadTimingFromParam(param)
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
                return EMPTY_RELOAD_FINISHING, ending_empty - int_time
            end
        end
    else
        -- if there is no ammo to consume, interrupt reloading
        if (not api:hasAmmoToConsume()) then
            interrupted_time = api:getReloadTime()
        end
    end

    local reloaded_count = cache.reloaded_count
    local reloaded_vacancy = cache.reloaded_vacancy
    local reload_vacancy = cache.vacancy
    local vacancyReloadTime = cache.vacancyReloadTime

    if ((not cache.is_tactical or api:getMagExtentLevel() == 1) and reloaded_count == 0) then
        if (reload_time > 1 * 1000) then
            api:removeAmmoFromMagazine(6)
        end
        reload_vacancy = 6
    end

    if (reload_vacancy ~= 0) then
        vacancyReloadTime = reloaded_count * loop_empty + loop_empty_feed
        if (not cache.is_tactical) then
            vacancyReloadTime = vacancyReloadTime + intro_empty
        else
            vacancyReloadTime = vacancyReloadTime + intro
        end
        if (api:getMagExtentLevel() == 1) then
            vacancyReloadTime = intro_empty + loader_feed
        end
        if (api:getFireMode() == SEMI) then
            vacancyReloadTime = vacancyReloadTime + 0.46 * 1000
        end
        while (vacancyReloadTime < reload_time) do
            if (reloaded_count > cache.needed_count) then
                break
            end
            if (api:getMagExtentLevel() == 1) then
                reloaded_count = reloaded_count + 7
                reloaded_vacancy = 6
                reload_vacancy = 0
                api:putAmmoInMagazine(api:isReloadingNeedConsumeAmmo() and api:consumeAmmoFromPlayer(6) or 6)
            else
                reloaded_count = reloaded_count + 1
                reloaded_vacancy = reloaded_vacancy + 1
                reload_vacancy = reload_vacancy -1
                vacancyReloadTime = vacancyReloadTime + loop_empty
                api:consumeAmmoFromPlayer(1)
                api:putAmmoInMagazine(1)
            end
        end
    end

    -- Load the ammo into the magazine one by one
    if (reloaded_count >= 0 and reload_vacancy == 0) then
        local base_time = (reloaded_count - reloaded_vacancy) * loop + loop_feed + reloaded_vacancy * loop_empty
        if (not cache.is_tactical) then
            base_time = base_time + intro_empty
        else
            base_time = base_time + intro
        end
        if (api:getFireMode() == SEMI) then
            base_time = base_time + 0.46 * 1000
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


    -- Write back cache
    if (reloaded_count >= cache.needed_count) then
        if (api:getMagExtentLevel() == 1) then
            interrupted_time = api:getReloadTime() - loader_feed + loader
        else
            interrupted_time = api:getReloadTime() - loop_feed + loop
        end
    end
    cache.interrupted_time = interrupted_time
    cache.reloaded_count = reloaded_count
    cache.reloaded_vacancy = reloaded_vacancy
    cache.vacancy = reload_vacancy
    cache.vacancyReloadTime = vacancyReloadTime
    api:cacheScriptData(cache)
    -- return reloadstate
    local total_time = (cache.needed_count - cache.vacancy) * loop + cache.vacancy * loop_empty
    if (api:getMagExtentLevel() == 1) then
        total_time = loader
    end
    if (api:getFireMode() == SEMI) then
        total_time = total_time + 0.46 * 1000
    end
    if (not cache.is_tactical) then
        total_time = total_time + intro_empty
        return EMPTY_RELOAD_FEEDING, total_time - reload_time
    else
        total_time = total_time + intro
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