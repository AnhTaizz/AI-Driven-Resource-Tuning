[CmdletBinding()]
param(
    [string]$EnvFile,
    [Parameter(Mandatory)] [string]$EvidenceDirectory,
    [Parameter(Mandatory)] [string]$ApplicationId
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
. (Join-Path $PSScriptRoot 'native-command.ps1')
. (Join-Path $PSScriptRoot 'verification-session.ps1')

if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env'
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing environment file: $EnvFile"
}
$EnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
$EvidenceDirectory = (Resolve-Path -LiteralPath $EvidenceDirectory).Path

function Read-EvidenceJson {
    param([Parameter(Mandatory)] [string]$Name)
    $path = Join-Path $EvidenceDirectory $Name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required observed evidence: $path"
    }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function New-VersionEvidence {
    param(
        [Parameter(Mandatory)] [object]$Observation,
        [Parameter(Mandatory)] [string]$Component
    )
    $rawName = "${Component}_version_raw"
    $normalizedName = "${Component}_version_normalized"
    $rawProperty = $Observation.normalized.PSObject.Properties[$rawName]
    $normalizedProperty = $Observation.normalized.PSObject.Properties[$normalizedName]
    $raw = if ($rawProperty) { $rawProperty.Value } else { $null }
    $normalized = if ($normalizedProperty) { $normalizedProperty.Value } else { $null }
    if (-not $raw -or -not $normalized) {
        throw "Version observation for $($Observation.environment) lacks $Component raw/normalized values."
    }
    return [ordered]@{
        source_service = $Observation.environment
        observed_at_utc = $Observation.normalized.observed_at_utc
        raw = [string]$raw
        normalized = [string]$normalized
    }
}

function Get-NullableInt64Property {
    param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name
    )
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $null
    }
    return [int64]$property.Value
}

$status = Read-EvidenceJson -Name 'verification_status.json'
if ($status.status -ne 'INCOMPLETE') {
    throw "Snapshot requires an active INCOMPLETE verification, observed $($status.status)."
}
if ($status.application_id -and $status.application_id -ne $ApplicationId) {
    throw "Snapshot application ID $ApplicationId differs from verification status $($status.application_id)."
}

$versionObservations = @(Read-EvidenceJson -Name 'runtime_versions_by_environment.json')
$sparkClientVersion = @($versionObservations | Where-Object { $_.environment -eq 'spark-client' }) | Select-Object -First 1
if (-not $sparkClientVersion) {
    throw 'Missing spark-client runtime version evidence.'
}
$pythonEvidence = @()
foreach ($environment in @('spark-client', 'nodemanager-1', 'nodemanager-2')) {
    $observation = @($versionObservations | Where-Object { $_.environment -eq $environment }) | Select-Object -First 1
    if (-not $observation) {
        throw "Missing Python version evidence for $environment."
    }
    $pythonEvidence += New-VersionEvidence -Observation $observation -Component python
}

$serviceImageDocument = Read-EvidenceJson -Name 'service_images_post_smoke.json'
$javaBaseImageResolution = Read-EvidenceJson -Name 'java_base_image_resolution.json'
$swapAssessment = Read-EvidenceJson -Name 'swap_assessment.json'
if ($javaBaseImageResolution.platform_manifest_digest -notmatch '^sha256:[0-9a-f]{64}$' -or
    $javaBaseImageResolution.registry_descriptor_digest -notmatch '^sha256:[0-9a-f]{64}$' -or
    -not $javaBaseImageResolution.selected_platform) {
    throw 'Java base-image evidence lacks an immutable registry descriptor or architecture-specific manifest digest.'
}
if ($serviceImageDocument.intended_image.java_base_image -ne $javaBaseImageResolution.resolved_reference) {
    throw 'Built LOCAL_YARN_V1 image label differs from the resolved Java base-image reference.'
}
$serviceImages = @()
foreach ($service in @($serviceImageDocument.services)) {
    $serviceImages += [ordered]@{
        service_name = $service.service
        container_name = $service.container_name
        container_id = $service.container_id
        image_reference = $service.image_reference
        image_id = $service.actual_image_id
        repo_digests = @($service.actual_image_repo_digests | Where-Object { $_ })
    }
}

