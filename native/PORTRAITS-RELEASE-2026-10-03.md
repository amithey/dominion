# Leader portraits in the Windows release

The main `dist/DOMINION.exe` and `dist/DOMINION-Setup.exe` now include all 22
leader portraits, including the thirteen additional leaders. Source commit:
`144067c`, version 0.9.49. The portraits use the existing identity-based gallery
in the faction picker, leader side panels and diplomatic meetings.

The executable was exported and tested with `--ui-test` (PASS). Source portrait
checks passed 158 assertions; faction integration passed 774 assertions. The
export log confirms the three newest imported textures are included in the pack.
Inno Setup compiled the installer successfully from the tested executable.

Release SHA-256:
- Game: `D85710CC7E5BD2DD0E2EA272CACF0DED26DD55008E904949A077B00188A8A838`
- Installer: `EFB779778E25942CF6F38E1524AAF3B6C342295AF9C9C265F323BBB3186EC61C`

Claude was concurrently preparing 0.9.50 balance changes. Those uncommitted files
were excluded from this build and remain untouched. Subsequent builds from the
shared branch automatically retain the committed portraits. Release binaries
are local artifacts and are excluded from Git by the existing `dist/` rule.
