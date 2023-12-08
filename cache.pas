unit cache;

interface

uses
  // Delphi
  SysUtils,
  // web3
  web3,
  web3.eth.etherscan;

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);

implementation

uses
  // project
  common;

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

var
  contractABIs: TArray<TContractABI> = [];

procedure getContractABI(const chain: TChain; const contract: TAddress; const callback: TProc<IContractABI, IError>);
begin
  for var I := 0 to High(contractABIs) do
    if (contractABIs[I].Chain = chain) and (contractABIs[I].Contract = contract) then
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

end.
