unit update;

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
  FMX.Types;

type
  TFrmUpdate = class(TForm)
    imgMilitereum: TImage;
    lblTitle: TLabel;
    lblMessage: TLabel;
    btnUpdateNow: TButton;
    btnUpdateLater: TButton;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnUpdateNowClick(Sender: TObject);
    procedure btnUpdateLaterClick(Sender: TObject);
  private
    { Private declarations }
  protected
    procedure DoShow; override;
  public
    { Public declarations }
  end;

procedure latestRelease(callback: TProc<string>);
procedure show(const tag: string);

implementation

{$R *.fmx}

uses
  // Delphi
  System.JSON,
  System.Net.URLClient,
  // web3
  web3,
  web3.http,
  web3.json,
  // project
  base,
  common;

procedure latestRelease(callback: TProc<string>);
begin
  web3.http.get(
    'https://api.github.com/repos/svanas/militereum/releases/latest',
    [
      TNetHeader.Create('Accept', 'application/vnd.github+json'),
      TNetHeader.Create('Authorization', 'Bearer ' + {$I github.api.key}),
      TNetHeader.Create('X-GitHub-Api-Version', '2022-11-28')
    ],
    procedure(response: TJsonValue; _: IError)
    begin
      if Assigned(response) then callback(getPropAsStr(response, 'tag_name'));
    end);
end;

procedure show(const tag: string);
begin
  const frmUpdate = TFrmUpdate.Create(Application);
  frmUpdate.lblTitle.Text := System.SysUtils.Format(frmUpdate.lblTitle.Text, [tag]);
  frmUpdate.Show;
end;

{ TFrmUpdate }

procedure TFrmUpdate.DoShow;
begin
  centerOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

procedure TFrmUpdate.btnUpdateNowClick(Sender: TObject);
begin
  common.Open('https://militereum.com');
  Self.Close;
end;

procedure TFrmUpdate.btnUpdateLaterClick(Sender: TObject);
begin
  Self.Close;
end;

procedure TFrmUpdate.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

end.
