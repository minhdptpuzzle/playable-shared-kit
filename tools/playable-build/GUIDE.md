# Playable Build Guide

Run commands from the project root:

```powershell
cd D:\_Projects\CC3\unity2cc_asset_converter\cocos_game
```

## 1. Check Environment

```powershell
npm run playable:doctor
```

The doctor command checks the project root, Cocos Creator discovery, build configs, builder profile, install folders, and git status. If Cocos is not found automatically, set one of these:

```powershell
$env:COCOS_CREATOR = "C:\ProgramData\cocos\editors\Creator\3.8.8\CocosCreator.exe"
npm run playable:doctor
```

or pass it directly:

```powershell
node tools/playable-build.cjs doctor --cocos "C:\ProgramData\cocos\editors\Creator\3.8.8\CocosCreator.exe"
```

## 2. Install Dependencies

Clean install all configured project folders:

```powershell
npm run playable:setup
```

Fast install without removing `node_modules` first:

```powershell
npm run playable:setup:fast
```

Configured install folders are in `tools/playable-build/playable-cli.config.cjs`.

## 3. Export Build Configs

If `profiles/v2/packages/builder.json` contains Cocos builder tasks, export them into `configs/*.json`:

```powershell
npm run playable:export-configs
```

The generated configs are the inputs for the build commands.

## 4. Build Playables

Build every config under `configs/`:

```powershell
npm run playable:build
```

Useful variants:

```powershell
npm run playable:build:fast
npm run playable:build:seq
npm run playable:build:maxcpu
```

Brief-specific shortcuts:

```powershell
npm run playable:build:short
npm run playable:build:mid
npm run playable:build:long
```

You can also run a custom brief name directly:

```powershell
node tools/playable-build.cjs build --brief brief1
```

## 5. Pull Playable Core

```powershell
npm run playable:subtree:pull
```

Subtree defaults are in `tools/playable-build/playable-cli.config.cjs`.

