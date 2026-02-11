#!/bin/bash
#
# update-homebrew.sh - Update the homebrew-tap formula when releasing a new version
#
# Usage: ./update-homebrew.sh [version]
# If version is not provided, uses the latest git tag

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEBREW_TAP_DIR="${HOME}/code/homebrew-tap"

# Get version from argument or latest git tag
if [[ $# -gt 0 ]]; then
    VERSION="$1"
else
    VERSION=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -z "$VERSION" ]]; then
        echo "Error: No version specified and no git tags found" >&2
        echo "Usage: $0 [version]" >&2
        exit 1
    fi
fi

# Remove 'v' prefix if present
VERSION="${VERSION#v}"
TAG="v${VERSION}"

echo "Updating homebrew formula for version ${TAG}..."

# Check if homebrew-tap directory exists
if [[ ! -d "$HOMEBREW_TAP_DIR" ]]; then
    echo "Error: homebrew-tap directory not found at ${HOMEBREW_TAP_DIR}" >&2
    echo "Please clone your tap repo: git clone https://github.com/calebcauthon/homebrew-tap.git ~/code/homebrew-tap" >&2
    exit 1
fi

# Download release tarball and calculate SHA256
echo "Downloading release tarball..."
URL="https://github.com/calebcauthon/agent-tee/archive/refs/tags/${TAG}.tar.gz"
SHA256=$(curl -L "${URL}" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

echo "SHA256: ${SHA256}"

# Update the formula
echo "Updating formula..."
cat > "${HOMEBREW_TAP_DIR}/Formula/agent-tee.rb" << EOF
class AgentTee < Formula
  desc "Run commands while teeing stdout+stderr to per-concern log files"
  homepage "https://github.com/calebcauthon/agent-tee"
  url "${URL}"
  sha256 "${SHA256}"
  license "MIT"

  def install
    bin.install "t"
  end

  test do
    system "#{bin}/t", "--version"
    (testpath/".agent-tee/logs").mkpath
    system "#{bin}/t", "@test", "echo", "hello"
    assert_match "hello", (testpath/".agent-tee/logs/test.log").read
  end
end
EOF

# Commit and push changes
cd "$HOMEBREW_TAP_DIR"
git add Formula/agent-tee.rb
git commit -m "Update agent-tee to ${TAG}"
git push origin master

echo "✅ Successfully updated homebrew formula to ${TAG}"
echo ""
echo "Users can now upgrade with:"
echo "  brew update"
echo "  brew upgrade agent-tee"
