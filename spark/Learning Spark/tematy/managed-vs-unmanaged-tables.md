# Managed vs unmanaged tables, views, global views

Spark SQL rozróżnia dwa typy tabel trwałych (persistent tables) rejestrowanych w katalogu (Hive Metastore lub wbudowanym katalogu Sparka), oraz dwa typy widoków tymczasowych.

## Managed tables (tabele zarządzane)

Dla tabeli zarządzanej **Spark zarządza zarówno metadanymi, jak i samymi danymi**. Dane fizycznie leżą w domyślnej lokalizacji magazynu (warehouse), określonej przez `spark.sql.warehouse.dir` (domyślnie coś w rodzaju `.../spark-warehouse/<nazwa_bazy>.db/<nazwa_tabeli>`).

```sql
CREATE TABLE managed_table (id INT, name STRING);
-- Spark sam decyduje, gdzie fizycznie zapisać dane
```

```python
df.write.saveAsTable("managed_table")
```

**Kluczowa cecha:** `DROP TABLE managed_table` usuwa **zarówno metadane z katalogu, jak i fizyczne pliki danych**. To Spark "posiada" dane od początku do końca ich cyklu życia.

## Unmanaged / external tables (tabele niezarządzane / zewnętrzne)

Dla tabeli niezarządzanej Spark zarządza **tylko metadanymi** — informację o schemacie, nazwie, formacie zapisuje w katalogu, ale same dane leżą w lokalizacji wskazanej jawnie przez użytkownika (np. na HDFS, S3, lokalnym systemie plików), niezależnie od Sparka.

```sql
CREATE TABLE unmanaged_table (id INT, name STRING)
USING PARQUET
LOCATION '/data/external/unmanaged_table';
```

```python
df.write.option("path", "/data/external/unmanaged_table").saveAsTable("unmanaged_table")
```

**Kluczowa cecha:** `DROP TABLE unmanaged_table` usuwa **tylko metadane z katalogu** — fizyczne pliki danych pod wskazaną ścieżką pozostają nietknięte. Tabela zewnętrzna jest przydatna, gdy dane są współdzielone z innymi systemami (np. Hive, Presto/Trino) albo gdy nie chcemy ryzykować przypadkowej utraty danych przy `DROP TABLE`.

## Porównanie

| Cecha | Managed table | Unmanaged (external) table |
|---|---|---|
| Kto zarządza metadanymi | Spark / metastore | Spark / metastore |
| Kto zarządza danymi | Spark (pełna kontrola cyklu życia) | Użytkownik / zewnętrzny system plików |
| Lokalizacja danych | Domyślny katalog warehouse | Jawnie podana przez `LOCATION`/`path` |
| Skutek `DROP TABLE` | Usuwa metadane **i** dane | Usuwa **tylko** metadane |
| Typowy use case | Dane "należące" wyłącznie do Sparka, tabele robocze/tymczasowe w pipeline | Współdzielenie danych z innymi silnikami, dane wrażliwe na przypadkowe usunięcie |

Sprawdzenie typu tabeli:

```sql
DESCRIBE FORMATTED nazwa_tabeli;
-- w wyniku pole "Type" pokaże MANAGED lub EXTERNAL
```

## Views (widoki)

Widok to **zapisane zapytanie**, a nie fizyczne dane — za każdym odwołaniem do widoku Spark na nowo wykonuje zapisany plan logiczny na aktualnych danych źródłowych.

### Temporary view (widok tymczasowy sesji)

```python
df.createOrReplaceTempView("people")
spark.sql("SELECT * FROM people").show()
```

- Związany wyłącznie z **konkretną `SparkSession`**, w której został utworzony.
- Znika, gdy ta sesja zostaje zamknięta.
- Niewidoczny z innych sesji (np. innej karty w Spark Thrift Server, innego wątku tworzącego nową sesję).

### Global temporary view (globalny widok tymczasowy)

```python
df.createGlobalTempView("people")
spark.sql("SELECT * FROM global_temp.people").show()
spark.newSession().sql("SELECT * FROM global_temp.people").show()  # inna sesja, ten sam SparkContext
```

- Powiązany ze specjalną, systemową bazą danych **`global_temp`** — dlatego zawsze trzeba odwoływać się do niego z prefiksem `global_temp.`.
- Żyje tak długo, jak **cała aplikacja Sparka** (czyli `SparkContext`), a nie tylko jedna sesja.
- Widoczny ze **wszystkich sesji** utworzonych w ramach tego samego `SparkContext` (np. przez `spark.newSession()`).
- Nadal **nie jest trwały** — po zakończeniu aplikacji znika (w przeciwieństwie do tabeli zarejestrowanej w metastore).

## Porównanie: temp view vs global temp view vs tabela trwała

| Cecha | Temp view | Global temp view | Tabela trwała (managed/unmanaged) |
|---|---|---|---|
| Zasięg | Jedna `SparkSession` | Cały `SparkContext` (baza `global_temp`) | Cały metastore, dostępna z innych aplikacji/narzędzi |
| Trwałość | Do końca sesji | Do końca aplikacji | Trwała, przeżywa restart aplikacji |
| Przechowuje dane fizycznie? | Nie – to zapisany plan zapytania | Nie – to zapisany plan zapytania | Tak (managed) lub odwołanie do danych (unmanaged) |
| Rejestracja w katalogu | Nie (widoczna tylko w kontekście sesji) | Częściowo (specjalna baza `global_temp`) | Tak, pełny wpis w metastore |

## Kluczowe zasady

- **Managed = Spark posiada dane i metadane** → `DROP TABLE` kasuje wszystko.
- **Unmanaged/external = Spark posiada tylko metadane** → `DROP TABLE` zostawia dane na dysku.
- **Temp view** żyje w obrębie jednej sesji, **global temp view** żyje w obrębie całej aplikacji i wymaga prefiksu `global_temp.`.
- Widoki nie przechowują danych — to zapisane zapytania wykonywane na żądanie na aktualnym stanie danych źródłowych.
