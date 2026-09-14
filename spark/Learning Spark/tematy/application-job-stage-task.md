# Czym są application, spark session, job, stage, task - wyjaśnij te pojęcia na przykładzie

## Hierarchia pojęć

```
Application
 └── SparkSession (może być kilka w ramach jednej aplikacji)
      └── Job (jeden na każdą akcję)
           └── Stage (podział wg granic shuffle'a)
                └── Task (jeden na partycję danych)
```

### Application

**Application** to cały program napisany przez użytkownika, uruchamiany od startu do końca poprzez `spark-submit` (lub sesję interaktywną w notebooku/shellu). Jednej aplikacji odpowiada jeden driver i jeden zestaw dedykowanych executorów przydzielonych przez cluster manager na czas jej działania. Aplikacja może w swoim toku uruchomić **wiele jobów** (każda akcja to nowy job).

### SparkSession

Punkt wejścia do API w ramach aplikacji — obiekt tworzony na driverze, przez który zgłaszamy operacje na DataFrame/DataSet/SQL. Zobacz [spark driver i spark session](spark-driver-i-spark-session.md). Zwykle jedna aplikacja = jedna sesja, ale technicznie można mieć kilka sesji (np. z różną konfiguracją) współdzielących ten sam `SparkContext`/executory.

### Job

**Job** jest tworzony za każdym razem, gdy w kodzie wywołana zostaje **akcja** (action), np. `collect()`, `count()`, `write.save(...)`. Job reprezentuje obliczenie potrzebne do wyprodukowania wyniku tej akcji — czyli cały DAG transformacji poprzedzających akcję, od źródła danych aż do niej.

### Stage

DAGScheduler dzieli job na **stages** — granicą podziału są operacje **wide** wymagające **shuffle'a** (np. `groupByKey`, `reduceByKey`, `join`, `repartition`, `distinct`, `sortBy`). W ramach jednego stage'a operacje narrow (`map`, `filter`, `select`, `withColumn`) są łączone w jeden pipeline (pipelining) — nie ma potrzeby materializować wyników pośrednich.

Stage'e wykonywane są w kolejności zależnej od DAG-a; jeśli stage B zależy od wyniku stage'a A (bo potrzebuje danych po shuffle'u z A), to A musi się zakończyć, zanim B ruszy.

### Task

Najmniejsza jednostka pracy — **jeden task na partycję danych** w danym stage'u. Jeśli stage operuje na DataFrame podzielonym na 200 partycji, DAGScheduler/TaskScheduler wygeneruje 200 tasków dla tego stage'a, rozdzielonych między dostępne executory (wg dostępnych rdzeni — `spark.executor.cores`). Task wykonuje faktyczny, wygenerowany (przez Tungsten/whole-stage codegen) kod na danych swojej partycji.

## Przykład (PySpark)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as _sum

spark = SparkSession.builder.appName("job-stage-task-demo").getOrCreate()

# Odczyt danych - narrow (samo wczytanie, brak shuffle'a)
orders = spark.read.parquet("/data/orders")          # np. 100 partycji
customers = spark.read.parquet("/data/customers")     # np. 20 partycji

# Transformacja narrow: filter (nie wywołuje shuffle'a)
recent_orders = orders.filter(col("order_date") >= "2024-01-01")

# Transformacja wide: join (WYMAGA shuffle'a -> granica nowego stage'a)
joined = recent_orders.join(customers, on="customer_id", how="inner")

# Transformacja wide: groupBy + agregacja (WYMAGA shuffle'a -> kolejna granica stage'a)
result = joined.groupBy("country").agg(_sum("amount").alias("total_amount"))

# AKCJA -> tworzy JOB
result.write.mode("overwrite").parquet("/data/output/sales_by_country")
```

### Co się dzieje krok po kroku

1. **Nic nie jest wykonywane**, dopóki nie pojawi się akcja — `read.parquet`, `filter`, `join`, `groupBy`, `agg` tylko budują logiczny plan (DAG). To leniwa ewaluacja.
2. Wywołanie `result.write...` (akcja) tworzy **jeden Job**.
3. DAGScheduler analizuje plan i dzieli go na **stage'e**, patrząc na operacje wide:
   - **Stage 0**: czytanie `orders`, `filter` (narrow) → przygotowanie danych do joina (tzw. "map side" joina, zapis shuffle).
   - **Stage 1**: czytanie `customers` → przygotowanie do joina (druga strona shuffle'a dla joina).
   - **Stage 2**: właściwy `join` (odczyt danych po shuffle'u z obu stron) + `groupBy`/`agg` — jeśli `join` i `groupBy` używają tego samego partycjonowania, mogą się złożyć w jeden lub dwa stage'e w zależności od planu fizycznego wybranego przez Catalyst (np. czy jest dodatkowy shuffle dla `groupBy`, czy dane są już odpowiednio popartycjonowane po joinie).
   - **Stage 3 (ostatni)**: zapis wyniku do `/data/output/...`.
   - (Rzeczywisty podział stage'ów zależy od wybranego przez Catalyst planu fizycznego — powyższe to uproszczenie dydaktyczne; dokładny DAG można zobaczyć w Spark UI.)
4. Stage'e, które nie zależą od siebie nawzajem (np. Stage 0 i Stage 1 — czytanie dwóch niezależnych źródeł), mogą być planowane/wykonywane równolegle.
5. Każdy stage jest dzielony na **taski** — jeden task na partycję. Np. Stage 0 operujący na 100 partycjach `orders` → 100 tasków.
6. TaskScheduler rozsyła taski do executorów, uwzględniając lokalność danych (data locality) i dostępne wolne rdzenie.
7. Po zakończeniu wszystkich tasków danego stage'a i zapisaniu danych shuffle, może ruszyć kolejny, zależny stage.
8. Po wykonaniu ostatniego stage'a i zapisaniu wyniku — job jest zakończony.

## Gdzie to zobaczyć

W **Spark UI** (domyślnie `http://<driver-host>:4040`):
- zakładka **Jobs** — lista jobów (jeden na akcję), z ich czasem trwania i statusem,
- wejście w konkretny job pokazuje **DAG Visualization** oraz listę **stage'ów**,
- wejście w stage pokazuje listę **tasków** wraz z metrykami (czas trwania, ilość przeczytanych/zapisanych danych, ewentualny data skew między taskami).

## Podsumowanie (na rozmowę kwalifikacyjną)

> Application to cały uruchomiony program Sparka z dedykowanym driverem i executorami. W ramach aplikacji tworzona jest SparkSession jako punkt wejścia do API. Każda akcja (np. `write`, `collect`) tworzy nowy Job. DAGScheduler dzieli job na Stage'e w miejscach, gdzie potrzebny jest shuffle (operacje wide typu join/groupBy), a operacje narrow łączy w jeden pipeline w ramach stage'a. Każdy stage dzielony jest dalej na Taski — po jednym na partycję danych — które są równolegle wykonywane przez executory.
