# Publishing Leo Dark to the VS Code Marketplace

A step-by-step guide to publish (and update) this theme.

## Prerequisites

- [Node.js](https://nodejs.org) installed
- A [GitHub](https://github.com) repo for this project (recommended)
- A Microsoft / Azure DevOps account

Install the publishing CLI:

```bash
npm install -g @vscode/vsce
```

## Step 1 — Create a Personal Access Token (PAT)

1. Sign in to [Azure DevOps](https://dev.azure.com).
2. Click your avatar → **Personal Access Tokens** → **New Token**.
3. Configure:
   - **Organization:** `All accessible organizations`
   - **Expiration:** your choice (e.g. 90 days or 1 year)
   - **Scopes:** click *Show all scopes* → **Marketplace** → check **Manage**
4. **Create** and copy the token somewhere safe — it's shown only once.

## Step 2 — Create a Marketplace publisher

1. Go to the [Marketplace publisher management page](https://marketplace.visualstudio.com/manage).
2. Click **Create publisher**.
3. Choose a **publisher ID** (e.g. `leomanrique`) and display name.
4. Update `package.json` so `"publisher"` matches this exact ID:

   ```json
   "publisher": "leomanrique"
   ```

## Step 3 — Prepare `package.json`

Make sure the manifest is publish-ready:

- [ ] Remove `"private": true` (vsce refuses to package private projects)
- [ ] Set `"publisher"` to your real publisher ID
- [ ] Add a `repository` field:

  ```json
  "repository": {
    "type": "git",
    "url": "https://github.com/LeoManrique/leo-theme.git"
  }
  ```

- [ ] (Optional) Add an icon — a 128×128 PNG referenced by `"icon": "icon.png"`
- [ ] Bump `"version"` using [semver](https://semver.org) when releasing updates

## Step 4 — Add supporting files

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

## Step 5 — Log in with vsce

```bash
vsce login <your-publisher-id>
```

Paste the PAT from Step 1 when prompted.

## Step 6 — Package and test locally

```bash
vsce package
```

This produces `leo-theme-<version>.vsix`. **Test it before publishing:**

1. VS Code → Extensions view → `…` menu → **Install from VSIX…**
2. Select the `.vsix`, reload the window.
3. `Ctrl/Cmd+K Ctrl/Cmd+T` → choose **Leo Dark** and confirm it looks right.

## Step 7 — Publish

```bash
vsce publish
```

The extension appears on the Marketplace within a few minutes at:

```
https://marketplace.visualstudio.com/items?itemName=<publisher-id>.leo-theme
```

## Updating later

Bump the version and publish in one command:

```bash
vsce publish patch   # 1.0.0 → 1.0.1  (bug fixes / tweaks)
vsce publish minor   # 1.0.0 → 1.1.0  (new colors / features)
vsce publish major   # 1.0.0 → 2.0.0  (breaking changes)
```

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Missing publisher name` | Set `"publisher"` in `package.json` to match your publisher ID |
| `ERROR  The author field...` / private | Remove `"private": true` |
| `401 Unauthorized` | PAT expired or wrong scope — recreate with **Marketplace → Manage** |
| Listing has no description/images | Flesh out `README.md`; add `repository` so relative image links resolve |
