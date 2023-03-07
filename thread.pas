unit thread;

interface

uses
  // Delphi
  System.Classes;

procedure synchronize(const P: TThreadProcedure);

implementation

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
