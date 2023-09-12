unit dextools;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3;

function token(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonValue, IError>): IAsyncResult;
function pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>): IAsyncResult;
function score(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>): IAsyncResult;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.Math,
  System.Net.URLClient,
  // web3
  web3.eth.types,
  web3.http,
  web3.json;

function network(chain: TChain): string; inline;
begin
  if chain = Ethereum then
    Result := 'ether'
  else if chain = Arbitrum then
    Result := 'arbitrum'
  else if chain = BNB then
    Result := 'bsc'
  else if chain = Base then
    Result := 'base'
  else
    Result := '';
end;

// get dextools' token information for given token address
function token(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonValue, IError>): IAsyncResult;
begin
  Result := nil;
  const network = network(chain);
  if network = '' then
    callback(nil, TError.Create('%s not supported', [chain.Name]))
  else
    Result := web3.http.get(
      Format('https://api.dextools.io/v1/token?chain=%s&address=%s', [network, address.ToChecksum]), [
        TNetHeader.Create('Accept', 'application/json'),
        TNetHeader.Create('X-API-Key', apiKey)
      ], callback
    );
end;

// get DEX token pairs for given token address
function pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>): IAsyncResult;
begin
  Result := token(apiKey, chain, address, procedure(obj: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const data = getPropAsObj(obj, 'data');
    if not Assigned(data) then
    begin
      callback(nil, TError.Create('data is null'));
      EXIT;
    end;
    const pairs = getPropAsArr(data, 'pairs');
    if Assigned(pairs) then
      callback(pairs, nil)
    else
      callback(nil, TError.Create('pairs is null'));
  end);
end;

// returns the lowest %address%-WETH score where %address% is the token address
function score(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>): IAsyncResult;
begin
  Result := nil;
  if chain.WETH = '' then
    callback(0, TError.Create('%s not supported', [chain.Name]))
  else
    Result := pairs(apiKey, chain, address, procedure(pairs: TJsonArray; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      var score := 0;
      try
        for var I := 0 to Pred(pairs.Count) do
          if TAddress(getPropAsStr(getPropAsObj(pairs[I], 'tokenRef'), 'address')).SameAs(chain.WETH) then
            if score = 0 then
              score := getPropAsInt(pairs[I], 'dextScore')
            else
              score := Min(score, getPropAsInt(pairs[I], 'dextScore'));
      finally
        callback(score, nil);
      end;
    end);
end;

end.
