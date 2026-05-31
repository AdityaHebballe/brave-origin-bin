#!/usr/bin/env bash
set -euo pipefail

repo="brave/brave-browser"
pkgname="brave-origin-bin"
pkgbase="${pkgname%-bin}"

current_ver="$(sed -n 's/^pkgver=//p' PKGBUILD)"

curl_headers=(-H "Accept: application/vnd.github+json")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

latest_ver="$(
  curl -fsSL "${curl_headers[@]}" "https://api.github.com/repos/${repo}/releases?per_page=50" |
    jq -r '
      .[]
      | select(.draft == false)
      | .tag_name as $tag
      | ($tag | ltrimstr("v")) as $ver
      | select(any(.assets[]?.name; . == ("brave-origin_" + $ver + "_amd64.deb")))
      | select(any(.assets[]?.name; . == ("brave-origin_" + $ver + "_arm64.deb")))
      | $ver
    ' |
    head -n1
)"

if [[ -z "${latest_ver}" ]]; then
  echo "No stable Brave Origin release with amd64 and arm64 assets found." >&2
  exit 1
fi

if [[ "${latest_ver}" == "${current_ver}" ]]; then
  echo "Already current: ${current_ver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

amd64_url="https://github.com/${repo}/releases/download/v${latest_ver}/${pkgbase}_${latest_ver}_amd64.deb.sha256"
arm64_url="https://github.com/${repo}/releases/download/v${latest_ver}/${pkgbase}_${latest_ver}_arm64.deb.sha256"

curl -fL "${amd64_url}" -o "${tmpdir}/${pkgbase}_${latest_ver}_amd64.deb.sha256"
curl -fL "${arm64_url}" -o "${tmpdir}/${pkgbase}_${latest_ver}_arm64.deb.sha256"

script_sum="$(sha256sum "${pkgname}.sh" | awk '{print $1}')"
amd64_sum="$(awk '{print $1}' "${tmpdir}/${pkgbase}_${latest_ver}_amd64.deb.sha256")"
arm64_sum="$(awk '{print $1}' "${tmpdir}/${pkgbase}_${latest_ver}_arm64.deb.sha256")"

for sum in "${script_sum}" "${amd64_sum}" "${arm64_sum}"; do
  if [[ ! "${sum}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Invalid SHA256 checksum: ${sum}" >&2
    exit 1
  fi
done

sed -i \
  -e "s/^pkgver=.*/pkgver=${latest_ver}/" \
  -e "s/^pkgrel=.*/pkgrel=1/" \
  -e "s/^sha256sums=.*/sha256sums=('${script_sum}')/" \
  -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${amd64_sum}')/" \
  -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${arm64_sum}')/" \
  PKGBUILD

makepkg --printsrcinfo > .SRCINFO

echo "Updated ${pkgname}: ${current_ver} -> ${latest_ver}"
