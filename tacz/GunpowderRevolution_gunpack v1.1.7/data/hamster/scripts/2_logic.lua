local M = {}

local function getReloadTimingFromParam(param)
    local mag_feed = param.mag_feed * 1000
    local mag = param.mag * 1000
    local mag_empty = param.mag_empty * 1000
    -- Check if any timing is nil
    if (mag_feed == nil or mag == nil or mag_empty == nil) then
        return nil
    end
    return mag_feed, mag, mag_empty
end

function M.start_reload(api)
    -- Initialize cache that will be used in reload ticking
    local cache = {
        reloaded_count = 0,
        needed_count = api:getNeededAmmoAmount(),
        is_tactical = api:getReloadStateType() == TACTICAL_RELOAD_FEEDING,
        interrupted_time = -1,
    }
    api:cacheScriptData(cache)
    -- Return true to start ticking
    return true
end

function M.tick_reload(api)
    -- 获取所有装弹所需要的数据
    local param = api:getScriptParams();
    local mag_feed, mag, mag_empty = getReloadTimingFromParam(param)
    -- 获取从开始装弹到现在的时间，单位为毫秒
    local reload_time = api:getReloadTime()
    -- 调用在装弹开始时初始化写入的缓存数据
    local cache = api:getCachedScriptData()

    if (not cache.is_tactical) then
        if (reload_time < mag_feed) then
            return TACTICAL_RELOAD_FEEDING, mag_feed - reload_time
        elseif (reload_time >= mag_feed and reload_time < mag_empty) then
            if (cache.needed_count > 0) then
                if (api:consumeAmmoFromPlayer(2) == 2) then
                    api:putAmmoInMagazine(cache.needed_count)
                elseif (api:consumeAmmoFromPlayer(2) == 1) then
                    api:putAmmoInMagazine(cache.needed_count / 2)
                end
                cache.needed_count = 0
                api:cacheScriptData(cache)
            end
            return TACTICAL_RELOAD_FINISHING, mag_empty - reload_time
        else
            return NOT_RELOADING, -1
        end
    else
        if (reload_time < mag_feed) then
            return EMPTY_RELOAD_FEEDING, mag_feed - reload_time
        elseif (reload_time >= mag_feed and reload_time < mag) then
            if (cache.needed_count > 0) then
                if (api:consumeAmmoFromPlayer(2) == 2) then
                    api:putAmmoInMagazine(cache.needed_count)
                elseif (api:consumeAmmoFromPlayer(2) == 1) then
                    api:putAmmoInMagazine(cache.needed_count / 2)
                end
                cache.needed_count = 0
                api:cacheScriptData(cache)
            end
            return EMPTY_RELOAD_FINISHING, mag - reload_time
        else
            return NOT_RELOADING, -1
        end
    end
end

return M