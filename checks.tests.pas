unit checks.tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TChecks = class
  public
    [Test]
    procedure Step12;
    [Test]
    procedure Step13;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.JSON,
  System.SysUtils,
  // web3
  web3,
  web3.json,
  // project
  dextools,
  moralis;

procedure TChecks.Step12;
begin
  var score: Integer := -1;
  var err  : IError  := nil;

  dextools.score({$I keys/dextools.api.key}, web3.Ethereum, '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8', procedure(score1: Integer; err1: IError)
  begin
    if not Assigned(err1) then
      score := score1
    else
      moralis.score({$I keys/moralis.api.key}, web3.Ethereum, '0x4DB5C8875ef00ce8040A9685581fF75C3c61aDC8', procedure(score2: Integer; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else
          score := score2;
      end);
  end);

  while (err = nil) and (score = -1) do TThread.Sleep(100);

  if Assigned(err) then Assert.Fail(err.Message) else if score = 0 then Assert.Fail('score is 0, expected value between 1 and 100');
end;

procedure TChecks.Step13;
begin
  var arr: TJsonArray := nil;
  var err: IError     := nil;

  dextools.pairs({$I keys/dextools.api.key}, web3.Ethereum, '0x14C926F2290044B647e1Bf2072e67B495eff1905', procedure(arr1: TJsonArray; err1: IError)
  begin
    if Assigned(arr1) and not Assigned(err1) then
      arr := arr1.Clone as TJsonArray
    else
      moralis.pairs({$I keys/moralis.api.key}, web3.Ethereum, '0x14C926F2290044B647e1Bf2072e67B495eff1905', procedure(arr2: TJsonArray; err2: IError)
      begin
        if Assigned(err2) then
          err := err2
        else if Assigned(arr2) then
          arr := arr2.Clone as TJsonArray
        else
          arr := web3.json.unmarshal('[]') as TJsonArray;
      end);
  end);

  while (err = nil) and (arr = nil) do TThread.Sleep(100);

  if Assigned(arr) then arr.Free;
  if Assigned(err) then Assert.Fail(err.Message);
end;

initialization
  TDUnitX.RegisterTestFixture(TChecks);

end.
