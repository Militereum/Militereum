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
    procedure Issue14;
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
    procedure Step14;
    [Test]
    procedure Step15;
    [Test]
    procedure Step16;
    [Test]
    procedure Step17;
    [Test]
    procedure Step18;
    [Test]
    procedure Step19;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.DateUtils,
  System.JSON,
  System.Math,
  // web3
  web3.coincap,
  web3.defillama,
  web3.eth.abi,
  web3.eth.alchemy.api,
  web3.eth.breadcrumbs,
  web3.eth.chainlink,
  web3.eth.etherscan,
  web3.eth.simulate,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.json,
  // project
  asset,
  cache,
  checks,
  coingecko,
  common,
  dextools,
  mobula,
  moralis,
  phisher,
  revoke.cash,
  vaults.fyi;

{$I keys/alchemy.api.key}

// executes an async test. the text is expected to call back into the 1st arg on success, otherwise the 2nd ags when an error occurred
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

// test TSpenderStatus on Base
procedure TChecks.Issue14;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    SPENDER: TAddress = '0x2397edd0c7c327f7d3661e0037c168de0206124b';
  begin
    getSpenderStatus(common.Base, SPENDER, procedure(status: TSpenderStatus; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if status = isGood then
        ok
      else
        err(TError.Create('%s''s status on Base is %d, expected to be good', [SPENDER, Ord(status)]))
    end);
  end);
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
        common.Etherscan(common.Ethereum).getContractSourceCode(UNISWAP_V2_ROUTER, procedure(src: string; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if src <> '' then
            ok
          else
            err(TError.Create('%s''s source code is null, expected non-empty string', [UNISWAP_V2_ROUTER]));
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
    web3.defillama.coin(web3.Ethereum, TETHER, procedure(coin: web3.defillama.ICoin; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Round(coin.Price) = 1 then
        ok
      else
        err(TError.Create('Tether''s price is %f, expected $1.00'))
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
    common.Etherscan(web3.Ethereum).getTransactions(VITALIK_DOT_ETH, procedure(txs: ITransactions; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Assigned(txs) and (txs.Count > 0) then
        ok
      else
        err(TError.Create('etherscan''s txlist returned 0 transactions, expected many more'));
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
    DARKNET_MARKETPLACE_HYDRA: TAddress = '0x098B716B8Aaf21512996dC57EB0615e2383E2f96';
  begin
    web3.eth.breadcrumbs.sanctioned({$I keys/breadcrumbs.api.key}, web3.Ethereum, DARKNET_MARKETPLACE_HYDRA, procedure(value: Boolean; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if value then
        ok
      else
        err(TError.Create('%s is not sanctioned, expected sanctioned', [DARKNET_MARKETPLACE_HYDRA]));
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
        moralis.securityScore({$I keys/moralis.api.key}, web3.Ethereum, RED_EYED_FROG, procedure(score2: Integer; err2: IError)
        begin
          if (score2 > 0) and not Assigned(err2) then
            ok
          else
            coingecko.score(web3.Ethereum, RED_EYED_FROG, procedure(score3: Double; err3: IError)
            begin
              if Assigned(err3) then
                err(err3)
              else if score3 > 0 then
                ok
              else
                err(TError.Create('score is 0, expected value between 1 and 100'));
            end);
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

// test etherscan's getabi
procedure TChecks.Step14;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    TETHER: TAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  begin
    cache.getContractABI(web3.Ethereum, TETHER, procedure(abi: IContractABI; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else
        if (function(const abi: IContractABI): Boolean // returns True if censorable, otherwise False
        begin
          if Assigned(abi) then for var I := 0 to Pred(abi.Count) do
            if (abi.Item(I).SymbolType = TSymbolType.Function) and (System.Pos('blacklist', abi.Item(I).Name.ToLower) > 0) then
            begin
              Result := True;
              EXIT;
            end;
          Result := False;
        end)(abi) then
         ok
        else
          if (function(const abi: IContractABI): Boolean // returns True if pausable, otherwise False
          begin
            if Assigned(abi) then for var I := 0 to Pred(abi.Count) do
              if (abi.Item(I).SymbolType = TSymbolType.Function) and (System.Pos('pause', abi.Item(I).Name.ToLower) > 0) then
              begin
                Result := True;
                EXIT;
              end;
            Result := False;
          end)(abi) then
            ok
          else
            err(TError.Create('Tether is neither censorable nor pausable, expected to have a blacklist'));
    end);
  end);
end;

// test for honeypot token on Sepolia
procedure TChecks.Step15;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  {$I keys/tenderly.api.key}
  const
    OWNER   : TAddress = '0x7033A74F69a49652A51ec1c5B6f952e420795C86'; // deployer/owner (is allowed to transfer)
    OTHER   : TAddress = '0x81B4a9f9Ab3b55Bf224407A3046b82BDFB32Af4d'; // brandly.eth (not allowed to transfer)
    HONEYPOT: TAddress = '0xdd8c2c0b62f1644ee1c7e67789dab758ba0e798b';
  begin
    // step 1: check if anyone (other than the owner) can transfer the token after a mint
    web3.eth.simulate.honeypots(ALCHEMY_API_KEY_ETHEREUM, TENDERLY_ACCOUNT_ID, TENDERLY_PROJECT_ID, TENDERLY_ACCESS_KEY, web3.Sepolia, OTHER, HONEYPOT, 0, web3.eth.abi.encode('mint(uint256)', [1000000000000000000]), procedure(honeypots1: IAssetChanges; err1: IError)
    begin
      if Assigned(err1) then
        err(err1)
      else if (honeypots1 = nil) or (honeypots1.Count = 0) then
        err(TError.Create('%s is a honeypot token and should be detected as such', [HONEYPOT]))
      else
        // step 2: now that we have confirmed the token to be a honeypot, double-check our logic and verify the owner *is* allowed to transfer
        web3.eth.simulate.honeypots(ALCHEMY_API_KEY_ETHEREUM, TENDERLY_ACCOUNT_ID, TENDERLY_PROJECT_ID, TENDERLY_ACCESS_KEY, web3.Sepolia, OWNER, HONEYPOT, 0, web3.eth.abi.encode('mint(uint256)', [1000000000000000000]), procedure(honeypots2: IAssetChanges; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if (honeypots2 = nil) or (honeypots2.Count = 0) then
            ok
          else
            err(TError.Create('owner %s should be allowed to transfer token %s', [OWNER, HONEYPOT]));
        end);
    end);
  end);
end;

// test for a dormant smart contract
procedure TChecks.Step16;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    POS_DUMMY_STATE_SENDER: TAddress = '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39';
  begin
    common.Etherscan(web3.Ethereum).getLatestTransaction(POS_DUMMY_STATE_SENDER, procedure(latest: ITransaction; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Assigned(latest) and (DaysBetween(System.SysUtils.Now, UnixToDateTime(latest.timeStamp, False)) < 30) then
        err(TError.Create('%s had a transcation less than 30 days ago, expected the smart contract to be dormant', [POS_DUMMY_STATE_SENDER]))
      else
        ok
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
    mobula.unlock({$I keys/mobula.api.key}, web3.Ethereum, UNI, 0, procedure(next: TDateTime; err1: IError)
    begin
      if (next > 0) and not Assigned(err1) then
        ok
      else
        dextools.unlock({$I keys/dextools.api.key}, web3.Ethereum, UNI, procedure(next: TDateTime; err2: IError)
        begin
          if Assigned(err2) then
            err(err2)
          else if next > 0 then
            ok
          else
            err(TError.Create('UNI''s next unlock date is zero, expected some future date'));
        end);
    end);
  end);
end;

// are we transacting with a contract (or receiving a token) that is on the revoke.cash exploit list?
procedure TChecks.Step18;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    RADIANT_CAPITAL: TAddress = '0xA950974f64aA33f27F6C5e017eEE93BF7588ED07';
  begin
    revoke.cash.exploit(web3.Ethereum, RADIANT_CAPITAL, procedure(exploit: IExploit; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Assigned(exploit) then
        ok
      else
        err(TError.Create('exploit is nil, expected Radiant Capital Hack'));
    end);
  end);
end;

// test the vaults.fyi API
procedure TChecks.Step19;
begin
  Self.Execute(procedure(ok: TProc; err: TProc<IError>)
  const
    STEAKHOUSE_USDC_RWA: TAddress = '0x6D4e530B8431a52FFDA4516BA4Aadc0951897F8C';
  begin
    vaults.fyi.better(web3.Ethereum, STEAKHOUSE_USDC_RWA, procedure(other: IVault; error: IError)
    begin
      if Assigned(error) then
        err(error)
      else if Assigned(other) then
        ok
      else
        err(TError.Create('vault is nil, expected better than Steakhouse USDC RWA'))
    end);
  end);
end;

initialization
  TDUnitX.RegisterTestFixture(TChecks);

end.
