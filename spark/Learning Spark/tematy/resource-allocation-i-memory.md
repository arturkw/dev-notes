# Dynamiczna vs statyczna alokacja zasobów (konfiguracja spark), execution memory vs storage memory, tuning wydajności związany z partycjami i operacją shuffle

## Static vs dynamic resource allocation

### Static allocation (domyślne zachowanie)

Przy zgłoszeniu aplikacji (`spark-submit`) podajesz z góry liczbę executorów oraz ich zasoby:

```
--num-executors 20
--executor-cores 4
--executor-memory 8g
```

Ta liczba executorów jest **rezerwowana na całą długość życia aplikacji**, niezależnie od tego, czy w danym momencie jest potrzebna. Zaleta: przewidywalność i stabilność wydajności — nie ma kosztu renegocjacji zasobów z cluster managerem w trakcie działania. Wada: marnotrawstwo zasobów klastra, gdy aplikacja ma fazy o różnym zapotrzebowaniu (np. długi etap czytania małego wejścia, potem ciężki shuffle na dużym zbiorze) albo gdy klaster jest współdzielony przez wiele aplikacji.

### Dynamic allocation

Spark potrafi dynamicznie zwiększać i zmniejszać liczbę executorów w trakcie działania aplikacji, w zależności od zalegających (pending) tasków.

Kluczowe configi:

```
spark.dynamicAllocation.enabled=true
spark.dynamicAllocation.minExecutors=2
spark.dynamicAllocation.maxExecutors=50
spark.dynamicAllocation.initialExecutors=<minExecutors domyślnie>
spark.dynamicAllocation.executorIdleTimeout=60s      # kiedy zwolnić "pusty" executor
spark.dynamicAllocation.schedulerBacklogTimeout=1s   # po jakim czasie zalegania tasków dokładać executory
```

Mechanizm działania:
- Scheduler co jakiś czas sprawdza, czy są zalegające (pending) taski, które czekałyby zbyt długo na wolny executor. Jeśli tak — driver prosi cluster manager o dodatkowe executory (żądanie rośnie wykładniczo, żeby szybko dogonić zapotrzebowanie).
- Executor, który przez `executorIdleTimeout` nie wykonuje żadnego zadania, jest zwalniany (decommissioned) i zwraca zasoby do klastra.

**Problem z shuffle danymi przy zwalnianiu executora**: jeśli executor przechowuje pliki shuffle (shuffle output), a zostanie zabity, kolejne stage'e, które muszą je odczytać (fetch), stracą te dane i Spark będzie musiał je przeliczyć. Dlatego dynamic allocation praktycznie wymaga **External Shuffle Service** (`spark.shuffle.service.enabled=true`) — osobnego procesu na każdym węźle (poza cyklem życia executora), który przechowuje i serwuje pliki shuffle nawet po tym, jak executor, który je wygenerował, zostanie usunięty. Od Sparka 3.x dostępna jest też alternatywa: **shuffle tracking** (`spark.dynamicAllocation.shuffleTracking.enabled=true`) — pozwala śledzić, które executory trzymają dane shuffle potrzebne innym stage'om i nie usuwać ich, dopóki dane nie zostaną skonsumowane, bez potrzeby uruchamiania zewnętrznego serwisu (przydatne np. w Kubernetes, gdzie External Shuffle Service jest trudniejszy do wdrożenia).

**Kiedy używać której strategii:**

| Kryterium | Static | Dynamic |
|---|---|---|
| Klaster dedykowany jednej aplikacji, stabilne obciążenie | ✅ | — |
| Klaster współdzielony (multi-tenant), zmienne obciążenie w czasie | — | ✅ |
| Aplikacje wsadowe (batch) o nierównym zapotrzebowaniu w czasie | — | ✅ |
| Streaming z niskimi wymaganiami na opóźnienie (nie chcesz "rozgrzewania" nowych executorów w trakcie) | ✅ (często) | zależnie od przypadku |

## Execution memory vs storage memory (Unified Memory Manager)

Pamięć każdego executora dzieli się (od Spark 1.6+, "Unified Memory Management") na:

- **Execution memory** — pamięć na obliczenia: shuffle, joiny (hash tables przy shuffle/broadcast hash join), sortowania (sort-based shuffle), agregacje. Ma charakter tymczasowy — dane mogą być odkładane (spilled) na dysk, gdy jej zabraknie.
- **Storage memory** — pamięć na cache'owane dane (`cache()`/`persist()`) i propagację zmiennych broadcast.

Obie kategorie dzielą wspólny region pamięci sterty JVM executora, którego rozmiar wyznacza:

```
usableMemory = (heapSize - 300MiB reserved) 
M = usableMemory * spark.memory.fraction        # domyślnie 0.6
R = M * spark.memory.storageFraction             # domyślnie 0.5 -> R = 0.5 * M
```

Reszta sterty (poza M) jest zarezerwowana na obiekty użytkownika i wewnętrzne metadane Sparka.

