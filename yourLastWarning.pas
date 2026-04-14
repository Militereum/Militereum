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
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types;

type
  TFrmLastWarning = class(TForm)
    label1: TLabel;
    label2: TLabel;
    edit: TEdit;
    btnContinue: TButton;
    btnCancel: TButton;
    imgError: TImage;
    procedure editTyping(Sender: TObject);
    procedure editKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  protected
    procedure DoShow; override;
  end;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils, System.UITypes,
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

procedure TFrmLastWarning.editKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkReturn) and btnContinue.Enabled then
  begin
    Key         := 0;
    KeyChar     := #0;
    ModalResult := btnContinue.ModalResult;
  end;
end;

end.
