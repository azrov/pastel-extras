# serial

Serial ports for Pastel programs: scales, barcode readers, Arduino boards, cash drawers, GPS receivers, modems — anything on `COM3` (Windows) or `/dev/ttyUSB0` (Linux).

```sh
pastel add serial
```

```pascal
uses
  SerialPort;

var
  Port: TSerialPort;
begin
  Port := TSerialPort.Create('/dev/ttyUSB0', 9600);    // or 'COM3'
  try
    Port.WriteLine('W');                // ask the scale for the weight
    WriteLn(Port.ReadLine(1000));       // its answer, waiting up to a second
  finally
    Port.Free;
  end;
end;
```

## TSerialPort

| | |
|---|---|
| `Create(Port, Baud, DataBits, Parity, StopBits, HardwareFlow)` | Opens it: `9600, 8, paNone, 1, False` unless told otherwise; `ESerialError` when it cannot |
| `Write(S)`, `WriteLine(S)`, `WriteBytes(Data)` | Sends; `WriteLine` adds `LineEnd` |
| `Read(TimeoutMs)` | What has arrived (waits up to `TimeoutMs` for something); `''` when nothing came |
| `ReadLine(TimeoutMs)` | One line without its end; `ESerialError` when it does not come in time — what came stays for the next read |
| `Clear` | Forgets what arrived and was not read |
| `LineEnd` | `#13#10` (default), `#10` or `#13` |

`ListSerialPorts` gives the ports of the computer: `['/dev/ttyACM0', '/dev/ttyUSB0']`, `['COM1', 'COM3']`.

In a desktop app, read in a `TTimer` (`Port.Read(0)` returns right away) or in a thread (`Pastel.Workers`), so the window stays responsive.

## Linux: permission

Serial ports belong to the group `dialout`. Once:

```sh
sudo usermod -aG dialout $USER     # then log out and in again
```

## Tests

```sh
pastel test       # on Linux a pseudo terminal plays the device at the other end
```

Built on Free Pascal's `Serial` unit. MIT License.
