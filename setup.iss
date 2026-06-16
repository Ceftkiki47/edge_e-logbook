[Setup]
; Informasi Utama Aplikasi
AppName=E-Logbook LoRa Monitor
AppVersion=1.0
AppPublisher=Divo Satria
AppPublisherURL=https://github.com/divosatria/elogbook

; Default folder instalasi (Program Files)
DefaultDirName={autopf}\ELogbook_LoRa_Monitor
DisableProgramGroupPage=yes

; Nama file installer yang dihasilkan
OutputDir=build\windows\x64\installer
OutputBaseFilename=ELogbook_Installer

; Konfigurasi Kompresi
Compression=lzma
SolidCompression=yes

; Tampilan Installer
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\elogbook_desktop.exe

; Hak akses instalasi
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Menyalin file utama (EXE)
Source: "build\windows\x64\runner\Release\elogbook_desktop.exe"; DestDir: "{app}"; Flags: ignoreversion

; Menyalin seluruh file DLL dan file pendukung
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Menyalin folder data (SANGAT PENTING)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

[Icons]
; Shortcut di Start Menu
Name: "{autoprograms}\E-Logbook LoRa Monitor"; Filename: "{app}\elogbook_desktop.exe"
; Shortcut di Desktop
Name: "{autodesktop}\E-Logbook LoRa Monitor"; Filename: "{app}\elogbook_desktop.exe"; Tasks: desktopicon

[Run]
; Menjalankan aplikasi secara otomatis setelah instalasi selesai
Filename: "{app}\elogbook_desktop.exe"; Description: "{cm:LaunchProgram,E-Logbook LoRa Monitor}"; Flags: nowait postinstall skipifsilent
