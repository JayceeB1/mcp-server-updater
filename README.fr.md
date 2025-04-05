# MCP Server Updater

Un outil PowerShell pour analyser et mettre à jour les serveurs Model Context Protocol (MCP) pour Claude Desktop.

![Bannière MCP Server Updater](https://raw.githubusercontent.com/JayceeB1/mcp-server-updater/main/assets/banner.svg)

## 🌟 Fonctionnalités

- **Détection automatique des serveurs MCP** : Lit votre configuration Claude Desktop pour trouver tous les serveurs MCP configurés.
- **Analyse intelligente des dépôts** : Détecte les dépôts Git même s'ils sont dans des répertoires parents.
- **Support multi-technologies** : Gère différents types de projets dont Node.js, Python, Go, Java, Rust, .NET et C/C++.
- **Rapports détaillés** : Fournit une analyse complète de tous vos serveurs MCP.
- **Vérification automatique des mises à jour** : Identifie les serveurs avec des mises à jour disponibles.
- **Mises à jour confirmées par l'utilisateur** : Demande une confirmation avant d'appliquer les mises à jour.
- **Mises à jour sécurisées** : Met de côté les modifications locales (`git stash`) avant d'appliquer les mises à jour (si des modifications existent).
- **Processus de build intelligent** : Exécute automatiquement les commandes de build appropriées selon le type de projet après la mise à jour.
- **Localisation Standardisée** : Utilise le système de localisation standard de PowerShell (fichiers `.psd1`), facilement extensible.

## 📋 Prérequis

- Windows 10/11
- PowerShell 5.1 ou ultérieur
- Git installé et dans votre PATH
- Claude Desktop installé
- Gestionnaires de paquets pour vos serveurs MCP (npm, pip, etc.)

## 🚀 Démarrage rapide

1.  Téléchargez la dernière version ou clonez ce dépôt :
    ```
    git clone https://github.com/JayceeB1/mcp-server-updater.git
    cd mcp-server-updater
    ```

2.  Exécutez le script depuis PowerShell :
    ```powershell
    # Autoriser l'exécution du script (si nécessaire, lancez PowerShell en tant qu'administrateur)
    # Set-ExecutionPolicy RemoteSigned -Scope CurrentUser 

    # Lancer l'outil de mise à jour
    .\Update-MCP-Servers.ps1 
    ```
    Le script analysera vos serveurs, affichera leur statut et vous demandera si vous souhaitez mettre à jour ceux qui ont des changements en attente.

3.  Pour utiliser une langue spécifique (par exemple, le français) :
    ```powershell
    .\Update-MCP-Servers.ps1 -Language fr-FR 
    ```
    *(Voir la section Localisation pour plus de détails)*

## 📊 Fonctionnement

L'outil effectue les opérations suivantes séquentiellement :

1.  **Phase d'analyse** :
    - Lit le fichier de configuration de Claude Desktop (`%APPDATA%\Claude\claude_desktop_config.json`) pour identifier tous les serveurs MCP.
    - Détecte l'emplacement de chaque serveur sur le disque.
    - Trouve le dépôt Git associé à chaque serveur (en cherchant dans les répertoires parents si nécessaire).
    - Détermine le type de projet et les outils de build nécessaires.
    - Vérifie si des mises à jour sont disponibles depuis le dépôt distant (`git fetch` + `git rev-list`).

2.  **Phase de rapport** :
    - Affiche des informations détaillées et le statut de mise à jour pour chaque serveur.
    - Génère un rapport JSON détaillé (`mcp-detailed-analysis.json`).
    - Génère un journal des opérations (`mcp-updater-log.txt`).

3.  **Phase de confirmation de mise à jour** :
    - Si des serveurs ont des mises à jour disponibles, ils sont listés.
    - Demande une confirmation à l'utilisateur (`O/N`) avant de procéder aux mises à jour.

4.  **Phase de mise à jour** (si confirmée par l'utilisateur) :
    - Pour chaque serveur confirmé pour la mise à jour :
        - Met de côté les modifications locales non validées avec `git stash` (optionnel, si des modifications existent).
        - Récupère les dernières modifications du dépôt distant (`git pull`).
        - Installe les dépendances à l'aide du gestionnaire de paquets approprié (npm, pip, etc.).
        - Compile le code mis à jour avec le système de build correct (npm run build, mvn install, etc.).
    - Rapporte le succès ou l'échec de chaque mise à jour.

## 🛠️ Types de projets pris en charge

| Type       | Méthode de détection                  | Commandes de mise à jour                     |
| :--------- | :-------------------------------- | :---------------------------------- |
| Node.js    | `package.json`                    | `npm install`, `npm run build`      |
| TypeScript | `tsconfig.json`                   | `npm install`, `npm run build`      |
| Python     | `requirements.txt`, `Pipfile`, `setup.py` | `pip install`, `pipenv install` |
| Go         | `go.mod`                          | `go mod download`, `go build`       |
| Java       | `pom.xml`, `gradlew`              | `mvn clean install`, `./gradlew build` |
| Rust       | `Cargo.toml`                      | `cargo build`                       |
| .NET       | `*.csproj`                        | `dotnet restore`, `dotnet build`    |
| C/C++      | `Makefile`, `CMakeLists.txt`      | `make`, `cmake`                     |

## 🔧 Configuration

Aucune configuration spéciale n'est requise pour le script lui-même. Il lit automatiquement votre configuration Claude Desktop depuis :

```
%APPDATA%\Claude\claude_desktop_config.json
```

Assurez-vous que ce fichier liste correctement vos serveurs MCP.

## 🌐 Localisation

L'outil utilise le mécanisme de localisation standard de PowerShell. Les chaînes de caractères destinées à l'utilisateur sont stockées dans des fichiers `.psd1` situés dans des sous-répertoires spécifiques à chaque langue sous le dossier `Strings` (par ex., `Strings\en-US`, `Strings\fr-FR`).

- **Langues prises en charge :**
    - Anglais (`en-US`) - Par défaut
    - Français (`fr-FR`)

- **Sélection de la langue :**
    1.  **Paramètre :** Utilisez le paramètre `-Language` avec un code de culture pris en charge (par ex., `.\Update-MCP-Servers.ps1 -Language fr-FR`).
    2.  **Défaut système :** Si `-Language` n'est pas fourni, le script tente d'utiliser la culture d'interface utilisateur actuelle de votre système (`$PSUICulture.Name`).
    3.  **Repli :** Si ni la langue spécifiée ni la culture système ne possèdent de fichier `.psd1` correspondant, le script utilise `en-US`.

- **Ajouter une nouvelle langue :**
    1.  Créez un nouveau sous-répertoire dans `Strings` en utilisant le code de culture approprié (par ex., `es-ES` pour l'espagnol).
    2.  Copiez `Strings\en-US\Update-MCP-Servers.psd1` dans votre nouveau répertoire.
    3.  Traduisez les valeurs des chaînes dans le fichier `.psd1` copié.
    4.  Vous pouvez maintenant utiliser la nouvelle langue via le paramètre `-Language` (par ex., `-Language es-ES`).

## 🔍 Utilisation avancée

### Arguments de ligne de commande

```powershell
.\Update-MCP-Servers.ps1 [-Language <codeCulture>]
```

- `-Language <codeCulture>` : Définit la langue d'affichage. Utilisez les codes de culture standard comme `en-US`, `fr-FR`, etc.

*(Note : Les arguments `-Update` et `-ForceUpdate` ont été supprimés. Le script vérifie maintenant automatiquement les mises à jour et demande confirmation.)*

### Variables d'environnement

- `MCP_UPDATER_BACKUP_DIR` : (Non implémenté actuellement) Emplacement personnalisé pour les sauvegardes.
- `MCP_UPDATER_LOG_LEVEL` : (Non implémenté actuellement) Définir sur DEBUG pour des journaux plus détaillés.

## 🚀 Principales améliorations

Par rapport aux méthodes de mise à jour basiques, cet outil offre :

1.  **Détection intelligente des dépôts Git** - Recherche dans les répertoires parents.
2.  **Interface utilisateur améliorée** - Affichage clair avec code couleur.
3.  **Localisation Standardisée** - Facilement extensible via les fichiers `.psd1`.
4.  **Exécution Simplifiée** - Pas d'arguments complexes requis pour l'opération de base.
5.  **Analyse approfondie des projets** - Détection automatique du type de projet et des commandes de build.
6.  **Protection des modifications locales** - Met de côté les modifications locales avant la mise à jour.
7.  **Compatibilité multiplateforme** - Fonctionne avec différents types de serveurs MCP.

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à soumettre une Pull Request. Envisagez d'ajouter des traductions pour de nouvelles langues !

## ☕ Soutenir le développement

Si vous trouvez ce module utile, envisagez de m'offrir un café pour soutenir son développement !

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jayceeB1)

Votre soutien est grandement apprécié et contribue à maintenir et améliorer ce projet !

## 📣 Remerciements

Cet outil a été créé avec l'aide de Claude, un assistant IA d'Anthropic.

## 📝 Autres langues

- [README en anglais](README.md)
