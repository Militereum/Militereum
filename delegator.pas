unit delegator;

interface

uses
  // Delphi
  System.Classes, System.SysUtils,
  // FireMonkey
  FMX.Controls, FMX.Controls.Presentation, FMX.Objects, FMX.StdCtrls, FMX.Types,
  // web3
  web3,
  // project
  base, transaction;

type
  TFrmDelegator = class(TFrmBase)
    lblTitle: TLabel;
    lblAddress: TLabel;
    lblFooter: TLabel;
    procedure lblAddressClick(Sender: TObject);
  strict private
    procedure SetContract(const value: TAddress);
  public
    property Contract: TAddress write SetContract;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmDelegator = TFrmDelegator.Create(chain, tx, callback, log);
  frmDelegator.Contract := contract;
  frmDelegator.Show;
end;

{ TFrmDelegator }

procedure TFrmDelegator.SetContract(const value: TAddress);
begin
  lblAddress.Text := string(value);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, value, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddress.Text := friendly;
      end);
    end);
end;

procedure TFrmDelegator.lblAddressClick(Sender: TObject);
begin
  cache.fromName(lblAddress.Text, procedure(address: TAddress; err: IError)
  begin
    if Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + lblAddress.Text)
    else
      common.Open(Self.Chain.Explorer + '/address/' + string(address));
  end);
end;

end.
