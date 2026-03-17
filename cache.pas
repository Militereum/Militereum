unit cache;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3, web3.eth.etherscan;

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);
procedure getSymbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
procedure getFriendlyName(const chain: TChain; const address: TAddress; const callback: TProc<string, IError>);
procedure fromName(const name: string; const callback: TProc<TAddress, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  // project
  common, thread,
  // web3
  web3.eth.erc20, web3.eth.types;

{----------------------------- TLockableArray<T> ------------------------------}

type
  TLockableArray<T> = class
  strict private
    FArray: TArray<T>;
    function GetItem(Index: Integer): T; inline;
  public
    procedure Add(const Value: T); inline;
    function Length: Integer; inline;
    property Items[Index: Integer]: T read GetItem; default;
  end;

procedure TLockableArray<T>.Add(const Value: T);
begin
  FArray := FArray + [Value];
end;

function TLockableArray<T>.GetItem(Index: Integer): T;
begin
  Result := FArray[Index];
end;

function TLockableArray<T>.Length: Integer;
begin
  Result := System.Length(FArray);
end;

{------------------------ getContractABI: TContractABI ------------------------}

type
  TContractABI = record
  strict private
    FChain     : TChain;
    FContract  : TAddress;
    FContractABI: IContractABI;
  public
    constructor Create(const aChain: TChain; const aContract: TAddress; const aContractABI: IContractABI);
    property Chain: TChain read FChain;
    property Contract: TAddress read FContract;
    property ContractABI: IContractABI read FContractABI;
  end;

constructor TContractABI.Create(const aChain: TChain; const aContract: TAddress; const aContractABI: IContractABI);
begin
  Self.FChain       := aChain;
  Self.FContract    := aContract;
  Self.FContractABI := aContractABI;
end;

var contractABIs: TLockableArray<TContractABI> = nil;

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);
begin
  const abi = thread.TLock.get<IContractABI>(contractABIs, function: IContractABI
  begin
    for var I := 0 to contractABIs.Length - 1 do
      if (contractABIs[I].Chain = chain) and contractABIs[I].Contract.SameAs(contract) then
      begin
        Result := contractABIs[I].ContractABI;
        EXIT;
      end;
    Result := nil;
  end);
  if Assigned(abi) then
  begin
    callback(abi, nil);
    EXIT;
  end;
  web3.eth.etherscan.getContractABI(common.Etherscan(chain), contract, procedure(abi: IContractABI; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    thread.Lock(contractABIs, procedure
    begin
      contractABIs.Add(TContractABI.Create(chain, contract, abi));
    end);
    callback(abi, err);
  end);
end;

{----------------------------- getSymbol: TSymbol -----------------------------}

type
  TSymbol = record
  strict private
    FChain : TChain;
    FToken : TAddress;
    FSymbol: string;
  public
    constructor Create(const aChain: TChain; const aToken: TAddress; const aSymbol: string);
    property Chain: TChain read FChain;
    property Token: TAddress read FToken;
    property Symbol: string read FSymbol;
  end;

constructor TSymbol.Create(const aChain: TChain; const aToken: TAddress; const aSymbol: string);
begin
  Self.FChain  := aChain;
  Self.FToken  := aToken;
  Self.FSymbol := aSymbol;
end;

var symbols: TLockableArray<TSymbol> = nil;

procedure getSymbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
begin
  const symbol = thread.TLock.get<string>(symbols, function: string
  begin
    for var I := 0 to symbols.Length - 1 do
      if (symbols[I].Chain = chain) and symbols[I].Token.SameAs(token) then
      begin
        Result := symbols[I].Symbol;
        EXIT;
      end;
    Result := '';
  end);
  if symbol <> '' then
  begin
    callback(symbol, nil);
    EXIT;
  end;
  web3.eth.erc20.create(TWeb3.Create(chain), token).Symbol(procedure(symbol: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    thread.Lock(symbols, procedure
    begin
      symbols.Add(TSymbol.Create(chain, token, symbol));
    end);
    callback(symbol, err);
  end);
end;

{------------------------- getFriendlyName & fromName -------------------------}

var friendly: TDictionary<TAddress, string> = nil;

procedure getFriendlyName(const chain: TChain; const address: TAddress; const callback: TProc<string, IError>);
begin
  var value: string;

  if thread.TLock.get<Boolean>(friendly, function: Boolean
  begin
    Result := friendly.TryGetValue(address, value)
  end) then
  begin
    callback(value, nil);
    EXIT;
  end;

  getContractABI(chain, address, procedure(abi: IContractABI; err: IError)
  begin
    if Assigned(abi) and abi.IsERC20 and not Assigned(err) then
    begin
      web3.eth.erc20.create(TWeb3.Create(chain), address).Name(procedure(name: string; err: IError)
      begin
        getSymbol(chain, address, procedure(symbol: string; err: IError)
        begin
          if (name <> '') and (symbol <> '') then
          begin
            value := System.SysUtils.Format('%s (%s)', [name, symbol]);
            thread.lock(friendly, procedure begin friendly.Add(address, value) end);
            callback(value, err);
            EXIT;
          end;
          callback(string(address), err);
        end);
      end);
      EXIT;
    end;
    address.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
    begin
      if (ens <> '') and not Assigned(err) then
      begin
        thread.lock(friendly, procedure begin friendly.Add(address, ens) end);
        callback(ens, err);
        EXIT;
      end;
      callback(string(address), err);
    end);
  end);
end;

procedure fromName(const name: string; const callback: TProc<TAddress, IError>);
begin
  const key = thread.TLock.get<TAddress>(friendly, function: TAddress
  begin
    for var pair in friendly do if pair.Value = name then
    begin
      Result := pair.Key;
      EXIT;
    end;
    Result := TAddress.Zero;
  end);
  if not key.IsZero then
  begin
    callback(key, nil);
    EXIT;
  end;
  TAddress.FromName(TWeb3.Create(common.Ethereum), name, callback);
end;

initialization
  contractABIs := TLockableArray<TContractABI>.Create;
  symbols      := TLockableArray<TSymbol>.Create;
  friendly     := TDictionary<TAddress, string>.Create;

finalization
  if Assigned(friendly)     then friendly.Free;
  if Assigned(symbols)      then symbols.Free;
  if Assigned(contractABIs) then contractABIs.Free;

end.
