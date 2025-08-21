unit thebannedlist.xyz;

interface

uses
  // Delphi
  System.SysUtils, System.Types,
  // web3
  web3;

function isBlacklistedByUSDC(const address: TAddress; const callback: TProc<Boolean, IError>): IAsyncResult;
function isBlacklistedByUSDT(const address: TAddress; const callback: TProc<Boolean, IError>): IAsyncResult;

implementation

uses
  // Delphi
  System.JSON,
  // web3
  web3.graph, web3.json;

const
  INDEXER = 'https://indexer.dev.hyperindex.xyz/fe6684b/v1/graphql';

function isBlacklisted(const where: string; const address: TAddress; const callback: TProc<Boolean, IError>): IAsyncResult;
const
  QUERY = '{"query": "{User(where: {%s: {_eq: true}}){ id }}"}';
begin
  Result := web3.graph.execute(INDEXER, Format(QUERY, [where]), procedure(response: TJsonObject; err: IError)
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
end;

function isBlacklistedByUSDC(const address: TAddress; const callback: TProc<Boolean, IError>): IAsyncResult;
begin
  Result := isBlacklisted('isBlacklistedByUSDC', address, callback);
end;

function isBlacklistedByUSDT(const address: TAddress; const callback: TProc<Boolean, IError>): IAsyncResult;
begin
  Result := isBlacklisted('isBlacklistedByUSDT', address, callback);
end;

end.
