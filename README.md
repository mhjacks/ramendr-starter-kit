# RamenDR Starter Kit

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![AWS](https://img.shields.io/endpoint?url=https%3A%2F%2Fstorage.googleapis.com%2Fhcp-results%2Faegitops-aws-ci.json)](https://storage.googleapis.com/hcp-results/aegitops-aws-ci.json)

## Start Here

If you've followed a link to this repository, but are not really sure what it contains
or how to use it, head over to [RamenDR Starter Kit](https://validatedpatterns.io/patterns/ramendr-starter-kit/)
for additional context and installation instructions.

## Variants

This pattern uses the clustergroup/ACM `variants/` folder layout. Presence of
`variants/` makes the patterns-operator set `global.vpNewFolderDir=true`.

Spoke BOMs nest under the install variant as
`variants/<variant>/values-<managedClusterGroup.name>.yaml`.

| Variant | Select | Purpose |
|---------|--------|---------|
| `hub` (default) | `main.variant: hub` | Baseline: full ODF Regional DR + Virtualization |
| `partner` | `main.variant: partner` | Partner CSI foundation: Submariner, OADP, OCP-V, Ramen/MCO; no ODF storage or Ramen CRs |

Layout:

```text
values-global.yaml
variants/
  hub/
    values-hub.yaml
    values-resilient.yaml              # full ODF spoke BOM
  partner/
    values-partner.yaml
    values-resilient.yaml              # partner spoke BOM (no ODF)
    values-regional-dr.yaml            # infrastructure DRPolicy/DRClusters; no DRPC/VMs
    values-console-plugins-*.yaml
overrides/                             # shared hub/spoke chart overrides
```

Example — set the variant in [`values-global.yaml`](values-global.yaml):

```yaml
main:
  variant: partner
```

Partner expectations after sync: Submariner and s3-ssl/CA via **opp-policy**, MCO (Ramen), CNV, and OADP present;
no odf-dr, MirrorPeer, DRPolicy/DRPC, or ODF StorageSystem.
