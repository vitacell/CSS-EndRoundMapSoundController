# Join and enjoy
First, join my zombie panic revival server: 85.87.24.173:27015
It's has some advantages over other panic/revival servers. It has some advantages for zombies, but teams are well balanced anyway. Suggestions are welcome.

# Fixes
This fork fixes the very annoying error, which stops playing map-end sounds after playing the latest soundtrack of the list.

## Console error output
```C
[SM] Exception reported: Invalid index 16 (count: 12)
[SM] Blaming: res.smx
[SM] Call stack trace:
[SM] [0] GetArrayString
[SM] [1] Line 1333, D:\Games\Servers\CSS-Public_Server\css\cstrike\addons\sourcemod\scripting\res.sp::OnRoundEnd
[SM] [3] CS_TerminateRound
[SM] [4] Line 330, src/zr/roundend.inc::RoundEndTerminateRound
[SM] [5] Line 103, src/zr/roundend.inc::RoundEndOnClientInfected
[SM] [6] Line 799, src/zr/infect.inc::InfectHumanToZombie
[SM] [7] Line 362, src/zr/infect.inc::InfectOnClientHurt
[SM] [8] Line 245, src/zr/event.inc::EventPlayerHurt
```

## Possible improvements
FrozDark made CT and T sounds random choosing at round end. The map-end sounds are just a playing from above to bottom, and then the list restars (thanks to fix). I can make to play map-end soundtracks random as CT and T win sounds.
