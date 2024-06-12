unit common.mac;

interface

function autoRunEnabled: Boolean;
procedure enableAutoRun;
procedure disableAutoRun;

function darkModeEnabled: Boolean;
procedure enableDarkMode;
procedure disableDarkMode;

procedure initialize;

procedure beforeShowDialog;
procedure afterShowDialog;

implementation

uses
  // Delphi
  Macapi.AppKit,
  Macapi.CocoaTypes,
  Macapi.Foundation,
  Macapi.ObjectiveC,
  System.Classes,
  System.IOUtils,
  System.Messaging,
  System.SysUtils,
  // FireMonkey
  FMX.Forms,
  FMX.Helpers.Mac,
  FMX.Platform,
  FMX.Platform.Mac,
  FMX.Styles,
  // web3
  web3.sync,
  // Project
  common,
  main,
  thread;

function launchAgents: string;
begin
  Result := System.IOUtils.TPath.GetLibraryPath;
  if (Result <> '') and (Result[Length(Result)] <> '/') then Result := Result + '/';
  Result := Result + 'LaunchAgents';
end;

function launchAgent: string;
begin
  Result := launchAgents;
  if (Result <> '') and (Result[Length(Result)] <> '/') then Result := Result + '/';
  Result := Result + 'com.militereum.agent.plist';
end;

function autoRunEnabled: Boolean;
begin
  Result := System.IOUtils.TFile.Exists(launchAgent);
  if Result then
  begin
    const plist = TStringList.Create;
    try
      for var line in plist do
      begin
        Result := SameText(line.Trim, System.SysUtils.Format('<string>%s</string>', [ParamStr(0)]));
        if Result then EXIT;
      end;
    finally
      plist.Free;
    end;
  end;
end;

procedure enableAutoRun;
begin
  System.IOUtils.TFile.WriteAllText(launchagent, System.SysUtils.Format(
    '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + #10 +
    '<plist version="1.0">' + #10 +
    '<dict>' + #10 +
    '	<key>Label</key>' + #10 +
    '	<string>com.militereum.agent</string>' + #10 +
    '	<key>LimitLoadToSessionType</key>' + #10 +
    '	<string>Aqua</string>' + #10 +
    '	<key>ProgramArguments</key>' + #10 +
    '	<array>' + #10 +
    '		<string>%s</string>' + #10 +
    '		<string>-autorun</string>' + #10 +
    '	</array>' + #10 +
    '	<key>ProcessType</key>' + #10 +
    '	<string>Interactive</string>' + #10 +
    '	<key>RunAtLoad</key>' + #10 +
    '	<true/>' + #10 +
    '	<key>KeepAlive</key>' + #10 +
    '	<false/>' + #10 +
    '</dict>' + #10 +
    '</plist>', [ParamStr(0)]));
end;

procedure disableAutoRun;
begin
  System.IOUtils.TFile.Delete(launchAgent);
end;

function darkModeEnabled: Boolean;
begin
  Result := False;
  var S: IFMXSystemAppearanceService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXSystemAppearanceService, S) then
    Result := S.ThemeKind = TSystemThemeKind.Dark;
end;

{$R 'assets\nero_mac.res'}

procedure enableDarkMode;
begin
  TStyleManager.TrySetStyleFromResource('nero_mac');
end;

procedure disableDarkMode;
begin
  TStyleManager.SetStyle(TStyleStreaming.LoadFromResource(hInstance, 'osxstyle', PChar(10)));
end;

type
  IApplicationDelegate = interface(NSApplicationDelegate)
  ['{452088EB-EFEC-4407-AF08-018C1D03496B}']
    procedure onMenuClicked(sender: NSMenuItem); cdecl;
    procedure applicationWillBecomeActive(Notification: NSNotification); cdecl;
  end;

