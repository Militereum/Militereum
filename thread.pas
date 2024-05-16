unit thread;

interface

type
  TSafeProc                = reference to procedure;
  TCallback                = reference to procedure;
  TSafeProcWithCallback    = reference to procedure(done: TCallback);
  TSafeFunc<T>             = reference to function: T;
  TCallbackWithArg<T>      = reference to procedure(const arg: T);
  TSafeProcWithCallback<T> = reference to procedure(done: TCallbackWithArg<T>);

  TLock = class
    class function get<T>(const O: TObject; const P: TSafeFunc<T>): T; overload; static;
    class function get<T>(const O: TObject; const P: TSafeProcWithCallback<T>): T; overload; static;
  end;

procedure lock(const O: TObject; const P: TSafeProc); overload;
procedure lock(const O: TObject; const P: TSafeProcWithCallback); overload;

procedure synchronize(const P: TSafeProc);

implementation

uses
  // Delphi
  System.Classes;

procedure lock(const O: TObject; const P: TSafeProc);
begin
  TMonitor.Enter(O);
  try
    P
  finally
    TMonitor.Exit(O);
  end;
end;

class function TLock.get<T>(const O: TObject; const P: TSafeFunc<T>): T;
begin
  TMonitor.Enter(O);
  try
    Result := P;
  finally
    TMonitor.Exit(O);
  end;
end;

procedure lock(const O: TObject; const P: TSafeProcWithCallback);
begin
  TMonitor.Enter(O);
  try
    var done := false;
    P(procedure
    begin
      done := True;
    end);
    while not done do TThread.Sleep(100);
  finally
    TMonitor.Exit(O);
  end;
end;

class function TLock.get<T>(const O: TObject; const P: TSafeProcWithCallback<T>): T;
begin
  TMonitor.Enter(O);
  try
    var output: T;
    try
      var done := false;
      P(procedure(const arg: T)
      begin
        output := arg;
        done   := True;
      end);
      while not done do TThread.Sleep(100);
    finally
      Result := output;
    end;
  finally
    TMonitor.Exit(O);
  end;
end;

procedure synchronize(const P: TSafeProc);
begin
  if TThread.CurrentThread.ThreadID = MainThreadId then
    P
  else
    TThread.Synchronize(nil, procedure
    begin
      P
    end);
end;

end.
