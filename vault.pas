unit vault;

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
  TFrmVault = class(TFrmBase)
    lblTitle: TLabel;
    Label1: TLabel;
    Label2: TLabel;
  strict private
    procedure SetSymbol(const value: string);
  public
    property Symbol: string write SetSymbol;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const callback: TProc<Boolean>; const log: TLog);

implementation

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmVault = TFrmVault.Create(chain, tx, callback, log);
  frmVault.Symbol := symbol;
  frmVault.Show;
end;

{ TFrmVault }

procedure TFrmVault.SetSymbol(const value: string);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [value]);
end;

end.
