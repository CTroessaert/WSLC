# Configuration du container DevBox côté Windows.
# Pour des réglages propres à un poste, créez config\devbox.local.psd1 (ignoré par git) :
# ses clés remplacent celles de ce fichier.
@{
    # Image publiée par la GitHub Action. Épingler une version : 'ghcr.io/ctroessaert/wslc:v2026.10.12'
    Image              = 'ghcr.io/ctroessaert/wslc:latest'

    ContainerName      = 'devbox'
    HostName           = 'devbox'

    # Volume wslc monté sur /home/dev : conserve az login, tokens, clés SSH, repos... entre deux mises à jour
    HomeVolume         = 'wslc-devbox-home'

    # Shell ouvert par Enter-DevBox.ps1 : 'pwsh' ou 'bash'
    Shell              = 'pwsh'

    TimeZone           = 'Europe/Paris'

    # Montages supplémentaires 'C:\chemin\windows:/chemin/linux' ou 'volume:/chemin'
    ExtraMounts        = @()

    # Limites de ressources (vide = valeurs par défaut de wslc), ex. '8G' et '4'
    Memory             = ''
    Cpus               = ''

    # Mise à jour automatique : à l'ouverture de session (+5 min) et chaque jour à cette heure
    UpdateTime         = '12:30'

    # Ne pas recréer le container si une session interactive y est ouverte (réessai au passage suivant)
    SkipUpdateWhenBusy = $true
}
