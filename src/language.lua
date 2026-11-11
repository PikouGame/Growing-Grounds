-- The mod's texts in the game's current language. The engine is asked each
-- time, so a language changed in the options is followed without a restart;
-- an unknown or unreadable language reads English.
return function(E,Texts)
    local name,texts
    return function()
        local ok,value=pcall(function()
            local v=E.objects.find('/Script/Engine.Default__KismetInternationalizationLibrary'):GetCurrentLanguage()
            return type(v)=='string' and v or v:ToString()
        end)
        if not ok then value=nil end
        if not texts or value~=name then
            name,texts=value,Texts.get(value)
            E.log('texts: game language '..(value and '"'..value..'"' or 'unreadable')..' -> '..Texts.match(value))
        end
        return texts
    end
end
