[CmdletBinding()]
param([string]$EnvFile)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
$dockerfile = Join-Path $repositoryRoot 'infrastructure\docker\Dockerfile'
$sparkDefaults = Join-Path $repositoryRoot 'infrastructure\docker\spark\spark-defaults.conf'
$sparkEnvironment = Join-Path $repositoryRoot 'infrastructure\docker\spark\spark-env.sh'
$javaSmoke = Join-Path $repositoryRoot 'infrastructure\docker\smoke\src\main\java\localyarn\LocalYarnSmoke.java'
$javaObservability = Join-Path $repositoryRoot 'infrastructure\docker\observability\src\main\java\localyarn\LocalYarnObservability.java'
$observabilityRunner = Join-Path $repositoryRoot 'infrastructure\docker\observability\run-observability-test.sh'
$observabilityHost = Join-Path $repositoryRoot 'infrastructure\docker\host\run-observability-test.ps1'
$startScript = Join-Path $repositoryRoot 'infrastructure\docker\host\start.ps1'
$verifyScript = Join-Path $repositoryRoot 'infrastructure\docker\host\verify.ps1'
$snapshotScript = Join-Path $repositoryRoot 'infrastructure\docker\host\snapshot-environment.ps1'
$stopScript = Join-Path $repositoryRoot 'infrastructure\docker\host\stop.ps1'
$verificationSessionScript = Join-Path $repositoryRoot 'infrastructure\docker\host\verification-session.ps1'
$nativeHelper = Join-Path $repositoryRoot 'infrastructure\docker\host\native-command.ps1'
$environmentFileHelper = Join-Path $repositoryRoot 'infrastructure\docker\host\environment-file.ps1'
$runtimeEvidenceScript = Join-Path $repositoryRoot 'infrastructure\docker\host\runtime-evidence.ps1'
$nativeRegression = Join-Path $repositoryRoot 'tests\infrastructure\test_native_command_ps51.ps1'
$verificationSessionRegression = Join-Path $repositoryRoot 'tests\infrastructure\test_verification_session_ps51.ps1'
$initHdfs = Join-Path $repositoryRoot 'infrastructure\docker\scripts\init-hdfs.sh'
$healthcheckHdfs = Join-Path $repositoryRoot 'infrastructure\docker\scripts\healthcheck-hdfs.sh'
$readHadoopXmlProperty = Join-Path $repositoryRoot 'infrastructure\docker\scripts\read-hadoop-xml-property.sh'
$snapshotYarnConfig = Join-Path $repositoryRoot 'infrastructure\docker\scripts\snapshot-yarn-config.sh'
$verifyHdfs = Join-Path $repositoryRoot 'infrastructure\docker\scripts\verify-hdfs.sh'
$verifyYarn = Join-Path $repositoryRoot 'infrastructure\docker\scripts\verify-yarn.sh'
$verifySpark = Join-Path $repositoryRoot 'infrastructure\docker\scripts\verify-spark.sh'
$capacityScheduler = Join-Path $repositoryRoot 'infrastructure\docker\hadoop\capacity-scheduler.xml'
$snapshotSchemaPath = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.snapshot.schema.json'
$verificationStatusSchemaPath = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.verification-status.schema.json'
$hostObservationSchemaPath = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.host-observation.schema.json'
$projectState = Join-Path $repositoryRoot 'PROJECT_STATE.md'
if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env.example'
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing environment file: $EnvFile"
}
$EnvFile = (Resolve-Path -LiteralPath $EnvFile).Path

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-HadoopProperty {
    param([string]$Path, [string]$Name)
    [xml]$document = Get-Content -LiteralPath $Path -Raw
    $property = @($document.configuration.property) | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if (-not $property) {
        return $null
    }
    return [string]$property.value
}

foreach ($xmlFile in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'infrastructure\docker\hadoop') -Filter '*.xml') {
    try {
        [void]([xml](Get-Content -LiteralPath $xmlFile.FullName -Raw))
    } catch {
        throw "Invalid XML: $($xmlFile.FullName): $($_.Exception.Message)"
    }
}

$dockerText = Get-Content -LiteralPath $dockerfile -Raw
$composeText = Get-Content -LiteralPath $composeFile -Raw
$sparkText = Get-Content -LiteralPath $sparkDefaults -Raw
$sparkEnvironmentText = Get-Content -LiteralPath $sparkEnvironment -Raw
$smokeText = Get-Content -LiteralPath $javaSmoke -Raw
Assert-True (Test-Path -LiteralPath $javaObservability) 'Missing Java infrastructure observability job.'
Assert-True (Test-Path -LiteralPath $observabilityRunner) 'Missing infrastructure observability runner.'
Assert-True (Test-Path -LiteralPath $observabilityHost) 'Missing Windows observability launcher.'
$observabilityText = Get-Content -LiteralPath $javaObservability -Raw
$observabilityRunnerText = Get-Content -LiteralPath $observabilityRunner -Raw
$observabilityHostText = Get-Content -LiteralPath $observabilityHost -Raw
$startText = Get-Content -LiteralPath $startScript -Raw
$verifyText = Get-Content -LiteralPath $verifyScript -Raw
$snapshotText = Get-Content -LiteralPath $snapshotScript -Raw
$stopText = Get-Content -LiteralPath $stopScript -Raw
$verificationSessionText = Get-Content -LiteralPath $verificationSessionScript -Raw
$runtimeEvidenceText = Get-Content -LiteralPath $runtimeEvidenceScript -Raw
$initHdfsText = Get-Content -LiteralPath $initHdfs -Raw
$healthcheckHdfsText = Get-Content -LiteralPath $healthcheckHdfs -Raw
$readHadoopXmlPropertyText = Get-Content -LiteralPath $readHadoopXmlProperty -Raw
$snapshotYarnConfigText = Get-Content -LiteralPath $snapshotYarnConfig -Raw
$verifyHdfsText = Get-Content -LiteralPath $verifyHdfs -Raw
$verifyYarnText = Get-Content -LiteralPath $verifyYarn -Raw
$verifySparkText = Get-Content -LiteralPath $verifySpark -Raw
$stateText = Get-Content -LiteralPath $projectState -Raw

