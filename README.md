# Les Eclats de Chartres - Base jouable Godot 4

Base 2D plateforme/aventure avec hub, niveau jouable, systeme de vitraux, UI d'equipement et sauvegarde.

## Lancement

1. Ouvrir le dossier dans Godot 4.2+.
2. Lancer la scene principale `res://scenes/main/Main.tscn` (definie dans `project.godot`).
3. Tester:
   - `A/D`: deplacement
   - `Q` ou `A`: gauche (selon clavier)
   - `Fleches gauche/droite`: deplacement alternatif
   - `Espace`: saut (double saut si Vitrail Orange equipe)
   - `Shift`: dash
   - `J`: utiliser pouvoir principal / attaquer
   - `E`: interagir (recuperer fragment)
   - `I`: ouvrir/fermer l'equipement
   - `1..8`: equiper/desequiper les vitraux de la liste
   - `Entree`: entrer dans le niveau depuis le hub
   - `Echap`: retour au hub

## Structure du projet

- `scripts/core`
  - `GameState.gd`: progression, inventaire vitraux, slots, events
  - `SaveSystem.gd`: sauvegarde JSON dans `user://save_game.json`
- `scripts/player`
  - `PlayerController.gd`: mouvement, saut, dash, interaction
- `scripts/powers`
  - `StainedGlassPower.gd`: definition des IDs de vitraux
  - `PowerManager.gd`: activation des effets de vitraux equipes
- `scripts/enemies`
  - `EnemyBase.gd`: IA patrouille simple + degats/faiblesses
  - `ShadowEnemy.gd`: ennemi faible a certains vitraux
- `scripts/interactables`
  - `BreakableWall.gd`: obstacle cassable via Rouge
  - `InvisiblePlatform.gd`: visible avec Bleu
  - `FragmentPickup.gd`: fragment principal du niveau
- `scripts/ui`
  - `EquipmentUI.gd`: interface equipement vitraux (slots 2 puis 3)
- `scripts/main`
  - `Main.gd`: hub cathedrale + chargement du niveau
- `scripts/levels`
  - `LevelController.gd`: logique locale de niveau

- `scenes/main/Main.tscn`: hub + conteneur de niveau + UI
- `scenes/player/Player.tscn`: personnage jouable
- `scenes/levels/Level_VieilleVille.tscn`: niveau jouable de base
- `scenes/enemies/ShadowEnemy.tscn`: ennemi de base
- `scenes/interactables/*.tscn`: objets puzzle/collecte
- `scenes/ui/EquipmentUI.tscn`: menu equipement

## Ce qui est implemente

- Hub principal cathedrale avec progression visible
- 1 niveau jouable (Vieille ville)
- Joueur fonctionnel: deplacement, saut, dash, interaction
- 3 vitraux jouables:
  - Bleu: revele plateformes invisibles
  - Rouge: casse les murs destructibles
  - Orange: boost dash + double saut
- UI equipement avec limite de slots
- Systeme de sauvegarde progression
- Ennemi simple + faiblesse de vitrail

## Extension rapide vers la version complete

- Ajouter de nouvelles scenes de zones:
  - `BordsEure`, `Souterrains`, `ZoneCorrompue`, `ZoneNaturelle`
- Ajouter des classes derivees pour les autres vitraux:
  - Temps, Ombre, Lumiere, Nature, Corruption
- Ajouter boss par zone:
  - heriter de `EnemyBase.gd` avec patterns specifiques
- Ajouter synergies:
  - verifier paires de vitraux dans `PowerManager.gd`
- Ajouter feedback visuel/sonore:
  - particles, shader glow, AudioStreamPlayer2D
