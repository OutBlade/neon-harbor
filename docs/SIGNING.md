# Code signing Neon Harbor

Unsigned installers trigger Windows SmartScreen on most machines and are
hard-blocked by Smart App Control (no Run anyway button) on newer
Windows 11 devices. Signing with a publicly trusted certificate is the
only fix that works everywhere. Two realistic options:

## Option A: Azure Trusted Signing (recommended, ~10 USD/month)

Microsoft's own signing service. Individual developers can be validated
with a government ID, no company needed.

1. Create an Azure account at https://azure.microsoft.com
2. Create a "Trusted Signing" resource (Basic tier)
3. Complete identity validation in the Azure portal
4. Create a certificate profile (Public Trust)
5. Install the signing tools:
   `winget install Microsoft.DotNet.SDK.8` then
   `dotnet tool install --global sign --prerelease`
6. Sign the binaries after every export:
   ```
   sign code trusted-signing dist/NeonHarbor-win-x64.exe dist/NeonHarbor-win-arm64.exe `
     -tse https://weu.codesigning.azure.net -tsa <account> -tscp <profile>
   ```
7. Uncomment the SignTool line in installer/neon_harbor.iss so the
   installer gets signed by Inno Setup during compilation

Once signed, SmartScreen warnings stop quickly and Smart App Control
accepts the binaries immediately.

## Option B: classic OV certificate (~100-400 USD/year)

Buy an OV code signing certificate (Certum, Sectigo, SSL.com), receive a
hardware token or cloud key, sign with signtool.exe. More paperwork,
same result.

## What is already mitigated without signing

- The winget package (`winget install OutBlade.NeonHarbor`) bypasses
  browser download marking, so SmartScreen does not interrupt installs
  on standard Windows configurations
- The in-game auto updater downloads new versions directly and never
  triggers SmartScreen
- README documents the More info / Run anyway path for manual downloads
