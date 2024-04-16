unit checks;

interface

uses
  // Indy
  IdGlobal,
  // web3
  web3,
  // project
  base,
  server,
  transaction;

type
  TWarning = (Approve, TransferOut, Other);

type
  TPrompted = set of TWarning;

type
  TDone = reference to procedure(const prompted: TPrompted);
  TNext = reference to procedure(const prompted: TPrompted; const err: IError);

type
  TStep  = procedure(const prompted: TPrompted; const next: TNext) of object;
  TSteps = array of TStep;

type
  TComment = class(TCustomAttribute)
  strict private
    FValue: string;
  public
    constructor Create(const aValue: string);
    property Value: string read FValue;
  end;

type
  TChecks = class(TObject)
  strict private
    server: TEthereumRPCServer;
    port  : TIdPort;
    chain : TChain;
    tx    : transaction.ITransaction;
    block : TDone;
    log   : TLog;
  public
    constructor Create(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const block: TDone; const log: TLog);
    [TComment('approve(address,uint256)')]
    procedure Step1(const prompted: TPrompted; const next: TNext);
    [TComment('transfer(address,uint256)')]
    procedure Step2(const prompted: TPrompted; const next: TNext);
    [TComment('setApprovalForAll(address,bool)')]
    procedure Step3(const prompted: TPrompted; const next: TNext);
    [TComment('are we transacting with (a) smart contract and (b) not verified with etherscan?')]
    procedure Step4(const prompted: TPrompted; const next: TNext);
    [TComment('are we transferring more than $5k in ERC-20, translated to USD?')]
    procedure Step5(const prompted: TPrompted; const next: TNext);
    [TComment('are we sending more than $5k in ETH, translated to USD?')]
    procedure Step6(const prompted: TPrompted; const next: TNext);
    [TComment('are we transacting with a contract that has been identified as a phisher in the MobyMask Phisher Registry?')]
    procedure Step7(const prompted: TPrompted; const next: TNext);
    [TComment('are we transacting with a spam contract or receiving spam tokens?')]
    procedure Step8(const prompted: TPrompted; const next: TNext);
    [TComment('have we transacted with this address before?')]
    procedure Step9(const prompted: TPrompted; const next: TNext);
    [TComment('are we transacting with an unsupported contract or receiving unsupported tokens?')]
    procedure Step10(const prompted: TPrompted; const next: TNext);
    [TComment('are we transacting with a sanctioned address?')]
    procedure Step11(const prompted: TPrompted; const next: TNext);
    [TComment('are we receiving (or otherwise transacting with) a low-DEX-score token?')]
    procedure Step12(const prompted: TPrompted; const next: TNext);
    [TComment('are we receiving (or otherwise transacting with) a token without a DEX pair?')]
    procedure Step13(const prompted: TPrompted; const next: TNext);
    [TComment('are we receiving (or otherwise transacting with) a censorable token that can blacklist you?')]
    procedure Step14(const prompted: TPrompted; const next: TNext);
    [TComment('are we buying a honeypot token?')]
    procedure Step15(const prompted: TPrompted; const next: TNext);
    [TComment('are we receiving (or otherwise transacting with) a dormant token/contract?')]
    procedure Step16(const prompted: TPrompted; const next: TNext);
    [TComment('are we receiving (or otherwise transacting with) a token with an unlock event coming up?')]
    procedure Step17(const prompted: TPrompted; const next: TNext);
    [TComment('simulate transaction, prompt for each and every token (a) getting approved, or (b) leaving your wallet')]
    procedure Step18(const prompted: TPrompted; const next: TNext);
    [TComment('include this step if you want the transaction to fail')]
    procedure Fail(const prompted: TPrompted; const next: TNext);
  end;

implementation

uses
  // Delphi
  System.DateUtils,
  System.JSON,
  System.Math,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.defillama,
  web3.eth.alchemy.api,
  web3.eth.breadcrumbs,
  web3.eth.etherscan,
  web3.eth.simulate,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.eth.utils,
  web3.utils,
  // project
  airdrop,
  asset,
  cache,
  censorable,
  common,
  dextools,
  dormant,
  error,
  firsttime,
  honeypot,
  limit,
  lowDexScore,
  moralis,
  noDexPair,
  pausable,
  phisher,
  sanctioned,
  setApprovalForAll,
  spam,
  thread,
  unlock,
  unsupported,
  unverified;

