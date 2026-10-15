# מדריך שלב-אחרי-שלב: בניית ה-BDF שנשארו (Controlled Maze)

המדריך הזה משלים את `docs/BDF_CONSTRUCTION.md` (שם יש את רשימות הפורטים המלאות).
כאן יש **סדר עבודה** ו**מלכודות** שנמצאו בדיקה מול הקבצים בפועל.

## מצב נוכחי (נבדק מול הקבצים)

| מה | מצב |
|---|---|
| `KBD_Block.bdf` | בנוי (508 שורות) |
| `Sound_Block.bdf` | בנוי (1066 שורות) |
| `Bird_Block.bdf`, `Coral_Block.bdf`, `hex_display_top.bdf` | **שלדים ריקים** (6 שורות) - צריך לבנות |
| `controlled_maze_top.bdf` | יש בו: `CLK_31P5`, `reset_sync`, `NOT`, `AND2`, `VGA_Controller`, `frame_sequencer`, `frame_blink`, `KBD_Block`, `OR4`, `button_pulse`, `game_logic`, `top_glue_logic`, שני `GND` |
| חסר ב-top | בדיוק מה שהדבקת: `Bird_Block`, `Coral_Block`, `water_background`, `text_draw`, `speed_readout`, `ui_panels`, `objects_mux`, `leading_zero_blank` x2, `hex_display_top`, `Sound_Block`, והרכבת `LEDR` |

סדר העבודה: **שלב 1** תיקון הכפילויות, **שלב 2** סימבולים, **שלבים 3-5** שלושת ה-BDF הפנימיים, **שלב 6** ה-top, **שלב 7** קומפילציה.

---

## כללי BDF שחובה לזכור

1. **חיבור לפי שם:** שני חוטים עם אותו שם מחוברים, גם בלי לצייר קו ביניהם. לכן נותנים לכל רשת שם ייחודי.
2. **אסור לחבר פיזית שני חוטים בשמות שונים.** כשצריך לחבר רשת בשם אחד למקום בשם אחר, משתמשים ב-**Mapper** (ראו למטה).
3. **שם אחד = רשת אחת.** ב-top יש כבר `blink` של `frame_blink`. אסור לקרוא ל-`blink` של הציפור (`screen == ST_HIT`) באותו שם, אחרת הם יתמזגו. קוראים לו `birdBlink`.
4. אוטובוסים נכתבים עם נקודותיים כפולות: `pixelX[10..0]`. מערכים דו-ממדיים כמו ב-`game_logic.bsf`: `score[2..0][3..0]`.
5. אחרי כל שינוי בפורטים של מודול: ליצור מחדש `.bsf` ולעדכן את הסימבול בתוך ה-BDF (קליק ימני על הסימבול, **Update Symbol or Block**).
6. `color_t` הוא אוטובוס של 8 ביטים: `RGB[7..0]`.
7. **Mapper:** קו אוטובוס (Orthogonal Bus Tool) שמסתיים בצומת, קליק ימני על הצומת, **Properties**, לשונית Mapper. בטבלה כותבים בצד אחד את הטווח הנכנס (`columnCount[1..0]`) ובצד השני לאן הוא ממופה (`LEDR[8..7]`). מומלץ לנסות קודם על מופע אחד ולוודא שהקו משנה צבע (מחובר).

---

## שלב 1: תיקון הכפילויות (הסיבה לשגיאות הקומפילציה)

כרגע ב-`controlled_maze.qsf` כל בלוק מופיע פעמיים: גם כ-`.sv` וגם כ-`.bdf`. Quartus נכשל עם
`Can't compile duplicate declarations of entity "Coral_Block"`.

1. **Project -> Add/Remove Files in Project**.
2. מסירים מהרשימה (**Remove**, בלי למחוק מהדיסק) את חמשת ה-`.sv` האלה:
   `RTL/DRAW/Bird_Block.sv`, `RTL/DRAW/Coral_Block.sv`, `RTL/DRAW/hex_display_top.sv`,
   `RTL/KEYBOARDX/KBD_Block.sv`, `RTL/GAME/Sound_Block.sv`.
   הקבצים נשארים בדיסק כי הסימולציות (`sim/`) משתמשות בהם.
