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
  Call with dict "base" <base install_config> "over" <override install_config>.
*/}}
{{- define "rdr.mergeInstallConfig" -}}
{{- $base := .base | default dict -}}
{{- $over := .over | default dict -}}
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
  Call with a context that has .Values and optionally .primaryOverrideInstallConfig (override install_config);
  if primaryOverrideInstallConfig is not provided, falls back to .Values.clusterOverrides.primary.install_config.
*/}}
{{- define "rdr.effectivePrimaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "primary" | default dict -}}
{{- $base := $dr.clusters.primary -}}
{{- $baseIC := $base.install_config | default dict -}}
{{- $overIC := index . "primaryOverrideInstallConfig" | default $over.install_config | default dict -}}
{{- /* Shallow merge: over wins. Deep-merge metadata and platform.aws so over wins for region. */ -}}
{{- $merged := merge $baseIC $overIC -}}
{{- $metadataMerged := merge (index $baseIC "metadata" | default dict) (index $overIC "metadata" | default dict) -}}
{{- $merged := merge $merged (dict "metadata" $metadataMerged) -}}
{{- $platformBase := index $baseIC "platform" | default dict -}}
{{- $platformOver := index $overIC "platform" | default dict -}}
{{- $awsBase := index $platformBase "aws" | default dict -}}
{{- $awsOver := index $platformOver "aws" | default dict -}}
{{- $awsMerged := merge $awsBase $awsOver -}}
{{- $platformFinal := merge $platformBase (dict "aws" $awsMerged) -}}
{{- $installConfig := merge $merged (dict "platform" $platformFinal) -}}
{{- $_mergedRegion := (index (index ($installConfig.platform | default dict) "aws" | default dict) "region") | default "" -}}
{{- $installConfigSafe := fromJson (include "rdr.sanitizeInstallConfig" $installConfig) -}}
{{- $defaultBaseDomain := join "." (slice (splitList "." (.Values.global.clusterDomain | default "cluster.example.com")) 1) -}}
{{- $installConfigWithBase := merge $installConfigSafe (dict "baseDomain" (default $defaultBaseDomain (index $installConfigSafe "baseDomain"))) -}}
{{- $clusterGroup := index $over "clusterGroup" | default $base.clusterGroup | default $dr.name -}}
{{- $_overICRegion := (index (index $overIC "platform" | default dict) "aws" | default dict).region | default "" -}}
{{- $_finalRegion := (index (index ($installConfigWithBase.platform | default dict) "aws" | default dict) "region") | default "" -}}
{{- $_safeRegion := (index (index ($installConfigSafe.platform | default dict) "aws" | default dict) "region") | default "" -}}
{{- dict "name" (index $over "name" | default $base.name) "version" (index $over "version" | default $base.version) "clusterGroup" $clusterGroup "install_config" $installConfigWithBase "_overICRegion" $_overICRegion "_mergedRegion" $_mergedRegion "_safeRegion" $_safeRegion "_finalRegion" $_finalRegion | toJson -}}
{{- end -}}

{{/*
  Effective secondary cluster: merge of regionalDR[0].clusters.secondary and clusterOverrides.secondary.
  Call with a context that has .Values and optionally .secondaryOverrideInstallConfig.
*/}}
{{- define "rdr.effectiveSecondaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "secondary" | default dict -}}
{{- $base := $dr.clusters.secondary -}}
{{- $baseIC := $base.install_config | default dict -}}
{{- $overIC := index . "secondaryOverrideInstallConfig" | default $over.install_config | default dict -}}
{{- $merged := merge $baseIC $overIC -}}
{{- $metadataMerged := merge (index $baseIC "metadata" | default dict) (index $overIC "metadata" | default dict) -}}
{{- $merged := merge $merged (dict "metadata" $metadataMerged) -}}
{{- $platformBase := index $baseIC "platform" | default dict -}}
{{- $platformOver := index $overIC "platform" | default dict -}}
{{- $awsMerged := merge (index $platformBase "aws" | default dict) (index $platformOver "aws" | default dict) -}}
{{- $platformFinal := merge $platformBase $platformOver (dict "aws" $awsMerged) -}}
{{- $installConfig := merge $merged (dict "platform" $platformFinal) -}}
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
