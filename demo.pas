unit demo;

interface

uses
  // Delphi
  System.Classes,
  System.Actions,
  // FireMonkey
  FMX.ActnList;

type
  TdmDemo = class(TDataModule)
    AL: TActionList;
    actApprove: TAction;
    actLimit: TAction;
    actSanctioned: TAction;
    actUnverified: TAction;
    actFirsttime: TAction;
    actPhisher: TAction;
    actSetApprovalForAll: TAction;
    actSpam: TAction;
    actHoneypot: TAction;
    actUnsupported: TAction;
    actNoDexPair: TAction;
    actLowDexScore: TAction;
    actAirdrop: TAction;
    procedure actApproveExecute(Sender: TObject);
    procedure actLimitExecute(Sender: TObject);
    procedure actSanctionedExecute(Sender: TObject);
    procedure actUnverifiedExecute(Sender: TObject);
    procedure actFirsttimeExecute(Sender: TObject);
    procedure actPhisherExecute(Sender: TObject);
    procedure actSetApprovalForAllExecute(Sender: TObject);
    procedure actSpamExecute(Sender: TObject);
    procedure actHoneypotExecute(Sender: TObject);
    procedure actUnsupportedExecute(Sender: TObject);
    procedure actNoDexPairExecute(Sender: TObject);
    procedure actUpdate(Sender: TObject);
    procedure actLowDexScoreExecute(Sender: TObject);
    procedure actAirdropExecute(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dmDemo: TdmDemo;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

uses
  // web3
  web3,
  web3.eth.tokenlists,
  // project
  airdrop,
  asset,
  base,
  common,
  firsttime,
  honeypot,
  limit,
  lowDexScore,
  noDexPair,
  phisher,
  sanctioned,
  setApprovalForAll,
  spam,
  thread,
  unsupported,
  unverified;

procedure TdmDemo.actUpdate(Sender: TObject);
begin
  if Sender is TCustomAction then
  begin
    (Sender as TCustomAction).Enabled := common.Demo;
    (Sender as TCustomAction).Visible := common.Demo;
  end;
end;

procedure TdmDemo.actAirdropExecute(Sender: TObject);
begin
  airdrop.show(taReceive, common.Ethereum, nil, '0x000386E3F7559d9B6a2F5c46B4aD1A9587D59Dc3', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actApproveExecute(Sender: TObject);
begin
  web3.eth.tokenlists.token(common.Ethereum, '0x6B175474E89094C44Da98b954EedeAC495271d0F', procedure(dai: IToken; err: IError)
  begin
    thread.synchronize(procedure
    begin
      asset.approve(common.Ethereum, nil, dai, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', web3.Infinite, procedure(allow: Boolean) begin end, nil);
    end);
  end);
end;

procedure TdmDemo.actFirsttimeExecute(Sender: TObject);
begin
  firsttime.show(common.Ethereum, nil, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actHoneypotExecute(Sender: TObject);
begin
  honeypot.show(common.Ethereum, nil, '0xc43420dbaF53b1a6C607C6A561aC60aFb16b05fd', '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actLimitExecute(Sender: TObject);
begin
  limit.show(common.Ethereum, nil, 'ETH', '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', 6080.45, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actLowDexScoreExecute(Sender: TObject);
begin
  lowDexScore.show(taReceive, common.Ethereum, nil, '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actNoDexPairExecute(Sender: TObject);
begin
  noDexPair.show(taReceive, common.Ethereum, nil, '0x14C926F2290044B647e1Bf2072e67B495eff1905', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actPhisherExecute(Sender: TObject);
begin
  phisher.show(common.Ethereum, nil, '0x408cfD714C3bca3859650f6D85bAc1500620961e', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actSanctionedExecute(Sender: TObject);
begin
  sanctioned.show(common.Ethereum, nil, '0x8589427373D6D84E98730D7795D8f6f8731FDA16', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actSetApprovalForAllExecute(Sender: TObject);
begin
  setApprovalForAll.show(common.Ethereum, nil, '0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D', '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actSpamExecute(Sender: TObject);
begin
  spam.show(taReceive, common.Ethereum, nil, '0x000386E3F7559d9B6a2F5c46B4aD1A9587D59Dc3', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actUnsupportedExecute(Sender: TObject);
begin
  unsupported.show(taReceive, common.Ethereum, nil, '0x249A198d59b57FDa5DDa90630FeBC86fd8c7594c', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actUnverifiedExecute(Sender: TObject);
begin
  unverified.show(common.Ethereum, nil, '0x5031eD87bd69fB164f2BA5e1b156603216574197', procedure(allow: Boolean) begin end, nil);
end;

end.
