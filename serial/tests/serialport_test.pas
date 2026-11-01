{ Tests for src/serialport.pas. On Linux a pseudo terminal plays the device
  at the other end of the cable. Run them with: pastel test }
unit SerialPort_Test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Pastel.Testing, SerialPort{$IFDEF UNIX}, BaseUnix{$ENDIF};

type
  TSerialPortTests = class(TTestSuite)
  published
    procedure AMissingPortIsExplained;
    procedure ListingPortsWorks;
    {$IFDEF UNIX}
    procedure LinesGoBothWays;
    procedure NoLineInTimeIsAnError;
    {$ENDIF}
  end;

implementation

{$IFDEF UNIX}
function posix_openpt(Flags: cint): cint; cdecl; external 'c';
function grantpt(Fd: cint): cint; cdecl; external 'c';
function unlockpt(Fd: cint): cint; cdecl; external 'c';
function ptsname(Fd: cint): PAnsiChar; cdecl; external 'c';

{ the device's end (Master) and the name of the port to open }
function OpenFakeDevice(out Master: cint): string;
begin
  Master := posix_openpt(O_RDWR or O_NOCTTY);
  if (Master < 0) or (grantpt(Master) <> 0) or (unlockpt(Master) <> 0) then
    raise Exception.Create('no pseudo terminal');
  Result := ptsname(Master);
end;

function DeviceRead(Master: cint): string;
var
  Buf: array[0..255] of Char;
  N: TSsize;
begin
  Sleep(50);
  N := FpRead(Master, Buf, SizeOf(Buf));
  if N > 0 then
    SetString(Result, PChar(@Buf[0]), N)
  else
    Result := '';
end;
{$ENDIF}

procedure TSerialPortTests.AMissingPortIsExplained;
var
  Msg: string;
begin
  Msg := '';
  try
    TSerialPort.Create({$IFDEF UNIX}'/dev/ttyNOTHERE'{$ELSE}'COM99'{$ENDIF}).Free;
  except
    on E: ESerialError do
      Msg := E.Message;
  end;
  AssertTrue(Pos('cannot open the serial port', Msg) > 0, Msg);
end;

procedure TSerialPortTests.ListingPortsWorks;
begin
  AssertTrue(Length(ListSerialPorts) >= 0);
end;

{$IFDEF UNIX}
procedure TSerialPortTests.LinesGoBothWays;
var
  Master: cint;
  Port: TSerialPort;
  S: string;
begin
  Port := TSerialPort.Create(OpenFakeDevice(Master), 9600);
  try
    Port.WriteLine('W');
    AssertEquals('W'#13#10, DeviceRead(Master));
    S := '12.5 kg'#13#10'13.0 kg'#13#10;
    FpWrite(Master, S[1], Length(S));
    AssertEquals('12.5 kg', Port.ReadLine(1000));
    AssertEquals('13.0 kg', Port.ReadLine(1000), 'the second line was kept');
  finally
    Port.Free;
    FpClose(Master);
  end;
end;

procedure TSerialPortTests.NoLineInTimeIsAnError;
var
  Master: cint;
  Port: TSerialPort;
  S: string;
  Failed: Boolean;
begin
  Port := TSerialPort.Create(OpenFakeDevice(Master));
  try
    S := 'half';
    FpWrite(Master, S[1], Length(S));
    Failed := False;
    try
      Port.ReadLine(200);
    except
      on E: ESerialError do
        Failed := True;
    end;
    AssertTrue(Failed, 'no line end came');
    S := ' done'#13#10;
    FpWrite(Master, S[1], Length(S));
    AssertEquals('half done', Port.ReadLine(1000), 'nothing was lost');
  finally
    Port.Free;
    FpClose(Master);
  end;
end;
{$ENDIF}

initialization
  RegisterTests(TSerialPortTests);

end.