{--------------------------------- TContract ----------------------------------}

type
  TContract = record
  private
    Action : TTokenAction;
    Address: TAddress;
    Chain  : TChain;
  public
    constructor Create(const aAction: TTokenAction; const aAddress: TAddress; const aChain: TChain);
    procedure IsToken(const callback: TProc<Boolean, IError>);
  end;

constructor TContract.Create(const aAction: TTokenAction; const aAddress: TAddress; const aChain: TChain);
begin
  Self.Action  := aAction;
  Self.Address := aAddress;
  Self.Chain   := aChain;
end;

procedure TContract.IsToken(const callback: TProc<Boolean, IError>);
begin
  const address = Self.Address;
  if Self.Action = taReceive then
    callback(True, nil)
  else
    cache.getContractABI(Self.Chain, address, procedure(abi: IContractABI; err: IError)
    begin
      if Assigned(err) then
        callback(False, err)
      else
        callback(abi.IsERC20, nil);
    end);
end;

{-------------------------------- getEachToken --------------------------------}

type
  TGetEach = reference to procedure(const contracts: TArray<TContract>; const err: IError);
  TSubStep = reference to procedure(const index: Integer; const prompted: TPrompted);

procedure getEachToken(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const callback: TGetEach);
begin
  var contracts: TArray<TContract> := [];
  // step #1: tx.To
  tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(contracts, err);
      EXIT;
    end;
    if not isEOA then
      contracts := contracts + [TContract.Create(taTransact, tx.&To, chain)];
    // step #2: incoming tokens
    server.apiKey(port)
      .ifErr(procedure(err: IError) begin callback(contracts, err) end)
      .&else(procedure(apiKey: string)
      begin
        tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
        begin
          if Assigned(err) or not Assigned(changes) then
            callback(contracts, err)
          else
            tx.From
              .ifErr(procedure(err: IError) begin callback(contracts, err) end)
              .&else(procedure(from: TAddress)
              begin
                const incoming: IAssetChanges = changes.Incoming(from);
                try
                  if Assigned(incoming) then for var I := 0 to Pred(incoming.Count) do
                    if incoming.Item(I).Asset = native then
                      // ignore native asset (probably ETH)
                    else if incoming.Item(I).Contract.SameAs(tx.&To) then
                      // ignore tx.To
                    else
                      contracts := contracts + [TContract.Create(taReceive, incoming.Item(I).Contract, chain)];
                finally
                  callback(contracts, nil);
                end;
              end);
        end);
      end);
  end);
end;

{---------------------------------- TComment ----------------------------------}

constructor TComment.Create(const aValue: string);
begin
  inherited Create;
  FValue := aValue;
end;

{---------------------------------- TChecks -----------------------------------}

constructor TChecks.Create(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const block: TDone; const log: TLog);
begin
  inherited Create;
  Self.server := server;
  Self.port   := port;
  Self.chain  := chain;
  Self.tx     := tx;
  Self.block  := block;
  Self.log    := log;
end;

procedure TChecks.Step1(const prompted: TPrompted; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(prompted, nil) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0x095EA7B3') then
        next(prompted, nil)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(prompted, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(prompted, nil)
            else begin
              const value = (function(const args: TArray<TArg>): BigInteger
              begin
                if Length(args) > 1 then
                  Result := args[1].toUInt256
                else
                  Result := web3.Infinite;
              end)(args);
              if value = 0 then
                next(prompted, nil)
              else
                web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; err: IError)
                begin
                  if Assigned(err) then
                    next(prompted, error.wrap(err, Self.Step1))
                  else if not Assigned(token) then
                    next(prompted, nil)
                  else
                    thread.synchronize(procedure
                    begin
                      asset.approve(chain, tx, token, args[0].ToAddress, value, procedure(allow: Boolean)
                      begin
                        if allow then
                          next(prompted + [TWarning.Approve], nil)
                        else
                          block(prompted);
                      end, log);
                    end);
                end);
            end;
          end);
    end);
