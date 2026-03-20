unit base;

interface

uses
  // Delphi
  System.Classes, System.SysUtils, System.UITypes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.Menus,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  transaction;

type
  TTokenAction = (taReceive, taTransact);
const
  ActionText: array[TTokenAction] of string = ('receive', 'transact with');

// 1. Labels with HorzAlign=Center are automatically enlarged until there are no more ellipsis
// 2. The form is automatically enlarged after (1)
// 3. The block/allow buttons automatically re-align after (2)
// 4. The block/allow buttons automatically free the form when clicked

type
  TLabel = class(FMX.StdCtrls.TLabel)
  protected
    procedure ApplyStyle; override;
    procedure Loaded; override;
  end;

  TLogProc = reference to procedure(const err: IError);

  TFormTimer<T: TCustomForm> = class(TComponent)
  private
    type
      TTimerProc = reference to procedure(const AForm: T; var AContinue: Boolean);
    var
      FForm: T;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(const AForm: T); reintroduce;
    procedure Start(const interval: Cardinal; const callback: TTimerProc);
  end;

  TBypass = record
  strict private
    FName: string;
    FProc: TProc;
  public
    constructor Create(const AName: string; const AProc: TProc);
    function Visible: Boolean;
    property Name: string read FName;
    property Proc: TProc read FProc;
  end;

  TFrmBase = class(TForm)
    imgMilitereum: TImage;
    imgWarning: TImage;
    btnBlock: TButton;
    btnAllow: TButton;
    imgError: TImage;
    rctShowThisWarning: TRectangle;
    edtShowThisWarning: TEdit;
    btnShowThisWarning: TEditButton;
    pmShowThisWarning: TPopupMenu;
    mnuNeverAgain: TMenuItem;
    mnuNeverForThis: TMenuItem;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnShowThisWarningClick(Sender: TObject);
    procedure mnuNeverAgainClick(Sender: TObject);
    procedure mnuNeverForThisClick(Sender: TObject);
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
  strict private
    FChain   : TChain;
    FCallback: TProc<Boolean>;
    FLogProc : TLogProc;
    procedure SetBlocked(value: Boolean);
  protected
    procedure DoShow; override;
    procedure Resize; override;
    procedure Log(const err: IError);
    function Bypass: TBypass; virtual;
    property Chain: TChain read FChain;
    property Blocked: Boolean write SetBlocked;
  public
    constructor Create(
      const chain   : TChain;
      const tx      : transaction.ITransaction;
      const callback: TProc<Boolean>;
      const log     : TLogProc); reintroduce; virtual;
  end;

  TBaseClass = class of TFrmBase;

procedure centerOnDisplayUnderMouseCursor(const F: TCommonCustomForm);

procedure whitelist(const warning: TBaseClass); overload;
procedure whitelist(const warning: TBaseClass; const address: TAddress); overload;

function whitelisted(const warning: TBaseClass): Boolean; overload;
function whitelisted(const warning: TBaseClass; const address: TAddress): Boolean; overload;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Generics.Collections, System.Math, System.Types,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth.gas, web3.eth.types, web3.eth.utils,
  // project
  common, thread;

procedure centerOnDisplayUnderMouseCursor(const F: TCommonCustomForm);

  function FitInRect(const aValue: TRectF; const aMaxRect: TRectF): TRectF;
  begin
    Result := aValue;
    if Result.Top < aMaxRect.Top then
      Result.Offset(0, aMaxRect.Top - Result.Top)
    else if Result.Bottom > aMaxRect.Bottom then
      Result.Offset(0, aMaxRect.Bottom - Result.Bottom);
    if Result.Left < aMaxRect.Left then
      Result.Offset(aMaxRect.Left - Result.Left, 0)
    else if Result.Right > aMaxRect.Right then
      Result.Offset(aMaxRect.Right - Result.Right, 0);
  end;

