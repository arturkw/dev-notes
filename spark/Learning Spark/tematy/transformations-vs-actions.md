# Transformations vs actions, lazy evaluation, narrow vs wide transformations

## Transformations vs actions

Operacje w Sparku (na RDD, DataFrame, DataSet) dzielą się na dwie kategorie:

- **Transformations** – budują nowy RDD/DataFrame z istniejącego, ale **nic się nie liczy w momencie ich wywołania**. Zwracają jedynie opis obliczenia (nowy węzeł w logicznym planie / DAG). Przykłady: `map`, `filter`, `select`, `groupBy`, `join`, `withColumn`, `distinct`, `union`.
- **Actions** – uruchamiają faktyczne obliczenie całego zbudowanego dotąd łańcucha transformations i albo zwracają wynik do drivera, albo zapisują dane. Przykłady: `collect`, `count`, `show`, `take`, `reduce`, `foreach`, `write.save`, `saveAsTextFile`.

Rozróżnienie to jest fundamentem modelu wykonania Sparka — bez akcji żadna transformation się nie wykonuje.

```python
df2 = df.filter(df.age > 18).select("name")   # transformation — nic się nie liczy
df2.show()                                     # action — dopiero teraz Spark liczy
```

## Lazy evaluation (leniwa ewaluacja)

Zamiast wykonywać każdą transformation od razu, Spark buduje **logiczny plan wykonania (DAG)** opisujący sekwencję operacji. Dopiero wywołanie akcji powoduje, że:

1. Catalyst Optimizer analizuje cały zgromadzony plan logiczny (a nie pojedynczą operację) i optymalizuje go jako całość (predicate pushdown, column pruning, eliminacja zbędnych operacji, łączenie filtrów itd.).
2. Plan logiczny jest tłumaczony na plan fizyczny i dzielony na joby/stage'e/taski.
3. Dopiero wtedy dane faktycznie są czytane i przetwarzane.

Korzyści leniwej ewaluacji:

- **Globalna optymalizacja** — optymalizator widzi cały łańcuch operacji naraz, a nie wykonuje ich krok po kroku, więc może np. przesunąć filtr przed join (predicate pushdown) albo pominąć kolumny, które nigdy nie są używane (column pruning).
- **Unikanie zbędnej pracy** — jeśli po wielu transformations wywołasz `.limit(10).show()`, Spark nie musi przetwarzać całego zbioru danych.
- **Mniejsze zużycie pamięci pośredniej** — nie trzeba materializować wyników każdego kroku.

Wada/pułapka: transformation zawierająca efekt uboczny (np. rzucający wyjątek `map`) nie ujawni błędu w momencie jej zdefiniowania, tylko dopiero przy wywołaniu akcji — co bywa mylące przy debugowaniu.

## Narrow vs wide transformations

Kluczowy podział transformations pod kątem tego, jak dane przepływają między partycjami — decyduje o tym, czy potrzebny jest **shuffle**, a więc i o granicach między **stage'ami**.

### Narrow transformation

- Każda partycja wyjściowa zależy **tylko od jednej partycji wejściowej** (1:1 lub N:1 bez potrzeby przenoszenia danych między węzłami).
- Można wykonać w całości na jednym executorze, bez komunikacji sieciowej.
- Przykłady: `map`, `mapPartitions`, `filter`, `flatMap`, `union`.
- Nie tworzy nowej granicy stage — Spark może je "spipeline'ować" (pipelining) razem w jednym stage.

### Wide transformation

- Partycja wyjściowa zależy od **wielu partycji wejściowych**, potencjalnie z różnych węzłów — dane muszą zostać przetasowane między executorami (**shuffle**).
- Przykłady: `groupByKey`, `reduceByKey`, `join` (bez broadcast), `distinct`, `repartition`, `sortBy`, `groupBy` w DataFrame.
- Kończy bieżący stage i rozpoczyna nowy — granica stage'y w Sparku wyznaczana jest właśnie przez wide transformations.

```
RDD_A --map--> RDD_B --filter--> RDD_C --reduceByKey--> RDD_D --map--> RDD_E
   \_______________ Stage 1 ________________/  |  \______ Stage 2 ______/
                                          (shuffle boundary)
```

### Konsekwencje praktyczne

| Aspekt | Narrow | Wide |
|---|---|---|
| Koszt | Niski, brak I/O sieciowego | Wysoki — dysk + sieć + serializacja |
| Granica stage | Nie tworzy | Tworzy nową |
| Odporność na awarie | Przeliczenie tylko utraconej partycji | Może wymagać przeliczenia wielu partycji poprzedników |
| Przykład optymalizacji | pipelining wielu narrow transformations w jeden przebieg | minimalizacja liczby shuffle'i, użycie `reduceByKey` zamiast `groupByKey`, broadcast join zamiast shuffle join |

Zrozumienie narrow vs wide transformations jest kluczowe przy optymalizacji — im mniej wide transformations (shuffle'i) w łańcuchu obliczeń, tym szybsza aplikacja.
