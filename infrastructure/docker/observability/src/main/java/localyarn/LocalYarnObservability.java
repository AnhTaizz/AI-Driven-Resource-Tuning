package localyarn;

import static org.apache.spark.sql.functions.col;
import static org.apache.spark.sql.functions.count;
import static org.apache.spark.sql.functions.lit;
import static org.apache.spark.sql.functions.sum;

import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.api.java.function.FlatMapFunction;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.apache.spark.storage.StorageLevel;

/**
 * Small, deterministic job for inspecting LOCAL_YARN_V1 monitoring surfaces.
 *
 * <p>This application is infrastructure observability only. It is not a
 * benchmark workload, an experiment, or a source of ML data.</p>
 */
public final class LocalYarnObservability {
    private static final long ROW_COUNT = 1_000_000L;
    private static final int INPUT_PARTITIONS = 8;
    private static final int SHUFFLE_PARTITIONS = 4;
    private static final int BUCKET_COUNT = 64;
    private static final int EXECUTOR_ACTIVITY_PARTITIONS = 2;
    private static final int MIN_OBSERVATION_SECONDS = 30;
    private static final int MAX_OBSERVATION_SECONDS = 600;

    private LocalYarnObservability() {
    }

    public static void main(String[] args) {
        int observationSeconds = parseObservationSeconds(args);
        SparkSession spark = SparkSession.builder()
                .appName("LOCAL_YARN_V1_OBSERVABILITY_TEST")
                .getOrCreate();

        Dataset<Row> cachedSource = null;
        Dataset<Row> cachedSummary = null;
        try {
            String applicationId = spark.sparkContext().applicationId();
            printConfiguration(applicationId, observationSeconds);

            spark.sparkContext().setJobGroup(
                    "OBSERVABILITY_CACHE",
                    "Materialize a deterministic cached Dataset for the Storage and Executors tabs",
                    false);
            cachedSource = spark.range(0L, ROW_COUNT, 1L, INPUT_PARTITIONS)
                    .withColumn("bucket", col("id").mod(BUCKET_COUNT))
                    .withColumn("value", col("id").multiply(lit(31L)).plus(lit(7L)))
                    .persist(StorageLevel.MEMORY_AND_DISK());

            long materializedRows = cachedSource.count();
            if (materializedRows != ROW_COUNT) {
                throw new IllegalStateException(
                        "Expected " + ROW_COUNT + " cached rows, observed " + materializedRows);
            }

            spark.sparkContext().setJobGroup(
                    "OBSERVABILITY_SHUFFLE",
                    "Run a fixed groupBy/orderBy query so SQL and shuffle metrics are populated",
                    false);
            cachedSummary = cachedSource
                    .repartition(SHUFFLE_PARTITIONS, col("bucket"))
                    .groupBy(col("bucket"))
                    .agg(
                            count("*").alias("record_count"),
                            sum(col("value")).alias("value_sum"))
                    .orderBy(col("bucket"))
                    .persist(StorageLevel.MEMORY_AND_DISK());

            List<Row> summaryRows = cachedSummary.collectAsList();
            if (summaryRows.size() != BUCKET_COUNT) {
                throw new IllegalStateException(
                        "Expected " + BUCKET_COUNT + " grouped rows, observed " + summaryRows.size());
            }
            long summarizedRecords = 0L;
            for (Row row : summaryRows) {
                summarizedRecords += ((Number) row.getAs("record_count")).longValue();
            }
            if (summarizedRecords != ROW_COUNT) {
                throw new IllegalStateException(
                        "Expected grouped record total " + ROW_COUNT + ", observed " + summarizedRecords);
            }

            spark.sparkContext().setJobGroup(
                    "OBSERVABILITY_EXECUTOR_ACTIVITY",
                    "Keep two bounded tasks active while live Spark UI and executor metrics are inspected",
                    false);
            System.out.println("OBSERVABILITY_WINDOW_STARTED=true");
            System.out.flush();

            JavaSparkContext javaSparkContext = JavaSparkContext.fromSparkContext(spark.sparkContext());
            long activityTaskCount = javaSparkContext
                    .parallelize(Arrays.asList(0, 1), EXECUTOR_ACTIVITY_PARTITIONS)
                    .mapPartitions(new ObservationPartition(observationSeconds))
                    .count();
            if (activityTaskCount != EXECUTOR_ACTIVITY_PARTITIONS) {
                throw new IllegalStateException(
                        "Expected " + EXECUTOR_ACTIVITY_PARTITIONS
                                + " executor activity tasks, observed " + activityTaskCount);
            }

            spark.sparkContext().setJobGroup(
                    "OBSERVABILITY_FINAL_CHECK",
                    "Read the cached Dataset once more before clean shutdown",
                    false);
            long bucketZeroRows = cachedSource.filter(col("bucket").equalTo(0L)).count();
            long expectedBucketZeroRows = ROW_COUNT / BUCKET_COUNT;
            if (bucketZeroRows != expectedBucketZeroRows) {
                throw new IllegalStateException(
                        "Expected " + expectedBucketZeroRows
                                + " rows in bucket zero, observed " + bucketZeroRows);
            }

            System.out.println("OBSERVABILITY_WINDOW_COMPLETED=true");
            System.out.println("OBSERVABILITY_MATERIALIZED_ROWS=" + materializedRows);
            System.out.println("OBSERVABILITY_SUMMARY_ROWS=" + summaryRows.size());
            System.out.println("OBSERVABILITY_ACTIVITY_TASKS=" + activityTaskCount);
            System.out.println("OBSERVABILITY_RESULT=SUCCESS");
        } finally {
            if (cachedSummary != null) {
                cachedSummary.unpersist(false);
            }
            if (cachedSource != null) {
                cachedSource.unpersist(false);
            }
            spark.stop();
        }
    }

