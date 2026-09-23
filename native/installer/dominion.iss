; DOMINION Windows installer (Inno Setup 6). Built by native/build-windows.ps1,
; which exports the game to dist/DOMINION.exe first and passes the version:
;   ISCC /DAppVersion=0.9.0 native\installer\dominion.iss
; Installs per user by default (no administrator prompt); the first page lets
; the player choose an install for all users instead.

#ifndef AppVersion
  #define AppVersion "0.9.0"
#endif
#define AppName "DOMINION"
#define AppExe "DOMINION.exe"
#define Root "..\.."

[Setup]
AppId={{6F1C2A7E-4B3D-4E8A-9C21-D0A1B2C3E4F5}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Amit Heymans
AppPublisherURL=https://github.com/amithey/dominion
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#Root}\dist
OutputBaseFilename=DOMINION-Setup
SetupIconFile=dominion.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Root}\dist\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Root}\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "THIRD-PARTY-NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Saved games and settings live in %APPDATA%\DOMINION and are kept on
; uninstall, so reinstalling or upgrading keeps the player's progress.
