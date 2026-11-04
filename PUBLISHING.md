# Publishing Leo Dark

The extension is `leoshell.leo-theme`. Every release uploads the same `.vsix` to two registries:

| Registry | Serves | Listing | Upload from |
|:--|:--|:--|:--|
| VS Code Marketplace | VS Code | [listing](https://marketplace.visualstudio.com/items?itemName=leoshell.leo-theme) | [manage page](https://marketplace.visualstudio.com/manage), with a personal Microsoft account |
| Open VSX | Cursor | [listing](https://open-vsx.org/extension/leoshell/leo-theme) | [open-vsx.org](https://open-vsx.org), with the `LeoManrique` GitHub account |

Cursor reads Open VSX, not the VS Code Marketplace, so a release only reaches it through the second upload.

If the manage page drops you into a work or school tenant, open a private window and choose **Use another account**.

## Prerequisites

[Node.js](https://nodejs.org) and the packaging CLI, which needs no login:

```bash
npm install -g @vscode/vsce
```

## Release

1. In `CHANGELOG.md`, rename `## Unreleased` to the new version.
2. Bump `"version"` in `package.json`, following [semver](https://semver.org).
3. Package it. `.vscodeignore` decides what ships.

   ```bash
   vsce package
   ```

4. Test `leo-theme-<version>.vsix`: Extensions view → `…` → **Install from VSIX…**, reload the window, then `Cmd/Ctrl+K` `Cmd/Ctrl+T` → **Leo Dark**.
5. Upload to the VS Code Marketplace: on the manage page, open the extension → **…** → **Update**, and drag in the `.vsix`.
6. Upload to Open VSX: **Publish** → **Publish Extension**, and drag in the same `.vsix`. To use the CLI instead, generate a token under **Settings** → **Access Tokens**:

   ```bash
   npx ovsx publish leo-theme-<version>.vsix -p "$OVSX_PAT"
   ```

7. Check that both listings show the new version, then search for `leoshell.leo-theme` in Cursor. Cursor syncs from Open VSX, so it can lag behind.