foreach ($schemaPath in @($snapshotSchemaPath, $verificationStatusSchemaPath, $hostObservationSchemaPath)) {
    Assert-True (Test-Path -LiteralPath $schemaPath) "Missing evidence schema: $schemaPath"
    try {
        [void](Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json)
    } catch {
        throw "Invalid JSON schema: $schemaPath`: $($_.Exception.Message)"
    }
}
$snapshotSchemaText = Get-Content -LiteralPath $snapshotSchemaPath -Raw
$snapshotSchema = $snapshotSchemaText | ConvertFrom-Json
$verificationStatusSchema = Get-Content -LiteralPath $verificationStatusSchemaPath -Raw | ConvertFrom-Json
$hostObservationSchema = Get-Content -LiteralPath $hostObservationSchemaPath -Raw | ConvertFrom-Json

Assert-True ($dockerText -match 'SPARK_VERSION=3\.5\.9') 'Spark 3.5.9 is not pinned in Dockerfile.'
Assert-True ($verifyText -match "PSObject\.Properties\['attemptId'\]") 'Host verification does not safely derive the optional Spark History Server attemptId.'
Assert-True ($verifyText -match '\$historyApplicationKey = \$applicationId') 'Host verification lacks the application-only Spark History endpoint fallback.'
Assert-True ($verifyText -match '\$historyApplicationKey = "\$applicationId/\$historyAttemptId"') 'Host verification lacks the attempt-aware Spark History endpoint branch.'
Assert-True ($verifyText -match 'history_environment_endpoint\.txt') 'Host verification does not preserve the actual Spark History environment endpoint.'
Assert-True ($snapshotText -match 'history_environment_endpoint\.txt') 'Environment snapshot does not cite the actual Spark History environment endpoint.'
Assert-True ($dockerText -match 'spark-\$\{SPARK_VERSION\}-bin-without-hadoop') 'The official no-Hadoop Spark artifact is not selected.'
Assert-True ($dockerText -match 'sha512sum --check --strict') 'Spark/Hadoop SHA-512 verification is missing.'
Assert-True (([regex]::Matches($dockerText, '--connect-timeout\s+15')).Count -eq 3) 'Each source download must have an explicit connection timeout.'
Assert-True (([regex]::Matches($dockerText, '--max-time\s+1800')).Count -eq 3) 'Each source download must have an explicit overall attempt timeout.'
Assert-True (([regex]::Matches($dockerText, '--retry-all-errors')).Count -eq 3) 'Each source download must retry interrupted TLS transfers.'
Assert-True ($dockerText -match '0ceafdcc46dff83272edbbe5a9a52c77e2c2c55672f67deaa33751e52e5e3ae13e3fc2c5deddec88d172a488cf8baa6c85cc0d2e88333217fdefccb303beda75') 'The official Spark 3.5.9 no-Hadoop SHA-512 is not pinned.'
Assert-True ($dockerText -match 'PYTHON_VERSION=3\.10\.21') 'Python 3.10.21 is not pinned.'
Assert-True ($dockerText -match 'sha256sum --check --strict') 'Python SHA-256 verification is missing.'
Assert-True ($dockerText -match 'a0da1e72132e950154eca0f6f47d5db828454700de20e5113667940d81e0db04') 'The official Python 3.10.21 SHA-256 is not pinned.'
Assert-True ($dockerText -notmatch '(?im)(^|[:=/-])latest($|\s)') 'An uncontrolled latest tag or URL was found.'
Assert-True ($composeText -notmatch '(?im)(^|[:=/-])latest($|\s)') 'Compose contains an uncontrolled latest tag.'
Assert-True ($composeText -match 'JAVA_BASE_IMAGE: \$\{JAVA_BASE_IMAGE:-eclipse-temurin:11\.0\.32_9-jdk-jammy\}') 'Java base image override/digest path is missing.'
Assert-True ($startText -match '@sha256:\[0-9a-f\]\{64\}') 'start.ps1 does not require an immutable base-image digest.'
Assert-True ($startText.Contains("@('build', 'namenode')")) 'start.ps1 must build the common runtime image exactly once through the canonical NameNode target.'
Assert-True ($startText.Contains("@('up', '--detach', '--no-build', '--force-recreate')")) 'start.ps1 must recreate every service from the already-built common image.'
Assert-True ($startText -match 'for \(\$pullAttempt = 1; \$pullAttempt -le 3;') 'Java base-image pull retries are not explicitly bounded to three attempts.'
Assert-True ($startText -match 'java_base_image_pull_attempt_\$pullAttempt\.txt') 'Java base-image pull attempts are not preserved as evidence.'
Assert-True ($startText -match "buildx', 'imagetools', 'inspect', '--raw'") 'start.ps1 does not resolve the architecture-specific Java base-image manifest.'
Assert-True ($startText -match 'platform_manifest_digest' -and $startText -match 'registry_descriptor_digest') 'Java base-image evidence does not distinguish registry descriptor and platform manifest digests.'
Assert-True ($startText -match 'started_service_images\.json') 'start.ps1 does not bind the verification session to its started container identities.'
Assert-True (([regex]::Matches($verifyText, "-Command\s+@\('run',\s*'--rm',\s*'--no-deps',")).Count -eq 7) 'Every verification spark-client run must bypass already-satisfied Compose dependencies.'
Assert-True ($verifyText -notmatch "-Command\s+@\('run',\s*'--rm',\s*'spark-client'") 'A verification command can restart the one-shot HDFS initializer through Compose dependencies.'
Assert-True ($sparkText -match 'spark-3\.5\.9-jars\.zip') 'spark.yarn.archive is not an explicit Spark 3.5.9 ZIP.'
Assert-True ($sparkEnvironmentText -match '(?m)^export SPARK_DAEMON_MEMORY=384m\s*$') 'Spark History Server heap must be configured through SPARK_DAEMON_MEMORY.'
$historyOptionsLines = @($sparkEnvironmentText -split "`r?`n" | Where-Object { $_ -match '^export SPARK_HISTORY_OPTS=' })
Assert-True ($historyOptionsLines.Count -eq 1) 'spark-env.sh must define exactly one SPARK_HISTORY_OPTS line.'
Assert-True ($historyOptionsLines[0] -notmatch '-Xm[xs]') 'SPARK_HISTORY_OPTS must not contain heap flags rejected by SparkClassCommandBuilder.'
Assert-True ($sparkText -match 'spark\.dynamicAllocation\.enabled\s+false') 'Dynamic allocation must be disabled.'
Assert-True ($sparkText -match 'spark\.sql\.adaptive\.enabled\s+false') 'AQE must be disabled.'
Assert-True ($sparkText -match 'spark\.pyspark\.python\s+/opt/python/bin/python3\.10') 'Pinned Python is not configured for PySpark.'
Assert-True ($smokeText -match 'INFRASTRUCTURE_SMOKE') 'Smoke application is not explicitly infrastructure-only.'
Assert-True ($smokeText -notmatch 'EXP_001|W03_JOIN_V1|DATA_DEBUG_V1') 'Smoke application crosses the approved task boundary.'
Assert-True ($observabilityText -match 'INFRASTRUCTURE_OBSERVABILITY_ONLY') 'Observability job lacks an infrastructure-only classification.'
Assert-True (($observabilityText + $observabilityRunnerText) -notmatch 'EXP_001|W03_JOIN_V1|DATA_DEBUG_V1') 'Observability tooling crosses the approved task boundary.'
Assert-True ($observabilityText -match 'NOT_BENCHMARK' -and $observabilityText -match 'NOT_ML_DATA') 'Observability job does not reject benchmark/ML interpretation.'
Assert-True ($observabilityText -match 'MIN_OBSERVATION_SECONDS = 30' -and $observabilityText -match 'MAX_OBSERVATION_SECONDS = 600') 'Java observability window is not explicitly bounded.'
Assert-True ($observabilityRunnerText -match 'min_observation_seconds=30' -and $observabilityRunnerText -match 'max_observation_seconds=600') 'Shell observability window is not explicitly bounded.'
Assert-True ($observabilityRunnerText -match 'application_poll_attempts=120' -and $observabilityRunnerText -match 'history_poll_attempts=60') 'Observability API polling is not explicitly bounded.'
Assert-True ($observabilityRunnerText -match 'history_validation_timeout_seconds=180' -and $observabilityRunnerText -match 'SECONDS < history_validation_deadline') 'Semantic History REST validation does not have a shared bounded deadline.'
Assert-True ($observabilityRunnerText -match 'spark\.dynamicAllocation\.enabled=false') 'Observability job must keep dynamic allocation disabled.'
Assert-True ($observabilityRunnerText -match 'spark\.sql\.adaptive\.enabled=false') 'Observability job must keep AQE disabled.'
Assert-True ($observabilityRunnerText -match 'spark\.ui\.prometheus\.enabled=true') 'Observability job does not expose the executor Prometheus endpoint.'
Assert-True ($observabilityRunnerText -match 'prometheus_samples=' -and $observabilityRunnerText -match 'worker_executor_ids=' -and $observabilityRunnerText -match 'prometheus_worker_executors') 'Observability runner does not correlate non-comment Prometheus samples with observed worker executors.'
Assert-True ($observabilityRunnerText -match 'spark\.eventLog\.logStageExecutorMetrics=true') 'Observability job does not preserve per-stage executor metrics in its event log.'
Assert-True ($observabilityRunnerText -match 'spark\.ui\.killEnabled=false') 'Observability UI still exposes destructive kill controls.'
Assert-True ($observabilityRunnerText -match 'OBSERVED_APPLICATION_ID=' -and $observabilityRunnerText -match 'OBSERVABILITY_TEST_RESULT=PASS') 'Observability runner does not report an observed application ID and final result.'
Assert-True ($observabilityRunnerText -match 'live_spark_application_key="\$\{application_id\}"') 'Live Spark REST must use the base application ID observed from this Spark 3.5.9 YARN runtime.'
Assert-True ($observabilityRunnerText -match 'live_yarn_state.*RUNNING' -and $observabilityRunnerText -match 'live_application_incomplete.*true') 'Live metrics are not correlated with an incomplete RUNNING YARN application.'
Assert-True ($observabilityRunnerText -match 'history_api_base="\$\{history_internal_base\}/api/v1/applications/\$\{application_id\}/\$\{history_attempt_id\}"') 'History REST must use the observed attempt-aware application key.'
Assert-True ($dockerText -notmatch 'LocalYarnObservability|local-yarn-observability') 'Observability code must not alter the formally snapshotted runtime image.'
Assert-True ($observabilityHostText -match ':ro"' -and $observabilityHostText -match '--no-deps') 'Observability source must be mounted read-only without restarting Compose dependencies.'
Assert-True ($observabilityHostText -match "status -ne 'COMPLETE'") 'Observability launcher can contaminate an incomplete formal verification session.'
Assert-True ($observabilityHostText -match 'Enter-LocalYarnVerificationLock' -and $observabilityHostText -match '(?s)finally\s*\{\s*Exit-LocalYarnVerificationLock') 'Observability launcher is outside the LOCAL_YARN_V1 lifecycle lock.'
Assert-True ($observabilityHostText -match 'runtime-evidence\.ps1' -and $observabilityHostText -match 'service_images_final\.json') 'Observability launcher is not bound to the completed runtime evidence.'
Assert-True ($observabilityHostText -match 'Get-LocalYarnServiceImageEvidence' -and $observabilityHostText -match 'container_id' -and $observabilityHostText -match 'actual_image_id' -and $observabilityHostText -match 'started_at') 'Observability launcher does not compare current container/image identities with completed evidence.'
Assert-True (([regex]::Matches($composeText, '127\.0\.0\.1:')).Count -eq 3) 'Exactly three loopback-only UI ports are required.'
Assert-True (([regex]::Matches($composeText, '(?m)^\s+memswap_limit:\s+')).Count -eq 9) 'Every daemon/tool service must prohibit cgroup swap by setting memswap_limit equal to mem_limit.'
Assert-True ($composeText -match 'namenode-data' -and $composeText -match 'datanode-1-data' -and $composeText -match 'datanode-2-data') 'Required persistent HDFS volumes are missing.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\core-site.xml') 'fs.defaultFS') -eq 'hdfs://namenode:8020') 'Unexpected HDFS URI.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\hdfs-site.xml') 'dfs.replication') -eq '2') 'HDFS replication must be 2.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\yarn-site.xml') 'yarn.nodemanager.resource.memory-mb') -eq '2048') 'NodeManager memory must be 2048 MB.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\yarn-site.xml') 'yarn.nodemanager.resource.cpu-vcores') -eq '2') 'NodeManager vcores must be 2.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\yarn-site.xml') 'yarn.scheduler.minimum-allocation-mb') -eq '256') 'Unexpected YARN minimum allocation.'
Assert-True ((Get-HadoopProperty (Join-Path $repositoryRoot 'infrastructure\docker\hadoop\yarn-site.xml') 'yarn.scheduler.maximum-allocation-mb') -eq '2048') 'Unexpected YARN maximum allocation.'
Assert-True ((Get-HadoopProperty $capacityScheduler 'yarn.scheduler.capacity.resource-calculator') -eq 'org.apache.hadoop.yarn.util.resource.DominantResourceCalculator') 'CapacityScheduler must explicitly use DominantResourceCalculator so memory and vcores both constrain scheduling.'
Assert-True ($healthcheckHdfsText -match 'NameNodeStatus') 'NameNode health must use its lightweight JMX status endpoint.'
Assert-True ($healthcheckHdfsText -match '\.beans\[0\]\.State\s*==\s*"active"') 'NameNode health must require the JMX active state.'
Assert-True ($healthcheckHdfsText -notmatch 'hdfs\s+dfsadmin') 'NameNode health must not launch a Hadoop JVM CLI on every probe.'
Assert-True ($initHdfsText -match 'HDFS_INIT_COMMAND_TIMEOUT_SECONDS:-30') 'HDFS initialization must allow the measured cold Hadoop CLI startup time under its CPU limit.'
Assert-True (Test-Path -LiteralPath $readHadoopXmlProperty) 'Missing deployed Hadoop XML property reader.'
Assert-True ($readHadoopXmlPropertyText -match 'len\(matches\) != 1') 'The deployed XML property reader must reject missing or duplicate properties.'
foreach ($yarnObservationText in @($snapshotYarnConfigText, $verifyYarnText)) {
    Assert-True ($yarnObservationText -match 'read-hadoop-xml-property\.sh') 'YARN evidence must read explicit properties from the deployed yarn-site.xml.'
    Assert-True ($yarnObservationText -notmatch 'yarn\s+getconf') 'Hadoop 3.3.6 does not expose a yarn getconf command.'
}
Assert-True ($snapshotYarnConfigText -match 'duplicate deployed capacity-scheduler properties') 'CapacityScheduler snapshot silently accepts duplicate deployed properties.'

