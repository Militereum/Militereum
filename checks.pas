unit checks;

interface

uses
  // Delphi
  System.SysUtils,
  // Indy
  IdGlobal,
  // web3
  web3,
  web3.eth.alchemy.api,
  // project
  server,
  transaction;

type
  TChecked = set of TChangeType;

type
  TNext = reference to procedure(const checked: TChecked; const err: IError = nil);

procedure Step1 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step2 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step3 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step4 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step5 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step6 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step7 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step8 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step9 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step10(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step11(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Step12(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
procedure Block (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TNext);

implementation

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.defillama,
  web3.eth.breadcrumbs,
  web3.eth.etherscan,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.utils,
  // project
  airdrop,
  asset,
  base,
  common,
  firsttime,
  honeypot,
  limit,
  sanctioned,
  setApprovalForAll,
  spam,
  thread,
  unsupported,
  unverified;

// approve(address,uint256)
procedure Step1(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0x095EA7B3') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(checked, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const value = (function(const args: TArray<TArg>): BigInteger
              begin
                if Length(args) > 1 then
                  Result := args[1].toUInt256
                else
                  Result := web3.Infinite;
              end)(args);
              if value = 0 then
                next(checked)
              else
                web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; err: IError)
                begin
                  if Assigned(err) then
                    next(checked, err)
                  else if not Assigned(token) then
                    next(checked)
                  else
                    thread.synchronize(procedure
                    begin
                      asset.approve(chain, token, args[0].ToAddress, value, procedure(allow: Boolean)
                      begin
                        if allow then
                          next(checked + [TChangeType.Approve])
                        else
                          block;
                      end);
                    end);
                end);
            end;
          end);
    end);
end;

// transfer(address,uint256)
procedure Step2(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(checked, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(checked)
              else
                server.apiKey(port)
                  .ifErr(procedure(err: IError) begin next(checked, err) end)
                  .&else(procedure(apiKey: string)
                  begin
                    tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
                    begin
                      if Assigned(err) then
                        next(checked, err)
                      else if not Assigned(changes) then
                        next(checked)
                      else begin
                        const index = changes.IndexOf(tx.&To);
                        if (index > -1) and (changes.Item(index).Amount > 0) then
                          thread.synchronize(procedure
                          begin
                            asset.show(chain, changes.Item(index), procedure(allow: Boolean)
                            begin
                              if allow then
                                next(checked + [TChangeType.Transfer])
                              else
                                block;
                            end);
                          end)
                        else
                          thread.synchronize(procedure
                          begin
                            honeypot.show(chain, tx.&To, args[0].ToAddress, procedure(allow: Boolean)
                            begin
                              if allow then
                                next(checked)
                              else
                                block;
                            end);
                          end);
                      end;
                    end);
                  end);
            end;
          end);
    end);
end;

// setApprovalForAll(address,bool)
procedure Step3(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA22CB465') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(checked, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const approved = (function(const args: TArray<TArg>): Boolean
              begin
                if Length(args) > 1 then
                  Result := args[1].toBoolean
                else
                  Result := False;
              end)(args);
              if not approved then
                next(checked)
              else
                thread.synchronize(procedure
                begin
                  setApprovalForAll.show(chain, tx.&To, args[0].ToAddress, procedure(allow: Boolean)
                  begin
                    if allow then
                      next(checked)
                    else
                      block;
                  end);
                end);
            end;
          end);
    end);
end;

// are we transacting with (a) smart contract and (b) not verified with etherscan?
procedure Step4(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) then
      next(checked, err)
    else if isEOA then
      next(checked)
    else
      common.Etherscan(chain)
        .ifErr(procedure(err: IError) begin next(checked, err) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getContractSourceCode(tx.&To, procedure(src: string; err: IError)
          begin
            if Assigned(err) then
              next(checked, err)
            else if src <> '' then
              next(checked)
            else
              thread.synchronize(procedure
              begin
                unverified.show(chain, tx.&To, procedure(allow: Boolean)
                begin
                  if allow then
                    next(checked)
                  else
                    block;
                end);
              end);
          end);
        end);
  end);
end;

// are we transferring more than $5k in ERC-20, translated to USD?
procedure Step5(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(err: IError) begin next(checked, err) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(checked)
              else
                web3.defillama.price(chain, tx.&To, procedure(price: Double; err: IError)
                begin
                  if Assigned(err) then
                    next(checked, err)
                  else if (price = 0) or (quantity.BitLength > 64) then
                    next(checked)
                  else begin
                    const amount = quantity.AsUInt64 * price;
                    if amount < common.LIMIT then
                      next(checked)
                    else
                      common.Symbol(chain, tx.&To, procedure(symbol: string; err: IError)
                      begin
                        if Assigned(err) then
                          next(checked, err)
                        else
                          thread.synchronize(procedure
                          begin
                            limit.show(chain, symbol, args[0].ToAddress, amount, procedure(allow: Boolean)
                            begin
                              if allow then
                                next(checked)
                              else
                                block;
                            end);
                          end);
                      end);
                  end;
                end);
            end;
          end);
    end);
