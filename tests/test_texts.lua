local root = assert(arg[1], 'pass the mod root with trailing slash')
local Texts = dofile(root .. 'src/texts.lua')

local cultures = {'en','ja','de','es','es-MX','fr','id','it','ko','pl','pt-BR','ru','th','tr','vi','zh-Hans','zh-Hant'}
local keys = {'rangeRow','chestRow','rangeCapTitle','rangeCapTip','chestCapTitle','chestCapTip','palboxRow','palboxCapTitle','palboxCapTip','off'}

local function same(a, b, what)
    assert(#a == #b, what .. ': ' .. #a .. ' items, expected ' .. #b)
    for i = 1, #b do assert(a[i] == b[i], what .. ' item ' .. i .. ': ' .. tostring(a[i]) .. ' != ' .. b[i]) end
end
local function has(text, part) return text:find(part, 1, true) ~= nil end

same(Texts.cultures, cultures, 'cultures')
same(Texts.keys, keys, 'keys')
print('PASS: the 17 cultures and the 10 keys are listed in order')

-- Every culture has exactly the ten keys, each one a trimmed single line.
for _, culture in ipairs(cultures) do
    local texts = Texts.get(culture)
    local count = 0
    for key, text in pairs(texts) do
        count = count + 1
        local where = culture .. '.' .. tostring(key)
        local known = false
        for _, k in ipairs(keys) do known = known or k == key end
        assert(known, where .. ' is not a known key')
        assert(type(text) == 'string' and #text > 0, where .. ' is empty')
        assert(utf8.len(text), where .. ' is not valid UTF-8')
        assert(not text:find('[%c]'), where .. ' has a control character or line break')
        assert(not text:find('^%s') and not text:find('%s$'), where .. ' has a leading or trailing space')
        assert(not text:find('  ', 1, true), where .. ' has a double space')
    end
    assert(count == #keys, culture .. ' has ' .. count .. ' keys, expected ' .. #keys)
end
print('PASS: every culture has exactly the ten keys, non-empty, single-line and trimmed')

-- English is the source text, verbatim.
local english = Texts.get('en')
assert(english.rangeRow == 'Base Range Bonus')
assert(english.chestRow == 'Bonus Chest Slots')
assert(english.rangeCapTitle == 'Growing Grounds: Maximum range bonus')
assert(english.rangeCapTip == 'The range bonus arrives steadily over all base levels; the last level gives it all. 0 disables it. +100% doubles the original radius; +300% makes it four times larger. Default: +100%. Nearby bases can limit growth.')
assert(english.chestCapTitle == 'Growing Grounds: Maximum bonus chest slots')
assert(english.chestCapTip == 'These slots arrive steadily over all base levels; the last level gives them all. 0 disables them. Default: 18. Guild Chests share one bonus. Occupied extra slots remain until emptied.')
assert(english.off == 'Off')
print('PASS: English is the final text, verbatim')

-- A culture that kept the English text was never translated.
for _, culture in ipairs(cultures) do
    if culture ~= 'en' then
        local texts = Texts.get(culture)
        for _, key in ipairs(keys) do
            assert(texts[key] ~= english[key], culture .. '.' .. key .. ' is still the English text')
        end
    end
end
print('PASS: no other culture keeps an English text')

-- The numbers, their plus sign and the mod name must survive translation. The percent sign moves with
-- the language (French "100 %", Turkish "%100"), so the number is searched on its own.
for _, culture in ipairs(cultures) do
    local texts = Texts.get(culture)
    assert(has(texts.rangeCapTitle, 'Growing Grounds'), culture .. ' range title lost the mod name')
    assert(has(texts.chestCapTitle, 'Growing Grounds'), culture .. ' chest title lost the mod name')
    for _, number in ipairs({'100', '300', '0'}) do
        assert(has(texts.rangeCapTip, number), culture .. ' range tip lost ' .. number)
    end
    for _, number in ipairs({'18', '0'}) do
        assert(has(texts.chestCapTip, number), culture .. ' chest tip lost ' .. number)
    end
    assert(texts.rangeCapTip:find('%+%%?100') and texts.rangeCapTip:find('%+%%?300'),
        culture .. ' range tip lost the signs of +100 and +300')
end
print('PASS: both titles keep "Growing Grounds" and the tips keep their numbers in every culture')

-- Row labels sit next to the game's two rows of the Base Upgrade screen: they must not run much longer.
-- Each entry: the game's "Max Pals Working at Base", "Max Number of Bases" and the game's "Off".
local game = {
    ["en"]     = {"Max Pals Working at Base", "Max Number of Bases", "Off"},
    ["ja"]     = {"拠点の作業パル最大数", "建築可能な拠点数", "オフ"},
    ["de"]     = {"Max. Anzahl von Arbeitspals im Lager", "Anzahl möglicher Lager", "Aus"},
    ["es"]     = {"Máximo de Pals trabajando en la base", "Número de bases que se pueden construir", "Desactivado"},
    ["es-MX"]  = {"Máximo de Pals de trabajo en la base", "Número de bases que puedes construir", "Desactivado"},
    ["fr"]     = {"Nombre max de Pals actifs à la base", "Nombre de bases pouvant être construites", "Désactivé"},
    ["id"]     = {"Jumlah maksimal Pal bekerja di markas", "Jumlah markas yang bisa dibangun", "Mati"},
    ["it"]     = {"Numero massimo di Pal attivi nella base", "Numero di basi possibili da costruire", "Spento"},
    ["ko"]     = {"거점 작업 팰 최대 수", "건축 가능한 거점 수", "끄기"},
    ["pl"]     = {"Maksymalna liczba Pali pracujących w bazie", "Maksymalna liczba baz", "Wyłączone"},
    ["pt-BR"]  = {"Máximo de Pals trabalhando na base", "Bases que podem ser construídas", "Desligado"},
    ["ru"]     = {"Макс. кол-во рабочих Палов на базе", "Макс. число баз", "Выкл."},
    ["th"]     = {"จำนวนพาลสูงสุดที่ทำงานในฐาน", "จำนวนฐานที่สร้างได้", "ปิด"},
    ["tr"]     = {"Üste Çalışan Maks. Pal", "Maks. Üs Sayısı", "Kapalı"},
    ["vi"]     = {"Số lượng Pal làm việc tối đa tại căn cứ", "Số lượng căn cứ có thể xây dựng", "Tắt"},
    ["zh-Hans"]= {"可分派至据点工作的帕鲁数量上限", "可建造的据点数量", "关闭"},
    ["zh-Hant"]= {"據點工作帕魯數量上限", "可建造據點數量", "關閉"},
}
for _, culture in ipairs(cultures) do
    local native = math.max(utf8.len(game[culture][1]), utf8.len(game[culture][2]))
    local limit = math.floor(native * 4 / 3)
    local texts = Texts.get(culture)
    for _, key in ipairs({'rangeRow', 'chestRow'}) do
        local length = utf8.len(texts[key])
        assert(length <= limit, culture .. '.' .. key .. ' is ' .. length .. ' characters, the limit is ' .. limit)
    end
end
print('PASS: row labels stay within a third of the longer game label, counted in characters')

-- "Off" is the game's own word for it in that culture.
for _, culture in ipairs(cultures) do
    assert(Texts.get(culture).off == game[culture][3], culture .. ' off is not the game word ' .. game[culture][3])
end
print('PASS: "off" is the game\'s own word in every culture')

-- The base and Guild Chest words come from the game (stems cover case and plural). Each entry: base
-- alternatives, Guild Chest alternatives.
local words = {
    ["en"]     = {{'Base', 'base'}, {'Guild Chest'}},
    ["ja"]     = {{'拠点'}, {'ギルドチェスト'}},
    ["de"]     = {{'Lager'}, {'Gildentruhe'}},
    ["es"]     = {{'base'}, {'cofres de gremio'}},
    ["es-MX"]  = {{'base'}, {'cofres de gremio'}},
    ["fr"]     = {{'base'}, {'coffres de guilde'}},
    ["id"]     = {{'Markas', 'markas'}, {'Peti Guild'}},
    ["it"]     = {{'base'}, {'forzieri della gilda'}},
    ["ko"]     = {{'거점'}, {'길드 상자'}},
    ["pl"]     = {{'baz', 'Baz'}, {'krzynie gildii'}},
    ["pt-BR"]  = {{'base'}, {'Baús de Guilda'}},
    ["ru"]     = {{'баз'}, {'ундуки гильдии'}},
    ["th"]     = {{'ฐาน'}, {'หีบกิลด์'}},
    ["tr"]     = {{'Üs', 'üs'}, {'Lonca Sandık'}},
    ["vi"]     = {{'căn cứ', 'Căn cứ'}, {'Rương Bang Hội'}},
    ["zh-Hans"]= {{'据点'}, {'公会箱子'}},
    ["zh-Hant"]= {{'據點'}, {'公會箱子'}},
}
local function hasAny(text, list)
    for _, part in ipairs(list) do if has(text, part) then return true end end
    return false
end
for _, culture in ipairs(cultures) do
    local texts = Texts.get(culture)
    assert(hasAny(texts.rangeRow, words[culture][1]), culture .. ' range row does not use the game word for base')
    assert(hasAny(texts.rangeCapTip, words[culture][1]), culture .. ' range tip does not use the game word for base')
    assert(hasAny(texts.chestCapTip, words[culture][1]), culture .. ' chest tip does not use the game word for base')
    assert(hasAny(texts.chestCapTip, words[culture][2]), culture .. ' chest tip does not use the game word for Guild Chest')
end
print('PASS: base and Guild Chest use the game\'s own words in every culture')

-- A repeated tip is a copy-paste. The two Spanish and the two Chinese are written differently, so they
-- differ too.
for i = 1, #cultures do
    for j = i + 1, #cultures do
        local a, b = Texts.get(cultures[i]), Texts.get(cultures[j])
        for _, key in ipairs({'rangeCapTip', 'chestCapTip'}) do
            assert(a[key] ~= b[key], cultures[i] .. ' and ' .. cultures[j] .. ' share the same ' .. key)
        end
    end
end
print('PASS: no two cultures share a tip')

-- Culture matching: the engine's string is not verified, so every plausible spelling is covered.
local cases = {
    -- an exact culture wins, in any case
    {'en', 'en'}, {'ja', 'ja'}, {'de', 'de'}, {'es', 'es'}, {'es-MX', 'es-MX'}, {'fr', 'fr'}, {'id', 'id'},
    {'it', 'it'}, {'ko', 'ko'}, {'pl', 'pl'}, {'pt-BR', 'pt-BR'}, {'ru', 'ru'}, {'th', 'th'}, {'tr', 'tr'},
    {'vi', 'vi'}, {'zh-Hans', 'zh-Hans'}, {'zh-Hant', 'zh-Hant'},
    {'FR', 'fr'}, {'ES-MX', 'es-MX'}, {'es-mx', 'es-MX'}, {'PT-br', 'pt-BR'}, {'ZH-HANS', 'zh-Hans'},
    {'zh-hant', 'zh-Hant'},
    -- separators
    {'fr_FR', 'fr'}, {'fr-FR', 'fr'}, {'es_MX', 'es-MX'}, {'pt_BR', 'pt-BR'}, {'zh_Hant', 'zh-Hant'},
    {'zh_Hans_CN', 'zh-Hans'}, {'fr_FR.UTF-8', 'fr'}, {' fr ', 'fr'},
    -- Chinese: the script decides, then the region, then Simplified
    {'zh-Hans-CN', 'zh-Hans'}, {'zh-Hans-TW', 'zh-Hans'}, {'zh-Hant-TW', 'zh-Hant'}, {'zh-Hant-CN', 'zh-Hant'},
    {'zh-Hant-HK', 'zh-Hant'}, {'zh-CN', 'zh-Hans'}, {'zh-SG', 'zh-Hans'}, {'zh-MY', 'zh-Hans'},
    {'zh-TW', 'zh-Hant'}, {'ZH-TW', 'zh-Hant'}, {'zh-HK', 'zh-Hant'}, {'zh-MO', 'zh-Hant'}, {'zh', 'zh-Hans'},
    {'zh-XX', 'zh-Hans'}, {'zh_TW', 'zh-Hant'}, {'zh-CHT', 'zh-Hant'}, {'zh-CHS', 'zh-Hans'},
    -- Spanish: Spain is es, every other region is es-MX
    {'es-ES', 'es'}, {'es_ES', 'es'}, {'ES-es', 'es'}, {'es-419', 'es-MX'}, {'es-AR', 'es-MX'}, {'es-CO', 'es-MX'},
    {'es-US', 'es-MX'}, {'es-Latn-ES', 'es'}, {'es-Latn-MX', 'es-MX'}, {'es-Latn', 'es'},
    -- Portuguese is always pt-BR
    {'pt', 'pt-BR'}, {'pt-PT', 'pt-BR'}, {'pt_PT', 'pt-BR'}, {'PT-AO', 'pt-BR'},
    -- the language part, when it is a culture
    {'ja-JP', 'ja'}, {'de-AT', 'de'}, {'de_CH', 'de'}, {'en-US', 'en'}, {'en_GB', 'en'}, {'ko-KR', 'ko'},
    {'it-CH', 'it'}, {'ru-RU', 'ru'}, {'th-TH', 'th'}, {'tr-TR', 'tr'}, {'vi-VN', 'vi'}, {'id-ID', 'id'},
    {'pl-PL', 'pl'}, {'fr-CA', 'fr'}, {'fr_BE', 'fr'},
    -- anything else is English
    {'xx', 'en'}, {'sv-SE', 'en'}, {'ar', 'en'}, {'', 'en'}, {'-', 'en'}, {'_', 'en'}, {'  ', 'en'},
    {'frfr', 'en'}, {'zhx', 'en'}, {'ptbr', 'en'}, {'english', 'en'},
}
for _, case in ipairs(cases) do
    local got = Texts.match(case[1])
    assert(got == case[2], 'match(' .. string.format('%q', case[1]) .. ') = ' .. tostring(got) .. ', expected ' .. case[2])
end
for _, odd in ipairs({42, true, false, {}, print, 0/0}) do
    assert(Texts.match(odd) == 'en', 'match of a ' .. type(odd) .. ' must be en')
end
assert(Texts.match(nil) == 'en' and Texts.match() == 'en')
-- whatever match returns is one of the cultures
local listed = {}
for _, culture in ipairs(cultures) do listed[culture] = true end
for _, case in ipairs(cases) do assert(listed[Texts.match(case[1])]) end
print('PASS: match covers exact cultures, separators, Chinese, Spanish, Portuguese, language parts and fallbacks')

-- get never returns nil or a missing key, whatever it is given, and each call is a fresh table.
for _, odd in ipairs({'', 'xx', 'zh-TW', 'es-419', 42, true, {}}) do
    local texts = Texts.get(odd)
    assert(type(texts) == 'table', 'get returned no table')
    for _, key in ipairs(keys) do
        assert(type(texts[key]) == 'string' and #texts[key] > 0, 'get(' .. tostring(odd) .. ') lacks ' .. key)
    end
end
local nothing = Texts.get(nil)
assert(nothing.rangeRow == english.rangeRow and nothing.off == 'Off')
assert(Texts.get('zh-TW').off == Texts.get('zh-Hant').off and Texts.get('zh-TW').off ~= Texts.get('zh-Hans').off)
assert(Texts.get('fr_FR').off == Texts.get('fr').off)
local first = Texts.get('de')
first.off = 'changed'
assert(Texts.get('de').off == 'Aus', 'get must hand out a copy')
print('PASS: get returns all ten keys for odd input and a fresh table each time')

-- The language reader: asks the engine each time, follows a change, reads
-- English when the engine cannot answer, and logs only when the answer changes.
do
    local answer, asked, lines = 'fr', 0, {}
    local library = {GetCurrentLanguage = function() asked = asked + 1; return answer end}
    local E = {log = function(message) lines[#lines + 1] = message end,
        objects = {find = function(path)
            assert(path == '/Script/Engine.Default__KismetInternationalizationLibrary')
            return library
        end}}
    local current = dofile(root .. 'src/language.lua')(E, Texts)
    local french = current()
    assert(french.off == 'Désactivé' and french.rangeRow == Texts.get('fr').rangeRow)
    assert(current() == french and asked == 2 and #lines == 1, 'same language: same texts, engine asked, nothing logged again')
    assert(lines[1] == 'texts: game language "fr" -> fr', lines[1])
    answer = {ToString = function() return 'zh-Hant-TW' end}
    assert(current().off == Texts.get('zh-Hant').off, 'an engine string object is read through ToString')
    answer = 'pt-PT'
    assert(current().off == Texts.get('pt-BR').off and lines[#lines] == 'texts: game language "pt-PT" -> pt-BR')
    answer = 'xx'
    assert(current().off == 'Off' and lines[#lines] == 'texts: game language "xx" -> en')
    local before = #lines
    library.GetCurrentLanguage = function() error('not exported by this build') end
    local fallback = current()
    assert(fallback.off == 'Off' and fallback.rangeRow == 'Base Range Bonus', 'an unreadable language reads English')
    assert(lines[#lines] == 'texts: game language unreadable -> en' and #lines == before + 1)
    current(); current()
    assert(#lines == before + 1, 'a persistent failure is reported once')
    E.objects.find = function() return nil end
    assert(current().off == 'Off' and #lines == before + 1, 'a missing library is the same unreadable case')
    library.GetCurrentLanguage = function() return 'ja' end
    E.objects.find = function() return library end
    assert(current().off == Texts.get('ja').off, 'the language is picked up again once readable')
end
print('PASS: the language reader follows the engine, falls back to English and logs each change once')

for _,culture in ipairs(cultures) do
    local t=Texts.get(culture)
    assert(has(t.palboxCapTitle,'Growing Grounds'))
    for _,number in ipairs({'0','1','32','64'}) do assert(has(t.palboxCapTip,number),culture..' Palbox tip lost '..number) end
end
print('PASS: Palbox settings and reward labels provided in all 17 cultures')
