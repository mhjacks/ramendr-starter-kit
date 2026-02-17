{{/*
  Sanitize install_config for OpenShift installer: ensure apiVersion, pass through all
  install-config fields (including full platform.aws: region, subnets, userTags, amiID,
  defaultMachinePlatform, serviceEndpoints, etc.) so regionalDR and clusterOverrides
  can override platform/region effectively. Only strip keys known invalid for the
  installer (e.g. vpc in platform.aws).
*/}}
{{- define "rdr.sanitizeInstallConfig" -}}
{{- $raw := . -}}
{{- $withVersion := merge (dict "apiVersion" "v1") $raw -}}
{{- $platform := index $withVersion "platform" | default dict -}}
{{- $aws := index $platform "aws" | default dict -}}
{{- /* Pass through full platform.aws (region, subnets, userTags, amiID, defaultMachinePlatform, serviceEndpoints, etc.); omit only known-invalid keys like vpc */ -}}
{{- $awsSafe := ternary (omit $aws "vpc") $aws (and (kindIs "map" $aws) (hasKey $aws "vpc")) -}}
{{- $platformSafe := merge $platform (dict "aws" $awsSafe) -}}
{{- $allowed := dict "apiVersion" (index $withVersion "apiVersion") "baseDomain" (index $withVersion "baseDomain") "metadata" (index $withVersion "metadata") "controlPlane" (index $withVersion "controlPlane") "compute" (index $withVersion "compute") "networking" (index $withVersion "networking") "platform" $platformSafe "publish" (index $withVersion "publish") "pullSecret" (index $withVersion "pullSecret") "sshKey" (index $withVersion "sshKey") -}}
{{- $allowed | toJson -}}
{{- end -}}

{{/*
  Deep-merge install_config so clusterOverrides can override only platform/region,
  metadata, or any subset without replacing the rest of base install_config.
*/}}
{{- define "rdr.mergeInstallConfig" -}}
{{- $base := index . 0 -}}
{{- $over := index . 1 -}}
{{- $merged := merge ($base | default dict) ($over | default dict) -}}
{{- $metadataBase := index $base "metadata" | default dict -}}
{{- $metadataOver := index $over "metadata" | default dict -}}
{{- $merged := merge $merged (dict "metadata" (merge $metadataBase $metadataOver)) -}}
{{- $platformBase := index $base "platform" | default dict -}}
{{- $platformOver := index $over "platform" | default dict -}}
{{- $platformMerged := merge $platformBase $platformOver -}}
{{- $awsBase := index $platformBase "aws" | default dict -}}
{{- $awsOver := index $platformOver "aws" | default dict -}}
{{- $awsMerged := merge $awsBase $awsOver -}}
{{- $platformFinal := merge $platformMerged (dict "aws" $awsMerged) -}}
{{- merge $merged (dict "platform" $platformFinal) | toJson -}}
{{- end -}}

{{/*
  Effective primary cluster: merge of regionalDR[0].clusters.primary and clusterOverrides.primary.
  Use when clusterOverrides is set to avoid replacing full regionalDR in override file.
*/}}
{{- define "rdr.effectivePrimaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "primary" | default dict -}}
{{- $base := $dr.clusters.primary -}}
{{- $installConfig := fromJson (include "rdr.mergeInstallConfig" (list ($base.install_config | default dict) (index $over "install_config" | default dict))) -}}
{{- $installConfigSafe := fromJson (include "rdr.sanitizeInstallConfig" $installConfig) -}}
{{- $defaultBaseDomain := join "." (slice (splitList "." (.Values.global.clusterDomain | default "cluster.example.com")) 1) -}}
{{- $installConfigWithBase := merge $installConfigSafe (dict "baseDomain" (default $defaultBaseDomain (index $installConfigSafe "baseDomain"))) -}}
{{- $clusterGroup := index $over "clusterGroup" | default $base.clusterGroup | default $dr.name -}}
{{- dict "name" (index $over "name" | default $base.name) "version" (index $over "version" | default $base.version) "clusterGroup" $clusterGroup "install_config" $installConfigWithBase | toJson -}}
{{- end -}}

{{/*
  Effective secondary cluster: merge of regionalDR[0].clusters.secondary and clusterOverrides.secondary.
*/}}
{{- define "rdr.effectiveSecondaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "secondary" | default dict -}}
{{- $base := $dr.clusters.secondary -}}
{{- $installConfig := fromJson (include "rdr.mergeInstallConfig" (list ($base.install_config | default dict) (index $over "install_config" | default dict))) -}}
{{- $installConfigSafe := fromJson (include "rdr.sanitizeInstallConfig" $installConfig) -}}
{{- $defaultBaseDomain := join "." (slice (splitList "." (.Values.global.clusterDomain | default "cluster.example.com")) 1) -}}
{{- $installConfigWithBase := merge $installConfigSafe (dict "baseDomain" (default $defaultBaseDomain (index $installConfigSafe "baseDomain"))) -}}
{{- $clusterGroup := index $over "clusterGroup" | default $base.clusterGroup | default $dr.name -}}
{{- dict "name" (index $over "name" | default $base.name) "version" (index $over "version" | default $base.version) "clusterGroup" $clusterGroup "install_config" $installConfigWithBase | toJson -}}
{{- end -}}

{{/* Primary cluster name for use in drpc, jobs, etc. */}}
{{- define "rdr.primaryClusterName" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- index (index (.Values.clusterOverrides | default dict) "primary" | default dict) "name" | default $dr.clusters.primary.name -}}
{{- end -}}

{{/* Secondary cluster name */}}
{{- define "rdr.secondaryClusterName" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- index (index (.Values.clusterOverrides | default dict) "secondary" | default dict) "name" | default $dr.clusters.secondary.name -}}
{{- end -}}

{{/* Preferred cluster for DRPC (default: primary). Override via values.drpc.preferredCluster. */}}
{{- define "rdr.preferredClusterName" -}}
{{- (index (.Values.drpc | default dict) "preferredCluster") | default (include "rdr.primaryClusterName" .) -}}
{{- end -}}
