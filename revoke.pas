unit revoke;

interface

uses
  // Delphi
  System.Classes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types;

type
  TFrmRevoke = class(TForm)
    btnYes: TButton;
    btnNo: TButton;
    imgMilitereum: TImage;
    lblTitle: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    imgRevokeCash: TImage;
  protected
    procedure DoShow; override;
  end;

implementation

{$R *.fmx}

uses
  // project
  base;

{ TFrmRevoke }

procedure TFrmRevoke.DoShow;
begin
  centerOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

end.
