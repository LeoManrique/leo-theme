# Publishing Leo Dark to the VS Code Marketplace

A step-by-step guide to publish (and update) this theme.

> **Read this first.** There are two ways to publish: the **manual web upload**
> (recommended — no Azure DevOps, no Personal Access Token, no command-line auth)
> and the **automated CLI** (`vsce publish`, needs a token). For a personal theme,
> use the manual route. It avoids the single most painful part of this whole process.

---

## ⚠️ Don't go to `dev.azure.com` or `portal.azure.com`

The old guides send you to **Azure DevOps** to create a Personal Access Token.
You do **not** need that for the manual upload route, and it's a rabbit hole:

- `dev.azure.com` frequently **redirects to `portal.azure.com`**, especially if
  you're signed into a work/school (Entra ID) tenant that restricts DevOps.
- Global Azure DevOps PATs are **being retired on December 1, 2026** anyway.

The Marketplace **publisher** page (below) is a plain Microsoft sign-in — no org,
no token, no redirect loop. That's all you need.

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
3. On the manage page, open your extension → **…** → **Update** → drag in the new `.vsix`.

---

## Route B — Automated CLI publish (optional, needs a token)

Only worth it if you publish often or want CI/CD. This requires authentication.
Because PATs are being retired (Dec 1, 2026), the forward-looking option is
**Microsoft Entra ID** auth rather than a classic PAT.

### Using a Personal Access Token (legacy)

1. Sign in to [Azure DevOps](https://dev.azure.com) — *if* it doesn't redirect you.
   Try [https://aex.dev.azure.com](https://aex.dev.azure.com) if `dev.azure.com` bounces you.
2. User settings ⚙️ → **Personal access tokens** → **New Token**.
3. Configure:
   - **Organization:** `All accessible organizations`
   - **Expiration:** your choice
   - **Scopes:** *Show all scopes* → **Marketplace** → check **Manage**
4. **Create** and copy the token — it's shown only once.
5. Log in and publish:

   ```bash
   vsce login <your-publisher-id>   # paste the PAT when prompted
   vsce publish                     # or: vsce publish patch | minor | major
   ```

### Using Microsoft Entra ID (recommended for automation)

In a pipeline, obtain an Entra ID token (e.g. via the Azure CLI) and publish with:

```bash
vsce publish --azure-credential
```

See the [official publishing docs](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
for the current, supported setup.

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `dev.azure.com` redirects to `portal.azure.com` | You don't need it — use **Route A**. If you insist on the CLI, try `aex.dev.azure.com` and a personal (non-org) account in an incognito window. |
| Sign-in forces a work/school tenant | Incognito window → **"Use another account"** → type your personal email. Consider a fresh `@outlook.com` account dedicated to publishing. |
| `Missing publisher name` | Set `"publisher"` in `package.json` to match your publisher ID exactly. |
| `ERROR  The author field...` / private | Remove `"private": true`. |
| `401 Unauthorized` (CLI route) | PAT expired or wrong scope — recreate with **Marketplace → Manage**, or switch to the manual upload route. |
| Listing has no description/images | Flesh out `README.md`; add `repository` so relative image links resolve. |

## References

- [Publishing Extensions — official VS Code docs](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
- [Marketplace publisher management](https://marketplace.visualstudio.com/manage)
