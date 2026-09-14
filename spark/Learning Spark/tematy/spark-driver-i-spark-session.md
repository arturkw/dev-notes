# Wyjaśnij spark driver, spark session

## Spark Driver

**Driver** to proces (JVM), w którym uruchamiana jest metoda `main()` aplikacji Sparka. To "mózg" aplikacji — nie przetwarza on sam danych na dużą skalę, ale zarządza całym cyklem życia obliczenia.

### Zadania drivera

1. **Tworzy `SparkSession`/`SparkContext`** — punkt wejścia do wszystkich funkcjonalności Sparka.
2. **Buduje logiczny plan wykonania (DAG)** na podstawie transformacji zadeklarowanych w kodzie użytkownika.
3. **Komunikuje się z cluster managerem** (Standalone, YARN, Kubernetes, Mesos) w celu zażądania zasobów (executorów).
4. **DAGScheduler** — dzieli DAG na stage'e (według granic shuffle'a).
5. **TaskScheduler** — dzieli stage'e na taski (po jednym na partycję) i zleca je konkretnym executorom, uwzględniając lokalizację danych (data locality).
6. **Śledzi stan wykonania** — monitoruje postęp tasków, obsługuje ich ponawianie w razie awarii, agreguje wyniki akcji (np. `collect()` zbiera dane z executorów z powrotem do drivera).
7. **Udostępnia Spark UI** (domyślnie port 4040) do monitorowania jobów/stage'ów/tasków.

### Ważna konsekwencja praktyczna

Ponieważ driver koordynuje wykonanie i czasem zbiera dane (np. `collect()`, `take()`), jest **pojedynczym punktem odpowiedzialnym za pamięć na poziomie aplikacji** — nieostrożne wywołanie `collect()` na bardzo dużym DataFrame może spowodować `OutOfMemoryError` na driverze, nawet jeśli klaster ma mnóstwo pamięci w executorach.

### Driver a tryby wdrożenia (deploy mode)

- **Client mode** — driver działa na maszynie, z której uruchomiono aplikację (np. laptop dewelopera, edge node) — poza klastrem. Wygodne do developmentu/debugowania (bezpośredni dostęp do logów), ale ryzykowne produkcyjnie (jeśli maszyna kliencka padnie lub straci łączność, aplikacja ginie).
- **Cluster mode** — driver jest uruchamiany jako proces **wewnątrz klastra** (np. na jednym z węzłów YARN/K8s), zarządzany przez cluster manager. Bardziej odporne produkcyjnie, bo driver podlega tym samym mechanizmom restartu/monitoringu co inne komponenty klastra.

## Spark Session

`SparkSession` to **ujednolicony punkt wejścia** do API Sparka, wprowadzony w Sparku 2.0, zastępujący wcześniejszą mnogość kontekstów (`SparkContext`, `SQLContext`, `HiveContext`, `StreamingContext`).

### Co udostępnia

```scala
val spark = SparkSession.builder()
  .appName("MojaAplikacja")
  .master("local[*]")
  .config("spark.sql.shuffle.partitions", "200")
  .enableHiveSupport()
  .getOrCreate()
```

- Dostęp do DataFrame/DataSet API (`spark.read`, `spark.createDataFrame`, `spark.sql(...)`).
- Wewnętrznie tworzy i opakowuje `SparkContext` (dostępny jako `spark.sparkContext`, potrzebny np. do operacji na RDD niskiego poziomu).
- Konfigurację aplikacji (`spark.conf`).
- Integrację z katalogiem metadanych (`spark.catalog`) — tabele, bazy danych, funkcje (w tym opcjonalnie Hive metastore przez `enableHiveSupport()`).
- Uruchamianie zapytań SQL bezpośrednio: `spark.sql("SELECT ...")`.

### SparkSession vs SparkContext

| | SparkContext | SparkSession |
|---|---|---|
| Wprowadzony w | Spark 1.x (pierwotne API) | Spark 2.0 |
| Poziom API | Niskopoziomowy — RDD | Wysokopoziomowy — DataFrame/DataSet/SQL |
| Rola | Połączenie z klastrem, zarządzanie zadaniami | Ujednolicony punkt wejścia, wewnątrz zawiera SparkContext |
| Liczba na JVM | Jeden na JVM (klasycznie) | Można mieć wiele sesji współdzielących ten sam SparkContext (np. izolowana konfiguracja/katalog per sesja) |

### Gdzie żyje SparkSession

`SparkSession` jest tworzony i istnieje **na driverze** — to obiekt, przez który kod użytkownika (na driverze) komunikuje się z resztą klastra. Nie da się go użyć/zserializować wewnątrz kodu wykonywanego na executorach (np. wewnątrz `.map(...)` na RDD) — próba użycia `spark` wewnątrz takiej funkcji zwykle kończy się błędem serializacji, ponieważ `SparkSession` reprezentuje stan driverowy, a nie coś, co ma sens per-partycja na executorze.

## Podsumowanie (na rozmowę kwalifikacyjną)

> Driver to proces JVM uruchamiający kod `main()` aplikacji, odpowiedzialny za budowę DAG-a, podział na stage'e/taski, komunikację z cluster managerem i koordynację całego wykonania. SparkSession to od Sparka 2.0 ujednolicony punkt wejścia do API (DataFrame/DataSet/SQL), tworzony na driverze i opakowujący wewnętrznie SparkContext, który pozostaje potrzebny do operacji niskopoziomowych na RDD.
