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
  base;

type
  TFrmSpam = class(TFrmBase)
    lblTitle: TLabel;
    lblContractText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblContractTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    procedure SetAction(value: TTokenAction);
    procedure SetContract(value: TAddress);
  public
    property Action: TTokenAction write SetAction;
    property Chain: TChain write FChain;
    property Contract: TAddress write SetContract;
  end;

procedure show(const action: TTokenAction; const chain: TChain; const contract: TAddress; const callback: TProc<Boolean>);

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

procedure show(const action: TTokenAction; const chain: TChain; const contract: TAddress; const callback: TProc<Boolean>);
begin
  const frmSpam = TFrmSpam.Create(Application);
  frmSpam.Action   := action;
  frmSpam.Chain    := chain;
  frmSpam.Contract := contract;
  frmSpam.Callback := callback;
  frmSpam.Show;
end;

{ TFrmSpam }

procedure TFrmSpam.SetAction(value: TTokenAction);
begin
  thread.synchronize(procedure
  begin
    lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value]]);
  end);
end;

procedure TFrmSpam.SetContract(value: TAddress);
begin
  lblContractText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblContractText.Text := ens;
      end);
  end);
end;

procedure TFrmSpam.lblContractTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblContractText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.Explorer + '/address/' + lblContractText.Text);
  end);
end;

end.
