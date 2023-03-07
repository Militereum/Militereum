unit airdrop;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  base;

type
  TFrmAirdrop = class(TFrmBase)
    lblTitle: TLabel;
    lblTokenTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblTokenText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblTokenTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetToken(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Token: TAddress write SetToken;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(const chain: TChain; const token: TAddress; const callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // web3
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const token: TAddress; const callback: TProc<Boolean>);
begin
  const frmAirdrop = TFrmAirdrop.Create(Application);
  frmAirdrop.Chain := chain;
  frmAirdrop.Token := token;
  frmAirdrop.Callback := callback;
  frmAirdrop.Show;
end;

{ TFrmAirdrop }

procedure TFrmAirdrop.SetToken(value: TAddress);
begin
  lblTokenText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblTokenText.Text := ens;
      end);
  end);
end;

procedure TFrmAirdrop.lblTokenTextClick(Sender: TObject);
begin
  TAddress.Create(TWeb3.Create(common.Ethereum), lblTokenText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.BlockExplorer + '/token/' + string(address))
    else
      common.Open(Self.FChain.BlockExplorer + '/token/' + lblTokenText.Text);
  end);
end;

procedure TFrmAirdrop.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmAirdrop.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
