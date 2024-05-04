unit moralis;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // web3
  web3;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
procedure score(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>);
procedure isPossibleSpam(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.Net.URLClient,
  // web3
  web3.http,
  web3.json;

const MORALIS_API_BASE = 'https://deep-index.moralis.io/api/v2.2/';

function network(const chain: TChain): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok('eth')
  else if chain = Optimism then
    Result := TResult<string>.Ok('oeth')
  else if chain = BNB then
    Result := TResult<string>.Ok('bnb')
  else if chain = Gnosis then
    Result := TResult<string>.Ok('gno')
  else if chain = Polygon then
    Result := TResult<string>.Ok('matic')
  else if chain = Fantom then
    Result := TResult<string>.Ok('ftm')
  else if chain = Base then
    Result := TResult<string>.Ok('base')
  else if chain = Holesky then
    Result := TResult<string>.Ok('holesky')
  else if chain = Arbitrum then
    Result := TResult<string>.Ok('arb1')
  else if chain = Sepolia then
    Result := TResult<string>.Ok('sep')
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
type
  TDEX  = string;
  TDEXs = array of TDEX;
  TDone = TProc<TJsonArray>;
  TStep = reference to procedure(const DEXs: TDEXs; const index: Integer; const result: TJsonArray; const done: TDone);
begin
  if chain.WETH = '' then
  begin
    const empty = web3.json.unmarshal('[]') as TJsonArray;
    try
      callback(empty, nil);
    finally
      empty.Free;
    end;
    EXIT;
  end;
  network(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(network: string)
    begin
      var next: TStep;
      next := procedure(const DEXs: TDEXs; const index: Integer; const result: TJsonArray; const done: TDone)
      begin
        if index >= Length(DEXs) then
          done(result)
        else
          web3.http.get(MORALIS_API_BASE + Format('%s/%s/pairAddress?chain=%s&exchange=%s', [address, chain.WETH, network, DEXs[index]]), [TNetHeader.Create('X-API-KEY', apiKey)],
            procedure(response: TJsonValue; err: IError)
            begin
              if Assigned(err) and not err.Message.ToLower.Contains('no pairs found') then
              begin
                callback(nil, err);
                EXIT;
              end;
              if getPropAsStr(response, 'pairAddress') <> '' then result.AddElement(TJsonString.Create(getPropAsStr(response, 'pairAddress')));
              next(DEXs, index + 1, result, done);
            end);
      end;
      next(['uniswapv2', 'uniswapv3', 'sushiswapv2', 'pancakeswapv1', 'pancakeswapv2'], 0, TJsonArray.Create, procedure(result: TJsonArray)
      begin
        callback(result, nil);
        result.Free;
      end);
    end);
end;

procedure score(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>);
begin
  network(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(network: string)
    begin
      web3.http.get(MORALIS_API_BASE + Format('discovery/token?chain=%s&token_address=%s', [network, address]), [TNetHeader.Create('X-API-KEY', apiKey)],
        procedure(response: TJsonValue; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            callback(getPropAsInt(response, 'security_score'), nil);
        end);
    end);
end;

procedure metadata(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonValue, IError>);
begin
  network(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(network: string)
    begin
      web3.http.get(MORALIS_API_BASE + Format('nft/%s/metadata?chain=eth', [address, network]), [TNetHeader.Create('X-API-KEY', apiKey)],
        procedure(response: TJsonValue; err: IError)
        begin
          if (err = nil) and Assigned(response) then
            callback(response, nil)
          else
            web3.http.get(MORALIS_API_BASE + Format('erc20/metadata?chain=%s&addresses=%s', [network, address]), [TNetHeader.Create('X-API-KEY', apiKey)],
              procedure(response: TJsonValue; err: IError)
              begin
                if Assigned(err) then
                  callback(nil, err)
                else
                  if Assigned(response) and (response is TJsonArray) and (TJsonArray(response).Count > 0) then
                    callback(TJsonArray(response).Items[0], nil)
                  else
                    callback(nil, TError.Create('response is null or not an array or an empty array'));
              end);
        end);
    end);
end;

procedure isPossibleSpam(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  metadata(apiKey, chain, address, procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
      callback(False, err)
    else if not Assigned(response) then
      callback(False, TError.Create('response is null'))
    else
      callback(getPropAsBool(response, 'possible_spam'), nil);
  end);
end;

end.
