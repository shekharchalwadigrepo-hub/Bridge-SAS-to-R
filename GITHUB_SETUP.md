# Expert guide: put SAS2R Guide on a new GitHub repository

This is the exact sequence a working programmer uses. Follow the path that matches your machine.

**Recommended names**

| What | Value |
| --- | --- |
| GitHub repo slug | `sas2r-guide` |
| Display title | SAS2R Guide |
| Description | Interactive SAS ↔ R learner guide with a teaching code converter (Shiny) |
| Visibility | Public (so others can clone) or Private (if it is only for you / your team) |
| Default branch | `main` |

This folder already has `README.md`, `LICENSE` (MIT), `.gitignore`, and a first commit on `main`. That changes one important rule below: **do not let GitHub create its own README**.

---

## Before you start (5-minute checklist)

1. You have a GitHub account: [https://github.com/signup](https://github.com/signup)
2. Git is installed:
   - Windows: [https://git-scm.com/download/win](https://git-scm.com/download/win)
   - macOS: `xcode-select --install` or install Git from git-scm.com
   - Confirm: open Terminal / Git Bash and run `git --version`
3. You know your GitHub username. Example used below: `YOUR-USER`
4. This project folder exists on your computer (unzip `sas-to-r-learner.zip` if needed)

Set your identity once on that computer (Git refuses commits without it):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Use the same email as your GitHub account if you want the commits to link to your profile.

---

## Path A — GitHub website + Git (clearest the first time)

### Step 1. Open GitHub and start a new repository

1. Sign in at [https://github.com](https://github.com)
2. Click the **+** in the top-right corner
3. Click **New repository**

Direct URL: [https://github.com/new](https://github.com/new)

### Step 2. Fill the form (this is the step people get wrong)

| Field | What to enter | Why |
| --- | --- | --- |
| Owner | Your user or an organization | The repo lives under this account |
| Repository name | `sas2r-guide` | Short, searchable slug |
| Description | `Interactive SAS ↔ R learner guide with a teaching code converter (Shiny)` | Shows on the repo header |
| Public / Private | Public unless the code must stay internal | Public is required for a free GitHub Pages site later |
| Add a README | **Leave unchecked** | You already have a README |
| Add .gitignore | **No .gitignore** | You already have one |
| Choose a license | **None** | You already have MIT in `LICENSE` |

Then click **Create repository**.

GitHub will show an empty-repo page with push instructions. That is what you want.

### Step 3. Copy the HTTPS URL

On the empty repo page you will see something like:

```text
https://github.com/YOUR-USER/sas2r-guide.git
```

Keep that tab open.

HTTPS is enough for most people. Use SSH later if you push often (`git@github.com:YOUR-USER/sas2r-guide.git`).

### Step 4. Open a terminal in the project folder

```bash
cd path/to/sas-to-r-learner
```

Check that Git already sees the project:

```bash
git status
git log -1 --oneline
git remote -v
```

Expected:

- `On branch main`
- a commit message like `Initial commit: SAS to R learner guide Shiny app`
- no remote yet (`git remote -v` prints nothing)

If `git status` says `not a git repository`, run the repair block at the bottom of this file.

### Step 5. Point this folder at GitHub

```bash
git remote add origin https://github.com/YOUR-USER/sas2r-guide.git
git remote -v
```

You should see `origin` listed twice (fetch and push) with your URL.

If you typed the URL wrong:

```bash
git remote remove origin
git remote add origin https://github.com/YOUR-USER/sas2r-guide.git
```

### Step 6. Push `main`

```bash
git branch -M main
git push -u origin main
```

`-u` remembers that local `main` tracks `origin/main`, so later you can just run `git push`.

### Step 7. Sign in when Git asks

GitHub no longer accepts your account password for Git over HTTPS.

Choose one:

**Option 1 — GitHub CLI (easiest after one install)**

```bash
gh auth login
git push -u origin main
```

**Option 2 — Personal Access Token (PAT)**

1. GitHub → your avatar → **Settings** → **Developer settings** → **Personal access tokens**
2. Fine-grained token on this repo with **Contents: Read and write**, or a classic token with `repo` scope
3. When Git asks for a password, paste the **token**, not your GitHub password

**Option 3 — SSH**

```bash
ssh-keygen -t ed25519 -C "you@example.com"
# then add ~/.ssh/id_ed25519.pub in GitHub → Settings → SSH and GPG keys
git remote set-url origin git@github.com:YOUR-USER/sas2r-guide.git
git push -u origin main
```

### Step 8. Confirm it landed

Refresh `https://github.com/YOUR-USER/sas2r-guide`.

You should see `app.R`, `R/`, `www/`, `README.md`, `LICENSE`.

### Step 9. Polish the repo page (2 minutes)

On the repo page, click the gear next to **About**:

- Description: same sentence as above
- Topics: `r`, `shiny`, `sas`, `tidyverse`, `education`
- Check **Releases**, uncheck wiki unless you will use it

That is the whole first publish.

---

## Path B — one command with GitHub CLI (`gh`)

Install: [https://cli.github.com](https://cli.github.com)

```bash
cd path/to/sas-to-r-learner
gh auth login
gh repo create sas2r-guide --public --source=. --remote=origin --push --description "Interactive SAS ↔ R learner guide with a teaching code converter (Shiny)"
```

`--source=.` uses this folder.  
`--push` sends `main`.  
Do **not** pass `--add-readme`.

Private instead of public:

```bash
gh repo create sas2r-guide --private --source=. --remote=origin --push
```

---

## Path C — you downloaded only the zip (no `.git` folder)

Unzip, then:

```bash
cd sas-to-r-learner
git init
git add .
git commit -m "Initial commit: SAS2R Guide Shiny app"
git branch -M main
```

Create the empty GitHub repo (Path A, Step 2), then:

```bash
git remote add origin https://github.com/YOUR-USER/sas2r-guide.git
git push -u origin main
```

---

## Day-2 commands you will actually use

After you edit files:

```bash
git status
git add -A
git commit -m "Describe the change in one sentence"
git push
```

Clone it onto another computer:

```bash
git clone https://github.com/YOUR-USER/sas2r-guide.git
cd sas2r-guide
```

In R:

```r
install.packages(c("shiny", "htmltools", "DT", "tidyverse", "haven"))
shiny::runApp()
```

---

## Optional: live demo on shinyapps.io

GitHub stores the code. It does not run Shiny by itself.

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(
  name   = "<account>",
  token  = "<token>",
  secret = "<secret>"
)
# run from the repo root
rsconnect::deployApp()
```

Then paste the shinyapps.io URL into the GitHub repo **About** website field.

---

## Mistakes that waste an hour (and the fix)

| What happened | Why | Fix |
| --- | --- | --- |
| `failed to push some refs` / non-fast-forward | GitHub repo was created **with** a README | Either recreate the GitHub repo empty, or `git pull origin main --allow-unrelated-histories`, resolve the README merge, then push |
| `remote origin already exists` | You added origin twice | `git remote remove origin` then add it again |
| Git asks for a password and rejects it | GitHub disabled account-password auth for Git | Use a PAT, `gh auth login`, or SSH |
| `src refspec main does not match any` | No commit exists yet | `git add .` then `git commit` then push |
| You pushed to `master` but GitHub shows `main` | Default branch name mismatch | `git branch -M main` then `git push -u origin main` |
| Large files / secrets | Accidental `.RData`, tokens | They are in `.gitignore`. If you already committed a secret, rotate the token; do not only delete the file |

Never commit:

- `.Rhistory`, `.RData`, `.Ruserdata`
- `rsconnect/` secrets
- real `.Renviron` with tokens

---

## Repair block (folder is not a Git repo)

```bash
cd path/to/sas-to-r-learner
git init
git add .
git commit -m "Initial commit: SAS2R Guide Shiny app"
git branch -M main
git remote add origin https://github.com/YOUR-USER/sas2r-guide.git
git push -u origin main
```

---

## Done when

- `https://github.com/YOUR-USER/sas2r-guide` shows the project files
- `git status` on your laptop says `Your branch is up to date with 'origin/main'`
- A teammate can `git clone` and run `shiny::runApp()`
