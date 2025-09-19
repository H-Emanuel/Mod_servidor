local M = {}

-- 尝试开火射击时调用
function M.shoot(api)
    local shoot_delay = api:getScriptParams().shoot_delay * 1000
    -- 将执行射击的部分委托为一次性的延时任务，从而达到延迟开火的目的
    api:safeAsyncTask(function ()
        api:shootOnce(true)
        if(api:getAimingProgress() == 1) then
            api:getEntityUtil():hurt(17)
        end
        return false
    end,shoot_delay,0,1)
end

return M