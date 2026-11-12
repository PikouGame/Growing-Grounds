-- Every text the mod shows to the player, in the 17 cultures of the game. This is NOT a UE4SS entry point.
-- Wording follows the game's own vocabulary (base, base level, Guild Chest, Off, slot) in each culture.
-- Percent signs follow each language's usual form; French uses a no-break space (U+00A0) as the game's
-- own French strings do.
local Texts = {}

-- The game's own culture codes, in the order of its package.
Texts.cultures = {"en", "ja", "de", "es", "es-MX", "fr", "id", "it", "ko", "pl", "pt-BR", "ru", "th",
    "tr", "vi", "zh-Hans", "zh-Hant"}

Texts.keys = {"rangeRow", "chestRow", "rangeCapTitle", "rangeCapTip", "chestCapTitle", "chestCapTip", "palboxRow", "palboxCapTitle", "palboxCapTip", "palboxStartTitle", "palboxStartTip", "chestCapacity", "off"}

local data = {
    ["en"] = {
        chestCapacity = "%d + %d slots",
        palboxRow = "Palbox Boxes",
        palboxCapTitle = "Growing Grounds: Maximum total Palbox boxes",
        palboxCapTip = "Total capacity, including starting boxes: 1–96; default: 64. Boxes unlock evenly across base levels, rounded to whole boxes. The last level reaches this total. Occupied, locked or open boxes are kept when reducing capacity.",
        rangeRow = "Base Range Bonus",
        chestRow = "Bonus Chest Slots",
        rangeCapTitle = "Growing Grounds: Maximum range bonus",
        rangeCapTip = "The range bonus arrives steadily over all base levels; the last level gives it all. 0 disables it. +100% doubles the original radius; +300% makes it four times larger. Default: +100%. Nearby bases can limit growth.",
        chestCapTitle = "Growing Grounds: Maximum bonus chest slots",
        chestCapTip = "These slots arrive steadily over all base levels; the last level gives them all. 0 disables them. Default: 18. Guild Chests share one bonus. Occupied extra slots remain until emptied.",
        off = "Off",
        palboxStartTitle = "Growing Grounds: Starting Palbox boxes",
        palboxStartTip = "Total boxes at base level 1. Minimum: 1; default: 32. Cannot exceed the maximum. Does not affect the Global Palbox.",
    },
    ["ja"] = {
        chestCapacity = "%d + %d スロット",
        palboxRow = "パルボックスのボックス数",
        palboxCapTitle = "Growing Grounds: パルボックスの最大合計ボックス数",
        palboxCapTip = "初期ボックスを含む合計数：1～96、初期値64。拠点レベルに応じて均等に増え、整数に丸められます。最終レベルで上限に到達します。減らす場合も、使用中・ロック中・表示中のボックスは保持されます。",
        rangeRow = "拠点の範囲ボーナス",
        chestRow = "チェストの追加スロット",
        rangeCapTitle = "Growing Grounds: 範囲ボーナスの上限",
        rangeCapTip = "範囲ボーナスは拠点レベルが上がるにつれて少しずつ増え、最大レベルですべて適用されます。0で無効になります。+100%で元の半径の2倍、+300%で4倍になります。初期値: +100%。近くの拠点によって拡大が制限されることがあります。",
        chestCapTitle = "Growing Grounds: 追加チェストスロットの上限",
        chestCapTip = "追加スロットは拠点レベルが上がるにつれて少しずつ増え、最大レベルですべて適用されます。0で無効になります。初期値: 18。すべてのギルドチェストで1つのボーナスを共有します。アイテムが入っている追加スロットは、空にするまで残ります。",
        off = "オフ",
        palboxStartTitle = "Growing Grounds: パルボックスの初期ボックス数",
        palboxStartTip = "拠点レベル1での合計ボックス数。最小1、初期値32。最大数を超えることはできません。グローバルパルボックスには影響しません。",
    },
    ["de"] = {
        chestCapacity = "%d + %d Plätze",
        palboxRow = "Palbox-Boxen",
        palboxCapTitle = "Growing Grounds: Maximale Gesamtzahl der Palbox-Boxen",
        palboxCapTip = "Gesamtkapazität einschließlich Startboxen: 1–96; Standard: 64. Boxen werden gleichmäßig über die Basisstufen verteilt und auf ganze Boxen gerundet. Die letzte Stufe erreicht das Maximum. Belegte, gesperrte oder geöffnete Boxen bleiben bei einer Verringerung erhalten.",
        rangeRow = "Lagerradius-Bonus",
        chestRow = "Zusätzliche Truhenslots",
        rangeCapTitle = "Growing Grounds: Maximaler Radiusbonus",
        rangeCapTip = "Der Radiusbonus steigt mit jedem Lagerlevel gleichmäßig an; auf dem letzten Level ist er vollständig erreicht. 0 deaktiviert ihn. +100 % verdoppelt den ursprünglichen Radius, +300 % vervierfacht ihn. Standard: +100 %. Nahe Lager können das Wachstum begrenzen.",
        chestCapTitle = "Growing Grounds: Maximale zusätzliche Truhenslots",
        chestCapTip = "Diese Slots kommen mit jedem Lagerlevel gleichmäßig hinzu; auf dem letzten Level sind alle freigeschaltet. 0 deaktiviert sie. Standard: 18. Gildentruhen teilen sich einen Bonus. Belegte zusätzliche Slots bleiben bestehen, bis sie geleert werden.",
        off = "Aus",
        palboxStartTitle = "Growing Grounds: Palbox-Boxen zu Beginn",
        palboxStartTip = "Gesamtzahl der Boxen auf Basisstufe 1. Minimum: 1; Standard: 32. Darf das Maximum nicht überschreiten. Betrifft nicht die globale Palbox.",
    },
    ["es"] = {
        chestCapacity = "%d + %d espacios",
        palboxRow = "Cajas de la Palbox",
        palboxCapTitle = "Growing Grounds: Máximo total de cajas de la Palbox",
        palboxCapTip = "Capacidad total, incluidas las cajas iniciales: 1–96; predeterminado: 64. Las cajas se reparten entre los niveles de base, redondeadas a cajas enteras. El último nivel alcanza este total. Al reducir la capacidad se conservan las cajas ocupadas, bloqueadas o abiertas.",
        rangeRow = "Bonificación de alcance de la base",
        chestRow = "Espacios extra de cofre",
        rangeCapTitle = "Growing Grounds: Bonificación máxima de alcance",
        rangeCapTip = "La bonificación de alcance aumenta de forma gradual a lo largo de todos los niveles de la base; el último nivel la otorga por completo. Con 0 se desactiva. +100 % duplica el radio original y +300 % lo multiplica por cuatro. Valor predeterminado: +100 %. Las bases cercanas pueden limitar el crecimiento.",
        chestCapTitle = "Growing Grounds: Máximo de espacios extra de cofre",
        chestCapTip = "Estos espacios se obtienen de forma gradual a lo largo de todos los niveles de la base; el último nivel los otorga todos. Con 0 se desactivan. Valor predeterminado: 18. Los cofres de gremio comparten una única bonificación. Los espacios extra ocupados se conservan hasta que se vacíen.",
        off = "Desactivado",
        palboxStartTitle = "Growing Grounds: Cajas iniciales de la Palbox",
        palboxStartTip = "Total de cajas en el nivel de base 1. Mínimo: 1; predeterminado: 32. No puede superar el máximo. No afecta a la Palbox global.",
    },
    ["es-MX"] = {
        chestCapacity = "%d + %d ranuras",
        palboxRow = "Cajas de la Palbox",
        palboxCapTitle = "Growing Grounds: Máximo total de cajas de la Palbox",
        palboxCapTip = "Capacidad total, incluidas las cajas iniciales: 1–96; predeterminado: 64. Las cajas se reparten entre los niveles de base, redondeadas a cajas enteras. El último nivel alcanza este total. Al reducir la capacidad se conservan las cajas ocupadas, bloqueadas o abiertas.",
        rangeRow = "Bonificación de rango de la base",
        chestRow = "Ranuras extra de cofre",
        rangeCapTitle = "Growing Grounds: Bonificación máxima de rango",
        rangeCapTip = "La bonificación de rango aumenta poco a poco con cada nivel de base; el último nivel la otorga completa. Con 0 se desactiva. +100% duplica el radio original y +300% lo hace cuatro veces más grande. Predeterminado: +100%. Las bases cercanas pueden limitar el crecimiento.",
        chestCapTitle = "Growing Grounds: Máximo de ranuras extra de cofre",
        chestCapTip = "Estas ranuras llegan poco a poco con cada nivel de base; el último nivel las otorga todas. Con 0 se desactivan. Predeterminado: 18. Los cofres de gremio comparten una sola bonificación. Las ranuras extra ocupadas se conservan hasta que se vacíen.",
        off = "Desactivado",
        palboxStartTitle = "Growing Grounds: Cajas iniciales de la Palbox",
        palboxStartTip = "Total de cajas en el nivel de base 1. Mínimo: 1; predeterminado: 32. No puede superar el máximo. No afecta a la Palbox global.",
    },
    ["fr"] = {
        chestCapacity = "%d + %d emplacements",
        palboxRow = "Boîtes du Palbox",
        palboxCapTitle = "Growing Grounds: Maximum total de boîtes du Palbox",
        palboxCapTip = "Capacité totale, boîtes de départ incluses : 1–96 ; par défaut : 64. Les boîtes se débloquent progressivement sur les niveaux de base, arrondies à l’unité. Le dernier niveau atteint ce total. Les boîtes occupées, verrouillées ou ouvertes sont conservées en cas de réduction.",
        rangeRow = "Bonus de rayon de la base",
        chestRow = "Emplacements de coffre bonus",
        rangeCapTitle = "Growing Grounds : bonus de rayon maximal",
        rangeCapTip = "Le bonus de rayon arrive progressivement sur tous les niveaux de la base ; le dernier niveau l'accorde en totalité. 0 le désactive. +100\u{A0}% double le rayon d'origine ; +300\u{A0}% le multiplie par quatre. Par défaut : +100\u{A0}%. Les bases voisines peuvent limiter la croissance.",
        chestCapTitle = "Growing Grounds : nombre max d'emplacements de coffre bonus",
        chestCapTip = "Ces emplacements arrivent progressivement sur tous les niveaux de la base ; le dernier niveau les accorde tous. 0 les désactive. Par défaut : 18. Les coffres de guilde partagent un seul bonus. Les emplacements bonus occupés restent jusqu'à ce qu'ils soient vidés.",
        off = "Désactivé",
        palboxStartTitle = "Growing Grounds: Boîtes du Palbox au départ",
        palboxStartTip = "Nombre total de boîtes au niveau de base 1. Minimum : 1 ; par défaut : 32. Ne peut pas dépasser le maximum. Sans effet sur le Palbox global.",
    },
    ["id"] = {
        chestCapacity = "%d + %d slot",
        palboxRow = "Kotak Palbox",
        palboxCapTitle = "Growing Grounds: Total maksimum kotak Palbox",
        palboxCapTip = "Kapasitas total termasuk kotak awal: 1–96; bawaan: 64. Kotak dibuka merata sepanjang level markas, dibulatkan ke kotak utuh. Level terakhir mencapai total ini. Kotak terisi, terkunci, atau terbuka tetap disimpan saat kapasitas dikurangi.",
        rangeRow = "Bonus Jangkauan Markas",
        chestRow = "Slot Peti Bonus",
        rangeCapTitle = "Growing Grounds: Bonus jangkauan maksimum",
        rangeCapTip = "Bonus jangkauan bertambah secara bertahap di sepanjang semua level markas; level terakhir memberikan seluruhnya. 0 menonaktifkannya. +100% menggandakan radius asli; +300% membuatnya empat kali lebih besar. Bawaan: +100%. Markas di dekatnya dapat membatasi pertumbuhan.",
        chestCapTitle = "Growing Grounds: Slot peti bonus maksimum",
        chestCapTip = "Slot ini bertambah secara bertahap di sepanjang semua level markas; level terakhir memberikan semuanya. 0 menonaktifkannya. Bawaan: 18. Peti Guild berbagi satu bonus. Slot tambahan yang terisi tetap ada sampai dikosongkan.",
        off = "Mati",
        palboxStartTitle = "Growing Grounds: Kotak Palbox awal",
        palboxStartTip = "Jumlah total kotak pada level markas 1. Minimum: 1; bawaan: 32. Tidak boleh melebihi maksimum. Tidak memengaruhi Global Palbox.",
    },
    ["it"] = {
        chestCapacity = "%d + %d slot",
        palboxRow = "Box del Palbox",
        palboxCapTitle = "Growing Grounds: Totale massimo di box del Palbox",
        palboxCapTip = "Capacità totale, inclusi i box iniziali: 1–96; predefinito: 64. I box si sbloccano uniformemente tra i livelli base, arrotondati a box interi. L’ultimo livello raggiunge questo totale. Riducendo la capacità, i box occupati, bloccati o aperti vengono conservati.",
        rangeRow = "Bonus raggio della base",
        chestRow = "Slot bonus dei forzieri",
        rangeCapTitle = "Growing Grounds: Bonus massimo di raggio",
        rangeCapTip = "Il bonus di raggio arriva gradualmente lungo tutti i livelli della base; l'ultimo livello lo concede per intero. Con 0 è disattivato. +100% raddoppia il raggio originale; +300% lo rende quattro volte più grande. Predefinito: +100%. Le basi vicine possono limitare la crescita.",
        chestCapTitle = "Growing Grounds: Numero massimo di slot bonus dei forzieri",
        chestCapTip = "Questi slot arrivano gradualmente lungo tutti i livelli della base; l'ultimo livello li concede tutti. Con 0 sono disattivati. Predefinito: 18. I forzieri della gilda condividono un unico bonus. Gli slot extra occupati restano finché non vengono svuotati.",
        off = "Spento",
        palboxStartTitle = "Growing Grounds: Box iniziali del Palbox",
        palboxStartTip = "Totale dei box al livello base 1. Minimo: 1; predefinito: 32. Non può superare il massimo. Non influisce sul Palbox globale.",
    },
    ["ko"] = {
        chestCapacity = "%d + %d칸",
        palboxRow = "팰 상자 박스 수",
        palboxCapTitle = "Growing Grounds: 팰 상자 최대 총 박스 수",
        palboxCapTip = "시작 박스를 포함한 총 용량: 1–96, 기본값 64. 거점 레벨에 따라 균등하게 증가하며 정수 박스 수로 반올림됩니다. 마지막 레벨에 이 총량에 도달합니다. 용량을 줄여도 사용 중이거나 잠겼거나 열린 박스는 유지됩니다.",
        rangeRow = "거점 범위 보너스",
        chestRow = "추가 상자 슬롯",
        rangeCapTitle = "Growing Grounds: 최대 범위 보너스",
        rangeCapTip = "범위 보너스는 모든 거점 레벨에 걸쳐 조금씩 늘어나며, 마지막 레벨에서 전부 적용됩니다. 0이면 비활성화됩니다. +100%는 원래 반경의 2배, +300%는 4배가 됩니다. 기본값: +100%. 근처에 다른 거점이 있으면 확장이 제한될 수 있습니다.",
        chestCapTitle = "Growing Grounds: 최대 추가 상자 슬롯",
        chestCapTip = "추가 슬롯은 모든 거점 레벨에 걸쳐 조금씩 늘어나며, 마지막 레벨에서 전부 적용됩니다. 0이면 비활성화됩니다. 기본값: 18. 길드 상자는 보너스 하나를 공유합니다. 아이템이 들어 있는 추가 슬롯은 비울 때까지 유지됩니다.",
        off = "끄기",
        palboxStartTitle = "Growing Grounds: 팰 상자 시작 박스 수",
        palboxStartTip = "거점 레벨 1의 총 박스 수입니다. 최소 1, 기본값 32이며 최대값을 초과할 수 없습니다. 글로벌 팰 상자에는 영향을 주지 않습니다.",
    },
    ["pl"] = {
        chestCapacity = "%d + %d miejsc",
        palboxRow = "Skrzynki Palboxa",
        palboxCapTitle = "Growing Grounds: Maksymalna łączna liczba skrzynek Palboxa",
        palboxCapTip = "Łączna pojemność wraz ze skrzynkami początkowymi: 1–96; domyślnie: 64. Skrzynki przybywają równomiernie wraz z poziomami bazy, po zaokrągleniu do pełnych skrzynek. Ostatni poziom osiąga ten limit. Zajęte, zablokowane lub otwarte skrzynki pozostają przy zmniejszaniu pojemności.",
        rangeRow = "Premia do zasięgu bazy",
        chestRow = "Dodatkowe miejsca w skrzyniach",
        rangeCapTitle = "Growing Grounds: Maksymalna premia do zasięgu",
        rangeCapTip = "Premia do zasięgu rośnie stopniowo przez wszystkie poziomy bazy; ostatni poziom daje ją w całości. 0 wyłącza premię. +100% podwaja pierwotny promień, a +300% czyni go czterokrotnie większym. Domyślnie: +100%. Pobliskie bazy mogą ograniczać wzrost.",
        chestCapTitle = "Growing Grounds: Maksymalna liczba dodatkowych miejsc w skrzyniach",
        chestCapTip = "Te miejsca pojawiają się stopniowo przez wszystkie poziomy bazy; ostatni poziom daje je wszystkie. 0 wyłącza je. Domyślnie: 18. Skrzynie gildii dzielą jedną premię. Zajęte dodatkowe miejsca zostają, dopóki nie zostaną opróżnione.",
        off = "Wyłączone",
        palboxStartTitle = "Growing Grounds: Początkowe skrzynki Palboxa",
        palboxStartTip = "Łączna liczba skrzynek na poziomie bazy 1. Minimum: 1; domyślnie: 32. Nie może przekraczać maksimum. Nie dotyczy globalnego Palboxa.",
    },
    ["pt-BR"] = {
        chestCapacity = "%d + %d espaços",
        palboxRow = "Caixas da Palbox",
        palboxCapTitle = "Growing Grounds: Máximo total de caixas da Palbox",
        palboxCapTip = "Capacidade total, incluindo as caixas iniciais: 1–96; padrão: 64. As caixas são distribuídas entre os níveis da base, arredondadas para caixas inteiras. O último nível atinge esse total. Caixas ocupadas, bloqueadas ou abertas são mantidas ao reduzir a capacidade.",
        rangeRow = "Bônus de alcance da base",
        chestRow = "Slots extras de baú",
        rangeCapTitle = "Growing Grounds: Bônus máximo de alcance",
        rangeCapTip = "O bônus de alcance chega aos poucos ao longo de todos os níveis da base; o último nível concede tudo. 0 desativa o bônus. +100% dobra o raio original e +300% o torna quatro vezes maior. Padrão: +100%. Bases próximas podem limitar o crescimento.",
        chestCapTitle = "Growing Grounds: Máximo de slots extras de baú",
        chestCapTip = "Estes slots chegam aos poucos ao longo de todos os níveis da base; o último nível concede todos. 0 desativa os slots. Padrão: 18. Os Baús de Guilda compartilham um único bônus. Slots extras ocupados permanecem até serem esvaziados.",
        off = "Desligado",
        palboxStartTitle = "Growing Grounds: Caixas iniciais da Palbox",
        palboxStartTip = "Total de caixas no nível de base 1. Mínimo: 1; padrão: 32. Não pode ultrapassar o máximo. Não afeta a Palbox global.",
    },
    ["ru"] = {
        chestCapacity = "%d + %d ячеек",
        palboxRow = "Ящики Палбокса",
        palboxCapTitle = "Growing Grounds: Максимальное общее число ящиков Палбокса",
        palboxCapTip = "Общая вместимость с учётом начальных ящиков: 1–96; по умолчанию: 64. Ящики равномерно распределяются по уровням базы с округлением до целых. Последний уровень достигает этого предела. При уменьшении сохраняются занятые, заблокированные или открытые ящики.",
        rangeRow = "Бонус к радиусу базы",
        chestRow = "Бонусные ячейки сундуков",
        rangeCapTitle = "Growing Grounds: Макс. бонус к радиусу",
        rangeCapTip = "Бонус к радиусу растёт плавно на протяжении всех уровней базы; на последнем уровне он достигается полностью. 0 отключает бонус. +100 % удваивает исходный радиус, +300 % увеличивает его в четыре раза. По умолчанию: +100 %. Соседние базы могут ограничивать рост.",
        chestCapTitle = "Growing Grounds: Макс. число бонусных ячеек сундуков",
        chestCapTip = "Эти ячейки добавляются плавно на протяжении всех уровней базы; на последнем уровне выдаются все. 0 отключает их. По умолчанию: 18. Сундуки гильдии делят один общий бонус. Занятые дополнительные ячейки сохраняются, пока их не освободят.",
        off = "Выкл.",
        palboxStartTitle = "Growing Grounds: Начальные ящики Палбокса",
        palboxStartTip = "Общее число ящиков на уровне базы 1. Минимум: 1; по умолчанию: 32. Не может превышать максимум. Не влияет на глобальный Палбокс.",
    },
    ["th"] = {
        chestCapacity = "%d + %d ช่อง",
        palboxRow = "กล่องในพาลบ็อกซ์",
        palboxCapTitle = "Growing Grounds: จำนวนกล่องพาลบ็อกซ์รวมสูงสุด",
        palboxCapTip = "ความจุรวมกล่องเริ่มต้น: 1–96 ค่าเริ่มต้น 64 ปลดล็อกกล่องอย่างสม่ำเสมอตามระดับฐานและปัดเป็นจำนวนเต็ม ระดับสุดท้ายจะถึงจำนวนนี้ เมื่อลดความจุ กล่องที่มีพาล ล็อกอยู่ หรือเปิดอยู่จะยังคงอยู่",
        rangeRow = "โบนัสรัศมีฐาน",
        chestRow = "ช่องหีบเพิ่มเติม",
        rangeCapTitle = "Growing Grounds: โบนัสรัศมีสูงสุด",
        rangeCapTip = "โบนัสรัศมีจะเพิ่มขึ้นทีละน้อยตลอดทุกเลเวลฐาน และจะได้รับครบเมื่อถึงเลเวลสุดท้าย ตั้งเป็น 0 เพื่อปิดใช้งาน +100% จะทำให้รัศมีเดิมเพิ่มเป็น 2 เท่า และ +300% จะเพิ่มเป็น 4 เท่า ค่าเริ่มต้น: +100% ฐานที่อยู่ใกล้เคียงอาจจำกัดการขยาย",
        chestCapTitle = "Growing Grounds: ช่องหีบเพิ่มเติมสูงสุด",
        chestCapTip = "ช่องเหล่านี้จะเพิ่มขึ้นทีละน้อยตลอดทุกเลเวลฐาน และจะได้รับครบเมื่อถึงเลเวลสุดท้าย ตั้งเป็น 0 เพื่อปิดใช้งาน ค่าเริ่มต้น: 18 หีบกิลด์ใช้โบนัสร่วมกัน ช่องเพิ่มเติมที่ยังมีไอเทมอยู่จะคงอยู่จนกว่าจะเอาไอเทมออกหมด",
        off = "ปิด",
        palboxStartTitle = "Growing Grounds: กล่องพาลบ็อกซ์เริ่มต้น",
        palboxStartTip = "จำนวนกล่องรวมที่ฐานระดับ 1 ต่ำสุด 1 ค่าเริ่มต้น 32 ต้องไม่เกินจำนวนสูงสุด ไม่ส่งผลต่อพาลบ็อกซ์ส่วนกลาง",
    },
    ["tr"] = {
        chestCapacity = "%d + %d yuva",
        palboxRow = "Palbox Kutuları",
        palboxCapTitle = "Growing Grounds: Toplam Palbox kutusu üst sınırı",
        palboxCapTip = "Başlangıç kutuları dahil toplam kapasite: 1–96; varsayılan: 64. Kutular üs seviyelerine eşit dağıtılır ve tam kutuya yuvarlanır. Son seviyede bu toplama ulaşılır. Kapasite azaltıldığında dolu, kilitli veya açık kutular korunur.",
        rangeRow = "Üs Menzili Bonusu",
        chestRow = "Bonus Sandık Yuvaları",
        rangeCapTitle = "Growing Grounds: Maksimum Menzil Bonusu",
        rangeCapTip = "Menzil bonusu tüm üs seviyeleri boyunca kademeli olarak gelir; son seviye bonusun tamamını verir. 0 bonusu kapatır. +%100 orijinal yarıçapı iki katına, +%300 ise dört katına çıkarır. Varsayılan: +%100. Yakındaki üsler büyümeyi sınırlayabilir.",
        chestCapTitle = "Growing Grounds: Maksimum Bonus Sandık Yuvası",
        chestCapTip = "Bu yuvalar tüm üs seviyeleri boyunca kademeli olarak gelir; son seviye hepsini verir. 0 yuvaları kapatır. Varsayılan: 18. Lonca Sandıkları tek bir bonusu paylaşır. Dolu olan ekstra yuvalar boşaltılana kadar kalır.",
        off = "Kapalı",
        palboxStartTitle = "Growing Grounds: Başlangıç Palbox kutuları",
        palboxStartTip = "Üs seviyesi 1’deki toplam kutu sayısı. En az: 1; varsayılan: 32. Üst sınırı aşamaz. Küresel Palbox etkilenmez.",
    },
    ["vi"] = {
        chestCapacity = "%d + %d ô",
        palboxRow = "Hộp trong Palbox",
        palboxCapTitle = "Growing Grounds: Tổng số hộp Palbox tối đa",
        palboxCapTip = "Tổng sức chứa gồm cả hộp ban đầu: 1–96; mặc định: 64. Hộp mở khóa đều qua các cấp căn cứ, làm tròn thành hộp nguyên. Cấp cuối đạt tổng này. Khi giảm sức chứa, các hộp có Pal, bị khóa hoặc đang mở vẫn được giữ lại.",
        rangeRow = "Phạm vi căn cứ cộng thêm",
        chestRow = "Ô rương cộng thêm",
        rangeCapTitle = "Growing Grounds: Phạm vi cộng thêm tối đa",
        rangeCapTip = "Phạm vi cộng thêm tăng dần đều qua mọi cấp độ căn cứ; cấp độ cuối cùng cho toàn bộ. 0 sẽ tắt tính năng này. +100% nhân đôi bán kính gốc; +300% khiến bán kính lớn gấp bốn lần. Mặc định: +100%. Các căn cứ ở gần có thể giới hạn mức tăng.",
        chestCapTitle = "Growing Grounds: Số ô rương cộng thêm tối đa",
        chestCapTip = "Các ô này tăng dần đều qua mọi cấp độ căn cứ; cấp độ cuối cùng cho toàn bộ. 0 sẽ tắt chúng. Mặc định: 18. Rương Bang Hội dùng chung một mức cộng thêm. Ô cộng thêm đang có vật phẩm vẫn được giữ lại cho đến khi dọn trống.",
        off = "Tắt",
        palboxStartTitle = "Growing Grounds: Hộp Palbox ban đầu",
        palboxStartTip = "Tổng số hộp ở cấp căn cứ 1. Tối thiểu: 1; mặc định: 32. Không thể vượt quá tối đa. Không ảnh hưởng đến Palbox toàn cầu.",
    },
    ["zh-Hans"] = {
        chestCapacity = "%d + %d 格",
        palboxRow = "帕鲁终端盒子",
        palboxCapTitle = "Growing Grounds: 帕鲁终端盒子总数上限",
        palboxCapTip = "包括初始盒子的总容量：1–96，默认64。盒子随据点等级均匀解锁，四舍五入为整数，最高等级达到此总数。降低容量时，已占用、锁定或正在打开的盒子会保留。",
        rangeRow = "据点范围加成",
        chestRow = "额外箱子栏位",
        rangeCapTitle = "Growing Grounds：范围加成上限",
        rangeCapTip = "范围加成会随据点等级提升逐步增加，达到最高等级时全部生效。设为0则禁用。+100%使原半径翻倍，+300%则变为原来的4倍。默认值：+100%。附近的据点可能会限制扩张。",
        chestCapTitle = "Growing Grounds：额外箱子栏位上限",
        chestCapTip = "额外栏位会随据点等级提升逐步增加，达到最高等级时全部生效。设为0则禁用。默认值：18。公会箱子共享同一份加成。已有物品的额外栏位会保留至清空为止。",
        off = "关闭",
        palboxStartTitle = "Growing Grounds: 帕鲁终端初始盒子数",
        palboxStartTip = "据点1级时的盒子总数。最少1，默认32，不能超过上限。不影响全局帕鲁终端。",
    },
    ["zh-Hant"] = {
        chestCapacity = "%d + %d 格",
        palboxRow = "帕魯終端盒子",
        palboxCapTitle = "Growing Grounds: 帕魯終端盒子總數上限",
        palboxCapTip = "包括初始盒子的總容量：1–96，預設64。盒子隨據點等級均勻解鎖，四捨五入為整數，最高等級達到此總數。降低容量時，已佔用、鎖定或正在開啟的盒子會保留。",
        rangeRow = "據點範圍加成",
        chestRow = "額外箱子欄位",
        rangeCapTitle = "Growing Grounds：範圍加成上限",
        rangeCapTip = "範圍加成會隨據點等級提升逐步增加，達到最高等級時全部生效。設為0則停用。+100%會使原半徑變為2倍，+300%則變為4倍。預設值：+100%。附近的據點可能會限制擴張。",
        chestCapTitle = "Growing Grounds：額外箱子欄位上限",
        chestCapTip = "額外欄位會隨據點等級提升逐步增加，達到最高等級時全部生效。設為0則停用。預設值：18。公會箱子共用同一份加成。已有物品的額外欄位會保留至清空為止。",
        off = "關閉",
        palboxStartTitle = "Growing Grounds: 帕魯終端初始盒子數",
        palboxStartTip = "據點1級時的盒子總數。最少1，預設32，不能超過上限。不影響全域帕魯終端。",
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
