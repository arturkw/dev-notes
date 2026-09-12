# Apache Spark – Job Scheduling (streszczenie)

Źródło: [spark.apache.org/docs/latest/job-scheduling.html](https://spark.apache.org/docs/latest/job-scheduling.html) (Spark 4.2.0)

Przewodnik opisujący dwa poziomy planowania zasobów w Sparku: między niezależnymi aplikacjami (na poziomie cluster managera) oraz wewnątrz jednej aplikacji (na poziomie schedulera Sparka, gdy wiele jobów działa równolegle w tym samym `SparkContext`).

## Spis treści

1. [Przegląd](#1-przegląd)
2. [Planowanie między aplikacjami](#2-planowanie-między-aplikacjami)
3. [Planowanie wewnątrz aplikacji](#3-planowanie-wewnątrz-aplikacji)
4. [Pule Fair Schedulera](#4-pule-fair-schedulera)
5. [Konfiguracja właściwości puli przez plik XML](#5-konfiguracja-właściwości-puli-przez-plik-xml)
6. [Planowanie przez połączenia JDBC](#6-planowanie-przez-połączenia-jdbc)
7. [Równoległe joby w PySpark](#7-równoległe-joby-w-pyspark)

---

## 1. Przegląd

Spark udostępnia dwa poziomy planowania zasobów:

1. **Między aplikacjami** – cluster manager przydziela zasoby niezależnym aplikacjom Sparka.
2. **Wewnątrz aplikacji** – scheduler Sparka rozdziela zasoby pomiędzy równoległe "joby" w ramach jednego `SparkContext`.

Każda aplikacja Sparka uruchamia niezależny zestaw JVM-ów executorów. W ramach jednej aplikacji może działać równolegle wiele "jobów" (akcji Sparka), jeśli są zgłaszane z różnych wątków – typowe dla aplikacji obsługujących ruch sieciowy (np. serwisy zapytań).

---

## 2. Planowanie między aplikacjami

### Statyczna alokacja zasobów (Static Resource Allocation)

Każda aplikacja otrzymuje maksymalną ilość zasobów na cały czas swojego działania. Konfiguracja zależy od typu klastra.

**Tryb Standalone**:
- Domyślnie: aplikacje uruchamiane są w kolejności FIFO, każda próbuje wykorzystać wszystkie dostępne węzły.
- Parametry:
  - `spark.cores.max` – limit rdzeni na aplikację
  - `spark.deploy.defaultCores` – domyślna liczba rdzeni dla aplikacji, które nie ustawiają `spark.cores.max`
  - `spark.executor.memory` – pamięć na executor
  - `spark.executor.cores` – rdzenie na executor

**Tryb YARN**:
- `--num-executors` / `spark.executor.instances` – liczba executorów
- `--executor-memory` / `spark.executor.memory` – pamięć na executor
- `--executor-cores` / `spark.executor.cores` – rdzenie na executor

**Tryb Kubernetes (K8s)**:
- Te same parametry co w YARN, plus dodatkowe (o wyższym priorytecie):
  - `spark.kubernetes.executor.limit.cores` – twardy limit rdzeni executora
  - `spark.kubernetes.executor.request.cores` – żądane rdzenie (ma wyższy priorytet niż `spark.executor.cores`)

**Uwaga**: brak współdzielenia pamięci między aplikacjami; żeby dzielić dane, trzeba uruchomić jeden serwer aplikacyjny odpytujący te same RDD.

### Dynamiczna alokacja zasobów (Dynamic Resource Allocation)

Pozwala aplikacji dynamicznie dostosowywać ilość zajmowanych zasobów do obciążenia — zwracać nieużywane zasoby i żądać nowych w miarę potrzeb.

- **Domyślnie wyłączona.**
- Dostępna na "coarse-grained" cluster managerach: Standalone, YARN, Kubernetes.

#### Konfiguracja i uruchomienie

Wymagane: `spark.dynamicAllocation.enabled = true` oraz **jedno** z poniższych rozwiązań dla shuffle:

1. **External Shuffle Service**: `spark.shuffle.service.enabled = true` + skonfigurowana zewnętrzna usługa shuffle na każdym worker node.
2. **Shuffle Tracking**: `spark.dynamicAllocation.shuffleTracking.enabled = true`.
3. **Decommission z blokami shuffle**: `spark.decommission.enabled = true` oraz `spark.storage.decommission.shuffleBlocks.enabled = true`.
4. **Własny ShuffleDataIO**: konfiguracja `spark.shuffle.sort.io.plugin.class` z niestandardową implementacją wspierającą trwałe przechowywanie danych.

- Standalone: uruchom workerów z `spark.shuffle.service.enabled = true`.
- YARN: konfiguracja zewnętrznej usługi shuffle wg dokumentacji YARN.
- Dodatkowa konfiguracja: przestrzenie nazw `spark.dynamicAllocation.*` i `spark.shuffle.service.*`.

**Zastrzeżenia**:
- **Standalone**: bez jawnego ustawienia `spark.executor.cores` każdy executor zajmuje wszystkie rdzenie workera – dynamiczna alokacja może przydzielić więcej executorów niż oczekiwano (patrz SPARK-30299). Zaleca się jawne ustawienie `spark.executor.cores` przed użyciem dynamicznej alokacji.
- **K8s**: nie można użyć `spark.shuffle.service.enabled = true`, bo K8s nie wspiera jeszcze zewnętrznej usługi shuffle.

#### Polityka żądania zasobów (Request Policy)

- Aplikacja żąda nowych executorów, gdy ma zadania oczekujące na zaplanowanie.
- Żądanie jest wyzwalane, gdy zadania czekają w kolejce przez `spark.dynamicAllocation.schedulerBacklogTimeout` sekund.
- Jeśli kolejka nadal istnieje, żądanie jest ponawiane co `spark.dynamicAllocation.sustainedSchedulerBacklogTimeout` sekund.
- **Wykładniczy backoff**: liczba żądanych executorów rośnie w rundach 1, 2, 4, 8... (inspirowane TCP slow-start).
- Uzasadnienie: ostrożne żądania początkowe zapobiegają nadmiernemu przydziałowi, a wykładniczy wzrost umożliwia szybkie zwiększenie liczby executorów, gdy są rzeczywiście potrzebne.

#### Polityka usuwania zasobów (Remove Policy)

- Prosty mechanizm: executor jest usuwany, gdy jest bezczynny dłużej niż `spark.dynamicAllocation.executorIdleTimeout` sekund.
- **Wyjątek**: executory z zcache'owanymi danymi domyślnie nigdy nie są usuwane – zmienia to `spark.dynamicAllocation.cachedExecutorIdleTimeout`.
- `spark.shuffle.service.fetch.rdd.enabled = true` pozwala usuwać executory, które trzymają tylko bloki RDD persystowane na dysku.

#### Łagodne wycofywanie executorów (Graceful Decommission)

- **Problem**: aplikacja nadal działa, gdy executor jest usuwany; dostęp do stanu usuniętego executora wymaga przeliczenia.
- **Krytyczne dla shuffle**: executory zapisują wyniki map lokalnie, a potem serwują je innym podczas fazy fetch. Zbyt wczesne usunięcie powoduje niepotrzebne przeliczenia, zwłaszcza przy "stragglerach" (zadaniach trwających długo).
- **Rozwiązanie – External Shuffle Service** (od Spark 1.2): długo działający proces na każdym węźle klastra, niezależny od aplikacji Sparka; executory pobierają pliki shuffle z tej usługi zamiast od siebie nawzajem, dzięki czemu stan shuffle przetrwa dłużej niż executor.
- Dla danych zcache'owanych: domyślnie executory z cache nie są usuwane (konfigurowalne przez `spark.dynamicAllocation.cachedExecutorIdleTimeout`); przyszłe wersje mogą zachowywać cache poprzez pamięć off-heap, podobnie jak external shuffle service.
- Gdy `spark.shuffle.service.fetch.rdd.enabled = true`, bloki RDD persystowane na dysku mogą być pobierane przez ExternalShuffleService; executory trzymające wyłącznie takie bloki są uznawane za bezczynne po `spark.dynamicAllocation.executorIdleTimeout` i zwalniane.

---

## 3. Planowanie wewnątrz aplikacji

Wiele równoległych jobów może działać jednocześnie, jeśli są zgłaszane z osobnych wątków. "Job" oznacza tu akcję Sparka (`save`, `collect` itd.) wraz z zależnymi od niej zadaniami. Scheduler jest w pełni bezpieczny wątkowo, co umożliwia obsługę wielu żądań naraz (np. usługa zapytań wielu użytkowników).

### FIFO Scheduler (domyślny)

- Joby wykonywane są w kolejności FIFO (pierwszy na wejściu, pierwszy obsłużony).
- Każdy job dzielony jest na "etapy" (stages) – np. fazy map, reduce.
- Pierwszy job dostaje wszystkie dostępne zasoby dla swoich etapów, potem drugi itd.
- **Ograniczenie**: jeśli joby na początku kolejki są duże, kolejne joby mogą być mocno opóźnione.

### Fair Scheduler

- Przydziela zadania między jobami w sposób **round-robin** – wszystkie joby dostają w przybliżeniu równy udział w zasobach klastra.
- **Zalety**: krótkie joby zgłoszone w trakcie długiego joba dostają zasoby od razu, dobry czas odpowiedzi bez czekania na zakończenie długiego joba – idealne dla środowisk wieloużytkownikowych.
- Domyślnie wyłączony; dostępny na "coarse-grained" cluster managerach.

**Włączenie Fair Schedulera**:

```scala
val conf = new SparkConf().setMaster(...).setAppName(...)
conf.set("spark.scheduler.mode", "FAIR")
val sc = new SparkContext(conf)
```

---

## 4. Pule Fair Schedulera

Mechanizm pul pozwala grupować joby o różnych opcjach planowania (np. wadze). Przydatne do:
- tworzenia puli o wysokim priorytecie dla ważnych jobów,
- grupowania po użytkowniku, tak by każdy użytkownik miał równy udział (a nie każdy job z osobna) – wzorowane na Hadoop Fair Scheduler.

### Domyślne zachowanie puli

- Nowo zgłoszone joby trafiają do puli `default`.
- Każda pula (włącznie z `default`) dostaje równy udział w zasobach klastra.
- Wewnątrz puli joby wykonywane są w kolejności FIFO.
- Przykład: przy pulach per-użytkownik każdy użytkownik ma równy udział, a jego zapytania wykonują się kolejno.

### Ustawianie puli dla jobów

Właściwość lokalna `spark.scheduler.pool` na wątku `SparkContext`:

```scala
// Ustawienie puli dla wszystkich jobów w tym wątku
sc.setLocalProperty("spark.scheduler.pool", "pool1")

// Wszystkie kolejne akcje na RDD (save, count, collect itd.) użyją "pool1"

// Wyczyszczenie przypisania puli
sc.setLocalProperty("spark.scheduler.pool", null)
```

Ustawienie per-wątek ułatwia uruchamianie wielu jobów w imieniu tego samego użytkownika.

---

## 5. Konfiguracja właściwości puli przez plik XML

Właściwości puli konfiguruje się plikiem XML. Każda pula ma trzy właściwości:

| Właściwość | Typ | Domyślna wartość | Opis |
|---|---|---|---|
| `schedulingMode` | `FIFO` lub `FAIR` | `FIFO` | Określa, czy joby w puli czekają w kolejce jeden za drugim (FIFO), czy dzielą zasoby puli sprawiedliwie (FAIR) |
| `weight` | liczba | `1` | Względny udział puli w zasobach klastra w porównaniu do innych pul; waga 2 = 2x zasobów; waga 1000 realizuje priorytet (pula zawsze uruchamiana jako pierwsza) |
| `minShare` | liczba rdzeni CPU | `0` | Minimalna gwarantowana liczba rdzeni; scheduler najpierw zaspokaja minimalne udziały wszystkich aktywnych pul, dopiero potem rozdziela nadwyżkę zasobów wg wagi |

### Lokalizacja pliku konfiguracyjnego

Dwie opcje:
1. Plik `fairscheduler.xml` na classpath.
2. Ścieżka wskazana przez `spark.scheduler.allocation.file` w `SparkConf`.

Ścieżka respektuje konfigurację Hadoopa (plik lokalny lub HDFS):

```scala
// Plik lokalny
conf.set("spark.scheduler.allocation.file", "file:///path/to/file")

// Plik na HDFS
conf.set("spark.scheduler.allocation.file", "hdfs:///path/to/file")
```

### Format pliku XML

```xml
<?xml version="1.0"?>
<allocations>
  <pool name="production">
    <schedulingMode>FAIR</schedulingMode>
    <weight>1</weight>
    <minShare>2</minShare>
  </pool>
  <pool name="test">
    <schedulingMode>FIFO</schedulingMode>
    <weight>2</weight>
    <minShare>3</minShare>
  </pool>
</allocations>
```

Dla pul nieskonfigurowanych w pliku obowiązują wartości domyślne: `schedulingMode = FIFO`, `weight = 1`, `minShare = 0`.

Pełny przykładowy plik: `conf/fairscheduler.xml.template` (w dystrybucji Sparka).

---

## 6. Planowanie przez połączenia JDBC

Pulę Fair Schedulera dla sesji klienta JDBC można ustawić zmienną SQL:

```sql
SET spark.sql.thriftserver.scheduler.pool=accounting;
```

---

## 7. Równoległe joby w PySpark

**Ograniczenie**: PySpark nie synchronizuje wątków PVM (Python Virtual Machine) z wątkami JVM. Uruchomienie wielu jobów w osobnych wątkach PVM nie gwarantuje, że każdy job wykona się w odpowiadającym mu wątku JVM.

**Konsekwencja**: nie da się ustawić różnych grup jobów przez `sc.setJobGroup` w osobnym wątku PVM, co uniemożliwia późniejsze anulowanie przez `sc.cancelJobGroup`.

**Rozwiązanie**: użycie `pyspark.InheritableThread`, które dziedziczy dziedziczalne atrybuty (takie jak właściwości lokalne) z wątku JVM do wątku PVM.

---

## Kluczowe zasady

- **Dwa poziomy planowania**: między aplikacjami (cluster manager) i wewnątrz aplikacji (scheduler Sparka).
- **Statyczna alokacja** = stały, maksymalny przydział zasobów na czas życia aplikacji; **dynamiczna alokacja** = przydział dostosowywany na bieżąco do obciążenia (domyślnie wyłączona, wymaga mechanizmu shuffle service/tracking).
- **FIFO** to domyślny scheduler wewnątrz aplikacji – prosty, ale krótkie joby mogą czekać za długimi.
- **Fair Scheduler** dzieli zasoby round-robin między joby/pule – lepszy dla wielu użytkowników i krótkich zapytań w tle długich jobów.
- **Pule** pozwalają nadać priorytety (`weight`) i gwarancje (`minShare`) różnym grupom jobów, konfigurowane deklaratywnie w XML.
- Przy dynamicznej alokacji kluczowe jest zabezpieczenie danych shuffle/cache przed utratą przy usuwaniu executorów – stąd External Shuffle Service i odpowiednie timeouty.
