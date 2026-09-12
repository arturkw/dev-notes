# Apache Spark – Spark SQL, DataFrames and Datasets Guide (streszczenie)

Źródło: [spark.apache.org/docs/latest/sql-programming-guide.html](https://spark.apache.org/docs/latest/sql-programming-guide.html) oraz powiązane podstrony: [sql-getting-started.html](https://spark.apache.org/docs/latest/sql-getting-started.html), [sql-data-sources.html](https://spark.apache.org/docs/latest/sql-data-sources.html), [sql-performance-tuning.html](https://spark.apache.org/docs/latest/sql-performance-tuning.html) (Spark 4.2.0)

Spark SQL to moduł Sparka do przetwarzania danych strukturalnych – w odróżnieniu od podstawowego RDD API dostarcza silnikowi więcej informacji o strukturze danych i wykonywanych obliczeniach, co pozwala na dodatkowe optymalizacje. Z tych samych danych i tego samego silnika wykonawczego można korzystać na kilka sposobów: przez zapytania SQL, API Dataset oraz API DataFrame – programista może swobodnie przełączać się między nimi w zależności od zadania.

## Spis treści

1. [Datasets i DataFrames](#1-datasets-i-dataframes)
2. [SparkSession](#2-sparksession)
3. [Tworzenie DataFrame](#3-tworzenie-dataframe)
4. [Nietypowane operacje na DataFrame](#4-nietypowane-operacje-na-dataframe)
5. [Uruchamianie zapytań SQL](#5-uruchamianie-zapytań-sql)
6. [Globalne widoki tymczasowe](#6-globalne-widoki-tymczasowe)
7. [Tworzenie Datasets](#7-tworzenie-datasets)
8. [Interoperacyjność z RDD](#8-interoperacyjność-z-rdd)
9. [Funkcje skalarne i agregujące](#9-funkcje-skalarne-i-agregujące)
10. [Źródła danych](#10-źródła-danych)
11. [Strojenie wydajności (Performance Tuning)](#11-strojenie-wydajności-performance-tuning)
12. [Kluczowe zasady](#kluczowe-zasady)

---

## 1. Datasets i DataFrames

### Dataset
- Rozproszona kolekcja danych wprowadzona w Sparku 1.6.
- Łączy zalety RDD (silne typowanie, funkcje lambda) z optymalizacjami silnika SQL Sparka (Catalyst/Tungsten).
- Może być budowany z obiektów JVM, wspiera transformacje funkcyjne: `map`, `flatMap`, `filter` itd.
- **Dostępność językowa**: tylko Scala i Java (typowany Dataset wymaga statycznego typowania na etapie kompilacji). Python i R nie mają bezpośredniego API Dataset – korzystają z dynamicznej natury DataFrame.

### DataFrame
- Dataset zorganizowany w nazwane kolumny – koncepcyjnie odpowiednik tabeli relacyjnej bazy danych lub `data.frame` w R/Pandas.
- **Dostępność językowa**: Python, Scala, Java, R.
- Reprezentacja wewnętrzna: w Scali/Javie to `Dataset[Row]` – w Scali `DataFrame` jest aliasem typu dla `Dataset[Row]`, w Javie używa się jawnie `Dataset<Row>`.
- Może być tworzony ze: ustrukturyzowanych plików danych, tabel Hive, zewnętrznych baz danych, istniejących RDD.

---

## 2. SparkSession

Punktem wejścia do wszystkich funkcjonalności Spark SQL jest klasa `SparkSession`.

```python
from pyspark.sql import SparkSession

spark = SparkSession \
    .builder \
    .appName("Python Spark SQL basic example") \
    .config("spark.some.config.option", "some-value") \
    .getOrCreate()
```

```scala
import org.apache.spark.sql.SparkSession

val spark = SparkSession
  .builder()
  .appName("Spark SQL basic example")
  .config("spark.some.config.option", "some-value")
  .getOrCreate()
```

```java
import org.apache.spark.sql.SparkSession;

SparkSession spark = SparkSession
  .builder()
  .appName("Java Spark SQL basic example")
  .config("spark.some.config.option", "some-value")
  .getOrCreate();
```

```r
sparkR.session(appName = "R Spark SQL basic example",
               sparkConfig = list(spark.some.config.option = "some-value"))
```

---

## 3. Tworzenie DataFrame

Przykład wczytania pliku JSON:

```python
df = spark.read.json("examples/src/main/resources/people.json")
df.show()
# +----+-------+
# | age|   name|
# +----+-------+
# |null|Michael|
# |  30|   Andy|
# |  19| Justin|
# +----+-------+
```

```scala
val df = spark.read.json("examples/src/main/resources/people.json")
df.show()
```

```java
Dataset<Row> df = spark.read().json("examples/src/main/resources/people.json");
df.show();
```

```r
df <- read.json("examples/src/main/resources/people.json")
showDF(df)
```

---

## 4. Nietypowane operacje na DataFrame

### `printSchema`
```python
df.printSchema()
# root
# |-- age: long (nullable = true)
# |-- name: string (nullable = true)
```

### `select`
```python
df.select("name").show()
```
```scala
import spark.implicits._
df.select("name").show()
```
```java
import static org.apache.spark.sql.functions.col;
df.select("name").show();
```
```r
head(select(df, "name"))
```

### `select` z wyrażeniami
```python
df.select(df['name'], df['age'] + 1).show()
```
```scala
df.select($"name", $"age" + 1).show()
```
```java
df.select(col("name"), col("age").plus(1)).show();
```

### `filter`
```python
df.filter(df['age'] > 21).show()
```
```scala
df.filter($"age" > 21).show()
```
```java
df.filter(col("age").gt(21)).show();
```

### `groupBy` + `count`
```python
df.groupBy("age").count().show()
```
```scala
df.groupBy("age").count().show()
```
```java
df.groupBy("age").count().show();
```

---

## 5. Uruchamianie zapytań SQL

DataFrame można zarejestrować jako widok tymczasowy i odpytywać czystym SQL-em:

```python
df.createOrReplaceTempView("people")
sqlDF = spark.sql("SELECT * FROM people")
sqlDF.show()
```

```scala
df.createOrReplaceTempView("people")
val sqlDF = spark.sql("SELECT * FROM people")
sqlDF.show()
```

```java
df.createOrReplaceTempView("people");
Dataset<Row> sqlDF = spark.sql("SELECT * FROM people");
sqlDF.show();
```

```r
df <- sql("SELECT * FROM table")
```

Widoki tworzone przez `createOrReplaceTempView` są związane z `SparkSession`, w którym powstały, i znikają po jego zamknięciu.

---

## 6. Globalne widoki tymczasowe

Widoki tymczasowe utworzone `createOrReplaceTempView` żyją tylko w obrębie jednej sesji. **Globalny widok tymczasowy** jest niezależny od sesji i powiązany z bazą `global_temp` – żyje aż do zakończenia całej aplikacji Sparka i można się do niego odwoływać z innych sesji tego samego `SparkContext`.

```python
df.createGlobalTempView("people")
spark.sql("SELECT * FROM global_temp.people").show()
spark.newSession().sql("SELECT * FROM global_temp.people").show()  # inna sesja
```

```scala
df.createGlobalTempView("people")
spark.sql("SELECT * FROM global_temp.people").show()
spark.newSession().sql("SELECT * FROM global_temp.people").show()
```

```sql
CREATE GLOBAL TEMPORARY VIEW temp_view AS SELECT a + 1, b * 2 FROM tbl;
SELECT * FROM global_temp.temp_view;
```

---

## 7. Tworzenie Datasets

Datasets są podobne do RDD, ale zamiast serializatorów Javy/Kryo używają wyspecjalizowanego kodera (Encoder), który serializuje obiekty do przetwarzania lub transmisji przez sieć.

**Scala (case class):**
```scala
case class Person(name: String, age: Long)

val caseClassDS = Seq(Person("Andy", 32)).toDS()
caseClassDS.show()

val primitiveDS = Seq(1, 2, 3).toDS()
primitiveDS.map(_ + 1).collect() // Array(2, 3, 4)

val path = "examples/src/main/resources/people.json"
val peopleDS = spark.read.json(path).as[Person]
peopleDS.show()
```

**Java (JavaBeans):**
```java
public static class Person implements Serializable {
  private String name;
  private long age;
  // gettery i settery...
}

Person person = new Person();
person.setName("Andy");
person.setAge(32);

Encoder<Person> personEncoder = Encoders.bean(Person.class);
Dataset<Person> javaBeanDS = spark.createDataset(
  Collections.singletonList(person), personEncoder);
javaBeanDS.show();

Encoder<Long> longEncoder = Encoders.LONG();
Dataset<Long> primitiveDS = spark.createDataset(Arrays.asList(1L, 2L, 3L), longEncoder);
primitiveDS.map((MapFunction<Long, Long>) value -> value + 1L, longEncoder).collect(); // [2, 3, 4]

Dataset<Person> peopleDS = spark.read().json(path).as(personEncoder);
```

---

## 8. Interoperacyjność z RDD

Spark SQL obsługuje dwa sposoby konwersji istniejących RDD na Datasety/DataFrame.

### 8.1 Wnioskowanie schematu przez refleksję

Metoda zwięzła, gdy typy elementów są znane wcześniej (np. przez case classes w Scali czy `Row` z nazwanymi polami w Pythonie).

```python
from pyspark.sql import Row

sc = spark.sparkContext
lines = sc.textFile("examples/src/main/resources/people.txt")
parts = lines.map(lambda l: l.split(","))
people = parts.map(lambda p: Row(name=p[0], age=int(p[1])))

schemaPeople = spark.createDataFrame(people)
schemaPeople.createOrReplaceTempView("people")

teenagers = spark.sql("SELECT name FROM people WHERE age >= 13 AND age <= 19")
teenNames = teenagers.rdd.map(lambda p: "Name: " + p.name).collect()
```

```scala
import spark.implicits._

val peopleDF = spark.sparkContext
  .textFile("examples/src/main/resources/people.txt")
  .map(_.split(","))
  .map(attributes => Person(attributes(0), attributes(1).trim.toInt))
  .toDF()
peopleDF.createOrReplaceTempView("people")

val teenagersDF = spark.sql("SELECT name, age FROM people WHERE age BETWEEN 13 AND 19")
teenagersDF.map(teenager => "Name: " + teenager(0)).show()
teenagersDF.map(teenager => "Name: " + teenager.getAs[String]("name")).show()

implicit val mapEncoder: Encoder[Map[String, Any]] =
  org.apache.spark.sql.Encoders.kryo[Map[String, Any]]
teenagersDF.map(teenager => teenager.getValuesMap[Any](List("name", "age"))).collect()
```

```java
JavaRDD<Person> peopleRDD = spark.read()
  .textFile("examples/src/main/resources/people.txt")
  .javaRDD()
  .map(line -> {
    String[] parts = line.split(",");
    Person person = new Person();
    person.setName(parts[0]);
    person.setAge(Integer.parseInt(parts[1].trim()));
    return person;
  });

Dataset<Row> peopleDF = spark.createDataFrame(peopleRDD, Person.class);
peopleDF.createOrReplaceTempView("people");

Dataset<Row> teenagersDF = spark.sql("SELECT name FROM people WHERE age BETWEEN 13 AND 19");
Dataset<String> teenagerNamesByIndexDF = teenagersDF.map(
    (MapFunction<Row, String>) row -> "Name: " + row.getString(0), Encoders.STRING());
```

### 8.2 Programistyczne definiowanie schematu

Używane, gdy nie da się z góry zdefiniować case classes (np. struktura rekordów jest zakodowana jako string i znana dopiero w czasie działania, albo liczba pól jest duża/zmienna). Schemat budowany jest programowo przez `StructType` złożony z obiektów `StructField`, a następnie stosowany do RDD zawierającego obiekty `Row`.

```python
from pyspark.sql.types import StringType, StructType, StructField

sc = spark.sparkContext
lines = sc.textFile("examples/src/main/resources/people.txt")
parts = lines.map(lambda l: l.split(","))
people = parts.map(lambda p: (p[0], p[1].strip()))

schemaString = "name age"
fields = [StructField(field_name, StringType(), True) for field_name in schemaString.split()]
schema = StructType(fields)

schemaPeople = spark.createDataFrame(people, schema)
schemaPeople.createOrReplaceTempView("people")

results = spark.sql("SELECT name FROM people")
results.show()
```

```scala
import org.apache.spark.sql.{Encoder, Row}
import org.apache.spark.sql.types._

val peopleRDD = spark.sparkContext.textFile("examples/src/main/resources/people.txt")

val schemaString = "name age"
val fields = schemaString.split(" ")
  .map(fieldName => StructField(fieldName, StringType, nullable = true))
val schema = StructType(fields)

val rowRDD = peopleRDD
  .map(_.split(","))
  .map(attributes => Row(attributes(0), attributes(1).trim))

val peopleDF = spark.createDataFrame(rowRDD, schema)
peopleDF.createOrReplaceTempView("people")
```

```java
JavaRDD<String> peopleRDD = spark.sparkContext()
  .textFile("examples/src/main/resources/people.txt", 1).toJavaRDD();

String schemaString = "name age";
List<StructField> fields = new ArrayList<>();
for (String fieldName : schemaString.split(" ")) {
  fields.add(DataTypes.createStructField(fieldName, DataTypes.StringType, true));
}
StructType schema = DataTypes.createStructType(fields);

JavaRDD<Row> rowRDD = peopleRDD.map((Function<String, Row>) record -> {
  String[] attributes = record.split(",");
  return RowFactory.create(attributes[0], attributes[1].trim());
});

Dataset<Row> peopleDataFrame = spark.createDataFrame(rowRDD, schema);
peopleDataFrame.createOrReplaceTempView("people");
```

---

## 9. Funkcje skalarne i agregujące

- **Funkcje skalarne** – zwracają pojedynczą wartość dla każdego wiersza. Spark SQL wspiera zarówno wbudowane funkcje skalarne, jak i funkcje zdefiniowane przez użytkownika (UDF).
- **Funkcje agregujące** – zwracają pojedynczą wartość dla grupy wierszy. Wbudowane: `count()`, `count_distinct()`, `avg()`, `max()`, `min()`. Można też tworzyć własne funkcje agregujące zdefiniowane przez użytkownika (UDAF).

---

## 10. Źródła danych

### Generyczne funkcje load/save

```scala
val df = spark.read
  .format("parquet")
  .option("key", "value")
  .load("path/to/data")

df.write
  .format("parquet")
  .option("key", "value")
  .mode("overwrite")
  .save("path/to/output")
```

**Uruchamianie SQL bezpośrednio na plikach** (bez wcześniejszego wczytywania do DataFrame):
```sql
SELECT * FROM parquet.`/path/to/file.parquet`
```

### Tryby zapisu (Save Modes)

| Tryb | Znaczenie |
|---|---|
| `error` (domyślny) | Rzuca błąd, jeśli dane już istnieją |
| `overwrite` | Nadpisuje istniejące dane |
| `append` | Dopisuje do istniejących danych |
| `ignore` | Ignoruje operację zapisu, jeśli dane już istnieją |

### Zapisywanie do tabel trwałych

```scala
df.write
  .mode("overwrite")
  .option("path", "/user/hive/warehouse/my_table")
  .saveAsTable("my_table")
```

### Bucketing, sortowanie i partycjonowanie

```scala
df.write
  .bucketBy(10, "id")
  .sortBy("name")
  .mode("overwrite")
  .option("path", "/path/to/output")
  .saveAsTable("my_bucketed_table")

df.write
  .partitionBy("year", "month")
  .mode("overwrite")
  .parquet("/path/to/partitioned/data")
```

### Ogólne opcje źródeł plikowych
Ignorowanie uszkodzonych plików, ignorowanie brakujących plików, filtrowanie ścieżek przez glob, rekurencyjne przeszukiwanie katalogów.

### Konkretne źródła danych

- **Parquet** – domyślny format Spark SQL. Wspiera automatyczne wykrywanie partycji na podstawie struktury katalogów, scalanie schematów (schema merging) z wielu plików Parquet oraz konwersję z/do metastore'u Hive.
  ```scala
  val parquetDF = spark.read.parquet("path/to/parquet/files")
  parquetDF.write.parquet("path/to/output")
  ```
- **ORC** – kolumnowy format plików wspierany analogicznie do Parquet.
- **JSON**:
  ```scala
  val jsonDF = spark.read.json("path/to/json/files")
  jsonDF.write.json("path/to/output")
  ```
- **CSV**:
  ```scala
  val csvDF = spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv("path/to/file.csv")
  ```
- **Text**:
  ```scala
  val textDF = spark.read.text("path/to/text/files")
  ```
- **Tabele Hive** – możliwość wskazania formatu przechowywania (Parquet, ORC itd.) oraz współpracy z różnymi wersjami metastore'u Hive:
  ```scala
  spark.sql("SELECT * FROM hive_table")
  ```
- **JDBC do innych baz danych** – połączenie z zewnętrzną bazą przez sterownik JDBC:
  ```scala
  val jdbcDF = spark.read
    .format("jdbc")
    .option("url", "jdbc:mysql://localhost:3306/database")
    .option("dbtable", "table_name")
    .option("user", "username")
    .option("password", "password")
    .load()
  ```
  Podstawowe właściwości połączenia: `url`, `dbtable`, `user`, `password`, `driver`.
- **XML** – odczyt/zapis danych XML.
- **Avro** – wymaga dodania osobnego pakietu; udostępnia funkcje `to_avro()` / `from_avro()`.
- **Protobuf** – wsparcie dla Protocol Buffers, funkcje `to_protobuf()` / `from_protobuf()`.
- **Whole Binary Files** – odczyt całych plików binarnych jako pojedynczych rekordów.

---

## 11. Strojenie wydajności (Performance Tuning)

### Cache'owanie danych w pamięci

```python
# Poprzez katalog Sparka
spark.catalog.cacheTable("tableName")
spark.catalog.uncacheTable("tableName")
spark.catalog.listCachedTables()

# Poprzez API DataFrame
dataFrame.cache()
dataFrame.unpersist()
```

| Parametr | Domyślnie | Opis |
|---|---|---|
| `spark.sql.inMemoryColumnarStorage.compressed` | `true` | Automatyczny wybór kodeka kompresji dla każdej kolumny na podstawie statystyk danych |
| `spark.sql.inMemoryColumnarStorage.batchSize` | `10000` | Rozmiar batcha przy cache'owaniu kolumnowym – większy poprawia kompresję, ale grozi OOM |

### Kluczowe parametry konfiguracyjne

| Parametr | Domyślnie | Opis |
|---|---|---|
| `spark.sql.files.maxPartitionBytes` | 128 MB | Maksymalna liczba bajtów pakowanych do jednej partycji przy odczycie plików (Parquet/JSON/ORC) |
| `spark.sql.files.openCostInBytes` | 4 MB | Szacowany koszt otwarcia pliku – pomaga rozłożyć małe pliki po partycjach |
| `spark.sql.files.minPartitionNum` | domyślny parallelism | Sugerowana minimalna liczba partycji plikowych |
| `spark.sql.files.maxPartitionNum` | brak | Sugerowana maksymalna liczba partycji plikowych |
| `spark.sql.shuffle.partitions` | `200` | Liczba partycji dla operacji shuffle (join/agregacje) |
| `spark.sql.sources.parallelPartitionDiscovery.threshold` | `32` | Próg dla równoległego listowania plików wejściowych |
| `spark.sql.autoBroadcastJoinThreshold` | 10 MB | Maksymalny rozmiar tabeli rozgłaszanej (broadcast) w joinach; `-1` wyłącza broadcast |
| `spark.sql.broadcastTimeout` | `300` s | Limit czasu oczekiwania na broadcast |

### Podpowiedzi (hints) strategii join

Dostępne cztery podpowiedzi wskazujące Sparkowi, jakiej strategii joina użyć:
- **BROADCAST** – wymusza broadcast join (nawet jeśli tabela przekracza próg),
- **MERGE** – sort-merge join,
- **SHUFFLE_HASH** – shuffled hash join,
- **SHUFFLE_REPLICATE_NL** – shuffled replicate nested loop join.

Przy sprzecznych podpowiedziach priorytet: **BROADCAST > MERGE > SHUFFLE_HASH > SHUFFLE_REPLICATE_NL**.

```python
spark.table("src").join(spark.table("records").hint("broadcast"), "key").show()
```
```sql
-- akceptuje też BROADCASTJOIN i MAPJOIN
SELECT /*+ BROADCAST(r) */ * FROM src s JOIN records r ON s.key = r.key
```

### Podpowiedzi coalesce/repartition

```sql
SELECT /*+ COALESCE(3) */ * FROM t;
SELECT /*+ REPARTITION(3) */ * FROM t;
SELECT /*+ REPARTITION(c) */ * FROM t;
SELECT /*+ REPARTITION(3, c) */ * FROM t;
SELECT /*+ REPARTITION_BY_RANGE(c) */ * FROM t;
SELECT /*+ REBALANCE */ * FROM t;
```

Służą do strojenia wydajności, redukcji liczby plików wyjściowych i kontroli rozkładu danych.

### Adaptive Query Execution (AQE)

AQE optymalizuje plan wykonania zapytania **w trakcie działania**, na podstawie statystyk runtime'owych. **Domyślnie włączone od Sparka 3.2.0** (`spark.sql.adaptive.enabled`).

Główne podfunkcje:

1. **Scalanie partycji po shuffle** (`spark.sql.adaptive.coalescePartitions.enabled`, domyślnie `true`) – łączy małe partycje, żeby uniknąć narzutu na dużą liczbę drobnych zadań. Powiązane parametry: `coalescePartitions.parallelismFirst`, `coalescePartitions.minPartitionSize`, `coalescePartitions.initialPartitionNum`, `advisoryPartitionSizeInBytes` (domyślnie 64 MB).
2. **Podział skośnych (skewed) partycji po shuffle** – rozbija nierówne partycje na mniejsze; parametr `optimizeSkewsInRebalancePartitions.enabled`.
3. **Konwersja sort-merge join na broadcast join**, gdy statystyki runtime pokazują, że jedna z tabel jest mała (`adaptive.autoBroadcastJoinThreshold`, `adaptive.localShuffleReader.enabled`).
4. **Konwersja sort-merge join na shuffled hash join**, gdy wszystkie partycje po shuffle mieszczą się w lokalnej hash-mapie (`maxShuffledHashJoinLocalMapThreshold`).
5. **Optymalizacja skośnych joinów (skew join)** – dzieli/replikuje skośne partycje na równe zadania (`skewJoin.enabled`, `skewJoin.skewedPartitionFactor` = 5.0, `skewJoin.skewedPartitionThresholdInBytes` = 256 MB, `forceOptimizeSkewedJoin`).

Zaawansowane opcje: `spark.sql.adaptive.optimizer.excludedRules` (wyłączenie wybranych reguł optymalizatora), `spark.sql.adaptive.customCostEvaluatorClass` (własna klasa oceny kosztu planu).

### Storage Partition Join (SPJ)

Eliminuje fazę shuffle, wykorzystując istniejący układ danych na dysku – uogólnia bucket joiny na dowolne partycjonowane źródła danych V2. Włączane m.in. przez `spark.sql.sources.v2.bucketing.enabled` (domyślnie `true`). Poznać po planie zapytania: brak węzłów `Exchange` przed joinem.

---

## Kluczowe zasady

- **Jeden silnik, wiele API** – SQL, DataFrame i Dataset korzystają z tego samego zoptymalizowanego silnika wykonawczego (Catalyst/Tungsten); wybór API to kwestia wygody, nie wydajności.
- **DataFrame = Dataset[Row]** – w Scali/Javie DataFrame to po prostu Dataset wierszy bez ścisłego typowania na etapie kompilacji; Dataset (silnie typowany) jest dostępny tylko w Scali/Javie.
- **Dwa sposoby konwersji RDD → DataFrame** – refleksja (szybsza w zapisie, wymaga znanego typu z góry) i programistyczne budowanie schematu (elastyczne, gdy schemat jest znany dopiero w runtime).
- **Format źródła danych jest wymienny** – ten sam ujednolicony DataFrame API (`read`/`write`) obsługuje Parquet, ORC, JSON, CSV, tekst, Hive, JDBC, Avro, Protobuf, XML.
- **AQE zmienia plan w locie** – od Sparka 3.2 domyślnie włączone, automatycznie koryguje liczbę partycji, strategię joina i obsługę skośności danych na podstawie realnych statystyk z wykonania, a nie tylko szacunków z planu logicznego.
- **Broadcast joiny są tanie, ale ograniczone rozmiarem** – `spark.sql.autoBroadcastJoinThreshold` i hinty (`BROADCAST`) pozwalają świadomie sterować, kiedy Spark unika kosztownego shuffle przy joinach.