end;

procedure TChecks.Step2(const prompted: TPrompted; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(prompted, nil) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(prompted, nil)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(prompted, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(prompted, nil)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(prompted, nil)
              else
                server.apiKey(port)
                  .ifErr(procedure(err: IError) begin next(prompted, err) end)
                  .&else(procedure(apiKey: string)
                  begin
                    tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
                    begin
                      if Assigned(err) then
                        next(prompted, error.wrap(err, Self.Step2))
                      else if not Assigned(changes) then
                        next(prompted, nil)
                      else begin
                        const index = changes.IndexOf(tx.&To);
                        if (index > -1) and (changes.Item(index).Amount > 0) then
                          thread.synchronize(procedure
                          begin
                            asset.show(chain, tx, changes.Item(index), procedure(allow: Boolean)
                            begin
                              if allow then
                                next(prompted + [TWarning.TransferOut], nil)
                              else
                                block(prompted);
                            end, log);
                          end)
                        else
                          thread.synchronize(procedure
                          begin
                            honeypot.show(chain, tx, tx.&To, args[0].ToAddress, procedure(allow: Boolean)
                            begin
                              if allow then
                                next(prompted + [TWarning.Other], nil)
                              else
                                block(prompted);
                            end, log);
                          end);
                      end;
                    end);
                  end);
            end;
          end);
    end);
end;

procedure TChecks.Step3(const prompted: TPrompted; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(prompted, nil) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA22CB465') then
        next(prompted, nil)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(prompted, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(prompted, nil)
            else begin
              const approved = (function(const args: TArray<TArg>): Boolean
              begin
                if Length(args) > 1 then
                  Result := args[1].toBoolean
                else
                  Result := False;
              end)(args);
              if not approved then
                next(prompted, nil)
              else
                thread.synchronize(procedure
                begin
                  setApprovalForAll.show(chain, tx, tx.&To, args[0].ToAddress, procedure(allow: Boolean)
                  begin
                    if allow then
                      next(prompted + [TWarning.Other], nil)
                    else
                      block(prompted);
                  end, log);
                end);
            end;
          end);
    end);
end;

procedure TChecks.Step4(const prompted: TPrompted; const next: TNext);
begin
  tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) then
      next(prompted, error.wrap(err, Self.Step4))
    else if isEOA then
      next(prompted, nil)
    else
      common.Etherscan(chain)
        .ifErr(procedure(err: IError) begin next(prompted, err) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getContractSourceCode(tx.&To, procedure(src: string; err: IError)
          begin
            if Assigned(err) then
              next(prompted, error.wrap(err, Self.Step4))
            else if src <> '' then
              next(prompted, nil)
            else
              thread.synchronize(procedure
              begin
                unverified.show(chain, tx, tx.&To, procedure(allow: Boolean)
                begin
                  if allow then
                    next(prompted + [TWarning.Other], nil)
                  else
                    block(prompted);
                end, log);
              end);
          end);
        end);
  end);
end;

procedure TChecks.Step5(const prompted: TPrompted; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(prompted, nil) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(prompted, nil)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(prompted, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(prompted, nil)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(prompted, nil)
              else
                web3.defillama.coin(chain, tx.&To, procedure(coin: ICoin; err: IError)
                begin
                  if Assigned(err) or not Assigned(coin) then
                    next(prompted, error.wrap(err, Self.Step5))
                  else begin
                    const amount = (quantity.AsDouble / Round(Power(10, coin.Decimals))) * coin.Price;
                    if amount < common.LIMIT then
                      next(prompted, nil)
                    else
                      cache.getSymbol(chain, tx.&To, procedure(symbol: string; err: IError)
                      begin
                        if Assigned(err) then
                          next(prompted, error.wrap(err, Self.Step5))
                        else
                          thread.synchronize(procedure
                          begin
                            limit.show(chain, tx, symbol, args[0].ToAddress, amount, procedure(allow: Boolean)
                            begin
                              if allow then
                                next(prompted + [TWarning.Other], nil)
                              else
                                block(prompted);
                            end, log);
                          end);
                      end);
                  end;
                end);
            end;
          end);
    end);
