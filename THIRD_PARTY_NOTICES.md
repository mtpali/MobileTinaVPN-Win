# Third-party notices

MobileTinaVPN for Windows includes or is distributed with the following components:

## Flutter

- Project: <https://github.com/flutter/flutter>
- License: BSD 3-Clause
- The Windows runner scaffold is generated from the official Flutter template.

## Xray-core

- Project: <https://github.com/XTLS/Xray-core>
- Version bundled by CI: `v26.3.27`
- License: Mozilla Public License 2.0
- Official Windows x64 archive SHA-256: `d004c39288ce9ada487c6f398c7c545f7d749e44bdfdd59dbc9f865afba4e1ad`

## QR.Flutter

- Project: <https://github.com/theyakka/qr.flutter>
- Version: `4.1.0`
- License: BSD 3-Clause
- Used to render a local QR code for sharing an individual server.

## cryptography

- Project: <https://github.com/dint-dev/cryptography>
- Version constraint: `^2.7.0`
- License: Apache License 2.0
- Used for AES-256-GCM protection of bundled assets and portable state.

## MobileTinaVPN artwork

- Source: <https://github.com/mtpali/MobileTinaVPN>
- The decrypted connection-state and branding artwork matches the Android project byte-for-byte; the Windows release stores it in authenticated protected payloads.
- The Android project and this repository are distributed under GPL-3.0.

The original license files shipped inside the Xray archive remain in the portable package.

## Vazirmatn UI

- Project: <https://github.com/rastikerdar/vazirmatn>
- License: SIL Open Font License 1.1
- Used as the bundled Persian UI font. The license text is stored at
  `assets/fonts/OFL.txt`.
- The official portable build also places the license at `VAZIRMATN_OFL.txt`.
