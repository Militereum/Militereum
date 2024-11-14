unit coingecko;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

type
  ICoin = interface
    function Id: string;
    function Symbol: string;
    function Address(const chain: TChain): IResult<TAddress>;
    function Score: Double;
  end;

procedure getCoinId(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
procedure getCoin(const Id: string; const callback: TProc<ICoin, IError>);

implementation

uses
  // Delphi
  System.JSON, System.Net.URLClient,
  // web3
  web3.http, web3.eth.types, web3.json;

const COINGECKO_API_BASE = 'https://api.coingecko.com/api/v3/';

function headers: TNetHeaders;
begin
  Result := [TNetHeader.Create('accept', 'application/json'), TNetHeader.Create('x-cg-demo-api-key', {$I keys/coingecko.api.key})];
end;

type
  IPlatforms = interface
    function Arbitrum: TAddress;
    function Base: TAddress;
    function BinanceSmartChain: TAddress;
    function Ethereum: TAddress;
    function Fantom: TAddress;
    function Optimism: TAddress;
    function Polygon: TAddress;
  end;

  TPlatforms = class(TDeserialized, IPlatforms)
    function Arbitrum: TAddress;
    function Base: TAddress;
    function BinanceSmartChain: TAddress;
    function Ethereum: TAddress;
    function Fantom: TAddress;
    function Optimism: TAddress;
    function Polygon: TAddress;
  end;

  function TPlatforms.Arbitrum: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'arbitrum-one'));
  end;

  function TPlatforms.Base: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'base'));
  end;

  function TPlatforms.BinanceSmartChain: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'binance-smart-chain'));
  end;

  function TPlatforms.Ethereum: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'ethereum'));
  end;

  function TPlatforms.Fantom: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'fantom'));
  end;

  function TPlatforms.Optimism: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'optimistic-ethereum'));
  end;

  function TPlatforms.Polygon: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'polygon-pos'));
  end;

type
  TCoin = class(TDeserialized, ICoin)
  public
    function Id: string;
    function Symbol: string;
    function Platforms: IPlatforms;
    function Address(const chain: TChain): IResult<TAddress>;
    function Score: Double;
  end;

  function TCoin.Id: string;
  begin
    Result := getPropAsStr(FJsonValue, 'id');
  end;

  function TCoin.Symbol: string;
  begin
    Result := getPropAsStr(FJsonValue, 'symbol');
  end;

  function TCoin.Platforms: IPlatforms;
  begin
    Result := TPlatforms.Create(getPropAsObj(FJsonValue, 'platforms'));
  end;

  function TCoin.Address(const chain: TChain): IResult<TAddress>;
  begin
    if chain = Arbitrum then
      Result := TResult<TAddress>.Ok(Platforms.Arbitrum)
    else if chain = Base then
      Result := TResult<TAddress>.Ok(Platforms.Base)
    else if chain = BNB then
      Result := TResult<TAddress>.Ok(Platforms.BinanceSmartChain)
    else if chain = Ethereum then
      Result := TResult<TAddress>.Ok(Platforms.Ethereum)
    else if chain = Fantom then
      Result := TResult<TAddress>.Ok(Platforms.Fantom)
    else if chain = Optimism then
      Result := TResult<TAddress>.Ok(Platforms.Optimism)
    else if chain = Polygon then
      Result := TResult<TAddress>.Ok(Platforms.Polygon)
    else
      Result := TResult<TAddress>.Err(TError.Create('%s not supported', [chain.Name]));
  end;

  function TCoin.Score: Double;
  begin
    Result := getPropAsDouble(FJsonValue, 'sentiment_votes_up_percentage');
  end;

var cache: TArray<ICoin> = [];

procedure coins(const callback: TProc<TArray<ICoin>, IError>);
begin
  if Length(cache) > 0 then
  begin
    callback(cache, nil);
    EXIT;
  end;
  web3.http.get(COINGECKO_API_BASE + 'coins/list?include_platform=true', headers, procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback([], err);
      EXIT;
    end;
    if not(response is TJsonArray) then
    begin
      callback([], TError.Create('response is not an array'));
      EXIT;
    end;
    try
      for var coin in (response as TJsonArray) do cache := cache + [TCoin.Create(coin)];
    finally
      callback(cache, nil);
    end;
  end);
end;

procedure getCoinId(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
begin
  coins(procedure(coins: TArray<ICoin>; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    for var coin in coins do coin.Address(chain).ifOk(procedure(address: TAddress)
    begin
      if address.SameAs(token) then
      begin
        callback(coin.Id, nil);
        EXIT;
      end;
    end);
    callback('', TError.Create('token %s does not exist on %s', [token, chain.Name]));
  end);
end;

procedure getCoin(const Id: string; const callback: TProc<ICoin, IError>);
begin
  web3.http.get(COINGECKO_API_BASE + 'coins/' + Id, headers, procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TCoin.Create(response), nil);
  end);
end;

end.
