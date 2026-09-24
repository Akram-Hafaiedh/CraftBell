# TODO

## Blocking
- [ ] Hear back from Loune-Hyjal (CurseForge) — personal fork vs PR vs public release with credit.
- [ ] LICENSE (MIT recommended) once release path is clear.
- [ ] Set real Author handle in `CraftBell.toc`.

## Done in 0.1.1
- [x] Persisted history queue (account SV)
- [x] Whisper / Ready / Reject / Skip actions
- [x] Light stats: completed / rejected / skipped (+ by profession)
- [x] Ready/mailed notify template
- [x] Toast click-to-whisper setting
- [x] Whisper length / hyperlink send fix
- [x] Compact fee format (`2k` / `2m`, no `g`)
- [x] Alert Whisper button matches UI kit

## Done in 0.1.0
- [x] Multi-owner schema + CraftRadarDB import
- [x] RecipeTracker (Track + Track All dialog)
- [x] ChatScanner (channels, whole-word, assigned-owner mute keys)
- [x] AlertFrame (`{fee}`, realm mismatch, smart crafter)
- [x] Main window + Recipes / Settings / History / Keywords tabs
- [x] Per-profession and per-recipe fees
- [x] Locales enUS / frFR / esES
- [x] `.gitignore`, luacheck, CI, issue/PR templates

## Later (if demand)
- [ ] Port RelaySystem (optional)
- [ ] Keyword ↔ profession pairing UI
- [ ] Category bulk-assign
- [ ] Richer stats (customers, realm friction, close reasons)
- [ ] History row overflow menu if four buttons feel tight
- [ ] Backfill `professionID` on old imports
- [ ] Test import against a real `CraftRadarDB` file

## Release QA
- [ ] `/reload` + character switch keeps history
- [ ] Whisper offer + Ready notify from crafter alt
- [ ] Reject / Skip update stats
- [ ] Long template whisper (item links) still sends
- [ ] Toast click-to-whisper on/off in Settings