end;

procedure TChecks.Step6(const prompted: TPrompted; const next: TNext);
begin
  if tx.Value = 0 then
    next(prompted, nil)
  else begin
    const client: IWeb3 = TWeb3.Create(chain);
    client.LatestPrice(procedure(price: Double; err: IError)
    begin
      if (price = 0) or Assigned(err) then
        next(prompted, error.wrap(err, Self.Step6))
      else begin
        const amount = dotToFloat(fromWei(tx.Value, ether)) * price;
        if amount < common.LIMIT then
          next(prompted, nil)
        else
          thread.synchronize(procedure
          begin
            limit.show(chain, tx, chain.Symbol, tx.&To, amount, procedure(allow: Boolean)
            begin
              if allow then
                next(prompted + [TWarning.Other], nil)
              else
                block(prompted);
            end, log);
          end);
      end;
    end);
  end;
end;

procedure TChecks.Step7(const prompted: TPrompted; const next: TNext);
begin
  isPhisher(tx.&To, procedure(result: Boolean; err: IError)
  begin
    if Assigned(err) then
      next(prompted, error.wrap(err, Self.Step7))
    else if not result then
      next(prompted, nil)
    else
      thread.synchronize(procedure
      begin
        phisher.show(chain, tx, tx.&To, procedure(allow: Boolean)
        begin
          if allow then
            next(prompted + [TWarning.Other], nil)
          else
            block(prompted);
        end, log);
      end);
  end);
end;

procedure TChecks.Step8(const prompted: TPrompted; const next: TNext);
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(prompted, err) end)
    .&else(procedure(apiKey: string)
    begin
      getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
      begin
        if Assigned(err) then
        begin
          next(prompted, error.wrap(err, Self.Step8));
          EXIT;
        end;
        var step: TSubStep;
        step := procedure(const index: Integer; const prompted: TPrompted)
        begin
          if index >= Length(contracts) then
            next(prompted, nil)
          else
            web3.eth.alchemy.api.detect(apiKey, chain, contracts[index].Address, procedure(contractType: TContractType; err: IError)
            begin
              if Assigned(err) then
                next(prompted, error.wrap(err, Self.Step8))
              else case contractType of
                TContractType.Airdrop: // probably an unwarranted airdrop (most of the owners are honeypots)
                  thread.synchronize(procedure
                  begin
                    airdrop.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
                    begin
                      if allow then
                        step(index + 1, prompted + [TWarning.Other])
                      else
                        block(prompted);
                    end, log);
                  end);
                TContractType.Spam: // probably spam (contains duplicate NFTs, or lies about its own token supply)
                  thread.synchronize(procedure
                  begin
                    spam.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
                    begin
                      if allow then
                        step(index + 1, prompted + [TWarning.Other])
                      else
                        block(prompted);
                    end, log);
                  end);
              else
                step(index + 1, prompted);
              end;
            end);
        end;
        step(0, prompted);
      end);
    end);
end;

procedure TChecks.Step9(const prompted: TPrompted; const next: TNext);
begin
  tx.From
    .ifErr(procedure(err: IError) begin next(prompted, err) end)
    .&else(procedure(from: TAddress)
    begin
      common.Etherscan(chain)
        .ifErr(procedure(err: IError) begin next(prompted, err) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getTransactions(from, procedure(txs: ITransactions; err: IError)
          begin
            if Assigned(err) then
              next(prompted, error.wrap(err, Self.Step9))
            else if not Assigned(txs) then
              next(prompted, nil)
            else begin
              txs.FilterBy(tx.&To);
              if txs.Count > 0 then
                next(prompted, nil)
              else
                thread.synchronize(procedure
                begin
                  firsttime.show(chain, tx, tx.&To, procedure(allow: Boolean)
                  begin
                    if allow then
                      next(prompted + [TWarning.Other], nil)
                    else
                      block(prompted);
                  end, log);
                end);
            end;
          end);
        end);
    end);
end;

