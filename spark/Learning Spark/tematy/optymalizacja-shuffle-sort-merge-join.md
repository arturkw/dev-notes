# Jak zoptymalizować shuffle sort merge join?

Shuffle Sort Merge Join (SMJ) — patrz [spark-join.md](spark-join.md) — to domyślna, ale najkosztowniejsza strategia joina dla dużych tabel: wymaga shuffle'owania **obu stron** po kluczu i ich sortowania. Poniżej konkretne techniki, którymi można go przyspieszyć albo całkowicie go uniknąć.

## 1. Zamień na Broadcast Hash Join, gdy to możliwe

Najskuteczniejsza optymalizacja — jeśli jedna ze stron joina jest wystarczająco mała, unikamy shuffle'a w ogóle.

```python
from pyspark.sql.functions import broadcast

result = fact_df.join(broadcast(dim_df), "customer_id")
```

Podnieś próg automatycznej detekcji, jeśli statystyki na to pozwalają:

```python
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 50 * 1024 * 1024)  # 50MB
```

Uwaga: jeśli mała tabela jest wynikiem złożonych transformacji (agregacje, joiny), Catalyst może źle oszacować jej rozmiar — wtedy warto wymusić `broadcast()` jawnie, zamiast polegać na automatycznej detekcji.

## 2. Bucketing — unikaj shuffle przy powtarzalnych joinach

Gdy te same tabele są joinowane wielokrotnie (np. w wielu jobach/zapytaniach) po tym samym kluczu, można **wstępnie zbucketować** obie tabele przy zapisie — dane są z góry podzielone na tę samą liczbę bucketów wg hash klucza joina i zapisane na dysku w tym układzie:

```python
(df
 .write
 .bucketBy(200, "customer_id")
 .sortBy("customer_id")
 .saveAsTable("fact_bucketed"))

(dim_df
 .write
 .bucketBy(200, "customer_id")
 .sortBy("customer_id")
 .saveAsTable("dim_bucketed"))
```

Jeśli obie tabele mają **identyczną liczbę bucketów i ten sam klucz bucketowania**, Spark przy joinie wykrywa, że dane są już odpowiednio podzielone i posortowane na dysku — może pominąć shuffle (i ewentualnie sortowanie) całkowicie ("bucket join" / eliminacja shuffle exchange w planie fizycznym). Koszt: shuffle jest przenoszony na moment **zapisu** tabeli (jednorazowo), zamiast płacić go przy **każdym** odczycie/joinie.

Ograniczenia: liczba bucketów musi się zgadzać (albo być wielokrotnością), a bucketing najlepiej sprawdza się dla tabel odpytywanych/joinowanych wielokrotnie — nie ma sensu dla danych używanych raz.

## 3. Salting przy data skew

Gdy klucz joina jest mocno nierównomierny (np. jeden `customer_id` odpowiada za 30% rekordów), jedna partycja po shuffle staje się "gorącym" wąskim gardłem (long-running task, możliwy spill/OOM).

**Salting**: do klucza po stronie dużej (skośnej) tabeli dodajemy losowy "sufiks" (np. 0-9), rozbijając w ten sposób gorący klucz na kilka mniejszych partycji, a po stronie mniejszej tabeli replikujemy odpowiednie wiersze dla każdej możliwej wartości soli:

```python
from pyspark.sql import functions as F

SALT_BUCKETS = 10

big_salted = big_df.withColumn("salt", (F.rand() * SALT_BUCKETS).cast("int")) \
    .withColumn("salted_key", F.concat_ws("_", "join_key", "salt"))

small_salted = small_df.withColumn("salt", F.explode(F.array([F.lit(i) for i in range(SALT_BUCKETS)]))) \
    .withColumn("salted_key", F.concat_ws("_", "join_key", "salt"))

result = big_salted.join(small_salted, "salted_key")
```

Od Sparka 3.x w wielu przypadkach nie trzeba tego robić ręcznie — patrz AQE skew join niżej.

