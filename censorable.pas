unit censorable;

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
  TFrmCensorable = class(TFrmBase)
    lblTitle: TLabel;
    lblToken: TLabel;
    lblFooter: TLabel;
    procedure lblTokenClick(Sender: TObject);
  strict private
    procedure SetAction(value: TTokenAction);
    procedure SetContract(value: TAddress);
    procedure SetIsERC20(value: Boolean);
  public
    property Action: TTokenAction write SetAction;
    property Contract: TAddress write SetContract;
    property IsERC20: Boolean write SetIsERC20;
  end;

procedure show(const action: TTokenAction; const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const isERC20: Boolean; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // web3
  web3.eth.types,
  // project
  cache,
  common,
  thread;

{$R *.fmx}

procedure show(const action: TTokenAction; const chain: TChain; const tx: transaction.ITransaction; const contract: TAddress; const isERC20: Boolean; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmCensorable = TFrmCensorable.Create(chain, tx, callback, log);
  frmCensorable.Action   := action;
  frmCensorable.Contract := contract;
  frmCensorable.IsERC20  := isERC20;
  frmCensorable.Show;
end;

{ TFrmCensorable }

procedure TFrmCensorable.SetAction(value: TTokenAction);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value], '%s']);
end;

procedure TFrmCensorable.SetContract(value: TAddress);
begin
  lblToken.Text := string(value);
  cache.getFriendlyName(Self.Chain, value, procedure(friendly: string; err: IError)
  begin
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
    begin
      lblToken.Text := friendly;
    end);
  end);
end;

procedure TFrmCensorable.SetIsERC20(value: Boolean);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [(function: string
  begin
    if value then Result := 'token' else Result := 'contract'
  end)()]);
end;

procedure TFrmCensorable.lblTokenClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblToken.Text, procedure(address: TAddress; err: IError)
  begin
    if Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + lblToken.Text)
    else
      common.Open(Self.Chain.Explorer + '/address/' + string(address));
  end);
end;

end.
