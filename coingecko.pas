unit coingecko;

interface

implementation

uses
  // Delphi
  System.Net.URLClient,
  // web3
  web3;

const COINGECKO_API_BASE = 'https://api.coingecko.com/api/v3/';

function network(const chain: TChain): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok('ethereum')
  else if chain = BNB then
    Result := TResult<string>.Ok('binance-smart-chain')
  else if chain = Polygon then
    Result := TResult<string>.Ok('polygon-pos')
  else if chain = Fantom then
    Result := TResult<string>.Ok('fantom')
  else if chain = Arbitrum then
    Result := TResult<string>.Ok('arbitrum-one')
  else if chain = Optimism then
    Result := TResult<string>.Ok('optimism')
  else if chain = Gnosis then
    Result := TResult<string>.Ok('xdai')
  else if chain = Base then
    Result := TResult<string>.Ok('base')
  else
    Result := TResult<string>.Err(TError.Create('%s not supported', [chain.Name]));
end;function headers: TNetHeaders;begin  Result := [TNetHeader.Create('accept', 'application/json'), TNetHeader.Create('x-cg-demo-api-key', {$I keys/coingecko.api.key})];
end;

end.
