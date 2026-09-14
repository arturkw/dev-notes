## Architektura i podstawy Sparka
- [Czym jest DAG?](tematy/dag.md)
- [Dlaczego Spark jest szybki?](tematy/dlaczego-spark-jest-szybki.md)
- [Czym jest Tungsten?](tematy/tungsten.md)
- [Dlaczego Spark jest szybszy od Hadoop?](tematy/spark-vs-hadoop.md)
- [Wyjaśnij spark driver, spark session](tematy/spark-driver-i-spark-session.md)
- [Typy cluster managerów](tematy/cluster-managery.md)
- [Czym jest spark executor](tematy/spark-executor.md)
- [Czym są application, spark session, job, stage, task - wyjaśnij te pojęcia na przykładzie (możesz dodać fragment kodu)](tematy/application-job-stage-task.md)

## Model wykonania i API (RDD/DataFrame/DataSet)
- [Transformations vs actions, lazy evaluation, narrow vs wide transformations](tematy/transformations-vs-actions.md)
- [Czym są partycje, operacja repartition](tematy/partycje-i-repartition.md)
- [Różnice pomiędzy RDD, DataFrame, DataSet, kiedy stosować które, jakie są kwestie związane z wydajnością](tematy/rdd-vs-dataframe-vs-dataset.md)
- [Czym jest DataSet encoder, serializacja / deserializacja w DS, a kwestie wydajności](tematy/dataset-encoder-serializacja.md)
- [Jakie są kwestie związane z wydajnością DataSet?](tematy/wydajnosc-dataset.md)
- [Czym jest user defined function?](tematy/user-defined-function.md)

## Spark SQL, Catalyst i tabele
- [Czym jest Spark SQL?](tematy/spark-sql.md)
- [Czym jest Catalyst Optimizer?](tematy/catalyst-optimizer.md)
- [Managed vs unmanaged tables, views, global views](tematy/managed-vs-unmanaged-tables.md)
- [Apache Hive - co to jest, scenariusze użycia i jak go używać w Sparku?](tematy/apache-hive.md)

## Formaty danych
- [Porównaj formaty parquet, avro, orc](tematy/parquet-avro-orc.md)

## Wydajność i tuning
- [Dynamiczna vs statyczna alokacja zasobów (konfiguracja spark), execution memory vs storage memory, tuning wydajności związany z partycjami i operacją shuffle](tematy/resource-allocation-i-memory.md)
- [Cachowanie i persystencja danych](tematy/caching-i-persystencja.md)
- [Operacja spark join: typy, kwestie wydajności, przykłady (Broadcast Hash Join vs Shuffle Sort Merge Join)](tematy/spark-join.md)
- [Jak zoptymalizować shuffle sort merge join?](tematy/optymalizacja-shuffle-sort-merge-join.md)

## Streaming
- [Structured Streaming: geneza, model programowania, źródła, transformacje stanowe, joiny i tuning](tematy/structured-streaming.md)
