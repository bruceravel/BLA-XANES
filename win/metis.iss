; -- demeter_and_strawberry_perl.iss --

#define MyInstName "Metis_Installer_for_Windows"
#define MyAppVersion "2.2"
#define MyAppPublisher "Bruce Ravel"
#define MyAppURL "https://github.io/bruceravel/BLA-XANES"
#define Metis "Metis"
#define Demeter "Demeter with Strawberry Perl"

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!
; using ISC 5.4.2(a)

; TODO: Restrict the installation path to have  no non-ascii characters in the path
; TODO: do we need to set Environment variable other than Path ? e.g. file extension mapping?
; TODO: Add alot more menu items that the original Strawberry also adds
; TODO: add License  LicenseFile
; TODO: add README   InfoAfterFile
; TODO: check for other perl installations (eg. in the Path variable) and warn or even abort if there is another one

[Setup]
AppId={{714B39D5-58E8-4545-877C-D89A238C4B23}
AppName={#Metis} {#MyAppVersion}
AppVersion={#MyAppVersion}
DefaultDirName=\strawberry
DefaultGroupName={#Demeter}
; UninstallDisplayIcon={app}\MyProg.exe
Compression=lzma2
SolidCompression=yes
SourceDir=c:\strawberry
OutputDir=c:\output\Metis\version{#MyAppVersion}
OutputBaseFilename={#MyInstName}_{#MyAppVersion}
AppComments=Bent Laue Spectrometer Data Processing
AppContact={#MyAppURL}
AppCopyright=Metis is copyright (c) 2011-2014,2016 Bruce Ravel, Jeremy Kropf
; AppMutex= TODO!
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}

ChangesAssociations=yes
ChangesEnvironment=yes

;SetupIconFile=Demeter.ico
;WizardImageFile=Demeter_installer.bmp

;LicenseFile=Metis.license.txt
;InfoAfterFile=Demeter.readme.txt


[Run]
Filename: "{app}\relocation.pl.bat";

[Dirs]
Name: "{userappdata}\demeter"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueName: "Path"; ValueType: expandsz; ValueData: "{olddata};{code:getPath}"; \
    Check: NeedsAddPath('\perl\site\bin');
; TODO: don't add the leading semi-colon to the Path if there is already a trailing one
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueName: "GNUPLOT_BINARY"; ValueType: expandsz; ValueData: "{app}\c\bin\gunplot\bin\gnuplot.exe";

[Files]
Source: perl\site\bin\metis; DestDir: {app}\perl\site\bin; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\bin\metis.bat; DestDir: {app}\perl\site\bin; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\Xray\BLA.pm; DestDir: {app}\perl\site\lib\Xray; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\Xray\BLA\*; DestDir: {app}\perl\site\lib\Xray\BLA; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\Demeter\UI\Metis.pm; DestDir: {app}\perl\site\lib\Demeter\UI; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion; Excludes: *.prj,*.stan,*~,artug\*,aug\*,UI\Metis.pm,UI\Metis\*; 
Source: perl\site\lib\Demeter\UI\Metis\*; DestDir: {app}\perl\site\lib\Demeter\UI\Metis; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion; Excludes: *.prj,*.stan,*~,artug\*,aug\*,UI\Metis.pm,UI\Metis\*; 
Source: c\hdf5\*; DestDir: {app}\c\hdf5; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\PDL\IO\HDF5.pm; DestDir: {app}\perl\site\lib\PDL\IO\HDF5.pm; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\PDL\IO\HDF5\*; DestDir: {app}\perl\site\lib\PDL\IO\HDF5; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;
Source: perl\site\lib\auto\PDL\IO\HDF5\HDF5.xs.dll; DestDir: {app}\perl\site\lib\auto\PDL\IO\HDF5\HDF5.xs.dll; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion;

[Tasks]
Name: "desktopicon"; Description: "Create &desktop icons"; GroupDescription: "Additional shortcuts:";

[Icons]
;;; Demeter applications
Name: "{group}\Metis - HERFD"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "HERFD Data Processing"; Parameters: "herfd"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_herfd.ico"
Name: "{group}\Metis - XES"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "XES Data Processing"; Parameters: "xes"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_xes.ico"

;;; Application desktop icons
Name: "{commondesktop}\Metis - HERFD"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "HERFD Data Processing"; Parameters: "herfd"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_herfd.ico"; Tasks: desktopicon
Name: "{commondesktop}\Metis - XES"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "XES Data Processing"; Parameters: "xes"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_xes.ico"; Tasks: desktopicon

[Code]
function getPath(Param: String): string;
begin
  Result := ExpandConstant('{app}') + '\perl\bin;' + ExpandConstant('{app}') + '\perl\site\bin;' + ExpandConstant('{app}') + '\c\bin;'
end;

// From http://stackoverflow.com/questions/3304463/how-do-i-modify-the-path-environment-variable-when-running-an-inno-setup-installe
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon
  // Pos() returns 0 if not found
  //Result := Pos(';' + ExpandConstant('{app}') + Param + ';', OrigPath) = 0;
  Result := Pos(getPath(''), OrigPath) = 0;
end;