type
  TApplicationDelegate = class(TOCLocal, IApplicationDelegate)
  private
    FFirstBecomeActive: Boolean;
  public
    constructor Create;
    function applicationShouldTerminate(Notification: NSNotification): NSInteger; cdecl;
    procedure applicationWillTerminate(Notification: NSNotification); cdecl;
    procedure applicationDidFinishLaunching(Notification: NSNotification); cdecl;
    function applicationDockMenu(sender: NSApplication): NSMenu; cdecl;
    procedure applicationDidHide(Notification: NSNotification); cdecl;
    procedure applicationDidUnhide(Notification: NSNotification); cdecl;
    procedure onMenuClicked(sender: NSMenuItem); cdecl;
    procedure applicationWillBecomeActive(Notification: NSNotification); cdecl;
  end;

var
  app: NSApplication;
  old: NSApplicationDelegate;
  new: TApplicationDelegate;
  cnt: ICriticalInt64 = nil;

function counter: ICriticalInt64;
begin
  if not Assigned(cnt) then cnt := TCriticalInt64.Create(0);
  Result := cnt;
end;

procedure initialize;
begin
  if FindCmdLineSwitch('autorun') then
    TMessageManager.DefaultManager.SubscribeToMessage(TMainFormChangedMessage, procedure(const Sender: TObject; const Msg: TMessage)
    begin
      const main = TMainFormChangedMessage(Msg).Value;
      if Assigned(main) and main.Visible then
      begin
        beforeShowDialog;
        try
          main.Visible := False;
        finally
          afterShowDialog;
        end;
      end;
    end);
  app := TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication);
  old := app.delegate;
  new := TApplicationDelegate.Create;
  app.setDelegate(IApplicationDelegate(new));
end;

procedure beforeShowDialog;
begin
  counter.Enter;
  try
    counter.Inc;
  finally
    counter.Leave;
  end;
end;

procedure afterShowDialog;
begin
  counter.Enter;
  try
    counter.Dec;
  finally
    counter.Leave;
  end;
end;

function SendOSXMessage(const Sender: TObject; const OSXMessageClass: TOSXMessageClass; const NSSender: NSObject): NSObject;
begin
  const MessageObject = TOSXMessageObject.Create(NSSender);
  try
    TMessageManager.DefaultManager.SendMessage(Sender, OSXMessageClass.Create(MessageObject, False), True);
    Result := MessageObject.ReturnValue;
  finally
    MessageObject.Free;
  end;
end;

{ TApplicationDelegate }

constructor TApplicationDelegate.Create;
begin
  inherited Create;
  FFirstBecomeActive := True;
end;

function TApplicationDelegate.applicationDockMenu(sender: NSApplication): NSMenu;
begin
  Result := old.applicationDockMenu(sender);
end;

function TApplicationDelegate.applicationShouldTerminate(Notification: NSNotification): NSInteger;
begin
  Result := old.applicationShouldTerminate(Notification);
end;

procedure TApplicationDelegate.applicationDidHide(Notification: NSNotification);
begin
  old.applicationDidHide(Notification);
end;

procedure TApplicationDelegate.applicationWillTerminate(Notification: NSNotification);
begin
  old.applicationWillTerminate(Notification)
end;

procedure TApplicationDelegate.applicationDidUnhide(Notification: NSNotification);
begin
  old.applicationDidUnhide(Notification);
end;

procedure TApplicationDelegate.onMenuClicked(sender: NSMenuItem);
begin
  SendOSXMessage(Self, TApplicationMenuClickedMessage, sender);
end;

procedure TApplicationDelegate.applicationDidFinishLaunching(Notification: NSNotification);
begin
  old.applicationDidFinishLaunching(Notification);
end;

procedure TApplicationDelegate.applicationWillBecomeActive(Notification: NSNotification);
begin
  if FFirstBecomeActive then
    FFirstBecomeActive := False
  else
    if (counter.Get = 0) and not common.Debug then thread.synchronize(procedure
    begin
      if Assigned(FrmMain) and not(FrmMain.Visible) then FrmMain.Show;
    end);
end;

end.
