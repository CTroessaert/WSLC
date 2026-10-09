# Fonctions utilisées pendant le build de l'image (sourcées par le Dockerfile).

# Architecture au format Debian/Go : amd64 | arm64
arch_deb() { echo "${TARGETARCH:-$(dpkg --print-architecture)}"; }

# Architecture au format .NET/Bicep/PowerShell : x64 | arm64
arch_alt() { [ "$(arch_deb)" = "arm64" ] && echo arm64 || echo x64; }
