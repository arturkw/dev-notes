# Apache Hive - co to jest, scenariusze użycia i jak go używać w Sparku?

## Czym jest Apache Hive

Apache Hive to zbudowana na Hadoopie **warstwa magazynu danych (data warehouse)**, która pozwala odpytywać dane leżące w rozproszonym systemie plików (HDFS, S3 itp.) językiem podobnym do SQL — **HiveQL**. Historycznie zapytania Hive były tłumaczone na joby MapReduce (dziś też Tez lub Spark jako silnik wykonawczy), ale kluczowym, trwałym elementem architektury Hive, który przetrwał i jest wykorzystywany do dziś niemal wszędzie w ekosystemie big data, jest **Hive Metastore**.

## Hive Metastore

Metastore to **scentralizowana baza metadanych** (zwykle relacyjna baza jak MySQL/PostgreSQL) przechowująca:

- definicje baz danych i tabel (schemat, typy kolumn),
- lokalizacje fizyczne danych (ścieżki na HDFS/S3),
- informacje o partycjonowaniu, formacie plików, bucketingu,
- statystyki tabel wykorzystywane przez optymalizatory kosztowe (CBO).

To właśnie dzięki temu, że metastore jest **niezależnym, wspólnym katalogiem**, wiele różnych silników (Hive, Spark, Presto/Trino, Impala) może odpytywać **te same tabele** bez duplikowania definicji — metastore pełni rolę uniwersalnego "słownika danych" dla całego klastra/data lake'u.

## Integracja Sparka z Hive

Spark SQL **nie wymaga** instalacji Hive, żeby działać — domyślnie korzysta z własnego, wbudowanego katalogu. Ale żeby korzystać z **istniejących tabel Hive** i współdzielić katalog z innymi narzędziami, włącza się wsparcie Hive:

```python
from pyspark.sql import SparkSession

spark = (SparkSession.builder
         .appName("hive-example")
         .config("spark.sql.warehouse.dir", "/user/hive/warehouse")
         .enableHiveSupport()
         .getOrCreate())
```

Kluczowe elementy konfiguracji:

- **`enableHiveSupport()`** — włącza `HiveSessionCatalog` zamiast domyślnego katalogu w pamięci; Spark zaczyna czytać/pisać metadane do rzeczywistego Hive Metastore (konfiguracja połączenia zwykle w `hive-site.xml` na classpath).
- **`spark.sql.warehouse.dir`** — domyślna lokalizacja, w której Spark (i Hive) fizycznie przechowują dane tabel zarządzanych (managed tables).

Po włączeniu obsługi Hive można odpytywać istniejące tabele bezpośrednio:

```python
spark.sql("SHOW DATABASES").show()
spark.sql("USE sales")
spark.sql("SELECT * FROM sales.orders WHERE year = 2024").show()
```

oraz tworzyć nowe tabele zarejestrowane w tym samym metastore, widoczne potem np. dla Hive czy Presto:

```sql
CREATE TABLE sales.orders_agg
STORED AS PARQUET
AS SELECT customer_id, SUM(amount) AS total
FROM sales.orders GROUP BY customer_id;
```

## Scenariusze użycia

1. **Data warehouse / data lake** — Hive Metastore jako centralny katalog tabel nad plikami w HDFS/S3, z których korzysta wiele zespołów i wiele silników zapytań.
2. **Migracja obliczeń z klasycznego Hive-on-MapReduce na Sparka** — istniejące tabele i zapytania HiveQL można uruchamiać na dużo szybszym silniku Sparka bez zmiany definicji danych, ustawiając Spark jako execution engine dla Hive (`hive.execution.engine=spark`) albo bezpośrednio odpytując te same tabele ze Sparka.
3. **Współdzielenie danych między narzędziami** — te same tabele (i ich metadane: schemat, partycjonowanie, statystyki) są widoczne jednocześnie dla Sparka, Presto/Trino, Hive czy narzędzi BI podłączonych przez JDBC (Spark Thrift Server, który emuluje HiveServer2).
4. **Wsparcie dla UDF-ów Hive** — Spark SQL potrafi rejestrować i wywoływać istniejące Hive UDF/UDAF/UDTF bez przepisywania ich na Sparka.
5. **Partycjonowane tabele produkcyjne** — Hive-style partycjonowanie katalogów (`/table/year=2024/month=01/...`) jest natywnie rozumiane zarówno przez Hive, jak i Spark, co ułatwia partition pruning.

## Hive vs Spark SQL — czym się różnią

| Aspekt | Hive (silnik MR/Tez) | Spark SQL |
|---|---|---|
| Model wykonania | Zwykle batch, historycznie MapReduce (dysk między etapami) | In-memory DAG, dużo szybszy dla iteracyjnych/wieloetapowych zapytań |
| Rola dziś | Głównie jako Metastore + HiveQL dialekt | Silnik wykonawczy zapytań SQL/DataFrame, może korzystać z metastore'u Hive |
| API | Głównie SQL | SQL, DataFrame, Dataset, RDD |
| Typowe użycie razem | Hive Metastore jako katalog | Spark jako silnik czytający/piszący te same tabele |

## Kluczowe zasady

- Hive to dziś w praktyce przede wszystkim **Hive Metastore** — wspólny katalog metadanych dla wielu silników.
- Spark integruje się z Hive przez `enableHiveSupport()` i `spark.sql.warehouse.dir`, uzyskując dostęp do istniejących tabel/baz i mogąc tworzyć nowe, widoczne dla innych narzędzi.
- Główna korzyść: **wspólny, spójny katalog danych** dla całego ekosystemu, zamiast silosów metadanych w każdym narzędziu z osobna.
