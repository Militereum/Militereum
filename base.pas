unit base;

interface

uses
  // Delphi
  System.Classes,
  System.UITypes,
  // FireMonkey
  FMX.Controls,
  FMX.Forms,
  FMX.Objects,
  FMX.Types;

type
  TFrmBase = class(TForm)
    imgMilitereum: TImage;
    imgWarning: TImage;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}

procedure TFrmBase.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

end.
