# Czym są partycje, operacja repartition

## Czym jest partycja

**Partycja** to podstawowa jednostka równoległości w Sparku — fizyczny fragment rozproszonego zbioru danych (RDD/DataFrame/DataSet), który mieści się na jednym executorze i jest przetwarzany przez pojedynczy **task**. Cały zbiór danych jest logicznie jedną całością, ale fizycznie jest podzielony na wiele partycji rozrzuconych po klastrze.

Kluczowe fakty:

- Liczba partycji określa **maksymalny stopień równoległości** dla danego etapu obliczeń — jeden task obsługuje jedną partycję, więc liczba tasków uruchomionych równolegle w danym momencie jest ograniczona liczbą dostępnych core'ów executorów, a łączna liczba tasków w stage = liczba partycji.
- Zbyt **mało partycji** → za mało równoległości, niewykorzystane zasoby klastra, ryzyko OOM (bo pojedyncza partycja musi zmieścić się w pamięci executora).
- Zbyt **dużo partycji** → narzut na zarządzanie dużą liczbą małych tasków (scheduling overhead), dużo małych plików wyjściowych przy zapisie.
- Liczba partycji ustalana jest m.in. przez: liczbę bloków pliku źródłowego (np. bloki HDFS / rozmiar plików przy `spark.sql.files.maxPartitionBytes`, domyślnie 128 MB), parametr `spark.default.parallelism` (dla RDD), `spark.sql.shuffle.partitions` (dla DataFrame po shuffle, domyślnie 200) lub jawne wywołanie `repartition`/`coalesce`.

## Operacja `repartition`

`repartition(numPartitions)` lub `repartition(numPartitions, col)` zmienia liczbę partycji zbioru danych — **zarówno w górę, jak i w dół** — poprzez pełny **shuffle** danych.

```python
df2 = df.repartition(200)          # zmiana liczby partycji, hash na wszystkich kolumnach
df3 = df.repartition(200, "user_id")  # repartycjonowanie po kluczu — dane z tym samym kluczem trafiają do tej samej partycji
```

```scala
val df2 = df.repartition(200)
val df3 = df.repartition(200, $"user_id")
```

Cechy:

- Zawsze wykonuje **pełny shuffle** (all-to-all) — kosztowna operacja (I/O dyskowe + sieciowe + serializacja).
- Tworzy partycje **względnie równe rozmiarem** (round-robin lub hash partitioning), co jest przydatne, gdy dane są skośne (data skew) i chcemy je wyrównać przed kolejnymi operacjami.
- Repartycjonowanie po kolumnie (`repartition(n, col)`) jest przydatne przed operacjami typu join/groupBy na tej kolumnie, żeby uniknąć dodatkowego shuffle w kolejnym kroku, oraz przydatne przy zapisie danych partycjonowanych po kluczu biznesowym.

## `repartition` vs `coalesce`

| Aspekt | `repartition(n)` | `coalesce(n)` |
|---|---|---|
| Kierunek | zwiększanie i zmniejszanie liczby partycji | tylko **zmniejszanie** (sensownie) |
| Shuffle | zawsze pełny shuffle | **unika shuffle**, gdzie to możliwe — łączy sąsiadujące partycje na tych samych executorach |
| Rozkład danych | równomierny (hash/round-robin) | może być nierówny, bo scala istniejące partycje bez przenoszenia danych między węzłami |
| Koszt | wysoki | niski (dla zmniejszania liczby partycji) |
| Typowe użycie | zwiększenie równoległości, naprawa data skew, repartycjonowanie po kluczu | zmniejszenie liczby plików wyjściowych po filtrze, który mocno zredukował dane |

```python
# po mocnym filtrze zostało mało danych w wielu małych partycjach
filtered = df.filter(df.status == "active")   # 200 partycji, ale mało danych w każdej

# coalesce - tanio zmniejsza liczbę partycji bez shuffle
filtered.coalesce(10).write.parquet("output/")

# repartition - drożej, ale wyrównuje rozmiary partycji (przydatne przy dużym skew)
filtered.repartition(10).write.parquet("output/")
```

**Pułapka**: użycie `coalesce` do drastycznego zmniejszenia liczby partycji (np. z 2000 do 1) może spowodować, że cała operacja zostanie wykonana na bardzo małej liczbie executorów (bo dane nie są przenoszone między węzłami) — traci się równoległość we wcześniejszych etapach obliczenia, jeśli `coalesce` zostanie zastosowany zbyt wcześnie w łańcuchu transformations.

## Podsumowanie zasady wyboru

- Chcesz **zmniejszyć** liczbę partycji i **nie zależy Ci** na równym rozkładzie ani na dodatkowym shuffle → `coalesce`.
- Chcesz **zwiększyć** liczbę partycji, **wyrównać** rozkład danych (skew) albo repartycjonować po konkretnym kluczu przed joinem/agregacją → `repartition`.