$yarnNodeDocument = Read-EvidenceJson -Name 'yarn_node_resources.json'
$yarnNodes = @()
foreach ($node in @($yarnNodeDocument.nodes)) {
    # Measure-Object resolves PSObject properties, while an OrderedDictionary
    # is enumerated as dictionary entries by the PowerShell 5.1 pipeline.
    $yarnNodes += [pscustomobject][ordered]@{
        node_id = $node.node_id
        state = $node.state
        total_memory_mb = [int64]$node.total_memory_mb
        available_memory_mb = Get-NullableInt64Property -InputObject $node -Name 'available_memory_mb'
        total_vcores = [int64]$node.total_vcores
        available_vcores = Get-NullableInt64Property -InputObject $node -Name 'available_vcores'
    }
}
$yarnEffective = Read-EvidenceJson -Name 'yarn_effective_config.json'
$hdfsEffective = Read-EvidenceJson -Name 'hdfs_effective_config.json'
$sparkEffective = Read-EvidenceJson -Name 'spark_effective_config.json'
$historyApplication = Read-EvidenceJson -Name 'history_application.json'
if ($historyApplication.id -ne $ApplicationId) {
    throw "Spark History Server evidence ID $($historyApplication.id) differs from $ApplicationId."
}
$historyEndpointPath = Join-Path $EvidenceDirectory 'history_environment_endpoint.txt'
if (-not (Test-Path -LiteralPath $historyEndpointPath)) {
    throw "Missing required observed evidence: $historyEndpointPath"
}
$historyEnvironmentEndpoint = (Get-Content -LiteralPath $historyEndpointPath -Raw).Trim()
$escapedApplicationId = [regex]::Escape($ApplicationId)
if ($historyEnvironmentEndpoint -notmatch "/api/v1/applications/$escapedApplicationId(?:/[^/]+)?/environment$") {
    throw "Unexpected Spark History environment endpoint: $historyEnvironmentEndpoint"
}

$hostObservationRefs = @()
foreach ($phase in @('HOST_BASELINE', 'CLUSTER_IDLE', 'POST_SMOKE')) {
    $fileName = '{0}.json' -f $phase.ToLowerInvariant()
    $observation = Read-EvidenceJson -Name $fileName
    if ($observation.phase -ne $phase -or $observation.verification_id -ne $status.verification_id) {
        throw "Host observation $fileName does not match phase/session."
    }
    $hostObservationRefs += [ordered]@{
        phase = $phase
        observed_at_utc = $observation.observed_at_utc
        artifact_ref = "artifacts/infrastructure_smoke/$($status.verification_id)/$fileName"
    }
}

$dockerVersionResult = Invoke-NativeCommand `
    -FilePath 'docker' `
    -ArgumentList @('version', '--format', '{{json .}}')
$dockerVersionJson = $dockerVersionResult.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
if (-not $dockerVersionJson) {
    throw 'Docker version inspection returned no JSON.'
}
$dockerVersion = $dockerVersionJson | ConvertFrom-Json
$composeVersionResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @('compose', 'version', '--short')

$clusterAvailableMemory = [int64](($yarnNodes | Measure-Object available_memory_mb -Sum).Sum)
$clusterAvailableVcores = [int64](($yarnNodes | Measure-Object available_vcores -Sum).Sum)
$snapshotTime = (Get-Date).ToUniversalTime()
$snapshotId = 'LOCAL_YARN_V1_SNAPSHOT_{0}_{1}' -f `
    $snapshotTime.ToString('yyyyMMddTHHmmssfffZ'), `
    ([guid]::NewGuid().ToString('N').Substring(0, 8))

