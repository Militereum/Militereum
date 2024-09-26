unit moralis;

interface

uses
  // Delphi
  System.JSON, System.SysUtils,
  // web3
  web3;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
procedure isPossibleSpam(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);
procedure securityScore(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections, System.Net.URLClient,
  // web3
  web3.http, web3.json;

const MORALIS_API_BASE = 'https://deep-index.moralis.io/api/v2.2/';

function network(const chain: TChain): string; inline;
begin
  Result := '0x' + IntToHex(chain.Id, 0);
end;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
type
  TDEX  = string;
  TDEXs = TArray<TDEX>;
  TDone = reference to procedure(const arr: TJsonArray);
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
  var next: TStep;
  next := procedure(const DEXs: TDEXs; const index: Integer; const result: TJsonArray; const done: TDone)
  begin
    if index >= Length(DEXs) then
      done(result)
    else
      web3.http.get(MORALIS_API_BASE + Format('%s/%s/pairAddress?chain=%s&exchange=%s', [address, chain.WETH, network(chain), DEXs[index]]), [TNetHeader.Create('X-API-KEY', apiKey)],
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
  next(['uniswapv2', 'uniswapv3', 'sushiswapv2', 'pancakeswapv1', 'pancakeswapv2', 'quickswap'], 0, TJsonArray.Create, procedure(const result: TJsonArray)
  begin
    callback(result, nil);
    result.Free;
  end);
end;

procedure metadata(const apiKey: string; const chain: TChain; const address: TAddress; const NFT: Boolean; const callback: TProc<TJsonValue, IError>);
begin
  if NFT then
    web3.http.get(MORALIS_API_BASE + Format('nft/%s/1?chain=%s&format=decimal', [address, network(chain)]), [TNetHeader.Create('X-API-KEY', apiKey)],
      procedure(response: TJsonValue; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          if Assigned(response) then
            callback(response, nil)
          else
            callback(nil, TError.Create('response is null'));
      end)
  else
    web3.http.get(MORALIS_API_BASE + Format('erc20/metadata?chain=%s&addresses[0]=%s', [network(chain), address]), [TNetHeader.Create('X-API-KEY', apiKey)],
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
end;

procedure isPossibleSpam(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  metadata(apiKey, chain, address, True, procedure(resp1: TJsonValue; err1: IError)
  begin
    if Assigned(resp1) and not Assigned(err1) then
      callback(getPropAsBool(resp1, 'possible_spam'), nil)
    else
      metadata(apiKey, chain, address, False, procedure(resp2: TJsonValue; err2: IError)
      begin
        if Assigned(resp2) and not Assigned(err2) then
          callback(getPropAsBool(resp2, 'possible_spam'), nil)
        else
          callback(False, err2);
      end);
  end);
end;

procedure securityScore(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>);
begin
  metadata(apiKey, chain, address, False, procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(response) and not Assigned(err) then
      callback(getPropAsInt(response, 'security_score'), nil)
    else
      callback(0, err);
  end);
end;

end.
