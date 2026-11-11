-- Every text the mod shows to the player, in the 17 cultures of the game. This is NOT a UE4SS entry point.
-- Wording follows the game's own vocabulary (base, base level, Guild Chest, Off, slot) in each culture.
-- Percent signs follow each language's usual form; French uses a no-break space (U+00A0) as the game's
-- own French strings do.
local Texts = {}

-- The game's own culture codes, in the order of its package.
Texts.cultures = {"en", "ja", "de", "es", "es-MX", "fr", "id", "it", "ko", "pl", "pt-BR", "ru", "th",
    "tr", "vi", "zh-Hans", "zh-Hant"}

Texts.keys = {"rangeRow", "chestRow", "rangeCapTitle", "rangeCapTip", "chestCapTitle", "chestCapTip", "off"}

local data = {
    ["en"] = {
        rangeRow = "Base Range Bonus",
        chestRow = "Bonus Chest Slots",
        rangeCapTitle = "Growing Grounds: Maximum range bonus",
        rangeCapTip = "The range bonus arrives steadily over all base levels; the last level gives it all. 0 disables it. +100% doubles the original radius; +300% makes it four times larger. Default: +100%. Nearby bases can limit growth.",
        chestCapTitle = "Growing Grounds: Maximum bonus chest slots",
        chestCapTip = "These slots arrive steadily over all base levels; the last level gives them all. 0 disables them. Default: 18. Guild Chests share one bonus. Occupied extra slots remain until emptied.",
        off = "Off",
    },
    ["ja"] = {
        rangeRow = "拠点の範囲ボーナス",
        chestRow = "チェストの追加スロット",
        rangeCapTitle = "Growing Grounds: 範囲ボーナスの上限",
        rangeCapTip = "範囲ボーナスは拠点レベルが上がるにつれて少しずつ増え、最大レベルですべて適用されます。0で無効になります。+100%で元の半径の2倍、+300%で4倍になります。初期値: +100%。近くの拠点によって拡大が制限されることがあります。",
        chestCapTitle = "Growing Grounds: 追加チェストスロットの上限",
        chestCapTip = "追加スロットは拠点レベルが上がるにつれて少しずつ増え、最大レベルですべて適用されます。0で無効になります。初期値: 18。すべてのギルドチェストで1つのボーナスを共有します。アイテムが入っている追加スロットは、空にするまで残ります。",
        off = "オフ",
    },
    ["de"] = {
        rangeRow = "Lagerradius-Bonus",
        chestRow = "Zusätzliche Truhenslots",
        rangeCapTitle = "Growing Grounds: Maximaler Radiusbonus",
        rangeCapTip = "Der Radiusbonus steigt mit jedem Lagerlevel gleichmäßig an; auf dem letzten Level ist er vollständig erreicht. 0 deaktiviert ihn. +100 % verdoppelt den ursprünglichen Radius, +300 % vervierfacht ihn. Standard: +100 %. Nahe Lager können das Wachstum begrenzen.",
        chestCapTitle = "Growing Grounds: Maximale zusätzliche Truhenslots",
        chestCapTip = "Diese Slots kommen mit jedem Lagerlevel gleichmäßig hinzu; auf dem letzten Level sind alle freigeschaltet. 0 deaktiviert sie. Standard: 18. Gildentruhen teilen sich einen Bonus. Belegte zusätzliche Slots bleiben bestehen, bis sie geleert werden.",
        off = "Aus",
    },
    ["es"] = {
        rangeRow = "Bonificación de alcance de la base",
        chestRow = "Espacios extra de cofre",
        rangeCapTitle = "Growing Grounds: Bonificación máxima de alcance",
        rangeCapTip = "La bonificación de alcance aumenta de forma gradual a lo largo de todos los niveles de la base; el último nivel la otorga por completo. Con 0 se desactiva. +100 % duplica el radio original y +300 % lo multiplica por cuatro. Valor predeterminado: +100 %. Las bases cercanas pueden limitar el crecimiento.",
        chestCapTitle = "Growing Grounds: Máximo de espacios extra de cofre",
        chestCapTip = "Estos espacios se obtienen de forma gradual a lo largo de todos los niveles de la base; el último nivel los otorga todos. Con 0 se desactivan. Valor predeterminado: 18. Los cofres de gremio comparten una única bonificación. Los espacios extra ocupados se conservan hasta que se vacíen.",
        off = "Desactivado",
    },
    ["es-MX"] = {
        rangeRow = "Bonificación de rango de la base",
        chestRow = "Ranuras extra de cofre",
        rangeCapTitle = "Growing Grounds: Bonificación máxima de rango",
        rangeCapTip = "La bonificación de rango aumenta poco a poco con cada nivel de base; el último nivel la otorga completa. Con 0 se desactiva. +100% duplica el radio original y +300% lo hace cuatro veces más grande. Predeterminado: +100%. Las bases cercanas pueden limitar el crecimiento.",
        chestCapTitle = "Growing Grounds: Máximo de ranuras extra de cofre",
        chestCapTip = "Estas ranuras llegan poco a poco con cada nivel de base; el último nivel las otorga todas. Con 0 se desactivan. Predeterminado: 18. Los cofres de gremio comparten una sola bonificación. Las ranuras extra ocupadas se conservan hasta que se vacíen.",
        off = "Desactivado",
    },
    ["fr"] = {
        rangeRow = "Bonus de rayon de la base",
        chestRow = "Emplacements de coffre bonus",
        rangeCapTitle = "Growing Grounds : bonus de rayon maximal",
        rangeCapTip = "Le bonus de rayon arrive progressivement sur tous les niveaux de la base ; le dernier niveau l'accorde en totalité. 0 le désactive. +100\u{A0}% double le rayon d'origine ; +300\u{A0}% le multiplie par quatre. Par défaut : +100\u{A0}%. Les bases voisines peuvent limiter la croissance.",
        chestCapTitle = "Growing Grounds : nombre max d'emplacements de coffre bonus",
        chestCapTip = "Ces emplacements arrivent progressivement sur tous les niveaux de la base ; le dernier niveau les accorde tous. 0 les désactive. Par défaut : 18. Les coffres de guilde partagent un seul bonus. Les emplacements bonus occupés restent jusqu'à ce qu'ils soient vidés.",
        off = "Désactivé",
    },
    ["id"] = {
        rangeRow = "Bonus Jangkauan Markas",
        chestRow = "Slot Peti Bonus",
        rangeCapTitle = "Growing Grounds: Bonus jangkauan maksimum",
        rangeCapTip = "Bonus jangkauan bertambah secara bertahap di sepanjang semua level markas; level terakhir memberikan seluruhnya. 0 menonaktifkannya. +100% menggandakan radius asli; +300% membuatnya empat kali lebih besar. Bawaan: +100%. Markas di dekatnya dapat membatasi pertumbuhan.",
        chestCapTitle = "Growing Grounds: Slot peti bonus maksimum",
        chestCapTip = "Slot ini bertambah secara bertahap di sepanjang semua level markas; level terakhir memberikan semuanya. 0 menonaktifkannya. Bawaan: 18. Peti Guild berbagi satu bonus. Slot tambahan yang terisi tetap ada sampai dikosongkan.",
        off = "Mati",
    },
    ["it"] = {
        rangeRow = "Bonus raggio della base",
        chestRow = "Slot bonus dei forzieri",
        rangeCapTitle = "Growing Grounds: Bonus massimo di raggio",
        rangeCapTip = "Il bonus di raggio arriva gradualmente lungo tutti i livelli della base; l'ultimo livello lo concede per intero. Con 0 è disattivato. +100% raddoppia il raggio originale; +300% lo rende quattro volte più grande. Predefinito: +100%. Le basi vicine possono limitare la crescita.",
        chestCapTitle = "Growing Grounds: Numero massimo di slot bonus dei forzieri",
        chestCapTip = "Questi slot arrivano gradualmente lungo tutti i livelli della base; l'ultimo livello li concede tutti. Con 0 sono disattivati. Predefinito: 18. I forzieri della gilda condividono un unico bonus. Gli slot extra occupati restano finché non vengono svuotati.",
        off = "Spento",
    },
    ["ko"] = {
        rangeRow = "거점 범위 보너스",
        chestRow = "추가 상자 슬롯",
        rangeCapTitle = "Growing Grounds: 최대 범위 보너스",
        rangeCapTip = "범위 보너스는 모든 거점 레벨에 걸쳐 조금씩 늘어나며, 마지막 레벨에서 전부 적용됩니다. 0이면 비활성화됩니다. +100%는 원래 반경의 2배, +300%는 4배가 됩니다. 기본값: +100%. 근처에 다른 거점이 있으면 확장이 제한될 수 있습니다.",
        chestCapTitle = "Growing Grounds: 최대 추가 상자 슬롯",
        chestCapTip = "추가 슬롯은 모든 거점 레벨에 걸쳐 조금씩 늘어나며, 마지막 레벨에서 전부 적용됩니다. 0이면 비활성화됩니다. 기본값: 18. 길드 상자는 보너스 하나를 공유합니다. 아이템이 들어 있는 추가 슬롯은 비울 때까지 유지됩니다.",
        off = "끄기",
    },
    ["pl"] = {
        rangeRow = "Premia do zasięgu bazy",
        chestRow = "Dodatkowe miejsca w skrzyniach",
        rangeCapTitle = "Growing Grounds: Maksymalna premia do zasięgu",
        rangeCapTip = "Premia do zasięgu rośnie stopniowo przez wszystkie poziomy bazy; ostatni poziom daje ją w całości. 0 wyłącza premię. +100% podwaja pierwotny promień, a +300% czyni go czterokrotnie większym. Domyślnie: +100%. Pobliskie bazy mogą ograniczać wzrost.",
        chestCapTitle = "Growing Grounds: Maksymalna liczba dodatkowych miejsc w skrzyniach",
        chestCapTip = "Te miejsca pojawiają się stopniowo przez wszystkie poziomy bazy; ostatni poziom daje je wszystkie. 0 wyłącza je. Domyślnie: 18. Skrzynie gildii dzielą jedną premię. Zajęte dodatkowe miejsca zostają, dopóki nie zostaną opróżnione.",
        off = "Wyłączone",
    },
    ["pt-BR"] = {
        rangeRow = "Bônus de alcance da base",
        chestRow = "Slots extras de baú",
        rangeCapTitle = "Growing Grounds: Bônus máximo de alcance",
        rangeCapTip = "O bônus de alcance chega aos poucos ao longo de todos os níveis da base; o último nível concede tudo. 0 desativa o bônus. +100% dobra o raio original e +300% o torna quatro vezes maior. Padrão: +100%. Bases próximas podem limitar o crescimento.",
        chestCapTitle = "Growing Grounds: Máximo de slots extras de baú",
        chestCapTip = "Estes slots chegam aos poucos ao longo de todos os níveis da base; o último nível concede todos. 0 desativa os slots. Padrão: 18. Os Baús de Guilda compartilham um único bônus. Slots extras ocupados permanecem até serem esvaziados.",
        off = "Desligado",
    },
    ["ru"] = {
        rangeRow = "Бонус к радиусу базы",
        chestRow = "Бонусные ячейки сундуков",
        rangeCapTitle = "Growing Grounds: Макс. бонус к радиусу",
        rangeCapTip = "Бонус к радиусу растёт плавно на протяжении всех уровней базы; на последнем уровне он достигается полностью. 0 отключает бонус. +100 % удваивает исходный радиус, +300 % увеличивает его в четыре раза. По умолчанию: +100 %. Соседние базы могут ограничивать рост.",
        chestCapTitle = "Growing Grounds: Макс. число бонусных ячеек сундуков",
        chestCapTip = "Эти ячейки добавляются плавно на протяжении всех уровней базы; на последнем уровне выдаются все. 0 отключает их. По умолчанию: 18. Сундуки гильдии делят один общий бонус. Занятые дополнительные ячейки сохраняются, пока их не освободят.",
        off = "Выкл.",
    },
    ["th"] = {
        rangeRow = "โบนัสรัศมีฐาน",
        chestRow = "ช่องหีบเพิ่มเติม",
        rangeCapTitle = "Growing Grounds: โบนัสรัศมีสูงสุด",
        rangeCapTip = "โบนัสรัศมีจะเพิ่มขึ้นทีละน้อยตลอดทุกเลเวลฐาน และจะได้รับครบเมื่อถึงเลเวลสุดท้าย ตั้งเป็น 0 เพื่อปิดใช้งาน +100% จะทำให้รัศมีเดิมเพิ่มเป็น 2 เท่า และ +300% จะเพิ่มเป็น 4 เท่า ค่าเริ่มต้น: +100% ฐานที่อยู่ใกล้เคียงอาจจำกัดการขยาย",
        chestCapTitle = "Growing Grounds: ช่องหีบเพิ่มเติมสูงสุด",
        chestCapTip = "ช่องเหล่านี้จะเพิ่มขึ้นทีละน้อยตลอดทุกเลเวลฐาน และจะได้รับครบเมื่อถึงเลเวลสุดท้าย ตั้งเป็น 0 เพื่อปิดใช้งาน ค่าเริ่มต้น: 18 หีบกิลด์ใช้โบนัสร่วมกัน ช่องเพิ่มเติมที่ยังมีไอเทมอยู่จะคงอยู่จนกว่าจะเอาไอเทมออกหมด",
        off = "ปิด",
    },
    ["tr"] = {
        rangeRow = "Üs Menzili Bonusu",
        chestRow = "Bonus Sandık Yuvaları",
        rangeCapTitle = "Growing Grounds: Maksimum Menzil Bonusu",
        rangeCapTip = "Menzil bonusu tüm üs seviyeleri boyunca kademeli olarak gelir; son seviye bonusun tamamını verir. 0 bonusu kapatır. +%100 orijinal yarıçapı iki katına, +%300 ise dört katına çıkarır. Varsayılan: +%100. Yakındaki üsler büyümeyi sınırlayabilir.",
        chestCapTitle = "Growing Grounds: Maksimum Bonus Sandık Yuvası",
        chestCapTip = "Bu yuvalar tüm üs seviyeleri boyunca kademeli olarak gelir; son seviye hepsini verir. 0 yuvaları kapatır. Varsayılan: 18. Lonca Sandıkları tek bir bonusu paylaşır. Dolu olan ekstra yuvalar boşaltılana kadar kalır.",
        off = "Kapalı",
    },
    ["vi"] = {
        rangeRow = "Phạm vi căn cứ cộng thêm",
        chestRow = "Ô rương cộng thêm",
        rangeCapTitle = "Growing Grounds: Phạm vi cộng thêm tối đa",
        rangeCapTip = "Phạm vi cộng thêm tăng dần đều qua mọi cấp độ căn cứ; cấp độ cuối cùng cho toàn bộ. 0 sẽ tắt tính năng này. +100% nhân đôi bán kính gốc; +300% khiến bán kính lớn gấp bốn lần. Mặc định: +100%. Các căn cứ ở gần có thể giới hạn mức tăng.",
        chestCapTitle = "Growing Grounds: Số ô rương cộng thêm tối đa",
        chestCapTip = "Các ô này tăng dần đều qua mọi cấp độ căn cứ; cấp độ cuối cùng cho toàn bộ. 0 sẽ tắt chúng. Mặc định: 18. Rương Bang Hội dùng chung một mức cộng thêm. Ô cộng thêm đang có vật phẩm vẫn được giữ lại cho đến khi dọn trống.",
        off = "Tắt",
    },
    ["zh-Hans"] = {
        rangeRow = "据点范围加成",
        chestRow = "额外箱子栏位",
        rangeCapTitle = "Growing Grounds：范围加成上限",
        rangeCapTip = "范围加成会随据点等级提升逐步增加，达到最高等级时全部生效。设为0则禁用。+100%使原半径翻倍，+300%则变为原来的4倍。默认值：+100%。附近的据点可能会限制扩张。",
        chestCapTitle = "Growing Grounds：额外箱子栏位上限",
        chestCapTip = "额外栏位会随据点等级提升逐步增加，达到最高等级时全部生效。设为0则禁用。默认值：18。公会箱子共享同一份加成。已有物品的额外栏位会保留至清空为止。",
        off = "关闭",
    },
    ["zh-Hant"] = {
        rangeRow = "據點範圍加成",
        chestRow = "額外箱子欄位",
        rangeCapTitle = "Growing Grounds：範圍加成上限",
        rangeCapTip = "範圍加成會隨據點等級提升逐步增加，達到最高等級時全部生效。設為0則停用。+100%會使原半徑變為2倍，+300%則變為4倍。預設值：+100%。附近的據點可能會限制擴張。",
        chestCapTitle = "Growing Grounds：額外箱子欄位上限",
        chestCapTip = "額外欄位會隨據點等級提升逐步增加，達到最高等級時全部生效。設為0則停用。預設值：18。公會箱子共用同一份加成。已有物品的額外欄位會保留至清空為止。",
        off = "關閉",
    },
}

