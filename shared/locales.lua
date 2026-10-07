Locales = {}

function _(str, ...)
    if Locales[Config.Locale] and Locales[Config.Locale][str] then
        return string.format(Locales[Config.Locale][str], ...)
    else
        return 'Translation [' .. Config.Locale .. '][' .. str .. '] does not exist'
    end
end

function _U(str, ...)
    return tostring(_(str, ...)):gsub("^%l", string.upper)
end
