unit mobula;

interface

uses
  // Delphi
  System.DateUtils, System.SysUtils,
  // web3
  web3;

procedure unlock(const apiKey: string; const chain: TChain; const address: TAddress; const now: TDateTime; const callback: TProc<TDateTime, IError>);

implementation

uses
  // Delphi
  System.JSON, System.Net.URLClient,
  // web3
  web3.http, web3.json;

const MOBULA_API_BASE = 'https://api.mobula.io/api/1/';

procedure blockchain(const apiKey: string; const chain: TChain; const callback: TProc<string, IError>);
begin
  web3.http.get(MOBULA_API_BASE + 'blockchains', [TNetHeader.Create('Authorization', apiKey)], procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    const data = getPropAsArr(response, 'data');
    if not Assigned(data) then
    begin
      callback('', TError.Create('data is null'));
      EXIT;
    end;
    for var blockchain in data do
      if getPropAsStr(blockchain, 'chainId') = IntToStr(chain.Id) then
      begin
        callback(getPropAsStr(blockchain, 'name'), nil);
        EXIT;
      end;
    callback('', TError.Create('blockchain %d does not exist', [chain.Id]));
  end);
end;

procedure unlock(const apiKey: string; const chain: TChain; const address: TAddress; const now: TDateTime; const callback: TProc<TDateTime, IError>);
begin
  blockchain(apiKey, chain, procedure(blockchain: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    web3.http.get(MOBULA_API_BASE + Format('metadata?asset=%s&blockchain=%s', [address, blockchain]), [TNetHeader.Create('Authorization', apiKey)], procedure(response: TJsonValue; err: IError)
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
      const schedule = getPropAsArr(data, 'release_schedule');
      if Assigned(schedule) then for var unlock in schedule do
      begin
        const date = getPropAsUInt64(unlock, 'unlock_date');
        if date > 0 then
        begin
          const &then = UnixToDateTime(date div 1000, False);
          if &then > now then
          begin
            callback(&then, nil);
            EXIT;
          end;
        end;
      end;
      callback(0, nil);
    end);
  end);
end;

end.