begin
  const display = Screen.DisplayFromPoint(Screen.MousePos);
  const R = TRectF.Create(display.WorkAreaRect.TopLeft, display.WorkAreaRect.Width, display.WorkAreaRect.Height);
  const N = TRectF.Create(TPointF.Create(R.Left + (R.Width - F.Width) / 2, R.Top + (R.Height - F.Height) / 2), F.Bounds.Width, F.Bounds.Height);
  F.SetBoundsF(FitInRect(N, Screen.DesktopRect));
end;

{---------------------------------- TBypass -----------------------------------}

constructor TBypass.Create(const AName: string; const AProc: TProc);
begin
  FName := AName;
  FProc := AProc;
end;

function TBypass.Visible: Boolean;
begin
  Result := (FName <> '') and Assigned(FProc);
end;

{--------------------------- whitelist & whitelisted --------------------------}

var
  allow1: TLockableArray<TBaseClass> = nil;
  allow2: TDictionary<TBaseClass, TArray<TAddress>> = nil;

procedure whitelist(const warning: TBaseClass);
begin
  if whitelisted(warning) then
    EXIT;
  thread.lock(allow1, procedure
  begin
    allow1.Add(warning);
  end);
end;

procedure whitelist(const warning: TBaseClass; const address: TAddress);
var
  values: TArray<TAddress>;
begin
  if whitelisted(warning, address) then
    EXIT;
  thread.lock(allow2, procedure
  begin
    if not allow2.ContainsKey(warning) then
      allow2.Add(warning, []);
    if not allow2.TryGetValue(warning, values) then
      EXIT;
    allow2.AddOrSetValue(warning, values + [address]);
  end);
end;

function whitelisted(const warning: TBaseClass): Boolean;
begin
  Result := thread.TLock.get<Boolean>(allow1, function: Boolean
  begin
    for var I := 0 to allow1.Length - 1 do
      if allow1[I] = warning then
      begin
        Result := True;
        EXIT;
      end;
    Result := False;
  end);
end;

function whitelisted(const warning: TBaseClass; const address: TAddress): Boolean;
var
  values: TArray<TAddress>;
begin
  if thread.TLock.get<Boolean>(allow2, function: Boolean
  begin
    Result := allow2.TryGetValue(warning, values);
  end) then
    for var I := 0 to High(values) do if values[I].SameAs(address) then
    begin
      Result := True;
      EXIT;
    end;
  Result := False;
end;

{----------------------------------- TLabel -----------------------------------}

procedure TLabel.ApplyStyle;

  function GetParentForm: TCommonCustomForm;
  begin
    if (Self.Root <> nil) and (Self.Root.GetObject is TCommonCustomForm) then
      Result := TCommonCustomForm(Self.Root.GetObject)
    else
      Result := nil;
  end;

  procedure CenterParentForm;
  begin
    const F = GetParentForm;
    if Assigned(F) then centerOnDisplayUnderMouseCursor(F);
  end;

begin
  inherited ApplyStyle;
  if Self.AutoSize then
  begin
    const F = GetParentForm;
    if Assigned(F) then
    begin
      Self.AutoSize := False;
      F.ClientWidth := Max(F.ClientWidth, Round((Self.Position.X * 2) + Self.Width));
      CenterParentForm;
      Self.Width := F.ClientWidth - (Self.Position.X * 2);
      Self.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop, TAnchorKind.akRight];
    end;
  end;
end;

procedure TLabel.Loaded;
begin
  inherited Loaded;
  if Self.TextSettings.HorzAlign = TTextAlign.Center then
  begin
    Self.WordWrap := False;
    Self.AutoSize := True;
  end;
end;

{--------------------------------- TFormTimer ---------------------------------}

constructor TFormTimer<T>.Create(const AForm: T);
begin
  inherited Create(nil); // not owned by the form
  FForm := AForm;
  if Assigned(FForm) then FForm.FreeNotification(Self);
end;

procedure TFormTimer<T>.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = TComponent(FForm)) then FForm := nil;
end;