**Mechanizm "borrowing" (pożyczania) między execution i storage:**
- Jeśli execution potrzebuje więcej pamięci, a storage nie wykorzystuje całego swojego regionu — execution może "pożyczyć" wolną część storage.
- Jeśli storage potrzebuje więcej pamięci, a execution nie wykorzystuje całości — storage może pożyczyć od execution, ale **tylko do momentu**, gdy execution zażąda tej pamięci z powrotem — wtedy zcache'owane bloki są usuwane (evicted) z pamięci (ewentualnie spisywane na dysk, zależnie od storage level).
- **Execution ma pierwszeństwo** — może wywłaszczyć (evict) bloki storage, ale storage **nigdy nie może wywłaszczyć execution** (ze względów na złożoność implementacji — przerwanie trwającego shuffle'a/sortowania w połowie byłoby dużo bardziej skomplikowane).
- Region `R` (storageFraction) to **minimalna gwarantowana** przestrzeń dla cache'a — execution nie wywłaszczy bloków storage poniżej tego progu.

Konsekwencja praktyczna: aplikacja, która dużo cache'uje, a jednocześnie robi ciężkie shuffle/joiny, może doświadczyć evictions cache'owanych bloków w trakcie działania joinów — obserwuje się to jako spadające "Storage" w Spark UI podczas wykonywania kolejnych stage'ów.

## Partycje i tuning shuffle

### Liczba partycji

- `spark.default.parallelism` — domyślny poziom równoległości dla operacji na RDD (np. `reduceByKey` bez podanej liczby partycji) — domyślnie liczba rdzeni w klastrze.
- `spark.sql.shuffle.partitions` — liczba partycji **wyjściowych po shuffle** w Spark SQL/DataFrame API (joiny, agregacje z `groupBy`) — domyślnie **200**, niezależnie od rozmiaru danych i rozmiaru klastra. To jeden z najczęściej dostrajanych parametrów w praktyce.

**Problemy przy złym ustawieniu:**
- **Za mało partycji** → za duże partycje → ryzyko spilla na dysk w trakcie shuffle, długie GC, ryzyko OOM na pojedynczym tasku, słabe wykorzystanie równoległości klastra (mało tasków na dużo rdzeni).
- **Za dużo partycji** → dużo małych plików shuffle, narzut na harmonogramowanie (scheduling overhead) tysięcy drobnych tasków, dużo małych plików wyjściowych (problem "small files" przy zapisie do HDFS/S3).

Rekomendacja praktyczna: docelowy rozmiar partycji po shuffle to zwykle 100–200 MB; liczbę partycji dobiera się na podstawie rozmiaru danych wejściowych do danego etapu, a nie "na sztywno" — stąd popularność Adaptive Query Execution (AQE), które robi to automatycznie.

### Adaptive Query Execution (AQE)

Od Sparka 3.0 (`spark.sql.adaptive.enabled=true`, domyślnie włączone od Sparka 3.2) silnik potrafi w trakcie wykonania zapytania na podstawie realnych statystyk runtime (a nie tylko szacunków z etapu planowania):
- **coalesce'ować** zbyt drobne partycje po shuffle w większe (`spark.sql.adaptive.coalescePartitions.enabled`),
- wykrywać i dzielić skośne (skewed) partycje (`spark.sql.adaptive.skewJoin.enabled`),
- dynamicznie przełączać strategię joina (np. z sort-merge na broadcast, jeśli po filtrach jedna strona okazała się mała).

### Data skew

Gdy klucz shuffle (np. `user_id`, `country`) jest nierównomiernie rozłożony, jedna partycja/task dostaje nieproporcjonalnie dużo danych — reszta klastra kończy pracę szybko, a jeden task blokuje cały stage ("long tail"). Objawy w Spark UI: jeden task w stage'u trwa wielokrotnie dłużej niż mediana, albo kończy się OOM/spillem.

Sposoby przeciwdziałania: AQE skew join optimization, **salting** klucza (dodanie losowego sufiksu do klucza po stronie dużej tabeli i odpowiednie rozbicie/replikacja po stronie małej), rozdzielenie przetwarzania skośnych kluczy od pozostałych ("isolate the skew").

### Shuffle — dodatkowe parametry tuningowe

```
spark.shuffle.compress=true                 # kompresja plików shuffle (domyślnie true)
spark.reducer.maxSizeInFlight               # ile danych shuffle reducer pobiera równolegle (bufor sieciowy)
spark.shuffle.file.buffer                   # bufor zapisu plików shuffle (mniej I/O przy większym buforze)
spark.sql.shuffle.partitions                # patrz wyżej
```

W praktyce tuning shuffle to połączenie: (1) właściwej liczby partycji / AQE, (2) unikania niepotrzebnego shuffle w ogóle (np. przez broadcast join zamiast sort-merge join — patrz [spark-join.md](spark-join.md) i [optymalizacja-shuffle-sort-merge-join.md](optymalizacja-shuffle-sort-merge-join.md)), (3) monitorowania spilli i skew w Spark UI.