$snapshot = [ordered]@{
    schema_version = 'local_yarn_snapshot_v2'
    evidence_classification = 'INFRASTRUCTURE_VERIFICATION_ONLY'
    benchmark_environment_id = 'LOCAL_YARN_V1'
    environment_status = 'PLANNED_PENDING_HUMAN_REVIEW'
    snapshot_id = $snapshotId
    verification_id = $status.verification_id
    observed_at_utc = $snapshotTime.ToString('o')
    planned_config = [ordered]@{
        source_ref = 'docs/benchmark_environment.md'
        runtime_versions = [ordered]@{
            spark = '3.5.9'
            hadoop = '3.3.6'
            java = '11.0.32+9'
            python = '3.10.21'
        }
        yarn = [ordered]@{
            nodemanager_count = 2
            per_nodemanager = [ordered]@{ memory_mb = 2048; vcores = 2 }
            allocation = [ordered]@{
                minimum_memory_mb = 256
                maximum_memory_mb = 2048
                minimum_vcores = 1
                maximum_vcores = 2
            }
            resource_calculator = 'org.apache.hadoop.yarn.util.resource.DominantResourceCalculator'
        }
        spark = [ordered]@{
            dynamic_allocation_enabled = $false
            adaptive_query_execution_enabled = $false
            yarn_archive = 'hdfs:///spark/jars/spark-3.5.9-jars.zip'
        }
    }
    observed_runtime_evidence = [ordered]@{
        runtime_versions = [ordered]@{
            spark = New-VersionEvidence -Observation $sparkClientVersion -Component spark
            hadoop = New-VersionEvidence -Observation $sparkClientVersion -Component hadoop
            java = New-VersionEvidence -Observation $sparkClientVersion -Component java
            python = $pythonEvidence
        }
        service_images = $serviceImages
        container_runtime = [ordered]@{
            docker = $dockerVersion
            compose_version = ($composeVersionResult.StdOut -join "`n").Trim()
            intended_image = $serviceImageDocument.intended_image
            java_base_image_resolution = $javaBaseImageResolution
            infrastructure_smoke_swap_assessment = $swapAssessment
        }
        yarn = [ordered]@{
            nodes = $yarnNodes
            cluster_totals = [ordered]@{
                node_count = $yarnNodes.Count
                total_memory_mb = [int64]$yarnNodeDocument.observed_cluster_total_memory_mb
                available_memory_mb = $clusterAvailableMemory
                total_vcores = [int64]$yarnNodeDocument.observed_cluster_total_vcores
                available_vcores = $clusterAvailableVcores
            }
            effective_allocation = [ordered]@{
                minimum_memory_mb = [int]$yarnEffective.minimum_allocation.memory_mb
                maximum_memory_mb = [int]$yarnEffective.maximum_allocation.memory_mb
                minimum_vcores = [int]$yarnEffective.minimum_allocation.vcores
                maximum_vcores = [int]$yarnEffective.maximum_allocation.vcores
                evidence_source = $yarnEffective.sources.yarn_site
            }
            scheduler = [ordered]@{
                scheduler_type = $yarnEffective.scheduler_class
                resource_calculator = $yarnEffective.capacity_scheduler.resource_calculator
                queue_policy = $yarnEffective.capacity_scheduler
                evidence_source = $yarnEffective.sources.capacity_scheduler
            }
        }
        spark = [ordered]@{
            application_id = $ApplicationId
            effective_properties = $sparkEffective
            history_server_record_ref = "artifacts/infrastructure_smoke/$($status.verification_id)/history_application.json"
            event_log_ref = "artifacts/infrastructure_smoke/$($status.verification_id)/spark_event_log_listing.stdout.txt"
            evidence_source = "Spark History Server $historyEnvironmentEndpoint"
        }
        storage = [ordered]@{
            hdfs_uri = $hdfsEffective.fs_default_fs
            hdfs_config_ref = "artifacts/infrastructure_smoke/$($status.verification_id)/hdfs_effective_config.json"
            hdfs_report_ref = "artifacts/infrastructure_smoke/$($status.verification_id)/hdfs_report.stdout.txt"
            spark_event_log_path = $sparkEffective.'spark.eventLog.dir'
            spark_yarn_archive = $sparkEffective.'spark.yarn.archive'
        }
        host_observation_refs = $hostObservationRefs
    }
}

$outputDirectory = Join-Path $repositoryRoot "artifacts\environment_snapshots\LOCAL_YARN_V1\$snapshotId"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$snapshotPath = Join-Path $outputDirectory 'snapshot.json'
Write-LocalYarnJson -Value $snapshot -Path $snapshotPath -Depth 100
Write-Host "ENVIRONMENT_SNAPSHOT=$snapshotPath"