3. **משאירים** את כל שאר ה-`.sv` (העלים: `bird_trajectory`, `coral_draw`, `text_draw` וכו') וגם את `RTL/TOP/top_glue.sv` (ה-top משתמש ב-`top_glue_logic`).
4. `RTL/TOP/controlled_maze_top_struct.sv` יכול להישאר ברשימה: שם המודול שלו שונה (`controlled_maze_top_struct`), אז הוא לא מתנגש עם ה-BDF. אבל הוא עדיין משתמש בבלוקים בשמות `Bird_Block` וכו', ולכן ייתכנו שגיאות elaboration אם תשאיר אותו עם הבלוקים ללא `.sv`. אם זה קורה, מסירים גם אותו מהרשימה.
5. **Assignments -> Settings -> General -> Top-level entity** = `controlled_maze_top`. (כרגע כתוב `top_glue`, ואין ישות כזו.)

> אם תעבוד על בלוק אחד בכל פעם, אפשר להשאיר את ה-`.sv` שלו ברשימה עד שה-BDF שלו מוכן. אבל לא יחד עם ה-`.bdf` באותה קומפילציה.

---

## שלב 2: יצירת סימבולים (`.bsf`)

לכל מודול שה-BDF מציב: פותחים את קובץ ה-`.sv` ובוחרים **File -> Create/Update -> Create Symbol Files for Current File**.

כבר יש `.bsf` ל: `CLK_31P5`, `reset_sync`, `VGA_Controller`, `frame_sequencer`, `frame_blink`, `button_pulse`, `game_logic`, `top_glue_logic`, `sound_arbiter` ועוד.

**חסרים** (צריך ליצור): `lfsr_rng`, `bird_trajectory`, `square_object`, `bird_anim`, `birdBitMap`, `coral_draw`, `SEG7` (`RTL/Seg7/SEG7.SV`), `water_background`, `text_draw`, `speed_readout`, `ui_panels`, `objects_mux`, `leading_zero_blank`.

אחרי שבונים כל BDF פנימי: פותחים אותו ויוצרים לו סימבול (אותה פקודה, כשה-BDF פתוח): `Bird_Block.bsf`, `Coral_Block.bsf`, `hex_display_top.bsf`.

---

## שלב 3: `Bird_Block.bdf`

פורטים של הבלוק (Input/Output pins, ליצור לפי הטבלה):
`clk`, `resetN`, `pixelX[10..0]`, `pixelY[10..0]`, `tick`, `run`, `restart`, `mode[1..0]`, `seedLoad`, `seed[15..0]`, `animate`, `blink` (כניסות)
`drawingRequest`, `RGBout[7..0]`, `birdY[10..0]` (יציאות).

סימבולים להציב (Edit -> Insert Symbol, או Project Navigator): `lfsr_rng`, `bird_trajectory`, `square_object`, `bird_anim`, `birdBitMap`, שער `AND2`, שער `NOT`.

חיבורים (כל שם הוא שם של חוט):

| סימבול | פורט | חיבור |
|---|---|---|
| `lfsr_rng` | `clk`, `resetN` | `clk`, `resetN` |
| | `step` | `tick` |
| | `seedLoad` | `seedLoad` |
| | `seed[15..0]` | `seedMix[15..0]` (ראו הערה 1) |
| | `rnd[15..0]` | `rnd[15..0]` |
| `bird_trajectory` | `clk`, `resetN`, `tick`, `run`, `restart`, `mode[1..0]` | לפי השם |
| | `rnd[15..0]` | `rnd[15..0]` |
| | `birdY[10..0]` | `birdY[10..0]` (גם ליציאת הבלוק וגם ל-`square_object`) |
| | `birdVy`, `trajState` | להשאיר ריקים |
| `square_object` | `clk`, `resetN`, `pixelX`, `pixelY` | לפי השם |
| | `topLeftX[10..0]` | קבוע 144 (הערה 2) |
| | `topLeftY[10..0]` | `birdY[10..0]` |
| | `offsetX[10..0]`, `offsetY[10..0]` | באותו שם, ל-`birdBitMap` |
| | `drawingRequest` | `inBracket` |
| | `RGBout` | להשאיר ריק |
| `bird_anim` | `clk`, `resetN`, `tick`, `animate`, `blink` | לפי השם |
| | `frame[1..0]` | `frame[1..0]` |
| | `blinkOff` | `blinkOff` |
| `birdBitMap` | `clk`, `resetN`, `offsetX`, `offsetY`, `frame` | לפי השם |
| | `InsideRectangle` | `inBracket` |
| | `drawingRequest` | `bitmapDR` |
| | `RGBout[7..0]` | ליציאת הבלוק `RGBout[7..0]` |

השער: `NOT(blinkOff)` -> `AND2` יחד עם `bitmapDR` -> היציאה `drawingRequest`.

**הערה 1 (`seedMix`):** ב-SV זה `{seed[7:0], seed[15:8]} ^ 16'h5A5A`. שתי דרכים:
- (פשוטה) קובץ עזר קטן `RTL/DRAW/bird_seed_mix.sv`:
  ```systemverilog
  module bird_seed_mix (input logic [15:0] seed, output logic [15:0] seedMix);
    assign seedMix = {seed[7:0], seed[15:8]} ^ 16'h5A5A;
  endmodule
  ```
  מוסיפים לפרויקט (Add/Remove Files), יוצרים סימבול ומציבים בין `seed` ל-`lfsr_rng.seed`.
- (גרפית) Mapper שמחליף בין החצאים, ו-8 שערי `NOT` על הביטים שבהם הקבוע הוא 1 (ביטים 1,3,4,6,9,11,12,14 של התוצאה).

**הערה 2 (קבוע 144):** `BIRD_X = 144` = `00010010000` בינארי. מחברים `VCC` לביטים 7 ו-4 (`topLeftX[7]`, `topLeftX[4]`) ו-`GND` לשאר (`topLeftX[10..8]`, `topLeftX[6..5]`, `topLeftX[3..0]`). ב-top יש כבר שני `GND` שמחוברים לאוטובוס ככה, אז זה אותו עיקרון.

**פרמטרים של `square_object`:** קליק ימני על הסימבול -> **Properties -> Parameters**: `OBJECT_WIDTH_X = 32`, `OBJECT_HEIGHT_Y = 32` (זה `BIRD_SIZE`; ה-BDF לא רואה את ה-package).

שמירה ואז סימבול: **File -> Create/Update -> Create Symbol Files for Current File**.

---

## שלב 4: `Coral_Block.bdf` (הכי פשוט)

פורטים: כניסות `clk`, `resetN`, `pixelX[10..0]`, `pixelY[10..0]`, `active[2..0]`, `colX[2..0][10..0]`, `gapTop[2..0][9..0]`, `gapBottom[2..0][9..0]`. יציאות `drawingRequest`, `RGBout[7..0]`.

מציבים סימבול אחד, `coral_draw`, ומחברים כל פורט לפין עם **אותו שם בדיוק** (`active`, `colX`, `gapTop`, `gapBottom`...). אין לוגיקה נוספת.

אם חיבור לפי שם של `colX[2..0][10..0]` לא נתפס (הקו נשאר שחור/אדום), מוחקים את החוט ומציירים קו אוטובוס ממש בין הפין לפורט.

---

## שלב 5: `hex_display_top.bdf`

פורטים: כניסות `clk`, `resetN`, `digits[5..0][3..0]`, `digitOn[5..0]`. יציאות `HEX0[6..0]` ... `HEX5[6..0]`.

מציבים 6 סימבולי `SEG7` (העתק והדבק). לכל `i` מ-0 עד 5:

| פורט של `SEG7` (מופע i) | חיבור |
|---|---|
| `clk`, `resetN` | `clk`, `resetN` |
| `iDIG[3..0]` | חוט בשם `digits[i][3..0]` |
| `darkN` | חוט בשם `digitOn[i]` |
| `oSEG[6..0]` | יציאה `HEX{i}[6..0]` |

אם חיבור לפי שם של `digits[i][3..0]` לא עובד: זה הבלוק עם הערך הנמוך ביותר ב-BDF. אפשר **לוותר** על `hex_display_top.bdf`: משאירים את `hex_display_top.sv` בפרויקט, מסירים את ה-`.bdf` שלו מהרשימה, וה-top ישתמש בו כמו שהוא.

---

## שלב 6: הקטע שהדבקת, ב-`controlled_maze_top.bdf`

פותחים את `controlled_maze_top.bdf` ומציבים את הסימבולים הבאים (כל חיבור "לפי שם" = מציבים חוט קצר ושם):

### 6.0 הכנה ב-`top_glue_logic`
ה-SV של הציפור צריך `screen == ST_HIT`, ו-`top_glue_logic` אין לו פלט כזה. מוסיפים ב-`RTL/TOP/top_glue.sv`:

```systemverilog
// בהצהרת הפורטים:   output logic hit,
assign hit = (screen == ST_HIT);
```

אחר כך יוצרים סימבול מחדש ל-`top_glue.sv` ו-**Update Symbol or Block** על `top_glue_logic` בתוך ה-top. (כך נמנעים מהשוואה גרפית של 3 ביטים.)

### 6.1 רשימת הסימבולים והחיבורים

| סימבול | חיבורים (פורט <- רשת) |
|---|---|
| **`Bird_Block`** | `clk`, `resetN`, `pixelX`, `pixelY` <- אותם שמות. `tick` <- `tickMove`. `run` <- `birdRun`. `restart` <- `birdRestart`. `mode[1..0]` <- `birdMode[1..0]`. `seedLoad` <- `birdSeedLoad`. `seed[15..0]` <- `birdSeed[15..0]`. `animate` <- `birdAnimate` (יציאת `NOT` של `crashed`). `blink` <- `birdBlink` (יציאת `hit` של `top_glue_logic`). פלטים: `drawingRequest` -> `birdDR`. `RGBout[7..0]` -> `birdRGB[7..0]`. `birdY[10..0]` -> `birdY[10..0]` (כניסת `game_logic.birdY`). |
| **`Coral_Block`** | `clk`, `resetN`, `pixelX`, `pixelY`. `active[2..0]` <- `coralShown[2..0]` (מ-`top_glue_logic`). `colX`, `gapTop`, `gapBottom` <- אותם שמות מ-`game_logic`. פלטים: `drawingRequest` -> `coralDR`, `RGBout` -> `coralRGB[7..0]`. |
| **`water_background`** | `clk`, `resetN`, `pixelX`, `pixelY`. `RGBout` -> `waterRGB[7..0]`. |
| **`text_draw`** | `clk`, `resetN`, `pixelX`, `pixelY`, `screen[2..0]`, `menuCursor[1..0]`. `scoreDigits[2..0][3..0]` <- `score[2..0][3..0]`. `bestDigits[2..0][3..0]` <- `best[2..0][3..0]`. `newBest` <- `newBest`. `blink` <- `blink` (**של `frame_blink`**). פלטים: `drawingRequest` -> `textDR`, `RGBout` -> `textRGB[7..0]`. |
| **`speed_readout`** | `clk`, `resetN`, `pixelX`, `pixelY`, `screen[2..0]`, `speedLevel[2..0]`. פלטים: `speedDR`, `speedRGB[7..0]`. |
| **`ui_panels`** | `clk`, `resetN`, `pixelX`, `pixelY`, `screen[2..0]`, `menuCursor[1..0]`, `flash` (מ-`top_glue_logic`). פלטים: `panelDR`, `panelRGB[7..0]`. |
| **`objects_mux`** | `clk`, `resetN`. `speedDrawingRequest` <- `speedDR`, `speedRGB` <- `speedRGB[7..0]`. `textDrawingRequest` <- `textDR`, `textRGB` <- `textRGB[7..0]`. `panelDrawingRequest` <- `panelDR`, `panelRGB` <- `panelRGB[7..0]`. `birdDrawingRequest` <- `birdDR`, `birdRGB` <- `birdRGB[7..0]`. `coralDrawingRequest` <- `coralDR`, `coralRGB` <- `coralRGB[7..0]`. `backgroundRGB` <- `waterRGB[7..0]`. פלט `RGBOut[7..0]` -> `screenRGB[7..0]` (זו הרשת שכניסת `VGA_Controller.RGBIn` מחכה לה; לוודא ששם זהה). |
| **`leading_zero_blank` (A)** | `digits[2..0][3..0]` <- `score[2..0][3..0]`. `digitOn[2..0]` -> חוט בשם `digitOn[2..0]` (ה-LOW). |
| **`leading_zero_blank` (B)** | `digits[2..0][3..0]` <- `best[2..0][3..0]`. `digitOn[2..0]` -> חוט `highOn[2..0]`, ואז Mapper `highOn[2..0]` -> `digitOn[5..3]`. |
| **`hex_display_top`** | `clk`, `resetN`. `digits[5..0][3..0]`: Mapper אחד מ-`best[2..0][3..0]` ל-`digits[5..3][3..0]` ו-Mapper שני מ-`score[2..0][3..0]` ל-`digits[2..0][3..0]`. `digitOn[5..0]` <- `digitOn[5..0]` (מהחוטים שלמעלה). `HEX0..HEX5` -> הפינים באותו שם. |
| **`Sound_Block`** | `clk`, `resetN`. `scoreTrigger` <- `scoreEvent`. `failTrigger` <- `failEvent`. `mute` <- `SW0`. `AUD_ADCLRCK`, `AUD_BCLK` <- הפינים. `AUD_DACDAT`, `AUD_XCK`, `AUD_I2C_SCLK` -> הפינים. `AUD_I2C_SDAT` <-> הפין הדו-כיווני. `playingScore`, `playingFail` להשאיר ריקים. |

חשוב: `game_logic` כבר מופיע, ולכן הפלטים שלו (`birdRun`, `colX`, `gapTop`, `score`...) רק צריכים **שם**. לא להוסיף חוטים נוספים.

### 6.2 `LEDR`
ב-SV: `LEDR = {blink, columnCount, difficulty, screen, resetN, pllLocked}`.

| ביטים של `LEDR` | מקור | איך |
|---|---|---|
| `[9]` | `blink` (מ-`frame_blink`) | Mapper `blink` -> `LEDR[9]` |
| `[8..7]` | `columnCount[1..0]` | Mapper `columnCount[1..0]` -> `LEDR[8..7]` |
| `[6..5]` | `difficulty[1..0]` | Mapper `difficulty[1..0]` -> `LEDR[6..5]` |
| `[4..2]` | `screen[2..0]` | Mapper `screen[2..0]` -> `LEDR[4..2]` |
| `[1]` | `resetN` | Mapper `resetN` -> `LEDR[1]` |
| `[0]` | `pllLocked` | Mapper `pllLocked` -> `LEDR[0]` |

כל Mapper מחובר לפין היציאה `LEDR[9..0]` (קו אוטובוס אחד שמגיע לפין, והחוטים שבשם `LEDR[...]` מתחברים אליו לפי שם).
אם זה מסורבל: קובץ עזר `led_pack.sv` עם `assign LEDR = {blink, columnCount, difficulty, screen, resetN, pllLocked};` (6 כניסות, פלט `LEDR[9..0]`) ממלא אותו תפקיד בסימבול אחד.

---

## שלב 7: קומפילציה ובדיקה

1. **Processing -> Start -> Start Analysis & Elaboration**. מצפים ל-0 שגיאות.
2. **Tools -> Tcl Scripts -> `pin.tcl` -> Run** (אחרי שלב 1, ה-top קיים ולכן הלולאה של 3.3V תמצא את כל הפינים).
3. **Start Compilation**.
4. פותחים **Pin Planner** וודאו שכל 20 הפורטים (שעון, KEY, SW0, PS2, LEDR, HEX, OVGA, AUD) מקבלים הדק.

### שגיאות נפוצות

| הודעה | פירוש / פתרון |
|---|---|
| `Can't compile duplicate declarations of entity` | נשאר `.sv` וגם `.bdf` של אותו בלוק (שלב 1). |
| `Top-level design entity "top_glue" is undefined` | לא שונה ה-Top-level entity (שלב 1). |
| `Port "x" does not exist in macrofunction` | הסימבול ב-BDF ישן. קליק ימני, **Update Symbol or Block**. |
| `Output port ... is connected to output ... width mismatch` | טווח לא תואם, למשל `[2..0]` מול `[3..0]`. לבדוק שם החוט. |
| `Pin "x" has no driver` / `stuck at GND` | חוט בלי שם או עם שם בכתיב שונה (`resetN` מול `resetn`). |
| רשת `blink` מתנהגת מוזר | בוצע חיבור בטעות בין `birdBlink` ל-`blink` של `frame_blink`. |
| `Can't find definition for ... square_object` | `square_object.sv` לא ברשימת הקבצים של הפרויקט, או שלא נוצר לו סימבול. |

## רשימת סימון קצרה
- [ ] הוסרו 5 ה-`.sv` של הבלוקים מהפרויקט (שלב 1)
- [ ] Top-level entity = `controlled_maze_top`
- [ ] נוצרו כל הסימבולים (שלב 2)
- [ ] נבנו `Bird_Block`, `Coral_Block`, `hex_display_top`
- [ ] נוסף `hit` ל-`top_glue_logic` ועודכן הסימבול
- [ ] ה-top: 11 סימבולים חדשים + `LEDR`
- [ ] Analysis & Elaboration נקי, אחר כך `pin.tcl`, אחר כך קומפילציה מלאה
