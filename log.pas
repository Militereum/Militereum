unit log;

interface

uses
  // Delphi
  System.Classes,
  System.UITypes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Memo,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Types;

type
  TLine = (Request, Response, Info, Error);

  TFrmLog = class(TForm)
    Memo: TMemo;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  strict private
    FUpdateCount: Integer;
    class function FormatTime: string;
    procedure ScrollToBottom;
  public
    constructor Create(aOwner: TComponent); override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure Add(const line: TLine; const msg: string);
  end;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils,
  // FireMonket
  FMX.BehaviorManager;

constructor TFrmLog.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  Self.Memo.AutoHide := TBehaviorBoolean.False;
end;

procedure TFrmLog.BeginUpdate;
begin
  Inc(FUpdateCount);
  if FUpdateCount = 1 then Self.Memo.Lines.BeginUpdate;
end;

procedure TFrmLog.EndUpdate;
begin
  if FUpdateCount > 0 then
  begin
    Dec(FUpdateCount);
    if FUpdateCount = 0 then
    begin
      Self.Memo.Lines.EndUpdate;
      ScrollToBottom;
    end;
  end;
end;

class function TFrmLog.FormatTime: string;
begin
  Result := FormatDateTime('hh:nn:ss:zzz', Now);
end;

procedure TFrmLog.ScrollToBottom;
begin
  Self.Memo.Model.CaretPosition := TCaretPosition.Create(Self.Memo.Model.Lines.Count - 1, 0)
end;

procedure TFrmLog.Add(const line: TLine; const msg: string);
begin
  case line of
    Request : Self.Memo.Lines.Add('[REQUEST]  ' + FormatTime + ' ' + msg);
    Response: Self.Memo.Lines.Add('[RESPONSE] ' + FormatTime + ' ' + msg);
    Info    : Self.Memo.Lines.Add('[INFO]     ' + FormatTime + ' ' + msg);
    Error   : Self.Memo.Lines.Add('[ERROR]    ' + FormatTime + ' ' + msg);
  end;
  if FUpdateCount = 0 then ScrollToBottom;
end;

procedure TFrmLog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.Terminate;
end;

end.
