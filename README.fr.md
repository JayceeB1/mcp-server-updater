# MCP Server Updater

Un outil PowerShell pour analyser et mettre à jour les serveurs Model Context Protocol (MCP) pour Claude Desktop.

![Bannière MCP Server Updater](https://raw.githubusercontent.com/JayceeB1/mcp-server-updater/main/assets/banner.svg)

## 🌟 Fonctionnalités

- **Détection automatique des serveurs MCP** : Lit votre configuration Claude Desktop pour trouver tous les serveurs MCP configurés
- **Analyse intelligente des dépôts** : Détecte les dépôts Git même s'ils sont dans des répertoires parents
- **Support multi-technologies** : Gère différents types de projets dont Node.js, Python, Go, Java, Rust, .NET et C/C++
- **Rapports détaillés** : Fournit une analyse complète de tous vos serveurs MCP
- **Mises à jour sécurisées** : Crée des branches de sauvegarde avant d'appliquer les mises à jour
- **Processus de build intelligent** : Exécute automatiquement les commandes de build appropriées selon le type de projet
- **Support de localisation** : Disponible en plusieurs langues (anglais, français)

## 📋 Prérequis

- Windows 10/11
- PowerShell 5.1 ou ultérieur
- Git installé et dans votre PATH
- Claude Desktop installé
- Gestionnaires de paquets pour vos serveurs MCP (npm, pip, etc.)

## 🚀 Démarrage rapide

1. Téléchargez la dernière version ou clonez ce dépôt :
   ```
   git clone https://github.com/JayceeB1/mcp-server-updater.git
   ```
   
2. Exécutez le script depuis PowerShell :
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Update-MCP-Servers.ps1
   ```
   
3. Pour activer le mode de mise à jour :
   ```powershell
   .\Update-MCP-Servers.ps1 -Update
   ```
   
4. Pour utiliser une langue spécifique :
   ```powershell
   .\Update-MCP-Servers.ps1 -Language fr
   ```

## 📊 Fonctionnement

L'outil effectue les opérations suivantes :

1. **Phase d'analyse** :
   - Lit le fichier de configuration de Claude Desktop pour identifier tous les serveurs MCP
   - Détecte l'emplacement de chaque serveur sur le disque
   - Trouve le dépôt Git associé à chaque serveur
   - Détermine le type de projet et les outils de build nécessaires
   - Vérifie si des mises à jour sont disponibles depuis le dépôt distant

2. **Phase de rapport** :
   - Affiche des informations détaillées sur chaque serveur
   - Montre quels serveurs peuvent être mis à jour
   - Génère un rapport JSON détaillé

3. **Phase de mise à jour** (optionnelle) :
   - Crée des branches de sauvegarde pour préserver votre état actuel
   - Récupère les dernières modifications des dépôts distants
   - Installe les dépendances à l'aide du gestionnaire de paquets approprié
   - Compile le code mis à jour avec le système de build correct

## 🛠️ Types de projets pris en charge

| Type | Méthode de détection | Commandes de mise à jour |
|------|-----------------|-----------------|
| Node.js | package.json | npm install, npm run build |
| TypeScript | tsconfig.json | npm install, npm run build |
| Python | requirements.txt, Pipfile, setup.py | pip install, pipenv install |
| Go | go.mod | go mod download, go build |
| Java | pom.xml, gradlew | mvn clean install, ./gradlew build |
| Rust | Cargo.toml | cargo build |
| .NET | *.csproj | dotnet restore, dotnet build |
| C/C++ | Makefile, CMakeLists.txt | make, cmake |

## 🔧 Configuration

Aucune configuration spéciale n'est requise. Le script lit automatiquement votre configuration Claude Desktop depuis :

```
%APPDATA%\Claude\claude_desktop_config.json
```

## 🌐 Localisation

L'outil prend en charge plusieurs langues :

- Anglais (par défaut)
- Français

Pour exécuter le script dans une langue spécifique :

```powershell
.\Update-MCP-Servers.ps1 -Language fr
```

Consultez le [README de localisation](localization/README.md) pour plus de détails sur l'ajout de nouvelles langues.

## 🔍 Utilisation avancée

### Arguments de ligne de commande

```powershell
.\Update-MCP-Servers.ps1 [-Update] [-ForceUpdate] [-Language <en|fr>]
```

- `-Update` : Active la phase de mise à jour (une confirmation vous sera demandée)
- `-ForceUpdate` : Met à jour les serveurs sans demander de confirmation
- `-Language` : Définit la langue d'affichage (en=Anglais, fr=Français)

### Variables d'environnement

- `MCP_UPDATER_BACKUP_DIR` : Emplacement personnalisé pour les sauvegardes
- `MCP_UPDATER_LOG_LEVEL` : Définir sur DEBUG pour des journaux plus détaillés

## 🚀 Principales améliorations

Par rapport aux méthodes de mise à jour basiques, cet outil offre :

1. **Détection intelligente des dépôts Git** - Recherche les dépôts Git dans les répertoires parents
2. **Interface utilisateur améliorée** - Affichage clair avec code couleur
3. **Support multilingue** - Anglais et français, facilement extensible
4. **Options de ligne de commande** - Options flexibles pour les mises à jour et la sélection de la langue
5. **Analyse approfondie des projets** - Détection automatique du type de projet et des commandes de build appropriées
6. **Protection des modifications locales** - Crée des branches de sauvegarde avant la mise à jour
7. **Compatibilité multiplateforme** - Fonctionne avec différents types de serveurs MCP (Node.js, Python, etc.)

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à soumettre une Pull Request.

## 📣 Remerciements

Cet outil a été créé avec l'aide de Claude, un assistant IA d'Anthropic.

## 📝 Autres langues

- [README en anglais](README.md)
