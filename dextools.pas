unit dextools;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // web3
  web3;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
procedure score(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Integer, IError>);

implementation

uses
  // Delphi
  System.DateUtils,
  System.Net.URLClient,
  // web3
  web3.http,
  web3.json;

const DEXTOOLS_API_BASE = 'https://open-api.dextools.io/free/';

function network(const chain: TChain): IResult<string>;
begin
  if chain = Arbitrum then
    Result := TResult<string>.Ok('arbitrum')
  else if chain = BNB then
    Result := TResult<string>.Ok('bsc')
  else if chain = Base then
    Result := TResult<string>.Ok('base')
  else if chain = Ethereum then
    Result := TResult<string>.Ok('ether')
  else if chain = Goerli then
    Result := TResult<string>.Ok('ethergoerli')
  else if chain = Fantom then
    Result := TResult<string>.Ok('fantom')
  else if chain = Gnosis then
    Result := TResult<string>.Ok('gnosis')
  else if chain = Optimism then
    Result := TResult<string>.Ok('optimism')
  else if chain = Polygon then
    Result := TResult<string>.Ok('polygon')
  else if chain = Pulsechain then
    Result := TResult<string>.Ok('pulse')
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

procedure pairs(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<TJsonArray, IError>);
begin
  network(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(network: string)
    begin
      web3.http.get(DEXTOOLS_API_BASE + Format('v2/token/%s/%s/pools?sort=creationTime&order=asc&from=2000-01-01&to=%4d-%2d-%2d', [network, address, YearOf(System.SysUtils.Now), MonthOf(System.SysUtils.Now), DayOf(System.SysUtils.Now)]), [TNetHeader.Create('X-BLOBR-KEY', apiKey)],
        procedure(response: TJsonValue; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, err);
            EXIT;
          end;
          const data = getPropAsObj(response, 'data');
          if not Assigned(data) then
          begin
            callback(nil, TError.Create('data is null'));
            EXIT;
          end;
          const results = getPropAsArr(data, 'results');
          if not Assigned(results) then
          begin
            callback(nil, TError.Create('results is null'));
            EXIT;
          end;
          callback(results, nil);
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
      web3.http.get(DEXTOOLS_API_BASE + Format('v2/token/%s/%s/score', [network, address]), [TNetHeader.Create('X-BLOBR-KEY', apiKey)],
        procedure(response: TJsonValue; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(0, err);
            EXIT;
          end;
          const data = getPropAsObj(response, 'data');
          if not Assigned(data) then
          begin
            callback(0, TError.Create('data is null'));
            EXIT;
          end;
          const score = getPropAsObj(data, 'dextScore');
          if not Assigned(score) then
          begin
            callback(0, TError.Create('dextScore is null'));
            EXIT;
          end;
          callback(getPropAsInt(score, 'total'), nil);
        end);
    end);
end;

end.
