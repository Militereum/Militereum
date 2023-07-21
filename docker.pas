unit docker;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types;

type
  TFrmDocker = class(TForm)
    btnYes: TButton;
    btnNo: TButton;
    imgMilitereum: TImage;
    lblTitle: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    imgDocker: TImage;
    PB: TProgressBar;
    procedure btnYesClick(Sender: TObject);
  protected
    procedure DoShow; override;
  end;

var
  callback: TFunc<TFrmDocker>;

function supported: Boolean; // returns true if Docker Engine can run, otherwise false
function installed: Boolean; // returns true if Docker Engine is installed, otherwise false
function running: Boolean;   // retruns true if Docker Engine is running, otherwise false
function start: Boolean;
function pull(const image: string): Boolean;
function run(const containerName, command: string): Boolean;
function getContainerId(const name: string): string;
function stop(const containerId: string): Boolean;

const
  RPCh_DOCKER_IMAGE   = 'europe-west6-docker.pkg.dev/rpch-375921/rpch/rpc-server:latest';
  RPCh_CONTAINER_NAME = 'rpc-server';

implementation

{$R *.fmx}

uses
  // Delphi
  System.IOUtils,
  System.Threading,
  System.UITypes,
  // Indy
  IdComponent,
  IdHTTP,
  IdSSLOpenSSL,
  // project
  base,
  common,
{$IFDEF MACOS}
  docker.mac,
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  docker.win,
{$ENDIF MSWINDOWS}
  thread;

function supported: Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.supported;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.supported;
{$ENDIF MSWINDOWS}
end;

function installed: Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.installed;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.installed;
{$ENDIF MSWINDOWS}
end;

function installer: string;
begin
{$IFDEF MACOS}
  Result := docker.mac.installer;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.installer;
{$ENDIF MSWINDOWS}
end;

function running: Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.running;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.running;
{$ENDIF MSWINDOWS}
end;

function start: Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.start;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.start;
{$ENDIF MSWINDOWS}
end;

function pull(const image: string): Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.pull(image);
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.pull(image);
{$ENDIF MSWINDOWS}
end;

function run(const containerName, command: string): Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.run(containerName, command);
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.run(containerName, command);
{$ENDIF MSWINDOWS}
end;

function getContainerId(const name: string): string;
begin
{$IFDEF MACOS}
  Result := docker.mac.getContainerId(name);
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.getContainerId(name);
{$ENDIF MSWINDOWS}
end;

function stop(const containerId: string): Boolean;
begin
{$IFDEF MACOS}
  Result := docker.mac.stop(containerId);
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := docker.win.stop(containerId);
{$ENDIF MSWINDOWS}
end;

type
  TIdEventHandler = class(TComponent)
  private
    FWorkBegin: TProc<Int64>;
    FWork     : TFunc<Int64, Boolean>;
    FWorkEnd  : TProc;
  public
    function  WorkBegin(aProc: TProc<Int64>): TIdEventHandler; overload;
    procedure WorkBegin(aSender: TObject; aWorkMode: TWorkMode; aWorkCountMax: Int64); overload;

    function  Work(aProc: TFunc<Int64, Boolean>): TIdEventHandler; overload;
    procedure Work(aSender: TObject; aWorkMode: TWorkMode; aWorkCount: Int64); overload;

    function  WorkEnd(aProc: TProc): TIdEventHandler; overload;
    procedure WorkEnd(aSender: TObject; aWorkMode: TWorkMode); overload;
  end;

function TIdEventHandler.WorkBegin(aProc: TProc<Int64>): TIdEventHandler;
begin
  FWorkBegin := aProc;
  Result := Self;
end;

procedure TIdEventHandler.WorkBegin(aSender: TObject; aWorkMode: TWorkMode; aWorkCountMax: Int64);
begin
  if aWorkMode = wmRead then FWorkBegin(aWorkCountMax);
end;

function TIdEventHandler.Work(aProc: TFunc<Int64, Boolean>): TIdEventHandler;
begin
  FWork := aProc;
  Result := Self;
end;

procedure TIdEventHandler.Work(aSender: TObject; aWorkMode: TWorkMode; aWorkCount: Int64);
begin
  if aWorkMode = wmRead then
  begin
    const proceed = FWork(aWorkCount);
    if not proceed then
      if Assigned(Self.Owner) and (Self.Owner is TIdHTTP) then
      begin
        (Self.Owner as TIdHTTP).IOHandler.CloseGracefully;
      end;
  end;
end;

function TIdEventHandler.WorkEnd(aProc: TProc): TIdEventHandler;
begin
  FWorkEnd := aProc;
  Result := Self;
end;

procedure TIdEventHandler.WorkEnd(aSender: TObject; aWorkMode: TWorkMode);
begin
  if aWorkMode = wmRead then FWorkEnd;
end;

procedure install(workBegin: TProc<Int64>; work: TFunc<Int64, Boolean>; workEnd: TProc);
begin
  const client = TIdHTTP.Create;
  try
    client.IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(client);
    TIdSSLIOHandlerSocketOpenSSL(client.IOHandler).SSLOptions.Method := sslvTLSv1_2;
    const tempFile = System.SysUtils.ChangeFileExt(common.GetTempFileName, (function: string
    begin
      Result := TPath.GetExtension(installer);
      if (Result <> '') and (Result[Low(Result)] <> '.') then Result := '.' + Result;
    end)());
    const fileStream = TFileStream.Create(tempFile, fmCreate);
    try
      client.OnWorkBegin := TIdEventHandler.Create(client).WorkBegin(workBegin).WorkBegin;
      client.OnWork := TIdEventHandler.Create(client).Work(work).Work;
      client.OnWorkEnd := TIdEventHandler.Create(client).WorkEnd(workEnd).WorkEnd;
      client.Get(installer, fileStream);
    finally
      fileStream.Free;
    end;
    common.Open(tempFile);
  finally
    client.Free;
  end;
end;

{ TFrmDocker }

procedure TFrmDocker.btnYesClick(Sender: TObject);
begin
  TTask.Create(procedure
  begin
    install(procedure(max: Int64)
    begin
      thread.synchronize(procedure
      begin
        if Assigned(callback) then callback.PB.Max := max;
      end);
    end,
    function(pos: Int64): Boolean
    begin
      Result := Assigned(callback);
      if Result then
        thread.synchronize(procedure
        begin
          if Assigned(callback) then callback.PB.Value := pos;
        end);
    end,
    procedure
    begin
      if Assigned(callback) then callback.ModalResult := mrYes;
    end);
  end).Start;
  Self.PB.Visible := True;
end;

procedure TFrmDocker.DoShow;
begin
  base.CenterOnDisplayUnderMouseCursor(Self);
  inherited DoShow;
end;

end.
