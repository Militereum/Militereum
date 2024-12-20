unit revoke.cash;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

type
  IExploit = interface
    function Name: string;
    function Description: string;
    function Date: string;
    function URL(const chain: TChain): string;
  end;

// is this address a known crypto exploit that abuses token approvals in order to steal funds from users?
procedure exploit(const chain: TChain; const address: TAddress; const callback: TProc<IExploit, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections, System.JSON,
  // web3
  web3.http, web3.json;

type
  TExploit = class(TDeserialized, IExploit)
  public
    function Name: string;
    function Description: string;
    function Date: string;
    function URL(const chain: TChain): string;
  end;

  function TExploit.Name: string;
  begin
    Result := getPropAsStr(FJsonValue, 'name');
  end;

  function TExploit.Description: string;
  begin
    Result := getPropAsStr(FJsonValue, 'description');
  end;

  function TExploit.Date: string;
  begin
    Result := getPropAsStr(FJsonValue, 'date');
  end;

  function TExploit.URL(const chain: TChain): string;
  begin
    Result := Format('https://revoke.cash/exploits/%s?chainId=%d', [Self.Name, chain.Id]);
  end;

procedure exploit(const chain: TChain; const address: TAddress; const callback: TProc<IExploit, IError>);
begin
  get('https://raw.githubusercontent.com/RevokeCash/approval-exploit-list/refs/heads/main/index.json', [], procedure(resp1: TJsonValue; err1: IError)
  begin
    if Assigned(err1) then
    begin
      callback(nil, err1);
      EXIT;
    end;
    if not(resp1 is TJsonArray) then
    begin
      callback(nil, TError.Create('not a JSON array'));
      EXIT;
    end;
    var step: TProc<TJsonArray, Integer, TProc<TJsonArray>>;
    step := procedure(arr: TJsonArray; idx: Integer; done: TProc<TJsonArray>)
    begin
      if idx >= arr.Count then
      begin
        callback(nil, nil);
        done(arr);
        EXIT;
      end;
      const name = arr[idx];
      if not(name is TJsonString) then
      begin
        callback(nil, TError.Create('not a JSON string'));
        done(arr);
        EXIT;
      end;
      get(Format('https://raw.githubusercontent.com/RevokeCash/approval-exploit-list/refs/heads/main/exploits/%s.json', [(name as TJsonString).Value]), [], procedure(resp2: TJsonValue; err2: IError)
      begin
        if Assigned(err2) then
        begin
          callback(nil, err2);
          done(arr);
          EXIT;
        end;
        const addresses = getPropAsArr(resp2, 'addresses');
        if not Assigned(addresses) then
        begin
          callback(nil, TError.Create('not a JSON array'));
          done(arr);
          EXIT;
        end;
        for var I := 0 to Pred(addresses.Count) do
          if (getPropAsUInt64(addresses[I], 'chainId') = chain.Id) and SameText(getPropAsStr(addresses[I], 'address'), string(address)) then
          begin
            callback(TExploit.Create(addresses[I]), nil);
            done(arr);
            EXIT;
          end;
        step(arr, idx + 1, done);
      end);
    end;
    step((resp1 as TJsonArray).Clone as TJsonArray, 0, procedure(arr: TJsonArray) begin arr.Free end);
  end);
end;

end.