procedure TFormTimer<T>.Start(const interval: Cardinal; const callback: TTimerProc);
begin
  TThread.CreateAnonymousThread(procedure
  begin
    var LContinue: Boolean;
    repeat
      TThread.Sleep(interval);
      TThread.Synchronize(nil, procedure
      begin
        if Assigned(Self.FForm) then callback(Self.FForm, LContinue);
      end);
    until (Self.FForm = nil) or not LContinue;
    if Assigned(Self.FForm) then Self.FForm.RemoveFreeNotification(Self);
    Self.Free;
  end).Start;
end;

{---------------------------------- TFrmBase ----------------------------------}

constructor TFrmBase.Create(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const callback: TProc<Boolean>;
  const log     : TLogProc);

  procedure InitShowThisWarning(const rect: TRectangle; edit: TEdit); inline;
  begin
    edit.ApplyStyleLookup;
    const bg = edit.FindStyleResource('background');
    if Assigned(bg) and (bg is TControl) then TControl(bg).Visible := False;
    rect.Stroke.Color := TAlphaColors.LightGray;
  end;

begin
  inherited Create(Application);

  FChain    := chain;
  FCallback := callback;
  FLogProc  := log;

  InitShowThisWarning(rctShowThisWarning, edtShowThisWarning);
end;

procedure TFrmBase.SetBlocked(value: Boolean);
begin
  imgError.Visible   := value;
  imgWarning.Visible := not value;
  // Allow button is disabled at first, but the user can click it after a 5 sec wait
  btnAllow.Enabled := not value;
  if value then
  begin
    var counter := 5;
    btnAllow.Text := IntToStr(counter);
    TFormTimer<TFrmBase>.Create(Self).Start(1000, procedure(const AForm: TFrmBase; var AContinue: Boolean)
    begin
      Dec(counter);
      AContinue := counter > 0;
      if AContinue then
        AForm.btnAllow.Text := IntToStr(counter)
      else
      begin
        AForm.btnAllow.Text := 'Allow';
        AForm.btnAllow.Enabled := True;
      end;
    end);
  end;
end;

function TFrmBase.Bypass: TBypass;
begin
  Result := Default(TBypass);
end;

procedure TFrmBase.DoShow;
begin
  centerOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

procedure TFrmBase.Resize;
begin
  inherited Resize;
  const M = Self.ClientWidth div 2;
  btnBlock.Position.X := M - btnBlock.Width - 4;
  btnBlock.Position.Y := Self.ClientHeight - btnBlock.Height - 16;
  btnAllow.Position.X := M + 4;
  btnAllow.Position.Y := Self.ClientHeight - btnAllow.Height - 16;
end;

procedure TFrmBase.Log(const err: IError);
begin
  if Assigned(FLogProc) then FLogProc(err);
end;

procedure TFrmBase.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

procedure TFrmBase.btnShowThisWarningClick(Sender: TObject);
begin
  const bypass = Self.Bypass;

  mnuNeverForThis.Visible := bypass.Visible;
  if mnuNeverForThis.Visible then
    mnuNeverForThis.Text := System.SysUtils.Format(mnuNeverForThis.Text, [bypass.Name]);

  var P := edtShowThisWarning.LocalToAbsolute(PointF(0, edtShowThisWarning.Height));
  P := Self.ClientToScreen(P);
  pmShowThisWarning.Popup(P.X, P.Y);
end;

procedure TFrmBase.mnuNeverAgainClick(Sender: TObject);
begin
  whitelist(TBaseClass(Self.ClassType));
  btnAllowClick(Sender);
end;

procedure TFrmBase.mnuNeverForThisClick(Sender: TObject);
begin
  const bypass = Self.Bypass;
  if Assigned(bypass.Proc) then
  begin
    bypass.Proc();
    btnAllowClick(Sender);
  end;
end;

procedure TFrmBase.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmBase.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

initialization
  allow1 := TLockableArray<TBaseClass>.Create;
  allow2 := TDictionary<TBaseClass, TArray<TAddress>>.Create;

finalization
  if Assigned(allow2) then allow2.Free;
  if Assigned(allow1) then allow1.Free;


end.
