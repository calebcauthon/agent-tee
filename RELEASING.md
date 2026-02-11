# Releasing New Versions

## Option 1: Manual Update (Local Script)

After creating a new git tag:

```bash
# 1. Update version in t script
# 2. Commit changes
git add t
git commit -m "Your changes"

# 3. Create and push tag
git tag v0.1.2
git push origin v0.1.2

# 4. Run the update script
./update-homebrew.sh
```

The script will:
- Download the release tarball
- Calculate SHA256
- Update the formula in ~/code/homebrew-tap
- Commit and push the changes

## Option 2: Automatic Update (GitHub Actions)

Just push a new tag:

```bash
git tag v0.1.2
git push origin v0.1.2
```

The GitHub Actions workflow will automatically update the homebrew-tap formula.

**Setup required:** Add a `TAP_GITHUB_TOKEN` secret to your GitHub repo with push access to calebcauthon/homebrew-tap.

## Users Upgrade With:

```bash
brew update
brew upgrade agent-tee
```
