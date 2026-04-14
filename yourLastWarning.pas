unit yourLastWarning;

interface

uses
  // Delphi
  System.Classes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.StdCtrls,
  FMX.Types;

type
  TFrmLastWarning = class(TForm)
    label1: TLabel;
    label2: TLabel;
    edit: TEdit;
    btnContinue: TButton;
    btnCancel: TButton;
    procedure editTyping(Sender: TObject);
  protected
    procedure DoShow; override;
  end;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils,
  // project
  base;

procedure TFrmLastWarning.DoShow;
begin
  centerOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

procedure TFrmLastWarning.editTyping(Sender: TObject);
begin
  btnContinue.Enabled := SameText(Trim(edit.Text), 'I will lose money');
end;

end.
