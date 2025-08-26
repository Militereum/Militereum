unit thebannedlist.xyz;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

procedure isBlacklistedByUSDC(const address: TAddress; const callback: TProc<Boolean, IError>);
procedure isBlacklistedByUSDT(const address: TAddress; const callback: TProc<Boolean, IError>);

implementation

uses
  // Delphi
  System.JSON,
  // web3
  web3.graph, web3.json,
  // project
  endpoints;

procedure isBlacklisted(const where: string; const address: TAddress; const callback: TProc<Boolean, IError>);
const
  QUERY = '{"query": "{User(where: {%s: {_eq: true}}){ id }}"}';
begin
  getEndpoint(ID_THE_BANNED_LIST, procedure(indexer: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;
    web3.graph.execute(indexer, Format(QUERY, [where]), procedure(response: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(False, err);
        EXIT;
      end;
      const data = web3.json.getPropAsObj(response, 'data');
      if not Assigned(data) then
      begin
        callback(False, TGraphError.Create('data does not exist'));
        EXIT;
      end;
      const user = web3.json.getPropAsArr(data, 'User');
      if not Assigned(user) then
      begin
        callback(False, TGraphError.Create('User does not exist'));
        EXIT;
      end;
      for var obj in user do
        if SameText(string(address), web3.json.getPropAsStr(obj, 'id')) then
        begin
          callback(True, nil);
          EXIT;
        end;
      callback(False, nil);
    end);
  end);
end;

procedure isBlacklistedByUSDC(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  isBlacklisted('isBlacklistedByUSDC', address, callback);
end;

procedure isBlacklistedByUSDT(const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  isBlacklisted('isBlacklistedByUSDT', address, callback);
end;

end.