local byLower = {}
for _, culture in ipairs(Texts.cultures) do byLower[culture:lower()] = culture end

local chineseScript = {hans="zh-Hans", chs="zh-Hans", hant="zh-Hant", cht="zh-Hant"}
local chineseRegion = {cn="zh-Hans", sg="zh-Hans", my="zh-Hans", tw="zh-Hant", hk="zh-Hant", mo="zh-Hant"}

-- The engine's culture string is not verified yet, so accept fr, fr-FR, fr_FR, zh-Hans-CN, ZH-TW,
-- pt-PT, es-419 or fr_FR.UTF-8 alike. Anything unknown falls back to English.
function Texts.match(culture)
    if type(culture) ~= "string" then return "en" end
    local tag = culture:match("^%s*(.-)%s*$"):lower():gsub("[%.@].*$", ""):gsub("_", "-")
    if byLower[tag] then return byLower[tag] end
    local parts = {}
    for part in tag:gmatch("[^%-]+") do parts[#parts + 1] = part end
    local language = parts[1]
    if language == "zh" then
        for i = 2, #parts do
            if chineseScript[parts[i]] then return chineseScript[parts[i]] end
        end
        for i = 2, #parts do
            if chineseRegion[parts[i]] then return chineseRegion[parts[i]] end
        end
        return "zh-Hans"
    elseif language == "pt" then
        return "pt-BR"
    elseif language == "es" then
        -- A region is two letters or three digits; a four-letter script subtag is not one.
        for i = 2, #parts do
            local part = parts[i]
            if part:match("^%a%a$") or part:match("^%d%d%d$") then
                return part == "es" and "es" or "es-MX"
            end
        end
        return "es"
    end
    return byLower[language or ""] or "en"
end

-- A fresh table each time, so one caller cannot change what another reads.
function Texts.get(culture)
    local source, texts = data[Texts.match(culture)], {}
    for _, key in ipairs(Texts.keys) do texts[key] = source[key] or data.en[key] end
    return texts
end

return Texts
