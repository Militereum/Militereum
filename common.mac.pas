unit common.mac;

interface

procedure initialize;

procedure beforeTransaction;
procedure afterTransaction;

implementation

uses
  // Delphi
  Macapi.AppKit,
  Macapi.CocoaTypes,
  Macapi.Foundation,
  Macapi.ObjectiveC,
  System.Messaging,
  // FireMonkey
  FMX.Helpers.Mac,
  FMX.Platform.Mac,
  // web3
  web3.sync,
  // Project
  main,
  thread;

type
  IApplicationDelegate = interface(NSApplicationDelegate)
  ['{452088EB-EFEC-4407-AF08-018C1D03496B}']
    procedure onMenuClicked(sender: NSMenuItem); cdecl;
    procedure applicationWillBecomeActive(Notification: NSNotification); cdecl;
  end;

type
  TApplicationDelegate = class(TOCLocal, IApplicationDelegate)
  public
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
  app := TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication);
  old := app.delegate;
  new := TApplicationDelegate.Create;
  app.setDelegate(IApplicationDelegate(new));
end;

procedure beforeTransaction;
begin
  counter.Enter;
  try
    counter.Inc;
  finally
    counter.Leave;
  end;
end;

procedure afterTransaction;
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
  if counter.Get = 0 then
    thread.synchronize(procedure
    begin
      if Assigned(FrmMain) and not(FrmMain.Visible) then FrmMain.Show;
    end);
end;

end.
