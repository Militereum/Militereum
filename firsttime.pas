unit firsttime;

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
  base,
  transaction;

type
  TFrmFirstTime = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    Label1: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    procedure SetAddress(value: TAddress);
  public
    property Address: TAddress write SetAddress;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // web3
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmFirstTime = TFrmFirstTime.Create(chain, tx, callback, log);
  frmFirstTime.Address := address;
  frmFirstTime.Show;
end;

{ TFrmFirstTime }

procedure TFrmFirstTime.SetAddress(value: TAddress);
begin
  lblAddressText.Text := string(value);
  if not common.Demo then
    value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddressText.Text := ens;
      end);
    end);
end;

procedure TFrmFirstTime.lblAddressTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblAddressText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.Chain.Explorer + '/address/' + lblAddressText.Text);
  end);
end;

end.
