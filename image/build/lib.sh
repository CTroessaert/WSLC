# Fonctions utilisées pendant le build de l'image (sourcées par le Dockerfile).

# Architecture au format Debian/Go : amd64 | arm64
arch_deb() { echo "${TARGETARCH:-$(dpkg --print-architecture)}"; }

# Architecture au format .NET/Bicep/PowerShell : x64 | arm64
arch_alt() { [ "$(arch_deb)" = "arm64" ] && echo arm64 || echo x64; }

# Dernier tag stable d'un dépôt GitHub, via la redirection de /releases/latest
# (évite la limite de requêtes de l'API GitHub non authentifiée).
gh_latest() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/##'
}
