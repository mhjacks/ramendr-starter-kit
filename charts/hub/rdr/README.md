# RDR (Regional DR) chart

Helm chart for Regional DR configuration (cluster pair, install_config, DRPC, etc.).

## Updating the default install_config JSON files

When `values.yaml` is changed (e.g. machine types, networking CIDRs, platform settings) under `regionalDR[0].clusters.primary.install_config` or `secondary.install_config`, the chart’s fallback files must be kept in sync so minimal `regionalDR` values still produce a full install_config.

From the **repository root**:

```bash
./scripts/update-rdr-default-install-config-json.sh
```

- **What it does:** Reads `charts/hub/rdr/values.yaml`, extracts both `install_config` sections, and overwrites:
  - `charts/hub/rdr/files/default-primary-install-config.json`
  - `charts/hub/rdr/files/default-secondary-install-config.json`
- **When to run:** After editing `install_config` in this chart’s `values.yaml`.
- **Dry-run:** To print the generated JSON without writing files:
  ```bash
  ./scripts/update-rdr-default-install-config-json.sh --dry-run
  ```
- **Requirements:** Python 3 with PyYAML (`pip install pyyaml`), or `yq` (and optionally `jq`).

Then run the install_config tests to confirm nothing is broken:

```bash
./scripts/test-rdr-install-config.sh
```
