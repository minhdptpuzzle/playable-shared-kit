# Playable Build Tools

`playable-build` contains the Cocos playable build helper tools imported from `GrillFever-Playable-Cocos`.

Use the root wrapper so commands run against this Cocos project:

```powershell
node tools/playable-build.cjs doctor
npm run playable:doctor
```

## Layout

- `tools/playable-build.cjs` is the root CLI entrypoint used by `package.json`.
- `tools/playable-build/playable-cli.cjs` contains the build, install, config export, and subtree pull logic.
- `tools/playable-build/playable-cli.config.cjs` contains local defaults for Cocos discovery, install folders, ad platform retention, and subtree settings.
- `tools/playable-build/playable-cli.config_TEMPLATE.cjs` is the fallback template used when the config file is missing.
- `tools/playable-build/build_project.*`, `install_all.*`, and `subtree_pull.*` are shell wrappers that now jump back to the project root before invoking the CLI.

## NPM Scripts

```powershell
npm run playable:doctor
npm run playable:setup
npm run playable:setup:fast
npm run playable:export-configs
npm run playable:build
npm run playable:build:fast
npm run playable:build:seq
npm run playable:build:maxcpu
npm run playable:build:short
npm run playable:build:mid
npm run playable:build:long
npm run playable:subtree:pull
```

The scripts are namespaced with `playable:*` so they do not replace the existing `memory:*` tooling.

