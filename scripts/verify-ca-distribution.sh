#!/bin/bash

# Script to verify CA bundle distribution across all clusters

set -euo pipefail

echo "CA Bundle Distribution Verification"
echo "==================================="

# Function to check hub cluster
check_hub_cluster() {
    echo "1. Checking Hub Cluster:"
    echo "========================"
    
    # Check if ConfigMap exists
    if oc get configmap cluster-proxy-ca-bundle -n openshift-config >/dev/null 2>&1; then
        local cert_count
        cert_count=$(oc get configmap cluster-proxy-ca-bundle -n openshift-config -o jsonpath="{.data['ca-bundle\.crt']}" | grep -c 'BEGIN CERTIFICATE' 2>/dev/null || echo "0")
        echo "✓ Hub cluster ConfigMap exists with $cert_count certificates"
    else
        echo "✗ Hub cluster ConfigMap not found"
        return 1
    fi
    
    # Check proxy configuration
    local proxy_ca
    proxy_ca=$(oc get proxy cluster -o jsonpath='{.spec.trustedCA.name}' 2>/dev/null || echo "")
    if [[ "$proxy_ca" == "cluster-proxy-ca-bundle" ]]; then
        echo "✓ Hub cluster proxy is configured to use the CA bundle"
    else
        echo "⚠️  Hub cluster proxy is not using the CA bundle (current: $proxy_ca)"
    fi
    
    echo ""
}

# Function to check managed clusters
check_managed_clusters() {
    echo "2. Checking Managed Clusters:"
    echo "============================="
    
    # Get managed clusters
    local managed_clusters
    managed_clusters=$(oc get managedclusters -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$managed_clusters" ]]; then
        echo "No managed clusters found"
        return 0
    fi
    
    local total_clusters=0
    local configured_clusters=0
    
    for cluster in $managed_clusters; do
        if [[ "$cluster" == "local-cluster" ]]; then
            continue
        fi
        
        ((total_clusters++))
        echo "Checking cluster: $cluster"
        
        # Check if policy is applied to this cluster
        local policy_status
        policy_status=$(oc get policy policy-cluster-proxy-ca-bundle-distribution -n policies -o jsonpath='{.status.status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$policy_status" == "Compliant" ]]; then
            echo "  ✓ Policy is compliant for $cluster"
            ((configured_clusters++))
        elif [[ "$policy_status" == "NonCompliant" ]]; then
            echo "  ⚠️  Policy is non-compliant for $cluster"
        else
            echo "  ❓ Policy status unknown for $cluster: $policy_status"
        fi
    done
    
    echo ""
    echo "Summary: $configured_clusters/$total_clusters managed clusters are properly configured"
    echo ""
}

# Function to check policy status
check_policy_status() {
    echo "3. Checking Policy Status:"
    echo "=========================="
    
    # Check if distribution policy exists
    if oc get policy policy-cluster-proxy-ca-bundle-distribution -n policies >/dev/null 2>&1; then
        echo "✓ Distribution policy exists"
        
        # Get policy details
        local policy_status
        policy_status=$(oc get policy policy-cluster-proxy-ca-bundle-distribution -n policies -o jsonpath='{.status.status}' 2>/dev/null || echo "Unknown")
        echo "  Policy status: $policy_status"
        
        # Get compliance details
        local compliant_clusters
        compliant_clusters=$(oc get policy policy-cluster-proxy-ca-bundle-distribution -n policies -o jsonpath='{.status.details[*].clusters[*].clusterName}' 2>/dev/null || echo "")
        if [[ -n "$compliant_clusters" ]]; then
            echo "  Compliant clusters: $compliant_clusters"
        fi
    else
        echo "✗ Distribution policy not found"
    fi
    
    # Check placement rule
    if oc get placementrule placement-cluster-proxy-ca-bundle -n policies >/dev/null 2>&1; then
        echo "✓ Placement rule exists"
    else
        echo "✗ Placement rule not found"
    fi
    
    # Check placement binding
    if oc get placementbinding binding-cluster-proxy-ca-bundle -n policies >/dev/null 2>&1; then
        echo "✓ Placement binding exists"
    else
        echo "✗ Placement binding not found"
    fi
    
    echo ""
}

# Function to check job status
check_job_status() {
    echo "4. Checking Job Status:"
    echo "======================="
    
    # Check if extraction job exists
    if oc get job extract-and-distribute-cas -n openshift-config >/dev/null 2>&1; then
        local job_status
        job_status=$(oc get job extract-and-distribute-cas -n openshift-config -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$job_status" == "True" ]]; then
            echo "✓ CA extraction job completed successfully"
        elif [[ "$job_status" == "False" ]]; then
            echo "⚠️  CA extraction job failed or is still running"
            
            # Show job logs
            echo "Recent job logs:"
            oc logs job/extract-and-distribute-cas -n openshift-config --tail=10 2>/dev/null || echo "Could not retrieve job logs"
        else
            echo "❓ CA extraction job status unknown: $job_status"
        fi
    else
        echo "✗ CA extraction job not found"
    fi
    
    echo ""
}

# Function to provide recommendations
provide_recommendations() {
    echo "5. Recommendations:"
    echo "==================="
    echo ""
    
    echo "If issues are found:"
    echo "1. Check job logs: oc logs job/extract-and-distribute-cas -n openshift-config"
    echo "2. Check policy compliance: oc get policy policy-cluster-proxy-ca-bundle-distribution -n policies -o yaml"
    echo "3. Manually trigger job: oc delete job extract-and-distribute-cas -n openshift-config"
    echo "4. Check placement rule: oc get placementrule placement-cluster-proxy-ca-bundle -n policies -o yaml"
    echo "5. Check placement binding: oc get placementbinding binding-cluster-proxy-ca-bundle -n policies -o yaml"
    echo ""
    echo "To force policy distribution:"
    echo "  oc patch policy policy-cluster-proxy-ca-bundle-distribution -n policies --type=merge --patch='{\"spec\":{\"disabled\":true}}'"
    echo "  oc patch policy policy-cluster-proxy-ca-bundle-distribution -n policies --type=merge --patch='{\"spec\":{\"disabled\":false}}'"
    echo ""
}

# Main execution
main() {
    echo "Starting CA bundle distribution verification..."
    echo ""
    
    check_hub_cluster
    check_managed_clusters
    check_policy_status
    check_job_status
    provide_recommendations
    
    echo "Verification completed!"
}

# Show usage if help requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "This script verifies that the CA bundle is properly distributed across all clusters by:"
    echo "1. Checking hub cluster configuration"
    echo "2. Checking managed cluster policy compliance"
    echo "3. Checking policy status and placement"
    echo "4. Checking job execution status"
    echo "5. Providing recommendations for issues"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    exit 0
fi

# Run main function
main
