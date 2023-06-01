unit sanctioned;

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
  TFrmSanctioned = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    procedure SetAddress(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Address: TAddress write SetAddress;
  end;

procedure show(const chain: TChain; const address: TAddress; const callback: TProc<Boolean>);

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

procedure show(const chain: TChain; const address: TAddress; const callback: TProc<Boolean>);
begin
  const frmSanctioned = TFrmSanctioned.Create(Application);
  frmSanctioned.Chain := chain;
  frmSanctioned.Address := address;
  frmSanctioned.Callback := callback;
  frmSanctioned.Show;
end;

{ TFrmSanctioned }

procedure TFrmSanctioned.SetAddress(value: TAddress);
begin
  lblAddressText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblAddressText.Text := ens;
      end);
  end);
end;

procedure TFrmSanctioned.lblAddressTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblAddressText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.Explorer + '/address/' + lblAddressText.Text);
  end);
end;

end.
