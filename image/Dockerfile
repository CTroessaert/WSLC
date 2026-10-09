# syntax=docker/dockerfile:1
# DevBox : poste d'administration Azure / Microsoft 365 / PowerShell 7
# exécuté comme container WSL (wslc). Image multi-arch (amd64 + arm64).
#
# Les outils sont installés en "dernière version stable" au moment du build :
# la GitHub Action reconstruit l'image chaque semaine sans cache et publie une
# release uniquement si une version (ou un paquet OS) a changé.
FROM ubuntu:24.04

ARG TARGETARCH
ARG USERNAME=dev
ARG USER_UID=1000
ARG NODE_MAJOR=22
ARG PS_MODULES="Az Microsoft.Graph ExchangeOnlineManagement MicrosoftTeams PnP.PowerShell"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Europe/Paris \
    DEVBOX_USER=${USERNAME} \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    AZURE_CORE_COLLECT_TELEMETRY=0 \
    AZURE_BICEP_USE_BINARY_FROM_PATH=true \
    AZURE_BICEP_CHECK_VERSION=false \
    AZD_SKIP_UPDATE_CHECK=1 \
    AZURE_DEV_COLLECT_TELEMETRY=no \
    CLIMICROSOFT365_NOUPDATE=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY build/ /tmp/build/

# Outils de base
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release apt-transport-https \
      git openssh-client jq unzip zip less vim nano sudo tzdata locales \
      bash-completion dnsutils iputils-ping netcat-openbsd tini python3 \
      libicu74 \
 && rm -rf /var/lib/apt/lists/*

# Azure CLI (dépôt apt Microsoft), GitHub CLI et Node.js (pour CLI for Microsoft 365)
RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
 && apt-get install -y --no-install-recommends gh nodejs \
 && rm -rf /var/lib/apt/lists/*

# PowerShell 7 (archive officielle : seule méthode commune à amd64 et arm64)
RUN source /tmp/build/lib.sh \
 && v="$(gh_latest PowerShell/PowerShell)" \
 && curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/${v}/powershell-${v#v}-linux-$(arch_alt).tar.gz" -o /tmp/pwsh.tgz \
 && mkdir -p /opt/microsoft/powershell/7 \
 && tar -xzf /tmp/pwsh.tgz -C /opt/microsoft/powershell/7 \
 && chmod +x /opt/microsoft/powershell/7/pwsh \
 && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
 && echo /usr/bin/pwsh >> /etc/shells \
 && rm /tmp/pwsh.tgz

# Modules PowerShell (scope AllUsers : ils font partie de l'image et suivent ses mises à jour)
RUN pwsh -NoLogo -NoProfile -Command ' \
      $ErrorActionPreference = "Stop"; \
      Install-PSResource -Name ($env:PS_MODULES -split " ") -Scope AllUsers -TrustRepository -AcceptLicense -Quiet; \
      Get-InstalledPSResource -Scope AllUsers -Name ($env:PS_MODULES -split " ") | Format-Table Name, Version'

# Bicep, azd, kubectl, helm
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://github.com/Azure/bicep/releases/latest/download/bicep-linux-$(arch_alt)" -o /usr/local/bin/bicep \
 && chmod +x /usr/local/bin/bicep \
 && curl -fsSL https://aka.ms/install-azd.sh | bash \
 && k="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" \
 && curl -fsSL "https://dl.k8s.io/release/${k}/bin/linux/$(arch_deb)/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && h="$(gh_latest helm/helm)" \
 && curl -fsSL "https://get.helm.sh/helm-${h}-linux-$(arch_deb).tar.gz" | tar -xz -C /tmp \
 && mv "/tmp/linux-$(arch_deb)/helm" /usr/local/bin/helm \
 && rm -rf "/tmp/linux-$(arch_deb)" \
 && kubectl completion bash > /etc/bash_completion.d/kubectl \
 && helm completion bash > /etc/bash_completion.d/helm \
 && gh completion -s bash > /etc/bash_completion.d/gh

# CLI for Microsoft 365
RUN npm install -g @pnp/cli-microsoft365 \
 && npm cache clean --force

# Utilisateur non-root (uid 1000) avec sudo sans mot de passe.
# /home/dev est un volume wslc persistant, initialisé au premier démarrage.
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u "${USER_UID}" -s /bin/bash "${USERNAME}" \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
 && mkdir -p /opt/microsoft/powershell/7/Scripts \
 && rm -rf /tmp/build
# ↑ ExchangeOnlineManagement échoue à l'import (non-root) si $PSHOME/Scripts n'existe pas

COPY --chmod=0755 rootfs/usr/local/bin/ /usr/local/bin/

LABEL org.opencontainers.image.title="wslc-devbox" \
      org.opencontainers.image.description="Container WSL (wslc) : Azure CLI, azd, Bicep, PowerShell 7 + modules Az/Graph/EXO/Teams/PnP, CLI for Microsoft 365, kubectl, helm, gh"

WORKDIR /home/${USERNAME}
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-init"]
CMD ["sleep", "infinity"]
