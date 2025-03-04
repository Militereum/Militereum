unit base;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.UITypes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
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

type
  TLog = reference to procedure(const err: IError);

type
  TFrmBase = class(TForm)
    imgMilitereum: TImage;
    imgWarning: TImage;
    btnBlock: TButton;
    btnAllow: TButton;
    lblGasFee: TLabel;
    imgGasFee: TImage;
    imgError: TImage;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
  strict private
    FChain   : TChain;
    FCallback: TProc<Boolean>;
    FOnLog   : TLog;
    procedure SetBlocked(value: Boolean);
  protected
    procedure DoShow; override;
    procedure Resize; override;
    procedure LoadGasFeeImage(const img: TImage);
    procedure Log(const err: IError);
    property Chain: TChain read FChain;
    property Blocked: Boolean write SetBlocked;
  public
    constructor Create(const chain: TChain; const tx: ITransaction; const callback: TProc<Boolean>; const log: TLog); reintroduce; virtual;
  end;

procedure centerOnDisplayUnderMouseCursor(const F: TCommonCustomForm);

implementation

{$R *.fmx}

uses
  // Delphi
  System.Math,
  System.Types,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth.gas,
  web3.eth.utils,
  // project
  common,
  thread;

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

{ TLabel }

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

{ TFrmBase }

constructor TFrmBase.Create(const chain: TChain; const tx: ITransaction; const callback: TProc<Boolean>; const log: TLog);
begin
  inherited Create(Application);

  FChain    := chain;
  FCallback := callback;
  FOnLog    := log;

  lblGasFee.Visible := False;
  imgGasFee.Visible := False;

  if Assigned(tx) then tx.EstimateGas(chain, procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then Self.Log(err) else web3.eth.gas.getGasPrice(TWeb3.Create(chain), procedure(price: TWei; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else TWeb3.Create(chain).LatestPrice(procedure(ticker: Double; err: IError)
      begin
        if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
        begin
          lblGasFee.Text := System.SysUtils.Format('$ %.2f', [dotToFloat(fromWei(qty * price, ether)) * ticker]);
          LoadGasFeeImage(imgGasFee);
          lblGasFee.Visible := True;
          imgGasFee.Visible := True;
        end);
      end);
    end);
  end);
end;

procedure TFrmBase.SetBlocked(value: Boolean);
begin
  btnAllow.Enabled   := not Value;
  imgError.Visible   := value;
  imgWarning.Visible := not value;
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

{$R 'assets\gas_pump.res'}

procedure TFrmBase.LoadGasFeeImage(const img: TImage);
begin
  const RS = TResourceStream.Create(hInstance, (function: string
  begin
    if common.DarkModeEnabled then
      Result := 'GAS_PUMP_DARK'
    else
      Result := 'GAS_PUMP_LIGHT';
  end)(), RT_RCDATA);
  try
    img.Bitmap.LoadFromStream(RS);
  finally
    RS.Free;
  end;
end;

procedure TFrmBase.Log(const err: IError);
begin
  if Assigned(FOnLog) then FOnLog(err);
end;

procedure TFrmBase.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
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

end.