    private static int parseObservationSeconds(String[] args) {
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected exactly one observation-seconds argument");
        }
        int value;
        try {
            value = Integer.parseInt(args[0]);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("Observation seconds must be an integer", exception);
        }
        if (value < MIN_OBSERVATION_SECONDS || value > MAX_OBSERVATION_SECONDS) {
            throw new IllegalArgumentException(
                    "Observation seconds must be between "
                            + MIN_OBSERVATION_SECONDS + " and " + MAX_OBSERVATION_SECONDS);
        }
        return value;
    }

    private static void printConfiguration(String applicationId, int observationSeconds) {
        System.out.println("OBSERVABILITY_CLASSIFICATION=INFRASTRUCTURE_OBSERVABILITY_ONLY");
        System.out.println("OBSERVABILITY_NOT_BENCHMARK=true");
        System.out.println("OBSERVABILITY_NOT_ML_DATA=true");
        System.out.println("OBSERVABILITY_APPLICATION_ID=" + applicationId);
        System.out.println("OBSERVABILITY_ROW_COUNT=" + ROW_COUNT);
        System.out.println("OBSERVABILITY_INPUT_PARTITIONS=" + INPUT_PARTITIONS);
        System.out.println("OBSERVABILITY_SHUFFLE_PARTITIONS=" + SHUFFLE_PARTITIONS);
        System.out.println("OBSERVABILITY_BUCKET_COUNT=" + BUCKET_COUNT);
        System.out.println("OBSERVABILITY_SECONDS=" + observationSeconds);
        System.out.flush();
    }

    private static final class ObservationPartition
            implements FlatMapFunction<Iterator<Integer>, Long> {
        private final long observationMillis;

        private ObservationPartition(int observationSeconds) {
            this.observationMillis = Math.multiplyExact((long) observationSeconds, 1_000L);
        }

        @Override
        public Iterator<Long> call(Iterator<Integer> values) throws Exception {
            long tokenCount = 0L;
            while (values.hasNext()) {
                values.next();
                tokenCount++;
            }
            Thread.sleep(observationMillis);
            return Collections.singletonList(tokenCount).iterator();
        }
    }
}
