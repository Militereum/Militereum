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
  base;

type
  TFrmFirstTime = class(TFrmBase)
    lblTitle: TLabel;
    lblContractTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblContractText: TLabel;
    Label1: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblContractTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetContract(contract: TAddress);
  public
    property Chain: TChain write FChain;
    property Contract: TAddress write SetContract;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; contract: TAddress; callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // project
  common;

{$R *.fmx}

procedure show(chain: TChain; contract: TAddress; callback: TProc<Boolean>);
begin
  const frmFirstTime = TFrmFirstTime.Create(Application);
  frmFirstTime.Chain := chain;
  frmFirstTime.Contract := contract;
  frmFirstTime.Callback := callback;
  frmFirstTime.Show;
end;

{ TFrmFirstTime }

procedure TFrmFirstTime.SetContract(contract: TAddress);
begin
  lblContractText.Text := string(contract);
end;

procedure TFrmFirstTime.lblContractTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/address/' + lblContractText.Text);
end;

procedure TFrmFirstTime.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmFirstTime.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
