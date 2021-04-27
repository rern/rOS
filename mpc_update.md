### RuneAudio+R e Update Database

**Flags:**
- Use only `updating` flag from start to finish.
- Resume on boot:
	- `updating` flag for resume `mpc update`
	- `listing` flag for resume without `mpc update`
	
**Pre:**
- Flag `updating`
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
		- `*.wav` - MPD not read albumartist
	- Others: `name`
	
**Files:**
- Save each mode to files
- Count
	
**Finish:**
- Pushstream broadcast counts
- `passive.js`
	- Hide updating status
	- Update Library counts
- Remove flags
	
