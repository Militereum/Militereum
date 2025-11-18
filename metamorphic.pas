unit metamorphic;

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
  TFrmMetamorphic = class(TFrmBase)
    lblTitle: TLabel;
    lblAddress: TLabel;
    lblFooter: TLabel;
    procedure lblAddressClick(Sender: TObject);
  strict private
    procedure SetAddress(const value: TAddress);
  public
    property Address: TAddress write SetAddress;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const address: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmMetamorphic = TFrmMetamorphic.Create(chain, tx, callback, log);
  frmMetamorphic.Address := address;
  frmMetamorphic.Show;
end;

{ TFrmMetamorphic }

procedure TFrmMetamorphic.SetAddress(const value: TAddress);
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

procedure TFrmMetamorphic.lblAddressClick(Sender: TObject);
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
