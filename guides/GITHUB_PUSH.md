# GitHub Push Guide

## Initialize and commit (already done by automation if this repo was empty)

```bash
git init
git add .
git commit -m "Initial FileTransferApp"
```

## Add remote and push

```bash
git remote add origin <YOUR_GITHUB_REPO_URL>
git branch -M main
git push -u origin main
```

Example remote URLs:

- HTTPS: `https://github.com/<user>/<repo>.git`
- SSH: `git@github.com:<user>/<repo>.git`