# HDFS bootstrap may only mutate paths after RPC reachability, two live DataNodes,
# and an explicit, bounded observation that safe mode is OFF.
$rpcIndex = $initHdfsText.IndexOf('dfsadmin -safemode get')
$dataNodeIndex = $initHdfsText.IndexOf('dfsadmin -report')
$safeModeOffIndex = $initHdfsText.IndexOf('Safe mode is OFF')
$mkdirIndex = $initHdfsText.IndexOf('hdfs dfs -mkdir')
Assert-True ($rpcIndex -ge 0) 'HDFS initialization does not explicitly check NameNode RPC reachability.'
Assert-True ($dataNodeIndex -gt $rpcIndex) 'HDFS initialization must check DataNode registration after NameNode RPC readiness.'
Assert-True ($safeModeOffIndex -gt $dataNodeIndex) 'HDFS initialization must prove safe mode is OFF after both DataNodes register.'
Assert-True ($mkdirIndex -gt $safeModeOffIndex) 'HDFS bootstrap paths must not be mutated before safe mode is explicitly OFF.'
Assert-True ($initHdfsText -notmatch '(?im)^\s*while\s+true\b') 'HDFS initialization contains an unbounded while-true readiness loop.'
$hasBoundedReadiness = (
    $initHdfsText -match '(?im)\b(max_attempts|timeout_seconds|deadline|readiness_timeout)\b' -or
    $initHdfsText -match '(?im)for\s+\w+\s+in\s+\$\(seq\s+1\s+[0-9]+\)'
)
Assert-True $hasBoundedReadiness 'HDFS readiness polling must have an explicit finite timeout or attempt bound.'
Assert-True ($initHdfsText -match '(?im)(last|observed).*(state|safe mode)') 'Safe-mode timeout must report the last observed state.'
Assert-True ($verifySparkText -match 'yarn application -kill') 'Timed-out or failed smoke submissions do not attempt to clean up an observed YARN application.'
Assert-True ($verifySparkText -match 'cleanup_max_attempts') 'YARN application cleanup polling is not explicitly bounded.'
Assert-True ($verifyHdfsText -match 'spark-3\.5\.9-jars\.zip') 'HDFS verification does not inspect the explicit Spark 3.5.9 YARN archive.'
Assert-True ($verifyHdfsText -match 'unzip -tqq' -and $verifyHdfsText -match 'nested_count' -and $verifyHdfsText -match 'non_jar_count') 'HDFS verification does not prove that the Spark YARN archive is an intact root-JAR-only ZIP.'
Assert-True ($verifySparkText -match 'OBSERVED_APPLICATION_ID=') 'Smoke verification does not expose an application ID before post-submit correlation can fail.'
Assert-True ($verifySparkText -match '%N.*\$\$.*RANDOM') 'Smoke output paths are not unique enough for concurrent or rapid submissions.'
Assert-True ($verifyYarnText -notmatch '//\s*0') 'YARN verification must not fabricate missing resource metrics as zero.'
Assert-True ($verifyYarnText -match 'omitted or mis-typed a required resource field') 'YARN verification does not explicitly reject absent resource operands.'
Assert-True ($verifyYarnText -match 'metrics_ready=false' -and $verifyYarnText -match 'metrics did not converge') 'YARN aggregate metrics are not polled to a bounded, capacity-consistent state.'

