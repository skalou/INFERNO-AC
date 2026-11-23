# INFERNO-Chat Alerts - Release Instructions

## Pour publier une nouvelle version

### 1. **Augmenter la version**
   Modifier `core/paths.lua` - ligne 10:
   ```lua
   version = '0.5.0',  -- X.Y.Z format
   ```

### 2. **Générer le ZIP de release**
   ```powershell
   cd C:\Users\r4fsc\source\repos\skalou\INFERNO-AC
   powershell -ExecutionPolicy Bypass -File .\release-build.ps1 -Version "X.Y.Z"
   ```

   Cela crée `INFERNO-AC-X.Y.Z.zip` avec la structure:
   ```
   assettocorsa/
   └── apps/
	   └── lua/
		   └── INFERNO-ChatAlerts/
			   ├── INFERNO-ChatAlerts.lua
			   ├── manifest.ini
			   ├── README.md
			   ├── core/
			   ├── lang/
			   ├── ui/
			   └── sounds/
				   └── DefaultAppSounds/
   ```

### 3. **Committer les changements**
   ```bash
   git add .
   git commit -m "Release vX.Y.Z: [description of changes]"
   git push origin wip/restore-lost-features
   ```

### 4. **Créer un tag et une release GitHub**
   ```bash
   git tag -a vX.Y.Z -m "INFERNO-Chat Alerts vX.Y.Z"
   git push origin vX.Y.Z
   ```

### 5. **Créer la release sur GitHub**
   - Aller sur: https://github.com/skalou/INFERNO-AC/releases/new
   - Tag: `vX.Y.Z`
   - Title: `INFERNO-Chat Alerts X.Y.Z`
   - Description: Les changements et améliorations
   - Uploader: `INFERNO-AC-X.Y.Z.zip`
   - Publish Release

## Structure du ZIP

Le ZIP généré ne contient **que les fichiers essentiels** au bon fonctionnement:
- ✅ INFERNO-ChatAlerts.lua (fichier principal)
- ✅ manifest.ini (config app Assetto Corsa)
- ✅ README.md (documentation)
- ✅ core/ (logique)
- ✅ lang/ (traductions)
- ✅ ui/ (interface)
- ✅ sounds/DefaultAppSounds/ (son par défaut)

Exclu du ZIP (via `.gitattributes` export-ignore):
- ❌ .git/, .vs/, session-state/
- ❌ Dev-Sounds/ (sons de développement)
- ❌ INFERNO-DEV/ (app de développement)
- ❌ icons/ (brouillons d'icônes)
- ❌ tools/ (outils de test)
- ❌ deploy.ps1, README_AI_NOTES.md

## Installation pour le joueur

1. Télécharger `INFERNO-AC-X.Y.Z.zip` depuis GitHub releases
2. Extraire le ZIP dans le dossier Assetto Corsa:
   ```
   C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\
   ```
3. La structure se crée automatiquement:
   ```
   assettocorsa\apps\lua\INFERNO-ChatAlerts\
   ```
4. Lancer Assetto Corsa et activer l'app

## Notes

- Le script `.gitattributes` avec `export-ignore` s'applique au ZIP généré par GitHub
- Le script `release-build.ps1` crée un ZIP local avec la structure correcte
- Toujours augmenter la version avant de publier
- Les tags doivent suivre le format: `vX.Y.Z` (ex: v0.5.0)
