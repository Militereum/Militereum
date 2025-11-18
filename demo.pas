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
    actAirdrop: TAction;
    actApprove: TAction;
    actBlacklisted: TAction;
    actCensorable: TAction;
    actDelegator: TAction;
    actDormant: TAction;
    actExploit: TAction;
    actFirsttime: TAction;
    actFundedBy: TAction;
    actHoneypot: TAction;
    actLimit: TAction;
    actLowDexScore: TAction;
    actMetamorphic: TAction;
    actNoDexPair: TAction;
    actPausable: TAction;
    actPhisher: TAction;
    actSanctioned: TAction;
    actSetApprovalForAll: TAction;
    actSpam: TAction;
    actUnlock: TAction;
    actUnsupported: TAction;
    actUnverified: TAction;
    actVault: TAction;
    procedure actAirdropExecute(Sender: TObject);
    procedure actApproveExecute(Sender: TObject);
    procedure actBlacklistedExecute(Sender: TObject);
    procedure actCensorableExecute(Sender: TObject);
    procedure actDelegatorExecute(Sender: TObject);
    procedure actDormantExecute(Sender: TObject);
    procedure actExploitExecute(Sender: TObject);
    procedure actFirsttimeExecute(Sender: TObject);
    procedure actFundedByExecute(Sender: TObject);
    procedure actHoneypotExecute(Sender: TObject);
    procedure actLimitExecute(Sender: TObject);
    procedure actLowDexScoreExecute(Sender: TObject);
    procedure actMetamorphicExecute(Sender: TObject);	
    procedure actNoDexPairExecute(Sender: TObject);
    procedure actPausableExecute(Sender: TObject);
    procedure actPhisherExecute(Sender: TObject);
    procedure actSanctionedExecute(Sender: TObject);
    procedure actSetApprovalForAllExecute(Sender: TObject);
    procedure actSpamExecute(Sender: TObject);
    procedure actUnlockExecute(Sender: TObject);
    procedure actUnsupportedExecute(Sender: TObject);
    procedure actUnverifiedExecute(Sender: TObject);
    procedure actUpdate(Sender: TObject);
    procedure actVaultExecute(Sender: TObject);
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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // project
  airdrop,
  asset,
  base,
  blacklisted,
  censorable,
  common,
  delegator,
  dormant,
  exploit,
  firsttime,
  fundedBy,
  honeypot,
  limit,
  lowDexScore,
  metamorphic,
  noDexPair,
  pausable,
  phisher,
  sanctioned,
  setApprovalForAll,
  spam,
  thread,
  unlock,
  unsupported,
  unverified,
  vault;

procedure TdmDemo.actAirdropExecute(Sender: TObject);
begin
  airdrop.show(taReceive, common.Ethereum, nil, '0x000386E3F7559d9B6a2F5c46B4aD1A9587D59Dc3', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actApproveExecute(Sender: TObject);
begin
  asset.approve(common.Ethereum, nil, web3.eth.tokenlists.DAI, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', isGood, web3.Infinite, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actBlacklistedExecute(Sender: TObject);
begin
  blacklisted.show(common.Ethereum, nil, '0xaa05f7c7eb9af63d6cc03c36c4f4ef6c37431ee0', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actCensorableExecute(Sender: TObject);
begin
  censorable.show(taReceive, common.Ethereum, nil, '0xdAC17F958D2ee523a2206206994597C13D831ec7', True, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actDelegatorExecute(Sender: TObject);
begin
  delegator.show(common.Ethereum, nil, '0x930fcc37d6042c79211ee18a02857cb1fd7f0d0b', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actDormantExecute(Sender: TObject);
begin
  dormant.show(taTransact, common.Ethereum, nil, '0x5031eD87bd69fB164f2BA5e1b156603216574197', False, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actExploitExecute(Sender: TObject);
begin
  exploit.show(common.Ethereum, nil, '0xA950974f64aA33f27F6C5e017eEE93BF7588ED07', 'Radiant Capital Hack', 'https://revoke.cash/exploits/radiant?chainId=1', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actFirsttimeExecute(Sender: TObject);
begin
  firsttime.show(common.Ethereum, nil, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actFundedByExecute(Sender: TObject);
begin
  fundedBy.show(common.Ethereum, nil, '0x8589427373D6D84E98730D7795D8f6f8731FDA16', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actHoneypotExecute(Sender: TObject);
begin
  honeypot.show(common.Ethereum, nil, '0x11d1A3cB34E7be24181A37DaE83bfFAE21Af524A', TCannot.Sell, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actLimitExecute(Sender: TObject);
begin
  limit.show(common.Ethereum, nil, 'ETH', '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', 6080.45, procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actLowDexScoreExecute(Sender: TObject);
begin
  lowDexScore.show(taReceive, common.Ethereum, nil, '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actMetamorphicExecute(Sender: TObject);
begin
  metamorphic.show(common.Ethereum, nil, '0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actNoDexPairExecute(Sender: TObject);
begin
  noDexPair.show(taReceive, common.Ethereum, nil, '0x14C926F2290044B647e1Bf2072e67B495eff1905', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actPausableExecute(Sender: TObject);
begin
  pausable.show(taReceive, common.Ethereum, nil, '0xdAC17F958D2ee523a2206206994597C13D831ec7', True, procedure(allow: Boolean) begin end, nil);
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

procedure TdmDemo.actUnlockExecute(Sender: TObject);
begin
  unlock.show(taReceive, common.Ethereum, nil, '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actUnsupportedExecute(Sender: TObject);
begin
  unsupported.show(taReceive, common.Ethereum, nil, '0x249A198d59b57FDa5DDa90630FeBC86fd8c7594c', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actUnverifiedExecute(Sender: TObject);
begin
  unverified.show(common.Ethereum, nil, '0x5031eD87bd69fB164f2BA5e1b156603216574197', procedure(allow: Boolean) begin end, nil);
end;

procedure TdmDemo.actUpdate(Sender: TObject);
begin
  if Sender is TCustomAction then
  begin
    (Sender as TCustomAction).Enabled := common.Demo;
    (Sender as TCustomAction).Visible := common.Demo;
  end;
end;

procedure TdmDemo.actVaultExecute(Sender: TObject);
begin
  vault.show(common.Ethereum, nil, 'USDC', procedure(allow: Boolean) begin end, nil);
end;

end.