# Native invocation behavior is a shared PowerShell 5.1 contract, not a
# one-line suppression in an individual host script.
Assert-True (Test-Path -LiteralPath $nativeHelper) 'Missing shared native-command helper.'
Assert-True (Test-Path -LiteralPath $nativeRegression) 'Missing PowerShell 5.1 native-command regression test.'
Assert-True (Test-Path -LiteralPath $verificationSessionRegression) 'Missing PowerShell 5.1 verification-session regression test.'
Assert-True (Test-Path -LiteralPath $environmentFileHelper) 'Missing authoritative environment-file helper.'
$nativeHelperText = Get-Content -LiteralPath $nativeHelper -Raw
Assert-True ($nativeHelperText -match 'function\s+Invoke-NativeCommand') 'Shared helper must expose Invoke-NativeCommand.'
. $nativeHelper
. $environmentFileHelper
foreach ($hostScript in @($startScript, $verifyScript, $snapshotScript, $stopScript)) {
    $hostText = Get-Content -LiteralPath $hostScript -Raw
    Assert-True ($hostText -match 'native-command\.ps1') "$hostScript does not load the shared native-command helper."
    Assert-True ($hostText -match 'Invoke-NativeCommand') "$hostScript still bypasses the shared native-command helper."
}
foreach ($composeHostScript in @($startScript, $verifyScript, $stopScript)) {
    $hostText = Get-Content -LiteralPath $composeHostScript -Raw
    Assert-True ($hostText -match 'environment-file\.ps1') "$composeHostScript does not load the environment-file helper."
    Assert-True ($hostText -match 'Import-LocalYarnEnvironmentFile') "$composeHostScript does not make the selected env file authoritative over inherited process values."
}
$env:LOCAL_YARN_IMAGE = '__CONFLICTING_PARENT_VALUE__'
$resolvedEnvironment = Import-LocalYarnEnvironmentFile -Path $EnvFile
Assert-True ($env:LOCAL_YARN_IMAGE -eq $resolvedEnvironment['LOCAL_YARN_IMAGE']) 'Env-file import did not override a conflicting process value before Compose interpolation.'
Assert-True ($runtimeEvidenceText -match '\$containerIds\.Count -ne 1') 'Per-service image evidence does not reject duplicate Compose containers.'
Assert-True ($runtimeEvidenceText -match 'restart_count' -and $runtimeEvidenceText -match "health -ne 'healthy'") 'Runtime service evidence does not reject unhealthy/restarting daemons.'
Assert-True ($runtimeEvidenceText -match 'memory\.swap\.current' -and $runtimeEvidenceText -match 'memory\.swap\.peak' -and $runtimeEvidenceText -match 'memory\.swap\.max') 'Runtime evidence does not observe per-service cgroup swap state.'
Assert-True ($verificationSessionText -match 'FileShare\]::None') 'Verification session locking does not request exclusive OS-level ownership.'
Assert-True ($verificationSessionText -match 'File\]::Replace') 'Verification JSON updates are not atomically replaced.'
foreach ($lifecycleText in @($startText, $verifyText, $stopText)) {
    Assert-True ($lifecycleText -match 'Enter-LocalYarnVerificationLock') 'A LOCAL_YARN_V1 lifecycle command is outside the repository-wide lock.'
    Assert-True ($lifecycleText -match '(?s)finally\s*\{\s*Exit-LocalYarnVerificationLock') 'A LOCAL_YARN_V1 lifecycle lock is not guaranteed to be released in a finally block.'
}
$startLockIndex = $startText.IndexOf('$verificationLock = Enter-LocalYarnVerificationLock')
$startActiveSessionIndex = $startText.LastIndexOf('New-LocalYarnVerificationSession -RepositoryRoot $repositoryRoot')
Assert-True ($startLockIndex -ge 0 -and $startLockIndex -lt $startActiveSessionIndex) 'start.ps1 can activate a session before acquiring the lifecycle lock.'
$verifyLockIndex = $verifyText.IndexOf('$verificationLock = Enter-LocalYarnVerificationLock')
$verifySessionReadIndex = $verifyText.IndexOf('Get-LocalYarnActiveVerificationSession')
$verifyStatusMutationIndex = $verifyText.IndexOf('$statusCanBeUpdated = $true')
Assert-True ($verifyLockIndex -ge 0 -and $verifyLockIndex -lt $verifySessionReadIndex -and $verifyLockIndex -lt $verifyStatusMutationIndex) 'verify.ps1 reads or mutates session state before acquiring the lifecycle lock.'
Assert-True ($verifyText -match 'omitted a resource field required to verify') 'Host verification does not fail explicitly when YARN resource operands are unavailable.'
Assert-True ($verifyText -match "Invoke-ComposeEvidence[\s\S]*-AllowNonZero") 'Compose evidence wrapper can throw before persisting non-zero command output.'
Assert-True ($verifyText -match 'Select-Object -Last 20') 'Compose failure evidence lacks a bounded last-output summary.'
Assert-True ($verifyText -match 'service_images_post_smoke\.json') 'Verification does not re-check service lifecycle and identity after smoke.'
Assert-True ($verifyText -match 'service_images_final\.json') 'Verification does not preserve a final service lifecycle observation.'
Assert-True ($verifyText -match 'host_linux_vm_swap_detected' -and $verifyText -match 'local_yarn_cgroup_swap_detected') 'Swap evidence does not distinguish host/Docker-VM activity from LOCAL_YARN cgroup activity.'
$swapAssessmentWriteIndex = $verifyText.LastIndexOf("Write-LocalYarnJson -Value `$swapAssessment")
$correlationStepIndex = $verifyText.IndexOf("`$currentStep = 'CORRELATE_RUNTIME_RECORDS'")
$snapshotStepIndex = $verifyText.IndexOf("`$currentStep = 'WRITE_ENVIRONMENT_SNAPSHOT'")
$completeBundleValidationIndex = $verifyText.IndexOf("`$currentStep = 'VALIDATE_EVIDENCE_BUNDLE'")
$completeStatusIndex = $verifyText.LastIndexOf('-Status COMPLETE')
Assert-True (
    $swapAssessmentWriteIndex -ge 0 -and
    $swapAssessmentWriteIndex -lt $correlationStepIndex -and
    $correlationStepIndex -lt $snapshotStepIndex -and
    $snapshotStepIndex -lt $completeBundleValidationIndex -and
    $completeBundleValidationIndex -lt $completeStatusIndex
) 'Swap invalidation must preserve correlated runtime evidence and the environment snapshot, then fail before COMPLETE bundle validation.'
$postSwapCaptureFlow = $verifyText.Substring(
    $swapAssessmentWriteIndex,
    $correlationStepIndex - $swapAssessmentWriteIndex
)
Assert-True ($postSwapCaptureFlow -notmatch '(?s)swap_detected[\s\S]*?throw') 'Verification still throws on swap before preserving correlated runtime evidence.'
Assert-True (
    $verifyText -match 'swapDetectedProperty = \$documents\[''swap_assessment\.json''\]\.PSObject\.Properties\[''swap_detected''\]' -and
    $verifyText -match 'swapDetectedProperty\.Value -isnot \[bool\]' -and
    $verifyText -match '(?m)^\s*\$swapDetectedProperty\.Value\)'
) 'Final evidence validation must accept only a typed false swap_detected value before COMPLETE.'
Assert-True ($verifyText -match 'started_at -ne \$expectedService\.started_at' -and $verifyText -match "service -eq 'hdfs-init'[\s\S]*finished_at -ne") 'Service continuity checks do not detect manual restarts or hdfs-init reruns.'
Assert-True ($verifyText -match "'VERIFY_CLUSTER_IDLE'" -and $verifyText -match 'yarn_idle_metrics\.json' -and $verifyText -match 'yarn_idle_applications\.json') 'Verification does not prove YARN is idle immediately before smoke.'
Assert-True ($verifyText -match '@\(\$appsProperty\.Value\.PSObject\.Properties\)\.Count -eq 0') 'YARN 3.3.6 empty application payload {"apps":{}} is not recognized as an idle cluster.'
Assert-True ($verifyText -match 'environment_snapshot_ref\.json') 'Verification bundle does not link to its environment snapshot.'
Assert-True ($verifyText -match 'function Assert-LocalYarnEvidenceBundle' -and $verifyText -match "'VALIDATE_EVIDENCE_BUNDLE'") 'Critical evidence instances are not validated before the verification is marked COMPLETE.'
Assert-True ($verifyText -match "yarn_application\.json'\]\.app\.finalStatus -ne 'SUCCEEDED'") 'Final evidence validation does not require a successful YARN application record.'
Assert-True ($snapshotText -match "Read-EvidenceJson -Name 'service_images_post_smoke\.json'") 'Environment snapshot does not use the final post-smoke service observation.'
Assert-True ($snapshotText -match '\$yarnNodes \+= \[pscustomobject\]\[ordered\]@\{') 'Snapshot YARN-node records must expose real PSObject properties to Measure-Object under PowerShell 5.1.'
Assert-True ($snapshotText -match 'java_base_image_resolution = \$javaBaseImageResolution') 'Environment snapshot omits the architecture-specific Java base-image resolution.'
Assert-True ($snapshotText -match 'infrastructure_smoke_swap_assessment = \$swapAssessment') 'Environment snapshot omits the infrastructure smoke swap assessment.'
Assert-True ($verifyText -notmatch 'http://localhost:') 'Host runtime verification must use the explicitly bound IPv4 loopback address.'
Assert-True ($verifyText -match "'hdfs_report\.stdout\.txt'" -and $verifyText -match "'spark_event_log_listing\.stdout\.txt'") 'Final validation does not require the exact stdout artifacts cited by the snapshot.'
Assert-True ($verifyText -match 'eventLogListing -notmatch \[regex\]::Escape\(\$ApplicationId\)') 'Final validation does not correlate the event-log listing with the smoke application ID.'

