unit cache;

interface

uses
  // Delphi
  SysUtils,
  // web3
  web3,
  web3.eth.etherscan;

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);
procedure getSymbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
procedure getFriendlyName(const chain: TChain; const address: TAddress; const callback: TProc<string, IError>);
procedure fromName(const name: string; const callback: TProc<TAddress, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  // project
  common,
  // web3
  web3.eth.erc20,
  web3.eth.types;

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

var contractABIs: TArray<TContractABI> = [];

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);
begin
  for var I := 0 to High(contractABIs) do
    if (contractABIs[I].Chain = chain) and contractABIs[I].Contract.SameAs(contract) then
    begin
      callback(contractABIs[I].ContractABI, nil);
      EXIT;
    end;
  common.Etherscan(chain).getContractABI(contract, procedure(abi: IContractABI; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    contractABIs := contractABIs + [TContractABI.Create(chain, contract, abi)];
    callback(abi, err);
  end);
end;

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

var symbols: TArray<TSymbol> = [];

procedure getSymbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
begin
  for var I := 0 to High(symbols) do
    if (symbols[I].Chain = chain) and symbols[I].Token.SameAs(token) then
    begin
      callback(symbols[I].Symbol, nil);
      EXIT;
    end;
  web3.eth.erc20.create(TWeb3.Create(chain), token).Symbol(procedure(symbol: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    symbols := symbols + [TSymbol.Create(chain, token, symbol)];
    callback(symbol, err);
  end);
end;

var friendly: TDictionary<TAddress, string> = nil;

procedure getFriendlyName(const chain: TChain; const address: TAddress; const callback: TProc<string, IError>);
begin
  var value: string;
  if friendly.TryGetValue(address, value) then
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
            friendly.Add(address, value);
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
        friendly.Add(address, ens);
        callback(ens, err);
        EXIT;
      end;
      callback(string(address), err);
    end);
  end);
end;

procedure fromName(const name: string; const callback: TProc<TAddress, IError>);
begin
  for var pair in friendly do if pair.Value = name then
  begin
    callback(pair.Key, nil);
    EXIT;
  end;
  TAddress.FromName(TWeb3.Create(common.Ethereum), name, callback);
end;

initialization
  friendly := TDictionary<TAddress, string>.Create;

finalization
  if Assigned(friendly) then friendly.Free;


end.
