# opencli-plugin-ata

An opencli plugin: ata

## Install

```bash
# From local development directory
opencli plugin install file:///private/tmp/browser-ops/ata

# From GitHub (after publishing)
opencli plugin install github:<user>/opencli-plugin-ata
```

## Commands

| Command | Type | Description |
|---------|------|-------------|
| `ata/hello` | YAML | Sample YAML command |
| `ata/greet` | TypeScript | Sample TS command |

## Development

```bash
# Install locally for development (symlinked, changes reflect immediately)
opencli plugin install file:///private/tmp/browser-ops/ata

# Verify commands are registered
opencli list | grep ata

# Run a command
opencli ata hello
opencli ata greet --name World
```
