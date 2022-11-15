unit log;

interface

uses
  // Delphi
  System.Classes,
  System.UITypes,
  // FireMonkey
  FMX.BehaviorManager,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Memo,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Types;

type
  TFrmLog = class(TForm)
    Memo: TMemo;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    constructor Create(aOwner: TComponent); override;
  end;

implementation

{$R *.fmx}

constructor TFrmLog.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  Self.Memo.AutoHide := TBehaviorBoolean.False;
end;

procedure TFrmLog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.Terminate;
end;

end.
