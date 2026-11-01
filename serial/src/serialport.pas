(* serial: serial ports (COM1 on Windows, /dev/ttyUSB0 on Linux) for scales,
  barcode readers, Arduino boards, cash drawers, GPS receivers...

    uses
      SerialPort;

    var
      Port: TSerialPort;
    begin
      Port := TSerialPort.Create('/dev/ttyUSB0', 9600);   // or 'COM3'
      try
        Port.WriteLine('W');                 // ask the scale for the weight
        WriteLn(Port.ReadLine(1000));        // its answer, waiting up to 1 s
      finally
        Port.Free;
      end;
    end;

  ListSerialPorts gives the ports of the computer. Built on Free Pascal's
  Serial unit. Part of pastel-extras, MIT License. *)
unit SerialPort;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Serial;

type
  ESerialError = class(Exception);

  TParity = (paNone, paOdd, paEven);

  TSerialPort = class
  private
    FHandle: TSerialHandle;
    FName: string;
    FBuffer: string;          { read, but not given out yet (after a line) }
    FLineEnd: string;
    { what is there, waiting up to TimeoutMs for the first byte }
    function ReadSome(var Buf: array of Byte; TimeoutMs: Integer): Integer;
  public
    { Opens the port: 9600 baud, 8 data bits, no parity, 1 stop bit unless
      told otherwise. ESerialError when it cannot be opened. }
    constructor Create(const PortName: string; Baud: Integer = 9600; DataBits: Integer = 8;
      Parity: TParity = paNone; StopBits: Integer = 1; HardwareFlow: Boolean = False);
    destructor Destroy; override;
    procedure Write(const S: string);
    { S and LineEnd. }
    procedure WriteLine(const S: string);
    procedure WriteBytes(const Data: TBytes);
    { What has arrived within TimeoutMs (it returns as soon as something is
      there); '' when nothing came. }
    function Read(TimeoutMs: Integer = 100): string;
    { One line, without its line end; waits up to TimeoutMs for all of it.
      ESerialError when the time is up (what came so far stays for the next read). }
    function ReadLine(TimeoutMs: Integer = 1000): string;
    { Forgets what has arrived and not been read. }
    procedure Clear;
    property Name: string read FName;
    { What WriteLine adds and ReadLine looks for: #13#10 (default), #10 or #13. }
    property LineEnd: string read FLineEnd write FLineEnd;
  end;

{ The serial ports of this computer: '/dev/ttyUSB0', '/dev/ttyACM0', ... on
  Linux; 'COM1', 'COM3', ... on Windows. }
function ListSerialPorts: TStringArray;

implementation

uses
  Math, DateUtils{$IFDEF UNIX}, BaseUnix{$ENDIF}{$IFDEF WINDOWS}, Windows{$ENDIF};

function TSerialPort.ReadSome(var Buf: array of Byte; TimeoutMs: Integer): Integer;
{$IFDEF UNIX}
var
  FDs: TFDSet;
  TV: TTimeVal;
begin
  Result := 0;
  fpFD_ZERO(FDs);
  fpFD_SET(FHandle, FDs);
  TV.tv_sec := TimeoutMs div 1000;
  TV.tv_usec := (TimeoutMs mod 1000) * 1000;
  if fpSelect(FHandle + 1, @FDs, nil, nil, @TV) > 0 then
    Result := Max(0, fpRead(FHandle, Buf[0], Length(Buf)));
end;
{$ELSE}
var
  Errors: DWORD;
  Stat: TComStat;
  N: Integer;
begin
  Result := SerReadTimeout(FHandle, Buf, 1, TimeoutMs);
  if (Result = 1) and ClearCommError(FHandle, Errors, @Stat) then
  begin
    N := Min(Integer(Stat.cbInQue), Length(Buf) - 1);
    if N > 0 then
      Inc(Result, Max(0, SerRead(FHandle, Buf[1], N)));
  end;
end;
{$ENDIF}

constructor TSerialPort.Create(const PortName: string; Baud: Integer; DataBits: Integer;
  Parity: TParity; StopBits: Integer; HardwareFlow: Boolean);
var
  Dev: string;
  Flags: TSerialFlags;
begin
  inherited Create;
  FName := PortName;
  FLineEnd := #13#10;
  Dev := PortName;
  {$IFDEF WINDOWS}
  { COM10 and above need this form; it works for all }
  if (Pos('\', Dev) = 0) and SameText(Copy(Dev, 1, 3), 'COM') then
    Dev := '\\.\' + Dev;
  {$ENDIF}
  FHandle := SerOpen(Dev);
  if (FHandle = 0) or (FHandle = TSerialHandle(-1)) then
  begin
    FHandle := 0;
    raise ESerialError.CreateFmt('cannot open the serial port %s (%s)', [PortName,
      {$IFDEF UNIX}'does it exist, and may you use it? on Linux: sudo usermod -aG dialout $USER, then log in again'
      {$ELSE}'does it exist, or does another program use it?'{$ENDIF}]);
  end;
  Flags := [];
  if HardwareFlow then
    Include(Flags, RtsCtsFlowControl);
  SerSetParams(FHandle, Baud, DataBits, TParityType(Ord(Parity)), StopBits, Flags);
end;

destructor TSerialPort.Destroy;
begin
  if FHandle <> 0 then
    SerClose(FHandle);
  inherited Destroy;
end;

procedure TSerialPort.WriteBytes(const Data: TBytes);
var
  Done, N: Integer;
begin
  Done := 0;
  while Done < Length(Data) do
  begin
    N := SerWrite(FHandle, Data[Done], Length(Data) - Done);
    if N <= 0 then
      raise ESerialError.CreateFmt('writing to %s failed', [FName]);
    Inc(Done, N);
  end;
  SerDrain(FHandle);
end;

procedure TSerialPort.Write(const S: string);
begin
  if S <> '' then
    WriteBytes(BytesOf(S));
end;

procedure TSerialPort.WriteLine(const S: string);
begin
  Write(S + FLineEnd);
end;

function TSerialPort.Read(TimeoutMs: Integer): string;
var
  Buf: array[0..1023] of Byte;
  N: LongInt;
begin
  Result := FBuffer;
  FBuffer := '';
  if Result <> '' then
    Exit;
  N := ReadSome(Buf, TimeoutMs);
  if N > 0 then
    SetString(Result, PAnsiChar(@Buf[0]), N);
end;

function TSerialPort.ReadLine(TimeoutMs: Integer): string;
var
  Until_: TDateTime;
  P, Left: Integer;
  Buf: array[0..255] of Byte;
  N: LongInt;
  Chunk, Ends: string;
begin
  Until_ := IncMilliSecond(Now, TimeoutMs);
  Ends := FLineEnd[Length(FLineEnd)];      { #10 of #13#10 }
  repeat
    P := Pos(Ends, FBuffer);
    if P > 0 then
    begin
      Result := Copy(FBuffer, 1, P - 1);
      Delete(FBuffer, 1, P);
      { the rest of a two-character line end }
      if (Length(FLineEnd) > 1) and (Result <> '') and (Result[Length(Result)] = FLineEnd[1]) then
        SetLength(Result, Length(Result) - 1);
      Exit;
    end;
    Left := MilliSecondsBetween(Until_, Now);
    if (Now >= Until_) or (Left <= 0) then
      raise ESerialError.CreateFmt('no line from %s within %d ms', [FName, TimeoutMs]);
    N := ReadSome(Buf, Left);
    if N > 0 then
    begin
      SetString(Chunk, PAnsiChar(@Buf[0]), N);
      FBuffer := FBuffer + Chunk;
    end;
  until False;
end;

procedure TSerialPort.Clear;
begin
  FBuffer := '';
  SerFlushInput(FHandle);
end;

function ListSerialPorts: TStringArray;
var
  L: TStringList;
  {$IFDEF UNIX}
  SR: TSearchRec;
  Pattern: string;
  {$ENDIF}
  {$IFDEF WINDOWS}
  I: Integer;
  H: THandle;
  {$ENDIF}
begin
  L := TStringList.Create;
  try
    {$IFDEF UNIX}
    for Pattern in ['ttyUSB*', 'ttyACM*', 'ttyAMA*', 'serial*', 'tty.usb*', 'cu.usb*'] do
      if FindFirst('/dev/' + Pattern, faAnyFile, SR) = 0 then
      try
        repeat
          L.Add('/dev/' + SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    {$ENDIF}
    {$IFDEF WINDOWS}
    for I := 1 to 64 do
    begin
      H := CreateFileA(PAnsiChar('\\.\COM' + IntToStr(I)), GENERIC_READ or GENERIC_WRITE, 0, nil,
        OPEN_EXISTING, 0, 0);
      if H <> INVALID_HANDLE_VALUE then
      begin
        CloseHandle(H);
        L.Add('COM' + IntToStr(I));
      end
      else if GetLastError = ERROR_ACCESS_DENIED then
        L.Add('COM' + IntToStr(I));      { there, but used by another program }
    end;
    {$ENDIF}
    L.Sort;
    Result := L.ToStringArray;
  finally
    L.Free;
  end;
end;

end.