end;

// are we sending more than $5k in ETH, translated to USD?
procedure Step6(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  if tx.Value = 0 then
    next(checked)
  else begin
    const client: IWeb3 = TWeb3.Create(chain);
    client.LatestPrice(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then
        next(checked, err)
      else if (price = 0) or (tx.Value.BitLength > 64) then
        next(checked)
      else begin
        const amount = tx.Value.AsUInt64 * price;
        if amount < common.LIMIT then
          next(checked)
        else
          thread.synchronize(procedure
          begin
            limit.show(chain, chain.Symbol, tx.&To, amount, procedure(allow: Boolean)
            begin
              if allow then
                next(checked)
              else
                block;
            end);
          end);
      end;
    end);
  end;
end;

// are we transacting with a spam contract or receiving spam tokens?
procedure Step7(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
type
  TDone    = reference to procedure(const err: IError);
  TForEach = reference to procedure(const action: TTokenAction; const contracts: TArray<TAddress>; const index: Integer; const done: TDone);
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(apiKey: string)
    begin
      var foreach: TForEach;
      foreach := procedure(const action: TTokenAction; const contracts: TArray<TAddress>; const index: Integer; const done: TDone)
      begin
        if index >= Length(contracts) then
          done(nil)
        else
          web3.eth.alchemy.api.detect(apiKey, chain, contracts[index], procedure(contractType: TContractType; err: IError)
          begin
            if Assigned(err) then
              done(err)
            else case contractType of
              TContractType.Airdrop: // probably an unwarranted airdrop (most of the owners are honeypots)
                thread.synchronize(procedure
                begin
                  airdrop.show(action, chain, contracts[index], procedure(allow: Boolean)
                  begin
                    if allow then
                      foreach(action, contracts, index + 1, done)
                    else
                      block;
                  end);
                end);
              TContractType.Spam: // probably spam (contains duplicate NFTs, or lies about its own token supply)
                thread.synchronize(procedure
                begin
                  spam.show(action, chain, contracts[index], procedure(allow: Boolean)
                  begin
                    if allow then
                      foreach(action, contracts, index + 1, done)
                    else
                      block;
                  end);
                end);
            else
              foreach(action, contracts, index + 1, done);
            end;
          end);
      end;

      const step1 = procedure(const done: TDone) // tx.To
      begin
        tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
        begin
          if Assigned(err) then
            done(err)
          else if isEOA then
            done(nil)
          else
            foreach(taTransact, [tx.&To], 0, done);
        end);
      end;

      const step2 = procedure(const done: TDone) // incoming tokens
      begin
        tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
        begin
          if Assigned(err) then
            done(err)
          else if not Assigned(changes) then
            done(nil)
          else
            tx.From
              .ifErr(procedure(err: IError) begin done(err) end)
              .&else(procedure(from: TAddress)
              begin
                foreach(taReceive, (function(const incoming: IAssetChanges): TArray<TAddress>
                begin
                  Result := [];
                  for var I := 0 to Pred(incoming.Count) do
                    if incoming.Item(I).Contract.SameAs(tx.&To) then
                      // ignore tx.To
                    else
                      Result := Result + [incoming.Item(I).Contract];
                end)(changes.Incoming(from)), 0, done);
              end);
        end);
      end;

      step1(procedure(const err: IError) begin if Assigned(err) then next(checked, err) else step2(procedure(const err: IError) begin next(checked, err) end) end);
    end);
end;

// have we transacted with this address before?
procedure Step8(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  tx.From
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(from: TAddress)
    begin
      common.Etherscan(chain)
        .ifErr(procedure(err: IError) begin next(checked, err) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getTransactions(from, procedure(txs: ITransactions; err: IError)
          begin
            if Assigned(err) then
              next(checked, err)
            else if not Assigned(txs) then
              next(checked)
            else begin
              txs.FilterBy(tx.&To);
              if txs.Count > 0 then
                next(checked)
              else
                thread.synchronize(procedure
                begin
                  firsttime.show(chain, tx.&To, procedure(allow: Boolean)
                  begin
                    if allow then
                      next(checked)
                    else
                      block;
                  end);
                end);
            end;
          end);
        end);
    end);
end;

