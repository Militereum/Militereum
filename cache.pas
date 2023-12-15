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

implementation

uses
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
  common.Etherscan(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err);
    end)
    .&else(procedure(etherscan: IEtherscan)
    begin
      etherscan.getContractABI(contract, procedure(abi: IContractABI; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        contractABIs := contractABIs + [TContractABI.Create(chain, contract, abi)];
        callback(abi, err);
      end);
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

end.