$windowsPowerShell = Join-Path $PSHOME 'powershell.exe'
$nativeRegressionResult = Invoke-NativeCommand `
    -FilePath $windowsPowerShell `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $nativeRegression) `
    -NoEcho
Assert-True (($nativeRegressionResult.Combined -join "`n") -match 'NATIVE_COMMAND_PS51_REGRESSION=PASS') 'PowerShell 5.1 native-command regression did not emit its PASS marker.'
$verificationSessionRegressionResult = Invoke-NativeCommand `
    -FilePath $windowsPowerShell `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $verificationSessionRegression) `
    -NoEcho
Assert-True (($verificationSessionRegressionResult.Combined -join "`n") -match 'VERIFICATION_SESSION_PS51_REGRESSION=PASS') 'PowerShell 5.1 verification-session regression did not emit its PASS marker.'

# Snapshot contracts keep intended values under planned_config and require
# independent runtime observations before a human can review the environment.
Assert-True ($snapshotSchema.properties.schema_version.const -eq 'local_yarn_snapshot_v2') 'Snapshot schema must use local_yarn_snapshot_v2.'
Assert-True (@($snapshotSchema.required) -contains 'planned_config') 'Snapshot schema does not require planned_config.'
Assert-True (@($snapshotSchema.required) -contains 'observed_runtime_evidence') 'Snapshot schema does not require observed_runtime_evidence.'
$observedSchemaText = $snapshotSchema.'$defs'.observedRuntimeEvidence | ConvertTo-Json -Depth 100
Assert-True ($observedSchemaText -notmatch '(?i)"planned[_A-Za-z0-9-]*"\s*:') 'An observed-runtime schema property is incorrectly labeled as planned evidence.'
Assert-True ($snapshotSchemaText -match '"raw"' -and $snapshotSchemaText -match '"normalized"') 'Observed runtime versions must preserve raw and normalized values.'
Assert-True ($snapshotSchemaText -match 'service_images' -and $snapshotSchemaText -match 'container_id' -and $snapshotSchemaText -match 'image_id') 'Snapshot schema lacks per-service runtime image identity.'
Assert-True ($snapshotSchemaText -match 'total_memory_mb' -and $snapshotSchemaText -match 'available_memory_mb' -and $snapshotSchemaText -match 'total_vcores' -and $snapshotSchemaText -match 'available_vcores') 'Snapshot schema lacks per-node YARN resource evidence.'
Assert-True ($observedSchemaText -match 'effective_allocation' -and $observedSchemaText -match 'resource_calculator' -and $observedSchemaText -match 'queue_policy') 'Snapshot schema lacks effective YARN allocation/scheduler evidence.'
Assert-True ($observedSchemaText -match 'spark\.dynamicAllocation\.enabled' -and $observedSchemaText -match 'spark\.sql\.adaptive\.enabled' -and $observedSchemaText -match 'spark\.sql\.shuffle\.partitions') 'Snapshot schema lacks effective Spark application-property evidence.'
Assert-True ($snapshotText -match 'planned_config' -and $snapshotText -match 'observed_runtime_evidence') 'Snapshot implementation does not emit the planned/observed separation required by v2.'
Assert-True ($snapshotText -notmatch 'planned_(min|max|node)') 'Legacy planned constants must not be emitted as observed YARN evidence.'
Assert-True ($snapshotText -match 'hdfs_uri = \$hdfsEffective\.fs_default_fs') 'Observed HDFS URI is not sourced from deployed configuration evidence.'
Assert-True ($snapshotText -match 'spark_event_log_path = \$sparkEffective\.''spark\.eventLog\.dir''') 'Observed event-log path is not sourced from effective Spark evidence.'
Assert-True ($snapshotText -match 'spark_yarn_archive = \$sparkEffective\.''spark\.yarn\.archive''') 'Observed Spark YARN archive is not sourced from effective Spark evidence.'

