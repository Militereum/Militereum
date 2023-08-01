unit phisher;

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
  web3.eth.contract,
  // project
  base,
  transaction;

type
  TMobyMask = class(TCustomContract)
  public
    constructor Create; reintroduce;
    procedure IsPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
  end;

type
  TFrmPhisher = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    lblFooter: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    procedure SetAddress(value: TAddress);
  public
    property Address: TAddress write SetAddress;
  end;

procedure isPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // web3
  web3.eth,
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure isPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  const MM = TMobyMask.Create;
  try
    MM.IsPhisher(address, callback);
  finally
    MM.Free;
  end;
end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmPhisher = TFrmPhisher.Create(chain, tx, callback, log);
  frmPhisher.Address := address;
  frmPhisher.Show;
end;

{ TMobyMask }

constructor TMobyMask.Create;
begin
  inherited Create(TWeb3.Create(common.Ethereum), '0xB06E6DB9288324738f04fCAAc910f5A60102C1F8');
end;

procedure TMobyMask.IsPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  web3.eth.call(Self.Client, Self.Contract, 'isPhisher(string)', ['eip155:1:' + string(address).ToLower], callback);
end;

{ TFrmPhisher }

procedure TFrmPhisher.SetAddress(value: TAddress);
begin
  lblAddressText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
    begin
      lblAddressText.Text := ens;
    end);
  end);
end;

procedure TFrmPhisher.lblAddressTextClick(Sender: TObject);
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
