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

procedure Step1 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step2 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step3 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step4 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step5 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step6 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step7 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step8 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step9 (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Step10(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
procedure Block (const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);

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
  common,
  firsttime,
  honeypot,
  limit,
  sanctioned,
  spam,
  thread,
  unverified;

// approve(address,uint256)
procedure Step1(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0x095EA7B3') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError) begin next(checked) end)
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
                web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; _: IError)
                begin
                  if not Assigned(token) then
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
procedure Step2(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError) begin next(checked) end)
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
                  .ifErr(procedure(_: IError) begin next(checked) end)
                  .&else(procedure(apiKey: string)
                  begin
                    tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
                    begin
                      if not Assigned(changes) then
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

// are we transacting with (a) smart contract and (b) not verified with etherscan?
procedure Step3(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) or isEOA then
      next(checked)
    else
      common.Etherscan(chain)
        .ifErr(procedure(_: IError) begin next(checked) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getContractSourceCode(tx.&To, procedure(src: string; _: IError)
          begin
            if src <> '' then
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
procedure Step4(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError) begin next(checked) end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(checked)
              else
                web3.defillama.price(chain, tx.&To, procedure(price: Double; _: IError)
                begin
                  if (price = 0) or (quantity.BitLength > 64) then
                    next(checked)
                  else begin
                    const amount = quantity.AsUInt64 * price;
                    if amount < common.LIMIT then
                      next(checked)
                    else
                      common.Symbol(chain, tx.&To, procedure(symbol: string; _: IError)
                      begin
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
procedure Step5(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  if tx.Value = 0 then
    next(checked)
  else begin
    const client: IWeb3 = TWeb3.Create(chain);
    client.LatestPrice(procedure(price: Double; _: IError)
    begin
      if (price = 0) or (tx.Value.BitLength > 64) then
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

// are we transacting with a spam contract, or receiving spam tokens?
procedure Step6(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
type
  TDetect = reference to procedure(const contracts: TArray<TAddress>; const index: Integer; const done: TProc);
begin
  server.apiKey(port)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(apiKey: string)
    begin
      var detect: TDetect;
      detect := procedure(const contracts: TArray<TAddress>; const index: Integer; const done: TProc)
      begin
        if index >= Length(contracts) then
          done
        else
          web3.eth.alchemy.api.detect(apiKey, chain, contracts[index], procedure(contractType: TContractType; _: IError)
          begin
            case contractType of
              TContractType.Airdrop: // probably an unwarranted airdrop (most of the owners are honeypots)
                thread.synchronize(procedure
                begin
                  airdrop.show(chain, tx.&To, procedure(allow: Boolean)
                  begin
                    if allow then
                      detect(contracts, index + 1, done)
                    else
                      block;
                  end);
                end);
              TContractType.Spam: // probably spam (contains duplicate NFTs, or lies about its own token supply)
                thread.synchronize(procedure
                begin
                  spam.show(chain, tx.&To, procedure(allow: Boolean)
                  begin
                    if allow then
                      detect(contracts, index + 1, done)
                    else
                      block;
                  end);
                end);
            else
              detect(contracts, index + 1, done);
            end;
          end);
      end;

      const step1 = procedure(const done: TProc) // tx.To
      begin
        tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
        begin
          if Assigned(err) or isEOA then
            done
          else
            detect([tx.&To], 0, procedure
            begin
              done;
            end);
        end);
      end;

      const step2 = procedure(const done: TProc) // incoming tokens
      begin
        tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
        begin
          if not Assigned(changes) then
            done
          else
            tx.From
              .ifErr(procedure(_: IError) begin done end)
              .&else(procedure(from: TAddress)
              begin
                detect((function(const incoming: IAssetChanges): TArray<TAddress>
                begin
                  Result := [];
                  for var I := 0 to Pred(incoming.Count) do
                    if incoming.Item(I).Contract.SameAs(tx.&To) then
                      // ignore tx.To
                    else
                      Result := Result + [incoming.Item(I).Contract];
                end)(changes.Incoming(from)), 0, procedure
                begin
                  done;
                end);
              end);
        end);
      end;

      step1(procedure begin step2(procedure begin next(checked) end) end);
    end);
end;

// have we transacted with this address before?
procedure Step7(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  tx.From
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(from: TAddress)
    begin
      common.Etherscan(chain)
        .ifErr(procedure(_: IError) begin next(checked) end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getTransactions(from, procedure(txs: ITransactions; _: IError)
          begin
            if not Assigned(txs) then
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

// are we transacting with a sanctioned address?
procedure Step8(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  web3.eth.breadcrumbs.sanctioned({$I breadcrumbs.api.key}, chain, tx.&To, procedure(value: Boolean; _: IError)
  begin
    if not value then
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
procedure Step9(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  server.apiKey(port)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(_: IError) begin next(checked) end)
        .&else(procedure(from: TAddress)
        begin
          web3.eth.alchemy.api.honeypots(apiKey, chain, from, tx.&To, tx.Value, web3.utils.toHex(tx.Data), procedure(honeypots: IAssetChanges; err: IError)
          begin
            if (err <> nil) or (honeypots = nil) or (honeypots.Count = 0) then
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

// simulate transaction
procedure Step10(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  server.apiKey(port)
    .ifErr(procedure(_: IError) begin next(checked) end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(_: IError) begin next(checked) end)
        .&else(procedure(from: TAddress)
        begin
          tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
          begin
            if not Assigned(changes) then
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
procedure Block(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  block;
end;

end.
