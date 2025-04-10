; Hire HQ Connector for Syrinx - Inno Setup Script
; This installer sets up Google Cloud SDK, Tailscale, a service account, and three scheduled sync tasks

[Setup]
AppName=Hire HQ Connector for Syrinx
AppVersion=1.0
DefaultDirName={autopf}\Hire HQ Connector for Syrinx
DefaultGroupName=Hire HQ Connector for Syrinx
OutputDir=.
OutputBaseFilename=HireHQConnectorForSyrinxSetup
Compression=lzma
SolidCompression=yes
SetupIconFile=hirehq-tray-icon-updated.ico
PrivilegesRequired=admin

[Registry]
Root: HKLM; Subkey: "Software\HireHQ\Connector"; ValueType: string; ValueName: "Version"; ValueData: "1.0"; Flags: uninsdeletekey

[Files]
Source: "GoogleCloudSDKInstaller.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "tailscale-setup-latest.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "HireHQTrayApp.exe"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\HireHQConnector"; Permissions: users-modify admins-full

[Code]
var
  SyrinxDirPage: TInputDirWizardPage;
  TenantIdPage: TInputQueryWizardPage;
  JsonPage: TWizardPage;
  JSONMemo: TMemo;
  TenantId: String;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  WizardForm.Caption := 'Hire HQ Connector for Syrinx Installer';

  SyrinxDirPage := CreateInputDirPage(wpSelectDir, 'Syrinx Install Directory', '',
    'Please select the Syrinx install directory:', False, '');
  SyrinxDirPage.Add('Syrinx Directory:');

  TenantIdPage := CreateInputQueryPage(SyrinxDirPage.ID, 'Hire HQ Tenant ID', '',
    'Enter your numeric Hire HQ Tenant ID:');
  TenantIdPage.Add('Tenant ID:', False);

  JsonPage := CreateCustomPage(TenantIdPage.ID, 'Service Account JSON', 'Paste your Google Cloud service-account.json content below:');
  JSONMemo := TMemo.Create(JsonPage.Surface);
  JSONMemo.Parent := JsonPage.Surface;
  JSONMemo.Top := 0;
  JSONMemo.Left := 0;
  JSONMemo.Width := JsonPage.SurfaceWidth;
  JSONMemo.Height := JsonPage.SurfaceHeight - 20;
  JSONMemo.ScrollBars := ssBoth;
  JSONMemo.WordWrap := False;
end;

function IsValidJson(const JsonStr: String): Boolean;
var
  S: String;
