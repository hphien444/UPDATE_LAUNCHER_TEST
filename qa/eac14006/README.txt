WESTSIDE TEST - OPTIONAL EAC 14006 QA DIAGNOSTICS
2026-10-28

This opt-in QA branch contains diagnostics, not a launcher update or a proven
VM/cafe compatibility fix. Automatic WESTSIDE TEST remains version 1000094.
No automatic updater metadata, Portal activation, CITY or game server changes
are part of this branch.

VM_PREFLIGHT_READONLY.ps1 collects a read-only safety snapshot from one existing
runtime directory. It does not start EAC, the game, recovery or repair; it does
not stop processes/services or remove safety markers. PowerShell 5.1 syntax,
pure-function checks and mocked collector scenarios were tested. A real guest
run and protected gameplay have not been validated by those tests.

Run only on the authorized affected machine with the correct existing *.app
directory, not the GAME subprocess directory. For initial QA, omit ReportPath
and IncludeHoldText: JSON is printed to stdout and manual hold text is omitted.
Example, after reviewing the script and using your actual runtime path:

  .\VM_PREFLIGHT_READONLY.ps1 -AppRoot "C:\YourGameFolder\WESTSIDE CITY.app"

Keep the resulting report private: it may include local paths, process names,
timestamps and safety metadata. Do not upload it to this public repository.
Normal PowerShell policy applies; this package does not change that policy.

Every report has LaunchAuthorized=false. STOP_FOR_REVIEW, unknown access,
pending/hold/quota evidence or incomplete coverage must be reviewed; never
erase or clone safety state, change clocks, or kill unrelated EAC sessions.
Hardlink counts and atomic file identity are not verified by this collector.
NoMatchingEventsFound does not prove that the machine has never crashed.

The official candidate build 14006 configuration is transferred separately
through an authorized private channel. No module, private Epic configuration,
catalog, credentials or launcher binary is included here. Downloading this
branch does not select or activate that module. Any later trial requires its
own explicit consent and actual module, protected-handoff and server-side
authentication evidence. Do not interpret this branch as a successful fix.
