package localyarn;

import static org.apache.spark.sql.functions.col;

import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;

/** Infrastructure-only smoke application. This is not a benchmark workload. */
public final class LocalYarnSmoke {
    private LocalYarnSmoke() {
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected exactly one HDFS output path argument");
        }

        SparkSession spark = SparkSession.builder()
                .appName("LOCAL_YARN_V1_INFRASTRUCTURE_SMOKE")
                .getOrCreate();

        try {
            Dataset<Row> result = spark.range(0L, 100_000L)
                    .withColumn("bucket", col("id").mod(8L))
                    .groupBy("bucket")
                    .count()
                    .orderBy("bucket");

            long rowCount = result.count();
            if (rowCount != 8L) {
                throw new IllegalStateException("Expected 8 grouped rows, observed " + rowCount);
            }

            result.write().mode("errorifexists").parquet(args[0]);
            System.out.println("INFRASTRUCTURE_SMOKE_OUTPUT=" + args[0]);
            System.out.println("INFRASTRUCTURE_SMOKE_GROUP_COUNT=" + rowCount);
        } finally {
            spark.stop();
        }
    }
}