## 4. Adaptive Query Execution (AQE)

Od Sparka 3.0 (domyślnie włączone od 3.2), `spark.sql.adaptive.enabled=true` pozwala silnikowi korygować plan **w trakcie wykonania**, na podstawie realnych statystyk runtime zebranych między stage'ami:

```
spark.sql.adaptive.enabled=true
spark.sql.adaptive.coalescePartitions.enabled=true   # scala zbyt drobne partycje po shuffle
spark.sql.adaptive.skewJoin.enabled=true             # automatycznie wykrywa i dzieli skośne partycje w SMJ
spark.sql.adaptive.skewJoin.skewedPartitionFactor     # próg "ile razy większa od mediany" = skew
spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes
```

- **Coalescing partitions**: jeśli po shuffle wiele partycji jest znacznie mniejszych niż optymalny rozmiar, AQE łączy je w mniejszą liczbę większych partycji — mniej narzutu na scheduling drobnych tasków.
- **Skew join optimization**: AQE automatycznie wykrywa, że jedna partycja po stronie SMJ jest dużo większa niż pozostałe, i dzieli ją na kilka mniejszych sub-partycji (odpowiednio replikując dopasowaną partycję drugiej strony) — efekt podobny do ręcznego salting, ale zrobiony automatycznie przez silnik.
- AQE potrafi też **dynamicznie przełączyć SMJ na Broadcast Hash Join**, jeśli po zastosowaniu filtrów okaże się w runtime, że jedna strona joina jest wystarczająco mała (czego Catalyst nie mógł wiedzieć na etapie statycznego planowania).

## 5. Filtrowanie przed joinem (predicate/projection pushdown)

- Filtruj (`.filter()`) i wybieraj tylko potrzebne kolumny (`.select()`) **przed** joinem, a nie po — mniej danych trafia do shuffle.
- Dla formatów kolumnowych (Parquet/ORC — patrz [parquet-avro-orc.md](parquet-avro-orc.md)) Catalyst i tak stara się zepchnąć filtry (predicate pushdown) i ograniczyć czytane kolumny (column pruning) możliwie nisko w planie, ale jawne filtrowanie wcześnie w kodzie ułatwia optymalizatorowi pracę i poprawia czytelność.

## 6. Odpowiednia liczba partycji shuffle

```python
spark.conf.set("spark.sql.shuffle.partitions", 400)  # dopasuj do rozmiaru danych i klastra
```

Zbyt mało partycji → duże partycje, spill na dysk, długie taski. Zbyt dużo → narzut na scheduling i małe pliki wyjściowe. Przy AQE (`coalescePartitions`) można bezpiecznie ustawić wyższą wartość startową — silnik i tak scali nadmiarowe partycje.

## 7. Kolejność i strategia joinów wielotabelowych

Przy joinowaniu wielu tabel warto joinować najpierw mniejsze/bardziej selektywne zbiory (po filtrach), zmniejszając ilość danych trafiających do kolejnych, droższych joinów. Catalyst Cost-Based Optimizer (CBO, przy `spark.sql.cbo.enabled=true` i aktualnych statystykach z `ANALYZE TABLE`) potrafi częściowo robić to automatycznie — reorder joinów na podstawie estymowanych rozmiarów tabel.

## Podsumowanie — checklist

1. Czy jedna strona joina zmieści się w pamięci → wymuś `broadcast()`.
2. Czy tabele są joinowane wielokrotnie → rozważ `bucketBy`.
3. Czy jest widoczny data skew w Spark UI (jeden task dużo dłuższy) → włącz AQE skew join albo zastosuj salting.
4. Czy AQE jest włączone (`spark.sql.adaptive.enabled=true`) — w nowoczesnych wersjach Sparka to pierwszy krok, zanim sięgnie się po ręczne triki.
5. Czy filtry/projekcje są zastosowane możliwie wcześnie, przed joinem.
6. Czy `spark.sql.shuffle.partitions` jest dopasowane do realnego rozmiaru danych.
