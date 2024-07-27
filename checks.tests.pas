unit checks.tests;

interface

uses
  // Delphi
  DUnitX.TestFramework,
  System.SysUtils,
  // web3
  web3;

type
  [TestFixture]
  TChecks = class
  strict protected
    procedure Execute(const proc: TProc<TProc, TProc<IError>>);
  public
    [Test]
    procedure Step4;
    [Test]
    procedure Step5;
    [Test]
    procedure Step6;
    [Test]
    procedure Step7;
    [Test]
    procedure Step8;
    [Test]
    procedure Step9;
    [Test]
    procedure Step10;
    [Test]
    procedure Step11;
    [Test]
    procedure Step12;
    [Test]
    procedure Step13;
    [Test]
    procedure Step17;
    [Test]
    procedure Step18;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.JSON,
  System.Math,
  // web3
  web3.coincap,
  web3.defillama,
  web3.eth.alchemy.api,
  web3.eth.breadcrumbs,
  web3.eth.chainlink,
  web3.eth.etherscan,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.json,
  // project
  common,
  dextools,
  moralis,
  phisher,
  vaults.fyi;

{$I keys/alchemy.api.key}

procedure TChecks.Execute(const proc: TProc<TProc, TProc<IError>>);
const
  TEST_TIMEOUT  = 60000; // 60 seconds
  TEST_INTERVAL = 100;   // 0.1 second
begin
  var done: Boolean := False;
  var err : IError  := nil;

  proc(procedure
  begin
    done := True;
  end, procedure(error: IError)
  begin
    err := error;
  end);

  var waited: UInt16 := 0;
  while (err = nil) and (not done) and (waited < TEST_TIMEOUT) do
  begin
    TThread.Sleep(TEST_INTERVAL); waited := waited + TEST_INTERVAL;
  end;

  if Assigned(err) then Assert.Fail(err.Message) else if waited >= TEST_TIMEOUT then Assert.Fail('test timed out');
end;

// are we transacting with (a) smart contract and (b) verified with etherscan?
procedure TChecks.Step4;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    UNISWAP_V2_ROUTER: TAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  begin
    UNISWAP_V2_ROUTER.IsEOA(TWeb3.Create(common.Ethereum), procedure(isEOA: Boolean; err1: IError)
    begin
      if Assigned(err1) then
        err(err1)
      else if isEOA then
        err(TError.Create('%s is an EOA, expected a smart contract', [UNISWAP_V2_ROUTER]))
      else
        common.Etherscan(common.Ethereum)
          .ifErr(procedure(err2: IError)
          begin
            err(err2)
          end)
          .&else(procedure(etherscan: IEtherscan)
          begin
            etherscan.getContractSourceCode(UNISWAP_V2_ROUTER, procedure(src: string; err3: IError)
            begin
              if Assigned(err3) then
                err(err3)
              else if src <> '' then
                ok
              else
                err(TError.Create('%s''s source code is null, expected non-empty string', [UNISWAP_V2_ROUTER]));
            end);
          end);
    end);
  end);
end;

// test DefiLlama's "current price of token by contract address" API
procedure TChecks.Step5;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    TETHER: TAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  begin
    web3.defillama.coin(web3.Ethereum, TETHER, procedure(coin: ICoin; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Round(coin.Price) = 1 then
        ok
      else
        err(TError.Create('TETHER''s price is %f, expected $1.00'))
    end);
  end);
end;

// test Chainlink and CoinCap price oracles
procedure TChecks.Step6;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  begin
    const client: IWeb3 = TWeb3.Create(common.Ethereum);
    web3.eth.chainlink.TAggregatorV3.Create(client, client.Chain.Chainlink).Price(procedure(price1: Double; err1: IError)
    begin
      if Assigned(err1) then
        err(err1)
      else
        web3.coincap.price(string(client.chain.Symbol), procedure(price2: Double; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if (price2 > 0) and (price1 > 0) and (System.Math.Floor(price2 / 100) = System.Math.Floor(price1 / 100)) then
            ok
          else
            err(TError.Create('CoinCap price is $%.2f, expected $%.2f (Chainlink)', [price2, price1]))
        end);
    end);
  end);
end;

// test the MobyMask Phisher Registry
procedure TChecks.Step7;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    HOOLIGAN_BEAR: TAddress = '0x408cfD714C3bca3859650f6D85bAc1500620961e';
  begin
    phisher.isPhisher(HOOLIGAN_BEAR, procedure(result: Boolean; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if result then
        ok
      else
        err(TError.Create('isPhisher(''eip155:1:%s'') returned false, expected true', [HOOLIGAN_BEAR]));
    end);
  end);
end;

