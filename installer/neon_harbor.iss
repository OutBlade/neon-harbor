; Inno Setup script for Neon Harbor.
; Build with: ISCC.exe neon_harbor.iss  (after exporting both Windows builds to dist\)

[Setup]
AppId={{9C4B6A1E-7F2D-4E8B-AD53-1A6E0B9F2C77}
AppName=Neon Harbor
AppVersion=1.2.0
AppPublisher=OutBlade
; Per-user install so the built-in auto updater can replace the binary
; without elevation.
PrivilegesRequired=lowest
DefaultDirName={autopf}\Neon Harbor
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=NeonHarborSetup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
UninstallDisplayIcon={app}\NeonHarbor.exe

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Files]
; Native binary per architecture, same installed name either way.
Source: "..\dist\NeonHarbor-win-arm64.exe"; DestDir: "{app}"; DestName: "NeonHarbor.exe"; Check: IsArm64
Source: "..\dist\NeonHarbor-win-x64.exe"; DestDir: "{app}"; DestName: "NeonHarbor.exe"; Check: not IsArm64
Source: "..\LICENSE"; DestDir: "{app}"

[Icons]
Name: "{autoprograms}\Neon Harbor"; Filename: "{app}\NeonHarbor.exe"
Name: "{autodesktop}\Neon Harbor"; Filename: "{app}\NeonHarbor.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NeonHarbor.exe"; Description: "Launch Neon Harbor"; Flags: nowait postinstall skipifsilent
