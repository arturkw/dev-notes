# Operacja spark join: typy, kwestie wydajności, przykłady (Broadcast Hash Join vs Shuffle Sort Merge Join)

Logiczny `join` w Spark SQL / DataFrame API jest tłumaczony przez Catalyst Optimizer (patrz [catalyst-optimizer.md](catalyst-optimizer.md)) na jedną z kilku **fizycznych strategii wykonania**. Wybór strategii ma ogromny wpływ na wydajność — ten sam kod logiczny może działać sekundy albo godziny w zależności od tego, jaki plan fizyczny zostanie wybrany.

## Typy fizycznych joinów

### 1. Broadcast Hash Join (BHJ)

- Mniejsza z dwóch tabel jest w całości serializowana i **rozesłana (broadcast) do wszystkich executorów**, gdzie budowana jest z niej hash table w pamięci.
- Większa tabela jest przetwarzana **lokalnie, partycja po partycji, bez shuffle** — dla każdego rekordu robimy lookup w lokalnej hash table.
- **Brak shuffle** = najszybszy typ joina, gdy da się go zastosować.
- Ograniczenie: mniejsza strona musi zmieścić się w pamięci każdego executora.

```python
from pyspark.sql.functions import broadcast

result = big_df.join(broadcast(small_df), "id")
```

Spark potrafi też **automatycznie** wybrać broadcast join bez podpowiedzi, jeśli szacowany rozmiar jednej ze stron jest mniejszy niż próg:

```
spark.sql.autoBroadcastJoinThreshold   # domyślnie 10MB (10485760)
```

Jeśli statystyki tabeli (np. z `ANALYZE TABLE` albo estymacja Catalysta) wskazują, że któraś strona joina jest mniejsza niż ten próg — Catalyst automatycznie zamienia plan na BHJ, nawet bez jawnego hinta.

### 2. Shuffle Sort Merge Join (SMJ) — domyślny dla dużych tabel

- Obie strony joina są **shuffle'owane** (repartycjonowane) po kluczu joina, tak by rekordy o tym samym kluczu trafiły do tej samej partycji na tym samym executorze.
- W obrębie partycji obie strony są **sortowane po kluczu joina**, a następnie łączone liniowym przejściem (merge), analogicznie do algorytmu merge sort.
- Domyślna strategia w Spark SQL, gdy żadna ze stron nie jest wystarczająco mała na broadcast.
- Kosztowny: pełny shuffle (I/O sieciowe i dyskowe) + sortowanie obu stron.

### 3. Shuffle Hash Join (SHJ)

- Podobnie jak SMJ — obie strony są shuffle'owane po kluczu joina.
- Zamiast sortowania, po stronie mniejszej z partycji budowana jest hash table (per-partycja, nie cała tabela jak w broadcast).
- Szybszy niż SMJ, gdy jedna strona partycji jest wyraźnie mniejsza od drugiej, ale mniej odporny na duże partycje (ryzyko OOM przy budowaniu hash table) — dlatego Spark preferuje SMJ jako bardziej "bezpieczny" domyślny wybór; SHJ trzeba zwykle wymusić hintem (`spark.sql.join.preferSortMergeJoin=false` + odpowiedni hint) albo occurs rzadziej automatycznie.

### 4. Broadcast Nested Loop Join (BNLJ)

- Używany, gdy **nie ma equi-join condition** (np. warunek joina to nierówność, `<`, `>`, zakres) albo jako fallback, gdy nie da się zastosować hash/sort merge.
- Dla każdego rekordu jednej strony przechodzi (nested loop) po wszystkich rekordach drugiej strony broadcastowanej.
- Bardzo kosztowny (O(n*m)) — stosowany zwykle tylko wtedy, gdy jedna ze stron jest mała, a warunek joina nie jest equi-join.

### 5. Cartesian Join

- Pełny iloczyn kartezjański, gdy brak jakiegokolwiek warunku joina (`crossJoin`) — praktycznie zawsze do unikania na dużych danych, chyba że to świadomy `crossJoin` na małych zbiorach.

## Porównanie wydajności

| Strategia | Shuffle | Sortowanie | Pamięć | Kiedy wybierana |
|---|---|---|---|---|
| Broadcast Hash Join | ❌ | ❌ | hash table jednej strony w pamięci każdego executora | jedna strona < `autoBroadcastJoinThreshold` (lub jawny hint) |
| Shuffle Sort Merge Join | ✅ (obie strony) | ✅ (obie strony) | umiarkowana (strumieniowe sortowanie/merge, możliwy spill) | domyślna dla dużych tabel po obu stronach |
| Shuffle Hash Join | ✅ (obie strony) | ❌ | hash table per partycja | jedna strona partycji wyraźnie mniejsza, ale rzadziej wybierana domyślnie |
| Broadcast Nested Loop Join | ❌ (broadcast zamiast) | ❌ | cała mała strona w pamięci, O(n*m) porównań | brak equi-join, jedna strona mała |
| Cartesian Join | ✅/❌ zależnie | ❌ | bardzo duże (pełny iloczyn) | brak warunku joina |

## Jak sprawdzić, jaki join wybrał Spark

```python
df.explain()          # albo df.explain("formatted") / explain(True) dla pełnego planu
```

W planie fizycznym (`== Physical Plan ==`) pojawi się np. `BroadcastHashJoin`, `SortMergeJoin`, `ShuffledHashJoin` — kluczowe miejsce do weryfikacji przy diagnozowaniu wolnych joinów.

## Praktyczne wskazówki

- Jeśli wiesz, że jedna tabela jest mała (np. tabela wymiarów w modelu gwiazdy) — **wymuś broadcast** jawnie zamiast liczyć na automatyczną detekcję, zwłaszcza gdy statystyki tabeli są nieaktualne (brak `ANALYZE TABLE`) lub dane pochodzą z transformacji, których Catalyst nie potrafi dobrze oszacować.
- Zbyt duży `autoBroadcastJoinThreshold` może doprowadzić do OOM na executorach próbujących zbudować zbyt dużą hash table — trzeba równoważyć rozmiar z dostępną pamięcią executora.
- Więcej o unikaniu kosztownego SMJ — patrz [optymalizacja-shuffle-sort-merge-join.md](optymalizacja-shuffle-sort-merge-join.md).