# Every partial or completed verification bundle has an explicit status, and
# every snapshot refers to the three host-observation phases.
Assert-True ($verificationStatusSchema.properties.schema_version.const -eq 'local_yarn_verification_status_v1') 'Unexpected verification-status schema version.'
$verificationStatuses = @($verificationStatusSchema.properties.status.enum)
foreach ($requiredStatus in @('COMPLETE', 'FAILED', 'INCOMPLETE')) {
    Assert-True ($verificationStatuses -contains $requiredStatus) "Verification-status schema is missing $requiredStatus."
}
$verificationToolingText = $verifyText + "`n" + $verificationSessionText
Assert-True ($verificationToolingText -match 'verification_status\.json') 'Verification tooling does not persist a machine-readable verification_status.json.'
Assert-True ($verificationToolingText -match 'local_yarn_verification_status_v1') 'Verification tooling does not identify the verification-status schema it emits.'
Assert-True ($startText -match 'New-LocalYarnVerificationSession[^\r\n]+-DoNotActivate') 'Docker preflight failure can overwrite an existing active verification session.'
foreach ($requiredStatus in @('COMPLETE', 'FAILED', 'INCOMPLETE')) {
    Assert-True ($verificationToolingText -match $requiredStatus) "Verification tooling never emits $requiredStatus."
}
Assert-True ($hostObservationSchema.properties.schema_version.const -eq 'local_yarn_host_observation_v1') 'Unexpected host-observation schema version.'
$hostPhases = @($hostObservationSchema.properties.phase.enum)
foreach ($requiredPhase in @('HOST_BASELINE', 'CLUSTER_IDLE', 'POST_SMOKE')) {
    Assert-True ($hostPhases -contains $requiredPhase) "Host-observation schema is missing $requiredPhase."
}
$combinedHostTooling = $startText + "`n" + $verifyText + "`n" + $snapshotText
foreach ($requiredPhase in @('HOST_BASELINE', 'CLUSTER_IDLE', 'POST_SMOKE')) {
    Assert-True ($combinedHostTooling -match $requiredPhase) "Host tooling does not capture $requiredPhase."
}
Assert-True ($stateText -match 'Environment status:\s+`LOCAL_YARN_V1`\s+=\s+\*\*VERIFIED\*\*') 'PROJECT_STATE does not record the Human-approved LOCAL_YARN_V1 VERIFIED state.'
Assert-True ($stateText -match 'LOCAL_YARN_V1_20260824T073936243Z_7cb92321' -and $stateText -match 'LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815') 'PROJECT_STATE does not preserve the approved verification session and snapshot IDs.'
Assert-True ($stateText -match 'Exact `C1` bootstrap values.*\*\*TBD') 'C1 must remain TBD.'
Assert-True ($stateText -match 'Data Gate:\s+\*\*NOT_APPROVED\*\*') 'Data Gate must remain NOT_APPROVED.'
Assert-True ($stateText -match '`UNVERIFIED_LEGACY`.*sha256:5902a010c834ec7a14c52dfd9b2fb0556b810d16dba9085859942d7713760a8e') 'Unsupported legacy digest is not explicitly excluded from verified evidence.'

$composeConfigResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'compose', '--env-file', $EnvFile, '-f', $composeFile, 'config', '--quiet'
)
Assert-True ($composeConfigResult.ExitCode -eq 0) 'docker compose config --quiet failed.'
$composeConfigJsonResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'compose', '--env-file', $EnvFile, '-f', $composeFile, '--profile', 'tools',
    'config', '--format', 'json'
) -NoEcho
$composeConfig = ($composeConfigJsonResult.StdOut -join "`n") | ConvertFrom-Json
foreach ($serviceProperty in @($composeConfig.services.PSObject.Properties)) {
    $serviceConfig = $serviceProperty.Value
    Assert-True (
        [int64]$serviceConfig.mem_limit -gt 0 -and
        [int64]$serviceConfig.memswap_limit -eq [int64]$serviceConfig.mem_limit
    ) "Compose service $($serviceProperty.Name) can use swap or lacks a memory limit."
}
$composeImagesResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'compose', '--env-file', $EnvFile, '-f', $composeFile, '--profile', 'tools', 'config', '--images'
)
$unexpectedImages = @($composeImagesResult.StdOut | Where-Object {
    $_ -and $_ -ne $resolvedEnvironment['LOCAL_YARN_IMAGE']
})
Assert-True ($unexpectedImages.Count -eq 0) 'Compose image interpolation differs from the authoritative selected env file.'
$composeServicesResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'compose', '--env-file', $EnvFile, '-f', $composeFile, '--profile', 'tools', 'config', '--services'
)
$services = @($composeServicesResult.StdOut | Where-Object { $_ })
$expectedServices = @('namenode', 'datanode-1', 'datanode-2', 'hdfs-init', 'resourcemanager', 'nodemanager-1', 'nodemanager-2', 'history-server', 'spark-client')
foreach ($service in $expectedServices) {
    Assert-True ($services -contains $service) "Missing Compose service: $service"
}
Assert-True ($services.Count -eq $expectedServices.Count) 'Unexpected Compose service count.'

Write-Host 'LOCAL_YARN_V1_STATIC_CONTRACT=PASS'
