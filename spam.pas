unit spam;

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
  TFrmSpam = class(TFrmBase)
    lblTitle: TLabel;
    lblContractText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblContractTextClick(Sender: TObject);
  strict private
    procedure SetAction(value: TTokenAction);
    procedure SetContract(value: TAddress);
  public
    property Action: TTokenAction write SetAction;
    property Contract: TAddress write SetContract;
  end;

procedure show(const action: TTokenAction; const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // project
  cache,
  common,
  thread;

{$R *.fmx}

procedure show(const action: TTokenAction; const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmSpam = TFrmSpam.Create(chain, tx, callback, log);
  frmSpam.Action   := action;
  frmSpam.Contract := contract;
  frmSpam.Show;
end;

{ TFrmSpam }

procedure TFrmSpam.SetAction(value: TTokenAction);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value]]);
end;

procedure TFrmSpam.SetContract(value: TAddress);
begin
  lblContractText.Text := string(value);
  cache.getFriendlyName(Self.Chain, value, procedure(friendly: string; err: IError)
  begin
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
    begin
      lblContractText.Text := friendly;
    end);
  end);
end;

procedure TFrmSpam.lblContractTextClick(Sender: TObject);
begin
  cache.fromName(lblContractText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.Chain.Explorer + '/address/' + lblContractText.Text);
  end);
end;

end.