// are we transacting with an unsupported contract or receiving unsupported tokens?
procedure Step9(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
type
  TDone    = reference to procedure(const err: IError);
  TForEach = reference to procedure(const action: TTokenAction; const contracts: TArray<TAddress>; const index: Integer; const done: TDone);
begin
  web3.eth.tokenlists.unsupported(chain, procedure(tokens: TTokens; err: IError)
  begin
    if Assigned(err) then
    begin
      next(checked, err);
      EXIT;
    end;

    var foreach: TForEach;
    foreach := procedure(const action: TTokenAction; const contracts: TArray<TAddress>; const index: Integer; const done: TDone)
    begin
      if index >= Length(contracts) then
        done(nil)
      else
        if tokens.IndexOf(contracts[index]) = -1 then
          foreach(action, contracts, index + 1, done)
        else
          thread.synchronize(procedure
          begin
            unsupported.show(action, chain, contracts[index], procedure(allow: Boolean)
            begin
              if allow then
                foreach(action, contracts, index + 1, done)
              else
                block;
            end);
          end);
    end;

    const step1 = procedure(const done: TDone) // tx.To
    begin
      tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
      begin
        if Assigned(err) or isEOA then
          done(err)
        else
          foreach(taTransact, [tx.&To], 0, done);
      end);
    end;

    const step2 = procedure(const done: TDone) // incoming tokens
    begin
      server.apiKey(port)
        .ifErr(procedure(err: IError) begin done(err) end)
        .&else(procedure(apiKey: string)
        begin
          tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
          begin
            if Assigned(err) or not Assigned(changes) then
              done(err)
            else
              tx.From
                .ifErr(procedure(err: IError) begin done(err) end)
                .&else(procedure(from: TAddress)
                begin
                  foreach(taReceive, (function(const incoming: IAssetChanges): TArray<TAddress>
                  begin
                    Result := [];
                    for var I := 0 to Pred(incoming.Count) do
                      if incoming.Item(I).Contract.SameAs(tx.&To) then
                        // ignore tx.To
                      else
                        Result := Result + [incoming.Item(I).Contract];
                  end)(changes.Incoming(from)), 0, done);
                end);
          end);
        end);
    end;

    step1(procedure(const err: IError) begin if Assigned(err) then next(checked, err) else step2(procedure(const err: IError) begin next(checked, err) end) end);
  end);
end;

// are we transacting with a sanctioned address?
procedure Step10(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  web3.eth.breadcrumbs.sanctioned({$I breadcrumbs.api.key}, chain, tx.&To, procedure(value: Boolean; err: IError)
  begin
    if Assigned(err) then
      next(checked, err)
    else if not value then
      next(checked)
    else
      thread.synchronize(procedure
      begin
        sanctioned.show(chain, tx.&To, procedure(allow: Boolean)
        begin
          if allow then
            next(checked)
          else
            block;
        end);
      end);
  end);
end;

// are we buying a honeypot token?
procedure Step11(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(err: IError) begin next(checked, err) end)
        .&else(procedure(from: TAddress)
        begin
          web3.eth.alchemy.api.honeypots(apiKey, chain, from, tx.&To, tx.Value, web3.utils.toHex(tx.Data), procedure(honeypots: IAssetChanges; err: IError)
          begin
            if Assigned(err) then
              next(checked, err)
            else if (honeypots = nil) or (honeypots.Count = 0) then
              next(checked)
            else begin
              var step: TProc<Integer, TProc>; // (index, done)
              step := procedure(index: Integer; done: TProc)
              begin
                if index >= honeypots.Count then
                  done
                else
                  thread.synchronize(procedure
                  begin
                    honeypot.show(chain, honeypots.Item(index).Contract, from, procedure(allow: Boolean)
                    begin
                      if allow then
                        step(index + 1, done)
                      else
                        block;
                    end);
                  end);
              end;
              step(0, procedure
              begin
                next(checked);
              end);
            end;
          end);
        end);
    end);
end;

// simulate transaction, prompt for each and every token (a) getting approved, or (b) leaving your wallet
procedure Step12(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  server.apiKey(port)
    .ifErr(procedure(err: IError) begin next(checked, err) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(err: IError) begin next(checked, err) end)
        .&else(procedure(from: TAddress)
        begin
          tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; err: IError)
          begin
            if Assigned(err) then
              next(checked, err)
            else if not Assigned(changes) then
              next(checked)
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
              var step: TProc<Integer, TProc>; // (index, done)
              step := procedure(index: Integer; done: TProc)
              begin
                if index >= changes.Count then
                  done
                else
                  // ignore incoming transactions
                  if (changes.Item(index).Amount = 0) or not from.SameAs(changes.Item(index).From) then
                    step(index + 1, done)
                  else
                    // if we have prompted for this approval before in step 1
                    if ((changes.Item(index).Change = TChangeType.Approve) and (approvals = 1) and (TChangeType.Approve in checked))
                    // or we have prompted for this transfer before in step 2
                    or ((changes.Item(index).Change = TChangeType.Transfer) and (transfers = 1) and (TChangeType.Transfer in checked)) then
                      step(index + 1, done)
                    else
                      thread.synchronize(procedure
                      begin
                        asset.show(chain, changes.Item(index), procedure(allow: Boolean)
                        begin
                          if allow then
                            step(index + 1, done)
                          else
                            block;
                        end);
                      end);
              end;
              step(0, procedure
              begin
                next(checked);
              end);
            end;
          end);
        end);
    end);
end;

// include this step if you want every transaction to fail (debug only)
procedure Block(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext);
begin
  block;
end;

end.
