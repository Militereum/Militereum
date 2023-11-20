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
    procedure ScrollToBottom;
  public
    constructor Create(aOwner: TComponent); override;
    procedure BeginUpdate; reintroduce;
    procedure EndUpdate; reintroduce;
    procedure Add(const line: TLine; const msg: string); overload;
    procedure Add(const line: TLine; const msg1, msg2: string); overload;
  end;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils,
  // FireMonkey
  FMX.BehaviorManager,
  FMX.Text;

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

procedure TFrmLog.ScrollToBottom;
begin
  Self.Memo.Model.CaretPosition := TCaretPosition.Create(Self.Memo.Model.Lines.Count - 1, 0)
end;

procedure TFrmLog.Add(const line: TLine; const msg: string);
begin
  Add(line, msg, '');
end;

procedure TFrmLog.Add(const line: TLine; const msg1, msg2: string);

  function Trim4k(const input: string): string; inline;
  begin
    if Length(input) > 4096 then
      Result := Copy(input, Low(input), 4095) + '…'
    else
      Result := input;
  end;

begin
  Self.Memo.Lines.Add(Trim4k((
    function(const time: string): string
    begin
      case line of
        Request : Result := '[REQUEST]  ' + time + ' ' + msg1;
        Response: Result := '[RESPONSE] ' + time + ' ' + msg1;
        Info    : Result := '[INFO]     ' + time + ' ' + msg1;
        Error   : Result := '[!ERROR!]  ' + time + ' ' + msg1;
      end;
    end)(FormatDateTime('hh:nn:ss:zzz', System.SysUtils.Now))));
  if msg2 <> '' then Self.Memo.Lines.Add(Trim4k('           ' + msg2));
  if FUpdateCount = 0 then ScrollToBottom;
end;

procedure TFrmLog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.Terminate;
end;

end.