// are we transacting with a spam contract or receiving spam tokens?
procedure TChecks.Step8;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    BORED_APE_NIKE_CLUB: TAddress = '0x000386E3F7559d9B6a2F5c46B4aD1A9587D59Dc3';
  begin
    web3.eth.alchemy.api.detect(ALCHEMY_API_KEY_ETHEREUM, web3.Ethereum, BORED_APE_NIKE_CLUB, [TContractType.Spam], procedure(contractType: TContractType; err1: IError)
    begin
      if (contractType = TContractType.Spam) and not Assigned(err1) then
        ok
      else
        moralis.isPossibleSpam({$I keys/moralis.api.key}, web3.Ethereum, BORED_APE_NIKE_CLUB, procedure(spam: Boolean; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if spam then
            ok
          else
            err(TError.Create('spam is false, expected true'));
        end)
    end);
  end);
end;

// test etherscan's txlist
procedure TChecks.Step9;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    VITALIK_DOT_ETH = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
  begin
    common.Etherscan(web3.Ethereum)
      .ifErr(procedure(err1: IError)
      begin
        err(err1);
      end)
      .&else(procedure(etherscan: IEtherscan)
      begin
        etherscan.getTransactions(VITALIK_DOT_ETH, procedure(txs: ITransactions; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if Assigned(txs) and (txs.Count > 0) then
            ok
          else
            err(TError.Create('etherscan''s txlist returned 0 transactions, expected many more'));
        end);
      end);
  end);
end;

// test Uniswap's unsupported tokens list
procedure TChecks.Step10;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    ZELDA_WHIRLWIND_CASH: TAddress = '0x249A198d59b57FDa5DDa90630FeBC86fd8c7594c';
  begin
    web3.eth.tokenlists.unsupported(web3.Ethereum, procedure(tokens: TTokens; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if tokens.IndexOf(ZELDA_WHIRLWIND_CASH) > -1 then
        ok
      else
        err(TError.Create('%s is supported, expected unsupported', [ZELDA_WHIRLWIND_CASH]));
    end);
  end);
end;

// test the Breadcrumbs sanctioned address API
procedure TChecks.Step11;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    TORNADO_CASH: TAddress = '0x8589427373D6D84E98730D7795D8f6f8731FDA16';
  begin
    web3.eth.breadcrumbs.sanctioned({$I keys/breadcrumbs.api.key}, web3.Ethereum, TORNADO_CASH, procedure(value: Boolean; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if value then
        ok
      else
        err(TError.Create('%s is not sanctioned, expected sanctioned', [TORNADO_CASH]));
    end);
  end);
end;

// are we receiving (or otherwise transacting with) a low-DEX-score token?
procedure TChecks.Step12;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    RED_EYED_FROG: TAddress = '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8';
  begin
    dextools.score({$I keys/dextools.api.key}, web3.Ethereum, RED_EYED_FROG, procedure(score1: Integer; err1: IError)
    begin
      if (score1 > 0) and not Assigned(err1) then
        ok
      else
        moralis.score({$I keys/moralis.api.key}, web3.Ethereum, RED_EYED_FROG, procedure(score2: Integer; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if score2 > 0 then
            ok
          else
            err(TError.Create('score is 0, expected value between 1 and 100'));
        end);
    end);
  end);
end;

// are we receiving (or otherwise transacting with) a token without a DEX pair?
procedure TChecks.Step13;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    BETHEREUM: TAddress = '0x14C926F2290044B647e1Bf2072e67B495eff1905';
  begin
    dextools.pairs({$I keys/dextools.api.key}, web3.Ethereum, BETHEREUM, procedure(arr1: TJsonArray; err1: IError)
    begin
      if Assigned(arr1) and not Assigned(err1) then
        ok
      else
        moralis.pairs({$I keys/moralis.api.key}, web3.Ethereum, BETHEREUM, procedure(arr2: TJsonArray; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if Assigned(arr2) then
            ok
          else
            err(TError.Create('pairs is nil, expected []'));
        end);
    end);
  end);
end;

// are we receiving (or otherwise transacting with) a token with an unlock event coming up?
procedure TChecks.Step17;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    UNI: TAddress = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984';
  begin
    dextools.unlock({$I keys/dextools.api.key}, web3.Ethereum, UNI, procedure(next: TDateTime; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if next > 0 then
        ok
      else
        err(TError.Create('UNI''s next unlock date is zero, expected some future date'));
    end);
  end);
end;

// test the vaults.fyi API
procedure TChecks.Step18;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    YEARN_V2_USDC: TAddress = '0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE';
  begin
    vaults.fyi.better(web3.Ethereum, YEARN_V2_USDC, procedure(other: IVault; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Assigned(other) then
        ok
      else
        err(TError.Create('vault is nil, expected better than Yearn v2 USDC'))
    end);
  end);
end;

initialization
  TDUnitX.RegisterTestFixture(TChecks);

end.