begin
  S := Trim(JsonStr);
  Result :=
    ((Pos('{', S) = 1) and (Pos('}', S) = Length(S))) or
    ((Pos('[', S) = 1) and (Pos(']', S) = Length(S)));
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = JsonPage.ID then
  begin
    try
      if not IsValidJson(JSONMemo.Text) then
      begin
        MsgBox('The service-account.json is not valid JSON.', mbError, MB_OK);
        Result := False;
      end;
    except
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ForceDirectories(ExpandConstant('{commonappdata}\HireHQConnector'));
    SaveStringToFile(ExpandConstant('{commonappdata}\HireHQConnector\service-account.json'), JSONMemo.Text, False);
    TenantId := TenantIdPage.Values[0];

    SaveStringToFile(ExpandConstant('{app}\sync-driver-photos.bat'),
      '@echo off' + #13#10 +
      'REM Sync Photos' + #13#10 +
      ExpandConstant('CALL gcloud auth activate-service-account --key-file="{commonappdata}\HireHQConnector\service-account.json"') + #13#10 +
      ExpandConstant('CALL gcloud storage rsync --recursive "' + SyrinxDirPage.Values[0] + '\Docs\Driver Photos" "gs://hirehq-app-production-photos/' + TenantId + '" --delete-unmatched-destination-objects --gzip-in-flight-all --exclude=".*\.db$"'), False);

    SaveStringToFile(ExpandConstant('{app}\sync-documents.bat'),
      '@echo off' + #13#10 +
      'REM Sync Documents' + #13#10 +
      ExpandConstant('CALL gcloud auth activate-service-account --key-file="{commonappdata}\HireHQConnector\service-account.json"') + #13#10 +
      ExpandConstant('CALL gcloud storage rsync --recursive "' + SyrinxDirPage.Values[0] + '\Docs\Category" "gs://hirehq-app-production-documents/' + TenantId + '/category" --delete-unmatched-destination-objects --gzip-in-flight=jpeg,jpg,gif,png --exclude=".*\.db$"') + #13#10 +
      ExpandConstant('CALL gcloud storage rsync --recursive "' + SyrinxDirPage.Values[0] + '\Docs\Fleet" "gs://hirehq-app-production-documents/' + TenantId + '/fleet" --delete-unmatched-destination-objects --gzip-in-flight=jpeg,jpg,gif,png --exclude=".*\.db$"'), False);

    SaveStringToFile(ExpandConstant('{app}\download-hire-contract-files.bat'),
      '@echo off' + #13#10 +
      'REM Sync Hire Contract Files (from Remote)' + #13#10 +
      ExpandConstant('CALL gcloud auth activate-service-account --key-file="{commonappdata}\HireHQConnector\service-account.json"') + #13#10 +
      ExpandConstant('CALL gcloud storage rsync --recursive "gs://hirehq-app-production-hire-contracts/' + TenantId + '" "' + SyrinxDirPage.Values[0] + '\Docs\Hire Contracts" --exclude="pending./.*" --dry-run'), False);
      
      Exec('schtasks', '/Create /TN "\Hire HQ\Dummy" /TR "cmd.exe /c exit" /SC ONCE /ST 00:00 /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('schtasks', '/Delete /TN "\Hire HQ\Dummy" /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

[Run]
Filename: "{app}\GoogleCloudSDKInstaller.exe"; Description: "Install Google Cloud SDK?"; Flags: postinstall skipifsilent
Filename: "{app}\tailscale-setup-latest.exe"; Description: "Install Tailscale?"; Flags: postinstall skipifsilent
Filename: "{app}\HireHQTrayApp.exe"; Description: "Run Hire HQ Monitor App?"; Flags: postinstall skipifsilent
Filename: "schtasks"; Parameters: "/Create /TN ""\Hire HQ\Hire HQ Sync Driver Photos"" /TR ""\""{app}\sync-driver-photos.bat\"""" /SC MINUTE /MO 10 /F /RL HIGHEST /DU 12:00"; Flags: runhidden
Filename: "schtasks"; Parameters: "/Create /TN ""\Hire HQ\Hire HQ Sync Documents"" /TR ""\""{app}\sync-documents.bat\"""" /SC HOURLY /MO 6 /F /RL HIGHEST /DU 12:00"; Flags: runhidden
Filename: "schtasks"; Parameters: "/Create /TN ""\Hire HQ\Hire HQ Download Hire Contract Files"" /TR ""\""{app}\download-hire-contract-files.bat\"""" /SC MINUTE /MO 10 /F /RL HIGHEST /DU 01:00"; Flags: runhidden
Filename: "schtasks"; Parameters: "/Create /TN ""\Hire HQ\Hire HQ Connector Tray"" /TR ""\""{app}\HireHQTrayApp.exe\"""" /SC ONLOGON /RL HIGHEST /F"; Flags: runhidden

[Icons]
Name: "{group}\Reconfigure Hire HQ Connector"; Filename: "{uninstallexe}"; Parameters: "/INSTALL"; WorkingDir: "{app}"
Name: "{group}\Manage Sync Tasks"; Filename: "{app}\HireHQTrayApp.exe"

[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /TN ""\Hire HQ\Hire HQ Sync Driver Photos"" /F"; Flags: runhidden; RunOnceId: syncDriverTask
Filename: "schtasks"; Parameters: "/Delete /TN ""\Hire HQ\Hire HQ Sync Documents"" /F"; Flags: runhidden; RunOnceId: syncDocumentsTask
Filename: "schtasks"; Parameters: "/Delete /TN ""\Hire HQ\Hire HQ Download Hire Contract Files"" /F"; Flags: runhidden; RunOnceId: syncContractTask
Filename: "schtasks"; Parameters: "/Delete /TN ""\Hire HQ\Hire HQ Connector Tray"" /F"; Flags: runhidden; RunOnceId: trayAppTask
