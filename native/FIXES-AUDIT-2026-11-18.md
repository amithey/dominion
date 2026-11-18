# מסמך תיקונים — ביקורת 18.11.2026

ממצאים פתוחים מהביקורת על גרסה `df40320`. המספרים נשמרים כדי שניתן יהיה לאתר את הממצאים בהיסטוריית Git.

סימון: 🔴 חמור · 🟠 בינוני · 🟡 נמוך · 🧪 בעיה בבדיקות (לא במשחק)

---

## 🟠 בינוני

### ✅ F3. מבנים שלא עושים מה שהכרטיס מבטיח — תוקן
- **Oil Refinery:** הופך 0.06 נפט/ש' ל־+$7/ש' כשיש נפט במלאי (`economy.gd`).
- **Mountain Mine:** +0.8 ברזל/ש' (עם Advanced Mining יותר).
- **Nuclear Reactor:** כשיש אורניום — צורך 0.04/ש', נותן +$5/ש' ו־+20% ייצור; בלי אורניום רק חשמל. הכרטיס אומר 280MW.
- **Embassy:** יחסים עם כל מדינה בשלום עולים ב־0.5 כל 10 ש' עד +50 (שתי שגרירויות נספרות) — `diplomacy.gd`.
- **Prison:** סוכני אויב 8% יותר נתפסים (שני בתי כלא נספרים) — `espionage.gd`.
- **Railway Station:** +300 אחסון מוחל.
- **Bank / Luxury Villas:** התקרות +60% ו־+16% נאכפות (`economy.income_pct`).
- **Hospital:** מטפל ברגלים פצועים עד 40 מ' (2% חיים/ש', לא תחת אש); כלי רכב — בתיקון רגיל.
- **כרטיסים:** Solar 65MW, Reactor 280MW, Chip Fab, Worship ובנק — עודכנו לאמת (`gameplay_rules.gd`).
- **בדיקה:** `tools/building-cards-check.gd` (9/9, נרשמה ב־`run-tests.ps1`). עוברים גם: economy-100, economy-test, audit-buildings, audit-text, diplomacy-100, intel-100, city-upgrade, gameplay-regressions.

### F4. שמונה מבנים שאי אפשר לבנות
- **איפה:** `native/godot/scripts/hud.gd:16` (`BUILD_MENU`), `:22` (`BUILD_GROUPS`).
- Apartments, Luxury Villas, Solar Farm, Water Treatment, Museum, Park, Stadium, Command Center — יש להם מודל, כרטיס והשפעה עובדת, אבל הם לא בתפריט. ה־AI כן בונה Park ו־Command Center.

### F6. ירייה שהיורה שלה נמחק לא עושה נזק
- **איפה:** `native/godot/scripts/firepower.gd:194`.
- `from is Node3D and is_instance_valid(from)` — הסדר הפוך; על אובייקט משוחרר זו שגיאה שעוצרת את הפיצוץ לפני הנזק. נתפס בטעינת quicksave.
- **כיוון:** `is_instance_valid(from) and from is Node3D`.

### F7. טעינה (F9) באמצע קרב משאירה פגזים באוויר
- **איפה:** `native/godot/scripts/world.gd:2678` (`clear_match`).
- לא מנקה את `effects._projectiles`: פגזים מהמצב הקודם נוחתים במשחק שנטען (נזק, ואפילו הכרזת מלחמה אוטומטית), או זורקים את שגיאת F6.

### F8. דליפות מידע (נגד הכלל: מידע על יריבים רק לפי מודיעין/ראייה)
- `native/godot/scripts/world.gd:6219` — "<Nation> <Building> destroyed" על כל מבנה בעולם, גם יריב מול יריב בתוך הערפל.
- `native/godot/scripts/sitrep.gd:190` — הודעה כזו נרשמת כ"הפסד" שלך.
- `native/godot/scripts/ai.gd:281` — "X forces are advancing on you" בכל גל, בלי בדיקת מודיעין.

### F9. תפריט ראשי/טעינה איטיים עם הרבה שמירות; אין מחיקת שמירה
- **איפה:** `native/godot/scripts/menu.gd:1117` (`list_saves`), `:236`.
- כל שמירה מפוענחת פעמיים לרשימה, והרשימה נבנית פעמיים → 4 פענוחי JSON מלאים לכל שמירה בכל פתיחה.
- אין כפתור מחיקה/שינוי שם במסך Load.

