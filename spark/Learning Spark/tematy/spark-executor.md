# Czym jest spark executor

## Definicja

Executor to **proces JVM** uruchamiany na węzłach roboczych (worker nodes) klastra, którego zadaniem jest faktyczne wykonywanie obliczeń (tasków) zleconych przez driver oraz przechowywanie danych (cache, dane shuffle). Każda aplikacja Sparka ma swój własny, dedykowany zestaw executorów — executory nie są współdzielone między różnymi aplikacjami.

## Cykl życia

1. Driver żąda zasobów od cluster managera.
2. Cluster manager uruchamia procesy executorów na dostępnych węzłach (liczba i rozmiar zależne od konfiguracji: `spark.executor.instances`, `spark.executor.cores`, `spark.executor.memory`).
3. Executory rejestrują się u drivera.
4. Driver (poprzez TaskScheduler) wysyła do executorów taski do wykonania.
5. Executory wykonują taski **równolegle**, wykorzystując wiele wątków (liczba równoległych tasków na executor ≈ liczba przydzielonych mu rdzeni CPU).
6. Executory żyją przez cały czas trwania aplikacji (chyba że włączona jest dynamiczna alokacja, wtedy mogą być tworzone/usuwane w trakcie) i kończą działanie, gdy aplikacja się kończy.

## Za co odpowiada executor

- **Wykonywanie tasków** — każdy task to jednostka pracy operująca na jednej partycji danych.
- **Przechowywanie danych w cache** — gdy dane są `cache()`/`persist()`owane, trafiają do pamięci (lub na dysk, zależnie od `StorageLevel`) konkretnego executora, który je przetworzył.
- **Przechowywanie danych shuffle** — wyniki pośrednie operacji wide (przed przetasowaniem do kolejnego stage'a) są zapisywane lokalnie przez executor na dysku, a następnie odczytywane (fetch) przez inne executory.
- **Raportowanie statusu i metryk** do drivera (postęp tasków, metryki wykonania widoczne potem w Spark UI).

## Wewnętrzna struktura pamięci executora

Pamięć executora (`spark.executor.memory`) dzieli się w uproszczeniu na:

- **Execution memory** — pamięć na obliczenia (shuffle, join, sort, agregacje).
- **Storage memory** — pamięć na dane cache'owane (`cache()`/`persist()`).
- **User memory** — na struktury danych użytkownika, np. UDF-y.
- **Reserved memory** — zarezerwowana wewnętrznie przez Sparka.

Execution i storage memory dzielą wspólny, elastyczny obszar (unified memory management) — mogą "pożyczać" sobie nawzajem miejsce w zależności od bieżącego zapotrzebowania, z pewnymi regułami pierwszeństwa. Szczegóły: [resource allocation i memory](resource-allocation-i-memory.md).

## Executor vs Task vs Slot

- Executor ma przydzieloną liczbę rdzeni (`spark.executor.cores`), co definiuje, ile tasków może wykonywać **równolegle** w danym momencie (jeden task = zwykle jeden rdzeń/wątek).
- Executor w ciągu życia aplikacji wykonuje **wiele tasków sekwencyjnie/równolegle** (nie jeden task = jeden executor).

## Executor vs Worker Node

- **Worker node** — fizyczna/wirtualna maszyna w klastrze.
- **Executor** — proces JVM uruchomiony na worker node. Na jednym worker node może działać jeden lub więcej executorów (zależnie od konfiguracji zasobów i typu cluster managera).

## Executor a fault tolerance

Jeśli executor ulegnie awarii (np. padnie węzeł, OOM), driver wykrywa to i:
- taski, które wykonywał ten executor, są ponawiane na innym executorze,
- dane cache'owane wyłącznie na tym executorze są tracone i przeliczane na nowo z lineage (chyba że replikowane, np. `StorageLevel.MEMORY_ONLY_2`),
- dane shuffle zapisane przez ten executor mogą wymagać ponownego przeliczenia odpowiednich tasków w poprzednim stage'u (chyba że używany jest External Shuffle Service, który przechowuje pliki shuffle niezależnie od cyklu życia executora).

## Konfiguracja (najważniejsze parametry)

| Parametr | Znaczenie |
|---|---|
| `spark.executor.instances` | Liczba executorów (przy statycznej alokacji) |
| `spark.executor.cores` | Liczba rdzeni na executor (stopień równoległości tasków w executorze) |
| `spark.executor.memory` | Pamięć JVM na executor |
| `spark.executor.memoryOverhead` | Dodatkowa pamięć off-heap (JVM overhead, natywne biblioteki) |

## Podsumowanie (na rozmowę kwalifikacyjną)

> Executor to długo żyjący proces JVM uruchamiany na węzłach klastra, dedykowany konkretnej aplikacji Sparka, który wykonuje zlecone przez driver taski (równolegle, wg liczby przydzielonych rdzeni), przechowuje dane cache'owane oraz pliki shuffle. W przeciwieństwie do klasycznego MapReduce, gdzie każdy task uruchamiał nową JVM, executory żyją przez cały czas trwania aplikacji, co znacząco redukuje narzut uruchamiania i pozwala efektywnie wykorzystywać pamięć (cache) między kolejnymi jobami tej samej aplikacji.
