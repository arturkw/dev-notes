# Czym jest Spark SQL?

Spark SQL to moduł Apache Spark do przetwarzania danych **strukturalnych i częściowo strukturalnych**. W odróżnieniu od niskopoziomowego RDD API, Spark SQL dostarcza silnikowi dodatkowej informacji o **strukturze danych** (schema) i **semantyce wykonywanych operacji**, dzięki czemu optymalizator (Catalyst) i silnik generowania kodu (Tungsten) mogą znacząco poprawić wydajność wykonania w porównaniu z ręcznie pisanym kodem na RDD.

## Kluczowa idea: jeden silnik, wiele API

Ten sam zestaw danych i ten sam silnik wykonawczy można odpytywać na trzy równoważne sposoby:

- **SQL** – klasyczne zapytania `spark.sql("SELECT ...")`,
- **DataFrame API** – nietypowany, deklaratywny DSL (`df.select(...).filter(...)`),
- **Dataset API** – silnie typowany odpowiednik DataFrame (tylko Scala/Java).

Wszystkie trzy kompilują się do tego samego planu logicznego, który przechodzi przez Catalyst Optimizer i trafia do tego samego silnika wykonawczego. Wybór API to kwestia wygody i bezpieczeństwa typów, **nie wydajności** — dobrze napisany DataFrame i odpowiadające mu zapytanie SQL wygenerują identyczny (lub bardzo zbliżony) plan fizyczny.

## Punkt wejścia: SparkSession

Od Sparka 2.0 jedynym punktem wejścia do Spark SQL (i całego Sparka) jest `SparkSession`, który ujednolicił wcześniejsze `SQLContext` i `HiveContext`.

```python
from pyspark.sql import SparkSession

spark = (SparkSession.builder
         .appName("spark-sql-example")
         .enableHiveSupport()
         .getOrCreate())
```

## Główne abstrakcje danych

- **DataFrame** — rozproszona kolekcja danych zorganizowana w nazwane kolumny, koncepcyjnie odpowiednik tabeli relacyjnej. W Scali/Javie to alias dla `Dataset[Row]`. Dostępny we wszystkich językach (Python, Scala, Java, R).
- **Dataset** — silnie typowana wersja DataFrame, dostępna tylko w Scali/Javie (Python i R nie mają statycznego typowania na etapie kompilacji, więc operują wyłącznie na DataFrame).

Więcej: [Różnice pomiędzy RDD, DataFrame, DataSet](rdd-vs-dataframe-vs-dataset.md).

## Skąd biorą się dane

DataFrame można zbudować m.in. z:

- plików ustrukturyzowanych (Parquet, JSON, CSV, ORC, Avro, tekst),
- tabel Hive (przez Hive Metastore),
- zewnętrznych baz danych po JDBC,
- istniejących RDD (przez refleksję lub programistyczne zdefiniowanie schematu).

```scala
val df = spark.read.json("people.json")
df.createOrReplaceTempView("people")
val teenagers = spark.sql("SELECT name FROM people WHERE age BETWEEN 13 AND 19")
```

## Dlaczego Spark SQL jest szybszy niż surowe RDD

1. **Znajomość schematu** — silnik wie, jakie kolumny i typy istnieją, więc może odrzucić nieużywane kolumny (column pruning) czy wcześnie odfiltrować dane (predicate pushdown).
2. **Catalyst Optimizer** — przekształca zapytanie przez fazy analysis → logical optimization → physical planning → code generation, wybierając najtańszy plan wykonania.
3. **Tungsten** — zarządza pamięcią poza stertą JVM (off-heap), generuje bajtkod dla całych fragmentów planu (whole-stage code generation), eliminując narzut wirtualnych wywołań i boxing/unboxing.
4. **Unifikacja źródeł danych** — ten sam zoptymalizowany silnik obsługuje pliki, tabele Hive, JDBC itd. przez jednolite API `read`/`write`.

## Typowe zastosowania

- Analityka wsadowa (batch) na dużych zbiorach danych — ETL, raportowanie.
- Interaktywne zapytania SQL na danych w data lake (Parquet/ORC na HDFS/S3).
- Warstwa danych dla Structured Streaming (te same API DataFrame/Dataset obsługują strumienie).
- Integracja z narzędziami BI przez JDBC/ODBC (Spark Thrift Server).

## Adaptive Query Execution (AQE)

Od Sparka 3.2 Spark SQL domyślnie koryguje plan wykonania **w trakcie działania zapytania** na podstawie realnych statystyk runtime (a nie tylko szacunków z planu logicznego) — m.in. scala małe partycje po shuffle, przełącza sort-merge join na broadcast join, gdy okaże się, że tabela jest mała, i optymalizuje skośne (skewed) partycje. Zobacz [Jak zoptymalizować shuffle sort merge join?](optymalizacja-shuffle-sort-merge-join.md).

## Podsumowanie

Spark SQL to nie tylko "SQL na Sparku" — to deklaratywny rdzeń całego silnika Sparka, na którym opierają się DataFrame, Dataset, Structured Streaming i większość nowoczesnych integracji. Dzięki znajomości schematu i optymalizatorowi Catalyst pozwala pisać kod deklaratywnie, a mimo to uzyskiwać wydajność zbliżoną do ręcznie strojonego niskopoziomowego kodu.