procedure TChecks.Step10(const prompted: TPrompted; const next: TNext);
begin
  web3.eth.tokenlists.unsupported(chain, procedure(tokens: TTokens; err: IError)
  begin
    if Assigned(err) then
    begin
      next(prompted, error.wrap(err, Self.Step10));
      EXIT;
    end;
    getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
    begin
      if Assigned(err) then
      begin
        next(prompted, error.wrap(err, Self.Step10));
        EXIT;
      end;
      var step: TSubStep;
      step := procedure(const index: Integer; const prompted: TPrompted)
      begin
        if index >= Length(contracts) then
          next(prompted, nil)
        else
          if tokens.IndexOf(contracts[index].Address) = -1 then
            step(index + 1, prompted)
          else
            thread.synchronize(procedure
            begin
              unsupported.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
              begin
                if allow then
                  step(index + 1, prompted + [TWarning.Other])
                else
                  block(prompted);
              end, log);
            end);
      end;
      step(0, prompted);
    end);
  end);
end;

procedure TChecks.Step11(const prompted: TPrompted; const next: TNext);
begin
  web3.eth.breadcrumbs.sanctioned({$I keys/breadcrumbs.api.key}, chain, tx.&To, procedure(value: Boolean; err: IError)
  begin
    if Assigned(err) then
      next(prompted, error.wrap(err, Self.Step11))
    else if not value then
      next(prompted, nil)
    else
      thread.synchronize(procedure
      begin
        sanctioned.show(chain, tx, tx.&To, procedure(allow: Boolean)
        begin
          if allow then
            next(prompted + [TWarning.Other], nil)
          else
            block(prompted);
        end, log);
      end);
  end);
end;

procedure TChecks.Step12(const prompted: TPrompted; const next: TNext);
begin
  getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
  begin
    if Assigned(err) then
    begin
      next(prompted, error.wrap(err, Self.Step12));
      EXIT;
    end;
    var step: TSubStep;
    step := procedure(const index: Integer; const prompted: TPrompted)
    begin
      if index >= Length(contracts) then
        next(prompted, nil)
      else (
        procedure(const token: TAddress; const callback: TProc<Integer, IError>)
        begin
          moralis.score({$I keys/moralis.api.key}, chain, token, procedure(score1: Integer; err1: IError)
          begin
            if (err1 = nil) or err1.Message.ToLower.Contains('address not found') then
              callback(score1, nil)
            else
              dextools.score({$I keys/dextools.api.key}, chain, token, procedure(score2: Integer; err2: IError)
              begin
                if Assigned(err2) and not err2.Message.ToLower.Contains('token not found') then
                  callback(0, err2)
                else
                  callback(score2, nil);
              end);
          end);
        end)(contracts[index].Address, procedure(score: Integer; err: IError)
        begin
          if Assigned(err) then
            next(prompted, error.wrap(err, Self.Step12))
          else
            if (score = 0) or (score >= 50) then
              step(index + 1, prompted)
            else
              thread.synchronize(procedure
              begin
                lowDexScore.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
                begin
                  if allow then
                    step(index + 1, prompted + [TWarning.Other])
                  else
                    block(prompted);
                end, log);
              end);
        end);
    end;
    step(0, prompted);
  end);
end;

procedure TChecks.Step13(const prompted: TPrompted; const next: TNext);
begin
  getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
  begin
    if Assigned(err) then
    begin
      next(prompted, error.wrap(err, Self.Step13));
      EXIT;
    end;
    var step: TSubStep;
    step := procedure(const index: Integer; const prompted: TPrompted)
    begin
      if index >= Length(contracts) then
        next(prompted, nil)
      else
        contracts[index].IsToken(procedure(isToken: Boolean; err: IError)
        begin
          if Assigned(err) then
            next(prompted, error.wrap(err, Self.Step13))
          else
            if not isToken then
              step(index + 1, prompted)
            else (
              procedure(const token: TAddress; const callback: TProc<TJsonArray, IError>)
              begin
                dextools.pairs({$I keys/dextools.api.key}, chain, token, procedure(arr: TJsonArray; err: IError)
                begin
                  if Assigned(arr) and not Assigned(err) then
                    callback(arr, nil)
                  else
                    moralis.pairs({$I keys/moralis.api.key}, chain, token, callback);
                end);
              end)(contracts[index].Address, procedure(arr: TJsonArray; err: IError)
              begin
                if Assigned(err) then
                  next(prompted, error.wrap(err, Self.Step13))
                else
                  if Assigned(arr) and (arr.Count > 0) then
                    step(index + 1, prompted)
                  else
                    thread.synchronize(procedure
                    begin
                      noDexPair.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
                      begin
                        if allow then
                          step(index + 1, prompted + [TWarning.Other])
                        else
                          block(prompted);
                      end, log);
                    end);
              end);
        end);
    end;
    step(0, prompted);
  end);
