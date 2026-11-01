# pastel-extras

Packages for [Pastel](https://github.com/azrov/pastel) that not every program needs: devices, charts, media. Each folder is one package; all of them have the same version (the tags of this repository).

| Package | What it is | |
|---|---|---|
| [serial](serial) | Serial ports: COM on Windows, `/dev/ttyUSB0` on Linux | `pastel add serial` |

Coming: barcode readers and labels, charts, GPIO on Raspberry Pi, cameras.

## Using a package

```sh
pastel add serial
```

Pastel finds it in the [registry](https://github.com/azrov/pastel-packages), puts `serial = "^0.1.0"` into `pastel.toml`, fetches it and writes its exact version into `pastel.lock`. More: [Packages](https://github.com/azrov/pastel/blob/main/docs/packages.md).

## Adding a package here

```sh
pastel new lib barcode       # a folder next to serial/
cd barcode
pastel test
```

- units named after the package (`SerialPort`, not `Serial` — Free Pascal has one), so they meet no others;
- a `README.md` with an example, and tests in `tests/` (they run on every push);
- works on Linux and Windows (`pastel build --target windows`);
- an entry in [pastel-packages](https://github.com/azrov/pastel-packages) `packages.toml`:

```toml
[barcode]
git = "https://github.com/azrov/pastel-extras"
path = "barcode"
description = "..."
```

## Releasing

```sh
git tag v0.2.0 && git push --tags
```

`v0.2.1` for fixes, `v0.3.0` for something new (before 1.0), `v1.0.0` when the packages are stable; after that `v2.0.0` when code that uses them must change.

MIT License.
