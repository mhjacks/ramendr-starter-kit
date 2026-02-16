{{/*
  Sanitize install_config for OpenShift installer: ensure apiVersion and strip invalid
  platform.aws keys (e.g. vpc). Installer accepts region, userTags, subnets, defaultMachinePlatform.
*/}}
{{- define "rdr.sanitizeInstallConfig" -}}
{{- $raw := . -}}
{{- $withVersion := merge (dict "apiVersion" "v1") $raw -}}
{{- $platform := index $withVersion "platform" | default dict -}}
{{- $aws := index $platform "aws" | default dict -}}
{{- $awsSafe := dict "region" (index $aws "region") "userTags" (index $aws "userTags" | default dict) -}}
{{- $platformSafe := merge $platform (dict "aws" $awsSafe) -}}
{{- merge $withVersion (dict "platform" $platformSafe) | toJson -}}
{{- end -}}

{{/*
  Effective primary cluster: merge of regionalDR[0].clusters.primary and clusterOverrides.primary.
  Use when clusterOverrides is set to avoid replacing full regionalDR in override file.
*/}}
{{- define "rdr.effectivePrimaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "primary" | default dict -}}
{{- $base := $dr.clusters.primary -}}
{{- $installConfig := merge ($base.install_config | default dict) (index $over "install_config" | default dict) -}}
{{- $installConfigSafe := fromJson (include "rdr.sanitizeInstallConfig" $installConfig) -}}
{{- dict "name" (index $over "name" | default $base.name) "version" (index $over "version" | default $base.version) "clusterGroup" $base.clusterGroup "install_config" $installConfigSafe | toJson -}}
{{- end -}}

{{/*
  Effective secondary cluster: merge of regionalDR[0].clusters.secondary and clusterOverrides.secondary.
*/}}
{{- define "rdr.effectiveSecondaryCluster" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- $over := index (.Values.clusterOverrides | default dict) "secondary" | default dict -}}
{{- $base := $dr.clusters.secondary -}}
{{- $installConfig := merge ($base.install_config | default dict) (index $over "install_config" | default dict) -}}
{{- $installConfigSafe := fromJson (include "rdr.sanitizeInstallConfig" $installConfig) -}}
{{- dict "name" (index $over "name" | default $base.name) "version" (index $over "version" | default $base.version) "clusterGroup" $base.clusterGroup "install_config" $installConfigSafe | toJson -}}
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
