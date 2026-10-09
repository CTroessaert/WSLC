# syntax=docker/dockerfile:1
# DevBox : poste d'administration Azure / Microsoft 365 / PowerShell 7
# exécuté comme container WSL (wslc). Image multi-arch (amd64 + arm64).
#
# Les versions des outils sont épinglées ci-dessous et mises à jour par Renovate
# (une PR par outil, voir renovate.json). Chaque ARG est déclaré juste avant
# l'étape qui l'utilise pour que le cache ne reconstruise que cette étape.
# Les paquets Ubuntu, eux, suivent « apt upgrade » au build hebdomadaire.
FROM ubuntu:24.04

ARG TARGETARCH
ARG USERNAME=dev
ARG USER_UID=1000

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
 && install -d -m 0755 /etc/apt/keyrings \
 && rm -rf /var/lib/apt/lists/*

# Azure CLI (dépôt apt Microsoft)
# renovate: datasource=pypi depName=azure-cli
ARG AZURE_CLI_VERSION=2.91.0
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends "azure-cli=${AZURE_CLI_VERSION}-1~$(lsb_release -cs)" \
 && rm -rf /var/lib/apt/lists/*

# Node.js (requis par CLI for Microsoft 365) : le dépôt NodeSource dépend de la version majeure
# renovate: datasource=node-version depName=node
ARG NODE_VERSION=22.23.3
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION%%.*}.x" | bash - \
 && apt-get install -y --no-install-recommends "nodejs=${NODE_VERSION}-1nodesource1" \
 && rm -rf /var/lib/apt/lists/*

# PowerShell 7 (archive officielle : seule méthode commune à amd64 et arm64)
# renovate: datasource=github-releases depName=PowerShell/PowerShell extractVersion=^v(?<version>.+)$
ARG PWSH_VERSION=7.6.6
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-$(arch_alt).tar.gz" -o /tmp/pwsh.tgz \
 && mkdir -p /opt/microsoft/powershell/7/Scripts/InstalledScriptInfos \
 && tar -xzf /tmp/pwsh.tgz -C /opt/microsoft/powershell/7 \
 && chmod +x /opt/microsoft/powershell/7/pwsh \
 && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
 && echo /usr/bin/pwsh >> /etc/shells \
 && rm /tmp/pwsh.tgz
# ↑ $PSHOME/Scripts/InstalledScriptInfos : sans ce dossier, ExchangeOnlineManagement échoue à l'import en non-root

# Bicep
# renovate: datasource=github-releases depName=Azure/bicep extractVersion=^v(?<version>.+)$
ARG BICEP_VERSION=0.48.1
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://github.com/Azure/bicep/releases/download/v${BICEP_VERSION}/bicep-linux-$(arch_alt)" -o /usr/local/bin/bicep \
 && chmod +x /usr/local/bin/bicep

# Azure Developer CLI
# renovate: datasource=github-releases depName=Azure/azure-dev extractVersion=^azure-dev-cli_(?<version>.+)$
ARG AZD_VERSION=1.35.1
RUN curl -fsSL https://aka.ms/install-azd.sh | bash -s -- --version "${AZD_VERSION}"

# kubectl
# renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.+)$
ARG KUBECTL_VERSION=1.37.1
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/$(arch_deb)/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && kubectl completion bash > /etc/bash_completion.d/kubectl

# Helm
# renovate: datasource=github-releases depName=helm/helm extractVersion=^v(?<version>.+)$
ARG HELM_VERSION=4.3.0
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-$(arch_deb).tar.gz" | tar -xz -C /tmp \
 && mv "/tmp/linux-$(arch_deb)/helm" /usr/local/bin/helm \
 && rm -rf "/tmp/linux-$(arch_deb)" \
 && helm completion bash > /etc/bash_completion.d/helm

# GitHub CLI (archive : le dépôt apt ne conserve que la dernière version)
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.+)$
ARG GH_VERSION=2.102.0
RUN source /tmp/build/lib.sh \
 && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_$(arch_deb).tar.gz" | tar -xz -C /tmp \
 && mv "/tmp/gh_${GH_VERSION}_linux_$(arch_deb)/bin/gh" /usr/local/bin/gh \
 && rm -rf "/tmp/gh_${GH_VERSION}_linux_$(arch_deb)" \
 && gh completion -s bash > /etc/bash_completion.d/gh

# CLI for Microsoft 365
# renovate: datasource=npm depName=@pnp/cli-microsoft365
ARG M365_CLI_VERSION=11.11.0
RUN npm install -g "@pnp/cli-microsoft365@${M365_CLI_VERSION}" \
 && npm cache clean --force

# Modules PowerShell (scope AllUsers), une couche par module.
# Pour ajouter un module : copier un bloc, puis l'ajouter à devbox-versions.
# renovate: datasource=nuget depName=Az registryUrl=https://www.powershellgallery.com/api/v2/
ARG PSMODULE_AZ_VERSION=16.4.0
RUN bash /tmp/build/install-psmodule.sh Az "${PSMODULE_AZ_VERSION}"

# renovate: datasource=nuget depName=Microsoft.Graph registryUrl=https://www.powershellgallery.com/api/v2/
ARG PSMODULE_GRAPH_VERSION=2.41.1
RUN bash /tmp/build/install-psmodule.sh Microsoft.Graph "${PSMODULE_GRAPH_VERSION}"

# renovate: datasource=nuget depName=ExchangeOnlineManagement registryUrl=https://www.powershellgallery.com/api/v2/
ARG PSMODULE_EXO_VERSION=3.10.1
RUN bash /tmp/build/install-psmodule.sh ExchangeOnlineManagement "${PSMODULE_EXO_VERSION}"

# renovate: datasource=nuget depName=MicrosoftTeams registryUrl=https://www.powershellgallery.com/api/v2/
ARG PSMODULE_TEAMS_VERSION=8.0.0
RUN bash /tmp/build/install-psmodule.sh MicrosoftTeams "${PSMODULE_TEAMS_VERSION}"

# renovate: datasource=nuget depName=PnP.PowerShell registryUrl=https://www.powershellgallery.com/api/v2/
ARG PSMODULE_PNP_VERSION=3.4.1
RUN bash /tmp/build/install-psmodule.sh PnP.PowerShell "${PSMODULE_PNP_VERSION}"

# Utilisateur non-root (uid 1000) avec sudo sans mot de passe.
# /home/dev est un volume wslc persistant, initialisé au premier démarrage.
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u "${USER_UID}" -s /bin/bash "${USERNAME}" \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
 && rm -rf /tmp/build

COPY --chmod=0755 rootfs/usr/local/bin/ /usr/local/bin/

LABEL org.opencontainers.image.title="wslc-devbox" \
      org.opencontainers.image.description="Container WSL (wslc) : Azure CLI, azd, Bicep, PowerShell 7 + modules Az/Graph/EXO/Teams/PnP, CLI for Microsoft 365, kubectl, helm, gh"

WORKDIR /home/${USERNAME}
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/devbox-init"]
CMD ["sleep", "infinity"]
