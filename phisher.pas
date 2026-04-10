unit phisher;

interface

uses
  // Delphi
  System.Classes, System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Menus,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3, web3.eth.contract,
  // project
  base, transaction;

type
  TFrmPhisher = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    lblFooter: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FAddress: TAddress;
    procedure SetAddress(const value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Address: TAddress write SetAddress;
  end;

procedure isPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const address : TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

implementation

uses
  // web3
  web3.eth,
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const address : TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmPhisher) or whitelisted(TFrmPhisher, address) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmPhisher = TFrmPhisher.Create(chain, tx, callback, logProc);
    frmPhisher.Address := address;
    frmPhisher.Show;
  end);
end;

{--------------------------------- TMobyMask ----------------------------------}

type
  TMobyMask = class(TCustomContract)
  public
    constructor Create; reintroduce;
    procedure IsPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
  end;

constructor TMobyMask.Create;
begin
  inherited Create(TWeb3.Create(common.Ethereum), '0xB06E6DB9288324738f04fCAAc910f5A60102C1F8');
end;

// mobyMaskContract.isPhisher('eip155:1:${transaction.to}')
procedure TMobyMask.IsPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  web3.eth.call(Self.Client, Self.Contract, 'isPhisher(string)', ['eip155:1:' + string(address).ToLower], callback);
end;

// https://github.com/Montoya/mobymask-snap#readme
procedure isPhisher(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  const MM = TMobyMask.Create;
  try
    MM.IsPhisher(address, callback);
  finally
    MM.Free;
  end;
end;

{-------------------------------- TFrmPhisher ---------------------------------}

procedure TFrmPhisher.SetAddress(const value: TAddress);
begin
  FAddress := value;
  lblAddressText.Text := string(FAddress);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FAddress, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddressText.Text := friendly;
      end);
    end);
end;

function TFrmPhisher.Bypass: TBypass;
begin
  Result := TBypass.Create('address', procedure
  begin
    whitelist(TFrmPhisher, FAddress);
  end);
end;

procedure TFrmPhisher.lblAddressTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FAddress));
end;

end.
