unit checks.tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TChecks = class
  public
    [Test]
    procedure Step4;
    [Test]
    procedure Step5;
    [Test]
    procedure Step6;
    [Test]
    procedure Step8;
    [Test]
    procedure Step12;
    [Test]
    procedure Step13;
    [Test]
    procedure Step18;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.JSON,
  System.SysUtils,
  // web3
  web3,
  web3.coincap,
  web3.defillama,
  web3.eth.alchemy.api,
  web3.eth.chainlink,
  web3.eth.etherscan,
  web3.eth.types,
  web3.json,
  // project
  common,
  dextools,
  moralis,
  vaults.fyi;

{$I keys/alchemy.api.key}

const
  TEST_TIMEOUT  = 60000; // 60 seconds
  TEST_INTERVAL = 100;   // 0.1 second

// are we transacting with (a) smart contract and (b) verified with etherscan?
procedure TChecks.Step4;
const
  UNISWAP_V2_ROUTER: TAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
begin
  var done: Boolean := False;
  var err : IError  := nil;

  UNISWAP_V2_ROUTER.IsEOA(TWeb3.Create(common.Ethereum), procedure(isEOA: Boolean; err1: IError)
  begin
    if Assigned(err1) then
      err := err1
    else if isEOA then
      err := TError.Create('%s is an EOA, expected a smart contract', [UNISWAP_V2_ROUTER])
    else
      common.Etherscan(common.Ethereum)
        .ifErr(procedure(err2: IError)
        begin
          err := err2
        end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getContractSourceCode(UNISWAP_V2_ROUTER, procedure(src: string; err3: IError)
          begin
            if Assigned(err3) then
              err := err3
            else if src <> '' then
              done := True
            else
              err := TError.Create('%s''s source code is null, expected non-empty string', [UNISWAP_V2_ROUTER])
          end);
        end);
  end);

  while (err = nil) and (not done) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message);
end;

// test DefiLlama's "current price of token by contract address" API
procedure TChecks.Step5;
const
  TETHER = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
begin
  var done: Boolean := False;
  var err : IError := nil;

  web3.defillama.coin(web3.Ethereum, TETHER, procedure(coin: ICoin; err1: IError)
  begin
    if Assigned(err1) then
      err := err1
    else if Round(coin.Price) <> 1 then
      err := TError.Create('price is %f, expected $1.00')
    else
      done := True;
  end);

  while (err = nil) and (not done) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message);
end;

// test Chainlink and CoinCap price oracles
procedure TChecks.Step6;
begin
  var done: Boolean := False;
  var err : IError  := nil;

  const client: IWeb3 = TWeb3.Create(common.Ethereum);

  web3.eth.chainlink.TAggregatorV3.Create(client, client.Chain.Chainlink).Price(procedure(price1: Double; err1: IError)
  begin
    if Assigned(err1) then
      err := err1
    else
      web3.coincap.price(string(client.chain.Symbol), procedure(price2: Double; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else if Round(price2 / 10) = Round(price1 / 10) then
          done := True
        else
          err := TError.Create('CoinCap price is $%.2f, expected $%.2f (Chainlink)', [price2, price1])
      end);
  end);

  while (err = nil) and (not done) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message);
end;

// are we transacting with a spam contract or receiving spam tokens?
procedure TChecks.Step8;
const
  BORED_APE_NIKE_CLUB = '0x000386E3F7559d9B6a2F5c46B4aD1A9587D59Dc3';
begin
  var result: TContractType := Good;
  var err   : IError        := nil;

  web3.eth.alchemy.api.detect(ALCHEMY_API_KEY_ETHEREUM, web3.Ethereum, BORED_APE_NIKE_CLUB, [TContractType.Spam], procedure(contractType: TContractType; err1: IError)
  begin
    if not Assigned(err1) then
      result := contractType
    else
      moralis.isPossibleSpam({$I keys/moralis.api.key}, web3.Ethereum, BORED_APE_NIKE_CLUB, procedure(spam: Boolean; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else
          if spam then
            result := TContractType.Spam
          else
            err := TError.Create('spam is false, expected true');
      end)
  end);

  while (err = nil) and (result = TContractType.Good) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message);
end;

// are we receiving (or otherwise transacting with) a low-DEX-score token?
procedure TChecks.Step12;
const
  RED_EYED_FROG = '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8';
begin
  var score: Integer := -1;
  var err  : IError  := nil;

  dextools.score({$I keys/dextools.api.key}, web3.Ethereum, RED_EYED_FROG, procedure(score1: Integer; err1: IError)
  begin
    if not Assigned(err1) then
      score := score1
    else
      moralis.score({$I keys/moralis.api.key}, web3.Ethereum, RED_EYED_FROG, procedure(score2: Integer; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else
          score := score2;
      end);
  end);

  while (err = nil) and (score = -1) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message) else if score = 0 then Assert.Fail('score is 0, expected value between 1 and 100');
end;

// are we receiving (or otherwise transacting with) a token without a DEX pair?
procedure TChecks.Step13;
const
  BETHEREUM = '0x14C926F2290044B647e1Bf2072e67B495eff1905';
begin
  var arr: TJsonArray := nil;
  var err: IError     := nil;

  dextools.pairs({$I keys/dextools.api.key}, web3.Ethereum, BETHEREUM, procedure(arr1: TJsonArray; err1: IError)
  begin
    if Assigned(arr1) and not Assigned(err1) then
      arr := arr1.Clone as TJsonArray
    else
      moralis.pairs({$I keys/moralis.api.key}, web3.Ethereum, BETHEREUM, procedure(arr2: TJsonArray; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else if Assigned(arr2) then
          arr := arr2.Clone as TJsonArray
        else
          arr := web3.json.unmarshal('[]') as TJsonArray;
      end);
  end);

  while (err = nil) and (arr = nil) do TThread.Sleep(100);

  if Assigned(arr) then arr.Free;
  if Assigned(err) then Assert.Fail(err.Message);
end;

// are we depositing into a vault, but is there another vault with higher APY (while having the same TVL or more)?
procedure TChecks.Step18;
const
  YEARN_V2_USDC = '0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE';
begin
  var vault: IVault := nil;
  var error: IError := nil;

  vaults.fyi.better(web3.Ethereum, YEARN_V2_USDC, procedure(other: IVault; err: IError)
  begin
    vault := other;
    error := err;
  end);

  var waited: Integer := 0;
  while (error = nil) and (vault = nil) and (waited < TEST_TIMEOUT) do
  begin
    TThread.Sleep(TEST_INTERVAL); waited := waited + TEST_INTERVAL;
  end;

  if Assigned(error) then Assert.Fail(error.Message) else if (vault = nil) then Assert.Fail('vault is nil, expected better than Yearn v2 USDC');
end;

initialization
  TDUnitX.RegisterTestFixture(TChecks);

end.
