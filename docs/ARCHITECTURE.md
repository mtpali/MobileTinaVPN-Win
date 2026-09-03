# Architecture

## Boundary

Flutter is the presentation and application-control layer. It is not the VPN engine. Xray runs as a separate child process and only receives a generated runtime configuration.

```text
Flutter UI
   │
   ├── AppController
   │     ├── SubscriptionService ── HTTP + parser
   │     ├── LatencyService ─────── TCP reachability
   │     ├── PortableStore ──────── JSON state + logs
   │     └── XrayCoreService
   │             ├── XrayConfigBuilder
   │             └── xray.exe
   │
   └── Windows method channel
          ├── System Proxy registry + WinINet refresh
          ├── Windows startup registry
          └── System Tray lifecycle
```

## Connection lifecycle

1. Resolve the selected server.
2. Generate a fresh Xray configuration in `portable-data/runtime/xray.json`.
3. Execute `xray run -test -config ...` and stop on validation failure.
4. Snapshot the user's current Windows Proxy values.
5. Start Xray and wait for its local SOCKS port to accept connections.
6. Apply the app's HTTP/SOCKS values to Windows System Proxy.
7. On disconnect, restore the exact previous Proxy values before stopping Xray.

An `active-session.json` marker and the saved proxy snapshot make the sequence recoverable after a crash. Startup kills the recorded orphan Core process and restores the old proxy state before accepting new work.

## Data ownership

Flutter runtime already uses a directory called `data`, so user-owned portable state intentionally uses `portable-data` to avoid collisions during Flutter upgrades.

`state.json` has an explicit `schemaVersion`. Writes use a temporary file and rename so a process interruption cannot leave a partially written main state file.

## Supported profile surface

The parser accepts:

- classic base64 JSON and standard URI VMess
- VLESS
- Trojan
- SIP002 and legacy Shadowsocks
- authenticated and unauthenticated SOCKS

The builder covers the common Xray stream transports: TCP, WS, gRPC, HTTPUpgrade, XHTTP/SplitHTTP and KCP, including TLS and REALITY client settings.

Unknown or malformed lines are rejected individually. Duplicate source URIs are collapsed by a deterministic ID.

## Trust boundary

Subscription content is untrusted input. It is parsed into typed fields and then serialized into a newly constructed Xray config. The app never executes subscription strings as commands. Process creation does not use a shell.
