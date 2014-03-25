; -- demeter_and_strawberry_perl.iss --

#define MyInstName "Metis_Installer_for_Windows"
#define MyAppVersion "1"
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
AppId={714B39D5-58E8-4545-877C-D89A238C4B23}
AppName={#Metis} {#MyAppVersion}
AppVersion={#MyAppVersion}
DefaultDirName=\strawberry
DefaultGroupName={#Demeter}
; UninstallDisplayIcon={app}\MyProg.exe
Compression=lzma2
SolidCompression=yes
SourceDir=c:\strawberry
OutputDir=c:\output\{#MyAppVersion}
OutputBaseFilename={#MyInstName}_{#MyAppVersion}
AppComments=XAS Data Processing and Analysis
AppContact={#MyAppURL}
AppCopyright=Metis is copyright (c) 2011-2014 Bruce Ravel, Jeremy Kropf
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
;Filename: "{app}\modify_path.pl.bat"; Parameters: """{app}"""
;Filename: "{app}\munge_pathenv.pl.bat"; Parameters: """{app}"""


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

[Tasks]
Name: "desktopicon"; Description: "Create &desktop icons"; GroupDescription: "Additional shortcuts:";

[Icons]
;;; Demeter applications
Name: "{group}\Metis"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "BLA Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_icon.ico"

;;; Application desktop icons
Name: "{commondesktop}\Metis"; Filename: "{app}\perl\site\bin\metis.bat"; Comment: "BLA Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Metis\share\metis_icon.ico"; Tasks: desktopicon

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

function RemovePath(): boolean;
var
  OrigPath: string;
  start_pos: Longint;
  end_pos: Longint;
  new_str: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  start_pos  := Pos(getPath(''), OrigPath);
  end_pos    := start_pos + Length(getPath(''));
  new_str    := Copy(OrigPath, 0, start_pos-1) + Copy(OrigPath, end_pos, Length(OrigPath));
  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', new_str);
  Result := True;
end;
function InitializeUninstall(): Boolean;
begin
  Result := True;
//  Result := MsgBox('InitializeUninstall:' #13#13 'Uninstall is initializing. Do you really want to start Uninstall?', mbConfirmation, MB_YESNO) = idYes;
//  if Result = False then
//    MsgBox('InitializeUninstall:' #13#13 'Ok, bye bye.', mbInformation, MB_OK);
  RemovePath();  
end;
// C:\Program Files\CollabNet\Subversion Client;%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;C:\strawberry\c\bin;C:\strawberry\perl\site\bin;C:\strawberry\perl\bin;;C:\Str\perl\bin;C:\Str\perl\site\bin;C:\Str\c\bin;d:\;


// Restrict the installation path to have no space 
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result :=True;
  case CurPageID of
    wpSelectDir :
    begin
    if Pos(' ', ExpandConstant('{app}') ) <> 0 then
      begin
        MsgBox('You cannot install to a path containing spaces. Please select a different path.', mbError, mb_Ok);
        Result := False;
      end;
    end;
  end;
end;





// see http://stackoverflow.com/questions/2000296/innosetup-how-to-automatically-uninstall-previous-installed-version
/////////////////////////////////////////////////////////////////////
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\Strawberry_Perl_with_Demeter_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;


/////////////////////////////////////////////////////////////////////
function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;


/////////////////////////////////////////////////////////////////////
function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
// Return Values:
// 1 - uninstall string is empty
// 2 - error executing the UnInstallString
// 3 - successfully executed the UnInstallString

  // default return value
  Result := 0;

  // get the uninstall string of the old app
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := 3
    else
      Result := 2;
  end else
    Result := 1;
end;

/////////////////////////////////////////////////////////////////////
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep=ssInstall) then
  begin
    if (IsUpgrade()) then
    begin
      UnInstallOldVersion();
    end;
  end;
end;