### F10. כטב"מים מתאבדים נספרים כאבדות
- **איפה:** `native/godot/scripts/world.gd` (`fire_weapon`, ענף "kamikaze") → `kill()`.
- Loiterer / Harop / Shahed / Interceptor Drone / Sea Drone: הדוח כותב "Lost: …" על תחמושת שנורתה כמתוכנן, ויש פיצוץ בנקודת השיגור.

### F11. ביצועים בסוף משחק
- 3 שמירות מאוחרות (highlands, inland_sea, strait) נטענו ב־36–43 שניות ורצו לאט מזמן אמת (נמדד תחת עומס מקבילי — לבדוק שוב לבד).

---

## 🟡 נמוך
- **F12.** חלון Build (1600×900) מכסה את Log/Menu/Cheats בפס העליון; חלון בחירת יחידה מכסה את "Skip the guide".
- **F13.** "Redirect shipment" מציע ספינות/מטוסים, אבל `missiles.gd:481` (`redirect_transfer`) מקבל רק מבנים (`hud.gd:1954`).
- **F14.** Attack-move / Bombard / Lay Mines לא מתבטלים בלחיצה נוספת (`hud.gd:914`).
- **F15.** Demolish כשנבחרו יחידות מוחק תעלות/מוקשים ברדיוס 16 מ' בלי אישור (`hud.gd:908`).
- **F16.** תקרת הצבא סופרת תורי אימון של כל המדינות (`world.gd:3208`).
- **F17.** יחידה חדשה יוצאת תמיד לכיוון מרכז המפה; אין rally point (`world.gd:3332`).
- **F18.** פלטפורמות ים של ה־AI נבנות פי 2 מהר (`world.gd:3011` + `ai.gd:187`).
- **F19.** כרטיס העיירה מחשב מס בלי סנקציות ובשיטה שונה מהמס הלאומי; `income_pct` מחושב ולא בשימוש (`economy.gd:239`).
- **F20.** העידן התעשייתי אומר "power grid" אבל סופר מבני מחקר (`research.gd:500`).
- **F21.** המדריך מקבל Housing (מגורי חיילים) כ"room for more people" (`beginner_guide.gd`).
- **F22.** הנחת Drone Swarms (−30%) חלה רק על היחידה `drone` (`research.gd:610`).
- **F23.** רכב בתנועה האזרחית עובר דרך מחלץ (traffic-stuck-check: "road body … 2.4 m from the centre of a extractor").

---

## 🧪 בדיקות (לא באגים במשחק, אבל צריך לתקן)
- **T1.** `world.gd:4095` soak test: `seconds += 2.0 * Engine.time_scale` כשהטיימר כבר מושפע מ־time_scale → "12 דקות" הן בפועל ~3.
- **T2.** `tools/ai-check.gd` — "rivals build their data centres and a fusion cell": מיושן, ה־AI בונה כפר קודם והבדיקה לא מציבה כפרים.
- **T3.** `tools/test_kit.gd` (`quiet`) מכבה ערפל, או"ם, WMD, DEFCON, משברים, עלויות ועוד — צריך לפחות סוויטה אחת שמריצה הכל דולק.
- **T4.** 40 כלים ב־`tools/` לא רשומים ב־`run-tests.ps1`; חלקם מדפיסים "N passed, 0 failed" בלי "PASS".
- **T6.** performance-check, road-traffic-check ותקציבי הזמן של gameplay-nations-100 — להריץ שוב לבד (נכשלו תחת עומס).
- **T7.** `tools/gameplay-nations-100.gd` (`meet_needs`): הכוח של אוקראינה (Long-Range Drone Strikes) עובד רק על מדינה במלחמה, והבדיקה לא פותחת לה מלחמה (כמו שהיא עושה לאיראן) — עוברת או נכשלת לפי מזל.

---

## בדיקת המשך על גרסת df40320

נסרקו 207 קובצי GDScript ובהם 2,652 הצהרות פונקציה בתיקיית scripts. לא נמצא נתיב חסר בהפניות קבועות שנבדקו בקריאות load/preload. אין מדידת כיסוי לכל פונקציה. בשלושת יומני הסבב הקודם יש 184 תוצאות. ארבעה כלים שסומנו ככישלון דיווחו בעצמם על אפס כשלים (AI applications, fortifications, leader badge, roster portraits). בדיקת מסך מלא דורשת תצוגה גרפית.
