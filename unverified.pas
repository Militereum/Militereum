unit unverified;

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
  TFrmUnverified = class(TFrmBase)
    lblTitle: TLabel;
    lblContractTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblContractText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblContractTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetContract(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Contract: TAddress write SetContract;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(const chain: TChain; const contract: TAddress; const callback: TProc<Boolean>);

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

procedure show(const chain: TChain; const contract: TAddress; const callback: TProc<Boolean>);
begin
  const frmUnverified = TFrmUnverified.Create(Application);
  frmUnverified.Chain := chain;
  frmUnverified.Contract := contract;
  frmUnverified.Callback := callback;
  frmUnverified.Show;
end;

{ TFrmUnverified }

procedure TFrmUnverified.SetContract(value: TAddress);
begin
  lblContractText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblContractText.Text := ens;
      end);
  end);
end;

procedure TFrmUnverified.lblContractTextClick(Sender: TObject);
begin
  TAddress.Create(TWeb3.Create(common.Ethereum), lblContractText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.BlockExplorer + '/address/' + string(address) + '#code')
    else
      common.Open(Self.FChain.BlockExplorer + '/address/' + lblContractText.Text + '#code');
  end);
end;

procedure TFrmUnverified.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmUnverified.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
