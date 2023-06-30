unit thread;

interface

uses
  // Delphi
  System.Classes;

procedure lock(const O: TObject; const P: TThreadProcedure);
procedure synchronize(const P: TThreadProcedure);

implementation

procedure lock(const O: TObject; const P: TThreadProcedure);
begin
  TMonitor.Enter(O);
  try
    P
  finally
    TMonitor.Exit(O);
  end;
end;

procedure synchronize(const P: TThreadProcedure);
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
