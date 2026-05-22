unit tokenTransferToContract;

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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  // project
  base, transaction;

type
  TFrmTokenTransferToContract = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    lblMessage: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FContract: TAddress;
  strict protected
    function Bypass: TBypass; override;
  public
    procedure Init(const contract: TAddress; const quantity: BigInteger);
  end;

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const quantity: BigInteger;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

implementation

uses
  // web3
  web3.eth.erc20, web3.utils,
  // project
  common, thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const quantity: BigInteger;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmTokenTransferToContract) or whitelisted(TFrmTokenTransferToContract, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmTokenTransferToContract = TFrmTokenTransferToContract.Create(chain, tx, callback, logProc);
    frmTokenTransferToContract.Init(contract, quantity);
    frmTokenTransferToContract.Blocked := True;
    frmTokenTransferToContract.Show;
  end);
end;

{------------------------ TFrmTokenTransferToContract -------------------------}

procedure TFrmTokenTransferToContract.Init(const contract: TAddress; const quantity: BigInteger);
resourcestring
  RS_TITLE = 'You are about to transfer %s %f to the %s smart contract.';
begin
  FContract := contract;

  lblAddressText.Text := string(FContract);

  const erc20: IERC20 = web3.eth.erc20.create(TWeb3.Create(chain), contract);
  erc20.Symbol(procedure(symbol: string; err: IError)
  begin
    if Assigned(err) then
      Self.Log(err)
    else
      erc20.Decimals(procedure(decimals: BigInteger; err: IError)
      begin
        if Assigned(err) then
          Self.Log(err)
        else
          thread.synchronize(procedure
          begin
            if decimals.IsZero then
              lblTitle.Text := System.SysUtils.Format(RS_TITLE, [symbol, quantity.AsDouble, symbol])
            else
              lblTitle.Text := System.SysUtils.Format(RS_TITLE, [symbol, web3.utils.unscale(quantity, decimals.AsInteger), symbol]);
          end);
      end);
  end);
end;

function TFrmTokenTransferToContract.Bypass: TBypass;
begin
  Result := TBypass.Create('token', procedure
  begin
    whitelist(TFrmTokenTransferToContract, FContract);
  end);
end;

procedure TFrmTokenTransferToContract.lblAddressTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FContract));
end;

end.
