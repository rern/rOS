### RuneAudio+R e Update Database

**Flags:**
- Use only `updating` flag from start to finish.
- `cue`, `wav` flag - optional:
	- Take times
	- Even more on NAS
- Resume on boot:
	- `updating` flag for resume `mpc update`
	- `listing` flag for resume without `mpc update`
	
**Pre:**
- Flag `updating`
- Flag `cue` if included
- Flag `wav` if included
- Pushstream broadcast `updating_db`
- `passive.js` show updating status

**Start:** `mpc rescan` or `mpc update`

**End:** `mpdidle.sh`
- Gets update event from MPD
- Verify with updating flag and mpc status not updating
	
**Query:** `cmd.sh mpcupdatelist`
- Flag `listing`
- Get all list modes into files:
	- Album mode: `album^^artist^^file`
		- Normal `mpc listall`
		- `*.wav` (MPD not read) if flagged.
	- Others: `name`
- Get all list modes from `*.cue` if flagged.
	- `cmd-listcue.sh`
	
**Files:**
- Combine each mode, `list` + `cue` to files
- Count
	
**Finish:**
- Pushstream broadcast counts
- `passive.js`
	- Hide updating status
	- Update Library counts
- Remove all flags
	
