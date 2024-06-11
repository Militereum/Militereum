unit revoke;

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
  web3;

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
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnYesClick(Sender: TObject);
    procedure btnNoClick(Sender: TObject);
  private
    FChain   : TChain;
    FCallback: TProc<Boolean>;
  protected
    procedure DoShow; override;
    procedure SetToken(const value: TAddress);
    procedure SetSpender(const value: TAddress);
  public
    property Chain   : TChain         write FChain;
    property Token   : TAddress       write SetToken;
    property Spender : TAddress       write SetSpender;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(
  const chain   : TChain;
  const token   : TAddress;
  const spender : TAddress;
  const callback: TProc<Boolean>);

implementation

{$R *.fmx}

uses
  // web3
  web3.eth.types,
  // project
  base,
  cache,
  thread;

procedure show(const chain: TChain; const token: TAddress; const spender: TAddress; const callback: TProc<Boolean>);
begin
  const frmRevoke = TFrmRevoke.Create(Application);
  frmRevoke.Chain    := chain;
  frmRevoke.Token    := token;
  frmRevoke.Spender  := spender;
  frmRevoke.Callback := callback;
  frmRevoke.Show;
end;

{ TFrmRevoke }

procedure TFrmRevoke.SetToken(const value: TAddress);
begin
  cache.getSymbol(Self.FChain, value, procedure(symbol: string; err: IError)
  begin
    if symbol <> '' then thread.synchronize(procedure
    begin
      lblTitle.Text := Format('Your %s are at risk', [symbol]);
    end);
  end);
end;

procedure TFrmRevoke.SetSpender(const value: TAddress);
begin
  Label1.Text := Format(Label1.Text, [value.Abbreviated]);
end;

procedure TFrmRevoke.btnNoClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmRevoke.btnYesClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

procedure TFrmRevoke.DoShow;
begin
  centerOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

procedure TFrmRevoke.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

end.
