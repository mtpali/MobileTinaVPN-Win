# Version 0.1 scope

## Included

- Portable Windows x64 ZIP
- Persian Auto and Manual connection flows
- Subscription CRUD and metadata display
- VMess, VLESS, Trojan, Shadowsocks and SOCKS parsing
- Parallel reachability test and Smart Connect
- Xray lifecycle and config validation
- Local HTTP/SOCKS inbounds
- Windows System Proxy with previous-state restoration
- Crash recovery, startup entry, tray, light/dark appearance and logs

## Explicit non-goals

- TUN/Wintun and full-device packet capture
- Split tunneling by process
- Routing-rule editor
- QR scanner on desktop
- Automatic application updates
- Code signing (requires a private Windows signing certificate)

## Next engineering milestone

Add a separately privileged TUN helper backed by sing-box or a narrowly scoped Wintun controller. It must include safe route/DNS rollback, elevation UX, driver lifecycle tests, and real Windows device validation before being enabled for ordinary users.