end;

procedure TChecks.Step14(const prompted: TPrompted; const next: TNext);
begin
  getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
  begin
    if Assigned(err) then
    begin
      next(prompted, error.wrap(err, Self.Step14));
      EXIT;
    end;
    var step: TSubStep;
    step := procedure(const index: Integer; const prompted: TPrompted)
    begin
      if index >= Length(contracts) then
        next(prompted, nil)
      else
        cache.getContractABI(chain, contracts[index].Address, procedure(abi: IContractABI; err: IError)
        begin
          if Assigned(err) then
            next(prompted, error.wrap(err, Self.Step14))
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
              thread.synchronize(procedure
              begin
                censorable.show(contracts[index].Action, chain, tx, contracts[index].Address, abi.IsERC20, procedure(allow: Boolean)
                begin
                  if allow then
                    step(index + 1, prompted + [TWarning.Other])
                  else
                    block(prompted);
                end, log);
              end)
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
                thread.synchronize(procedure
                begin
                  pausable.show(contracts[index].Action, chain, tx, contracts[index].Address, abi.IsERC20, procedure(allow: Boolean)
                  begin
                    if allow then
                      step(index + 1, prompted + [TWarning.Other])
                    else
                      block(prompted);
                  end, log);
                end)
              else
                step(index + 1, prompted);
        end);
    end;
    step(0, prompted);
  end);
end;

procedure TChecks.Step15(const prompted: TPrompted; const next: TNext);
{$I keys/tenderly.api.key}
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(prompted, err) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(err: IError) begin next(prompted, err) end)
        .&else(procedure(from: TAddress)
        begin
          web3.eth.simulate.honeypots(apiKey, TENDERLY_ACCOUNT_ID, TENDERLY_PROJECT_ID, TENDERLY_ACCESS_KEY, chain, from, tx.&To, tx.Value, web3.utils.toHex(tx.Data), procedure(honeypots: IAssetChanges; err: IError)
          begin
            if Assigned(err) then
              next(prompted, error.wrap(err, Self.Step15))
            else if (honeypots = nil) or (honeypots.Count = 0) then
              next(prompted, nil)
            else begin
              var step: TSubStep;
              step := procedure(const index: Integer; const prompted: TPrompted)
              begin
                if index >= honeypots.Count then
                  next(prompted, nil)
                else
                  thread.synchronize(procedure
                  begin
                    honeypot.show(chain, tx, honeypots.Item(index).Contract, from, procedure(allow: Boolean)
                    begin
                      if allow then
                        step(index + 1, prompted)
                      else
                        block(prompted);
                    end, log);
                  end);
              end;
              step(0, prompted);
            end;
          end);
        end);
    end);
end;

procedure TChecks.Step16(const prompted: TPrompted; const next: TNext);
begin
  getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
  begin
    if Assigned(err) then
      next(prompted, error.wrap(err, Self.Step16))
    else
      common.Etherscan(chain)
        .ifErr(procedure(err: IError)
        begin
          next(prompted, error.wrap(err, Self.Step16))
        end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          var step: TSubStep;
          step := procedure(const index: Integer; const prompted: TPrompted)
          begin
            if index >= Length(contracts) then
              next(prompted, nil)
            else
              etherscan.getLatestTransaction(contracts[index].Address, procedure(latest: ITransaction; err: IError)
              begin
                if Assigned(err) then
                  next(prompted, error.wrap(err, Self.Step16))
                else
                  if Assigned(latest) and (DaysBetween(System.SysUtils.Now, UnixToDateTime(latest.timeStamp, False)) < 30) then
                    step(index + 1, prompted)
                  else
                    contracts[index].IsToken(procedure(isERC20: Boolean; err: IError)
                    begin
                      thread.synchronize(procedure
                      begin
                        dormant.show(contracts[index].Action, chain, tx, contracts[index].Address, isERC20, procedure(allow: Boolean)
                        begin
                          if allow then
                            step(index + 1, prompted + [TWarning.Other])
                          else
                            block(prompted);
                        end, log);
                      end)
                    end)
              end);
          end;
          step(0, prompted);
        end);
  end);
