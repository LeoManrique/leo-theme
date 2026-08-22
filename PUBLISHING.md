# Publishing Leo Dark to the VS Code Marketplace

A step-by-step guide to publish (and update) this theme.

---

## Prerequisites

- [Node.js](https://nodejs.org) installed
- A **personal** Microsoft account (e.g. an `@outlook.com` address). Avoid using a
  work/school account — your extension shouldn't be tied to an org you might lose
  access to, and org tenants are what cause the `dev.azure.com` redirect mess.
- A [GitHub](https://github.com) repo for this project (recommended)

Install the packaging CLI (used only to build the `.vsix` — no login required):

```bash
npm install -g @vscode/vsce
```

---

## Route A — Manual web upload (recommended, no token)

### Step 1 — Create a Marketplace publisher

1. Go to the [Marketplace publisher management page](https://marketplace.visualstudio.com/manage).
2. Sign in with your **personal** Microsoft account.
3. Click **Create publisher**.
4. Choose a unique **publisher ID** (e.g. `leomanrique`) and a display name, then **Create**.

> If sign-in keeps dropping you into a work/school tenant, open a private/incognito
> window and choose **"Use another account"** to sign in with your personal account.

### Step 2 — Prepare `package.json`

Make sure the manifest is publish-ready:

- [ ] Remove `"private": true` (vsce refuses to package private projects)
- [ ] Set `"publisher"` to the exact publisher ID from Step 1:

  ```json
  "publisher": "leomanrique"
  ```

- [ ] Add a `repository` field:

  ```json
  "repository": {
    "type": "git",
    "url": "https://github.com/LeoManrique/leo-theme.git"
  }
  ```

- [ ] (Optional) Add an icon — a 128×128 PNG referenced by `"icon": "icon.png"`
- [ ] Bump `"version"` using [semver](https://semver.org) when releasing updates

### Step 3 — Add supporting files

- [ ] **`LICENSE`** — you declare `"license": "MIT"`, so include the matching file
- [ ] **`README.md`** — shown on the Marketplace listing page (already present)
- [ ] **`CHANGELOG.md`** (optional) — release notes shown in the *Changelog* tab
- [ ] **`.vscodeignore`** — exclude dev files from the package:

  ```
  .git/
  .gitignore
  .vscodeignore
  PUBLISHING.md
  ```

### Step 4 — Package the `.vsix`

```bash
vsce package
```

This produces `leo-theme-<version>.vsix`. **Test it before publishing:**

1. VS Code → Extensions view → `…` menu → **Install from VSIX…**
2. Select the `.vsix`, reload the window.
3. `Ctrl/Cmd+K Ctrl/Cmd+T` → choose **Leo Dark** and confirm it looks right.

### Step 5 — Upload it

1. Back on the [publisher management page](https://marketplace.visualstudio.com/manage),
   select your publisher.
2. Click **New extension → Visual Studio Code**.
3. Drag in (or browse to) your `leo-theme-<version>.vsix`.

The extension appears on the Marketplace within a few minutes at:

```
https://marketplace.visualstudio.com/items?itemName=<publisher-id>.leo-theme
```

### Updating later (manual)

1. Bump `"version"` in `package.json`.
2. Run `vsce package` again.
3. On the [manage page](https://marketplace.visualstudio.com/manage), open your extension → **…** → **Update** → drag in the new `.vsix`.