end;

procedure TChecks.Step17(const prompted: TPrompted; const next: TNext);
begin
  getEachToken(server, port, chain, tx, procedure(const contracts: TArray<TContract>; const err: IError)
  begin
    if Assigned(err) then
    begin
      next(prompted, error.wrap(err, Self.Step17));
      EXIT;
    end;
    var step: TSubStep;
    step := procedure(const index: Integer; const prompted: TPrompted)
    begin
      if index >= Length(contracts) then
        next(prompted, nil)
      else
        contracts[index].IsToken(procedure(isToken: Boolean; err: IError)
        begin
          if Assigned(err) then
            next(prompted, error.wrap(err, Self.Step17))
          else
            if not isToken then
              step(index + 1, prompted)
            else
              dextools.unlock({$I keys/dextools.api.key}, chain, contracts[index].Address, procedure(dt: TDateTime; err: IError)
              begin
                if Assigned(err) then
                  next(prompted, error.wrap(err, Self.Step17))
                else
                  if (dt = 0) or (MonthsBetween(System.SysUtils.Now, dt) > 3) then
                    step(index + 1, prompted)
                  else
                    thread.synchronize(procedure
                    begin
                      unlock.show(contracts[index].Action, chain, tx, contracts[index].Address, procedure(allow: Boolean)
                      begin
                        if allow then
                          step(index + 1, prompted + [TWarning.Other])
                        else
                          block(prompted);
                      end, log);
                    end);
              end);
        end);
    end;
    step(0, prompted);
  end);
end;

procedure TChecks.Step18(const prompted: TPrompted; const next: TNext);
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(prompted, err) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(err: IError) begin next(prompted, err) end)
        .&else(procedure(from: TAddress)
        begin
          tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
          begin
            if Assigned(err) then
              next(prompted, error.wrap(err, Self.Step18))
            else if not Assigned(changes) then
              next(prompted, nil)
            else begin
              const approvals = (function(const changes: IAssetChanges): Integer
              begin
                Result := 0;
                for var I := 0 to Pred(changes.Count) do
                  if changes.Item(I).Change = TChangeType.Approve then Inc(Result);
              end)(changes);
              const transfers = (function(const changes: IAssetChanges): Integer
              begin
                Result := 0;
                for var I := 0 to Pred(changes.Count) do
                  if changes.Item(I).Change = TChangeType.Transfer then Inc(Result);
              end)(changes);
              var step: TSubStep;
              step := procedure(const index: Integer; const prompted: TPrompted)
              begin
                if index >= changes.Count then
                  next(prompted, nil)
                else
                  // ignore incoming transactions
                  if (changes.Item(index).Amount = 0) or not from.SameAs(changes.Item(index).From) then
                    step(index + 1, prompted)
                  else
                    // if we have prompted for this approval before in step 1
                    if ((changes.Item(index).Change = TChangeType.Approve) and (approvals = 1) and (TWarning.Approve in prompted))
                    // or we have prompted for this transfer before in step 2
                    or ((changes.Item(index).Change = TChangeType.Transfer) and (transfers = 1) and (TWarning.TransferOut in prompted)) then
                      step(index + 1, prompted)
                    else
                      thread.synchronize(procedure
                      begin
                        asset.show(chain, tx, changes.Item(index), procedure(allow: Boolean)
                        begin
                          if allow then
                            step(index + 1, prompted + [TWarning.Other])
                          else
                            block(prompted);
                        end, log);
                      end);
              end;
              step(0, prompted);
            end;
          end);
        end);
    end);
end;

procedure TChecks.Fail(const prompted: TPrompted; const next: TNext);
begin
  block(prompted);
end;

end.
