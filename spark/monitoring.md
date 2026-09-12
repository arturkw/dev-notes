# Apache Spark – Monitoring and Instrumentation (streszczenie)

Źródło: [spark.apache.org/docs/latest/monitoring.html](https://spark.apache.org/docs/latest/monitoring.html) (Spark 4.2.0)

Przewodnik opisujący sposoby monitorowania aplikacji Spark: web UI, REST API, system metryk (Dropwizard Metrics) oraz zewnętrzne narzędzia do instrumentacji.

## Spis treści

1. [Interfejsy webowe](#1-interfejsy-webowe)
2. [History Server (podgląd po zakończeniu aplikacji)](#2-history-server-podgląd-po-zakończeniu-aplikacji)
3. [REST API](#3-rest-api)
4. [Metryki zadań wykonawców (task metrics)](#4-metryki-zadań-wykonawców-task-metrics)
5. [System metryk (Metrics System)](#5-system-metryk-metrics-system)
6. [Dostępne źródła metryk](#6-dostępne-źródła-metryk)
7. [Zaawansowana instrumentacja](#7-zaawansowana-instrumentacja)
8. [Kluczowe zasady](#kluczowe-zasady)

---

## 1. Interfejsy webowe

Każdy `SparkContext` domyślnie uruchamia web UI na **porcie 4040**, dostępne pod `http://<driver-node>:4040`. Jeśli na jednej maszynie działa wiele SparkContextów, kolejne binduje się na kolejnych portach (4041, 4042...). Informacje w UI są domyślnie dostępne **tylko podczas działania aplikacji**.

### Zakładki UI

| Zakładka | Zawartość |
|---|---|
| **Jobs** | Lista etapów (stages) i zadań (tasks) schedulera |
| **Stages** | Szczegóły etapów i informacje o zadaniach |
| **Storage** | Rozmiary RDD i zużycie pamięci |
| **Environment** | Informacje o środowisku aplikacji (konfiguracja, classpath, właściwości systemowe) |
| **Executors** | Informacje o działających executorach |
| **SQL** | (dla aplikacji SQL) szczegóły wykonania zapytań SQL |

Wszystkie tabele można sortować klikając nagłówki kolumn – ułatwia to znajdowanie wolnych zadań i przekosów danych (data skew).

---

## 2. History Server (podgląd po zakończeniu aplikacji)

Aby móc oglądać UI aplikacji **po jej zakończeniu**, trzeba włączyć logowanie zdarzeń (event log) przed uruchomieniem aplikacji:

```
spark.eventLog.enabled=true
spark.eventLog.dir=hdfs://namenode/shared/spark-logs
```

Następnie uruchamia się History Server:

```bash
./sbin/start-history-server.sh
```

Domyślnie dostępny pod `http://<server-url>:18080`, wyświetla listę aplikacji ukończonych i niedokończonych (wraz z ich próbami/attempts).

### Zmienne środowiskowe

| Zmienna | Znaczenie | Domyślnie |
|---|---|---|
| `SPARK_DAEMON_MEMORY` | Pamięć przydzielona history server | 1g |
| `SPARK_DAEMON_JAVA_OPTS` | Opcje JVM | brak |
| `SPARK_DAEMON_CLASSPATH` | Classpath | brak |
| `SPARK_PUBLIC_DNS` | Publiczny adres history server | brak |
| `SPARK_HISTORY_OPTS` | Opcje `spark.history.*` | brak |

### Najważniejsze opcje konfiguracyjne

| Właściwość | Domyślnie | Znaczenie |
|---|---|---|
| `spark.history.provider` | `FsHistoryProvider` | Klasa backendu historii aplikacji |
| `spark.history.fs.logDirectory` | `file:/tmp/spark-events` | Katalog z logami zdarzeń (obsługuje `file://`, `hdfs://`, wiele ścieżek po przecinku) |
| `spark.history.fs.update.interval` | 10s | Częstotliwość sprawdzania nowych/zaktualizowanych logów |
| `spark.history.retainedApplications` | 50 | Liczba aplikacji trzymanych w cache |
| `spark.history.ui.maxApplications` | Int.MaxValue | Liczba aplikacji wyświetlanych na stronie podsumowania |
| `spark.history.ui.port` | 18080 | Port, na którym nasłuchuje UI |
| `spark.history.kerberos.enabled` | false | Włącza logowanie Kerberos |
| `spark.history.fs.cleaner.enabled` | false | Włącza okresowe czyszczenie starych logów |
| `spark.history.fs.cleaner.interval` | 1d | Jak często sprawdzać do czyszczenia |
| `spark.history.fs.cleaner.maxAge` | 7d | Usuwaj pliki starsze niż ten czas |
| `spark.history.fs.cleaner.maxNum` | Int.MaxValue | Maksymalna liczba plików w katalogu logów |
| `spark.history.fs.numReplayThreads` | 25% rdzeni | Liczba wątków przetwarzających logi zdarzeń |
| `spark.history.store.maxDiskUsage` | 10g | Maksymalne zużycie dysku na cache historii |
| `spark.history.store.path` | brak | Lokalny katalog cache (włącza trwałość na dysku) |
| `spark.history.store.hybridStore.enabled` | false | Użycie HybridStore do parsowania (RocksDB/LevelDB) |

### Rolowanie i kompaktowanie logów zdarzeń

Dla długo działających aplikacji (np. streamingowych) warto włączyć rolowanie plików logów:

```
spark.eventLog.rolling.enabled=true
spark.eventLog.rolling.maxFileSize=<rozmiar>
spark.history.fs.eventLog.rolling.maxFilesToRetain=2
```

**Uwaga**: kompaktowanie jest operacją **stratną** – usuwa m.in. zdarzenia zakończonych jobów/etapów/zadań, zakończonych executorów oraz zakończonych zapytań SQL, które wskazują na już nieaktualne dane.

---

## 3. REST API

Poza web UI Spark udostępnia REST API do pobierania statusu aplikacji w formacie JSON.

- **History Server**: `http://<server-url>:18080/api/v1`
- **Działająca aplikacja**: `http://localhost:4040/api/v1`

### Najważniejsze endpointy

| Endpoint | Znaczenie |
|---|---|
| `/applications` | Wszystkie aplikacje (filtry: `status`, `minDate`, `maxDate`, `limit`) |
| `/applications/[app-id]/jobs` | Wszystkie joby (filtr `status`) |
| `/applications/[app-id]/jobs/[job-id]` | Szczegóły joba |
| `/applications/[app-id]/stages` | Wszystkie etapy (filtry `status`, `details`, `taskStatus`, `withSummaries`, `quantiles`) |
| `/applications/[app-id]/stages/[stage-id]/[attempt-id]/taskList` | Lista zadań (paginacja, sortowanie, filtr statusu) |
| `/applications/[app-id]/executors` | Aktywni executorzy |
| `/applications/[app-id]/allexecutors` | Wszyscy executorzy (aktywni i martwi) |
| `/applications/[app-id]/storage/rdd` | Zapisane (persisted) RDD |
| `/applications/[base-app-id]/logs` | Logi zdarzeń dla wszystkich prób (zip) |
| `/applications/[app-id]/streaming/statistics` | Statystyki streamingu |
| `/applications/[app-id]/streaming/batches` | Zachowane batch'e streamingu |
| `/applications/[app-id]/sql` | Wszystkie zapytania SQL |
| `/applications/[app-id]/sql/[execution-id]` | Szczegóły zapytania SQL |
| `/applications/[app-id]/environment` | Szczegóły środowiska |
| `/version` | Wersja Sparka |

### Polityka wersjonowania API

- Endpointy nigdy nie są usuwane, pola nigdy nie są usuwane.
- Mogą pojawiać się nowe endpointy i nowe pola w istniejących endpointach.
- Nowe wersje API (np. `api/v2`) mogą współistnieć, ale nie muszą być wstecznie kompatybilne; stare wersje mogą zostać wycofane po co najmniej jednym minor release współistnienia.

---

## 4. Metryki zadań wykonawców (task metrics)

Dostępne przez REST API, opisują wykonanie pojedynczego zadania:

| Metryka | Opis |
|---|---|
| `executorRunTime` | Czas wykonywania zadania przez executor (ms) |
| `executorCpuTime` | Czas CPU zużyty na zadanie (ns) |
| `executorDeserializeTime` | Czas deserializacji zadania (ms) |
| `jvmGCTime` | Czas garbage collection JVM (ms) |
| `resultSize` | Bajty zwrócone do drivera |
| `memoryBytesSpilled` / `diskBytesSpilled` | Bajty rozlane (spill) do pamięci/na dysk |
| `peakExecutionMemory` | Szczytowe zużycie pamięci na shuffle/agregacje/joiny |
| `inputMetrics.bytesRead` / `recordsRead` | Odczytane dane wejściowe |
| `outputMetrics.bytesWritten` / `recordsWritten` | Zapisane dane wyjściowe |
| `shuffleReadMetrics.*` | Bloki/bajty lokalne i zdalne odczytane w shuffle, czas oczekiwania (`fetchWaitTime`) |
| `shuffleWriteMetrics.*` | Bajty/rekordy zapisane w shuffle, czas zapisu |

Executorzy udostępniają też własne metryki (`rddBlocks`, `memoryUsed`, `activeTasks`, `totalGCTime`, `maxMemory` itd.) przez `/applications/[app-id]/executors` oraz w formacie Prometheus przez `/metrics/executors/prometheus`, w tym szczegółowe metryki pamięci on/off-heap (`memoryMetrics.*`) i metryki szczytowe (`peakMemoryMetrics.*`, np. `JVMHeapMemory`, `OnHeapExecutionMemory`, GC counts).

---

## 5. System metryk (Metrics System)

Spark wykorzystuje **bibliotekę Dropwizard Metrics** do konfigurowalnego systemu metryk.

### Konfiguracja

1. Plik konfiguracyjny: `$SPARK_HOME/conf/metrics.properties` (szablon: `metrics.properties.template`)
2. Niestandardowa lokalizacja: właściwość `spark.metrics.conf`
3. Parametry konfiguracyjne z prefiksem `spark.metrics.conf.*`

### Przestrzeń nazw (namespace)

Domyślnie root namespace to `spark.app.id` (zmienia się przy każdym uruchomieniu). Aby śledzić metryki między uruchomieniami tej samej aplikacji:

```
spark.metrics.namespace=${spark.app.name}
```

Metryki drivera i executorów są prefiksowane tym namespace; pozostałe komponenty – nie.

### Komponenty (instancje) raportujące metryki

| Instancja | Opis |
|---|---|
| `master` | Proces mastera Spark Standalone |
| `applications` | Raportowanie o aplikacjach (tylko master) |
| `worker` | Proces workera Spark Standalone |
| `executor` | Executor Sparka |
| `driver` | Proces drivera Sparka |
| `shuffleService` | Usługa shuffle |
| `applicationMaster` | ApplicationMaster (tylko YARN) |

### Sinki (miejsca docelowe metryk)

| Sink | Przeznaczenie |
|---|---|
| `ConsoleSink` | Loguje metryki do konsoli |
| `CSVSink` | Eksportuje do plików CSV w interwałach |
| `JmxSink` | Rejestruje do podglądu w konsoli JMX |
| `MetricsServlet` | Serwuje JSON w Spark UI pod `/metrics/json` |
| `PrometheusServlet` | Metryki w formacie Prometheus (eksperymentalne) |
| `GraphiteSink` | Wysyła do węzła Graphite |
| `Slf4jSink` | Wysyła przez slf4j do logów |
| `StatsdSink` | Wysyła do węzła StatsD |
| `GangliaSink` | Wysyła do Ganglii (wymaga osobnej kompilacji, licencja LGPL) |

**Przykład konfiguracji Graphite:**

```
spark.metrics.conf.*.sink.graphite.class=org.apache.spark.metrics.sink.GraphiteSink
spark.metrics.conf.*.sink.graphite.host=<hostname>
spark.metrics.conf.*.sink.graphite.port=<port>
spark.metrics.conf.*.sink.graphite.period=10
spark.metrics.conf.*.sink.graphite.unit=seconds
spark.metrics.conf.*.sink.graphite.prefix=optional_prefix
```

### Endpointy Prometheus per komponent

| Komponent | Port | Endpoint JSON | Endpoint Prometheus |
|---|---|---|---|
| Master | 8080 | `/metrics/master/json/` | `/metrics/master/prometheus/` |
| Worker | 8081 | `/metrics/json/` | `/metrics/prometheus/` |
| Driver | 4040 | `/metrics/json/` | `/metrics/prometheus/` |
| Driver (executorzy) | 4040 | `/api/v1/applications/{id}/executors/` | `/metrics/executors/prometheus/` |

### Instalacja Ganglii

Ganglia jest licencjonowana LGPL i wymaga własnej kompilacji Sparka:

```bash
# SBT
export SPARK_GANGLIA_LGPL=1
# Maven
mvn build -Pspark-ganglia-lgpl
```

---

## 6. Dostępne źródła metryk

Metryki mają typy: **gauge**, **counter** (sufiks `.count`), **histogram**, **meter**, **timer**.

### Driver

- **BlockManager**: `memory.maxMem_MB`, `memory.memUsed_MB`, `memory.remainingMem_MB`, `disk.diskSpaceUsed_MB` itd.
- **DAGScheduler**: `job.activeJobs`, `job.allJobs`, `stage.failedStages`, `stage.runningStages`, `stage.waitingStages`
- **HiveExternalCatalog**: `fileCacheHits.count`, `filesDiscovered.count`, `hiveClientCalls.count` (wymaga `spark.metrics.staticSources.enabled=true`, domyślnie włączone)
- **CodeGenerator**: histogramy `compilationTime`, `generatedClassSize`, `sourceCodeSize`
- **LiveListenerBus**: czasy przetwarzania zdarzeń per listener, rozmiary kolejek, liczba porzuconych zdarzeń
- **appStatus** (od Sparka 3.0): `stages.failedStages.count`, `tasks.completedTasks.count`, `tasks.excludedExecutors.count`, `jobs.succeededJobs`, `jobs.failedJobs`, `jobDuration`
- **AccumulatorSource**: `DoubleAccumulatorSource`, `LongAccumulatorSource` – akumulatory zdefiniowane przez użytkownika
- **spark.streaming** (Structured Streaming, wymaga `spark.sql.streaming.metricsEnabled=true`, domyślnie false): `eventTime-watermark`, `inputRate-total`, `processingRate-total`, `latency`, `states-rowsTotal`, `states-usedBytes`
- **ExecutorAllocationManager** (przy `spark.dynamicAllocation.enabled=true`): liczba executorów do dodania/usunięcia, decommissioning itp.
- **plugin.\<Nazwa klasy pluginu\>**: metryki dostarczane przez plugin API

### Executor

- **executor**: `bytesRead.count`, `bytesWritten.count`, `cpuTime.count`, `jvmGCTime.count`, `shuffleRemoteBytesRead.count`, `shuffleBytesWritten.count`, metryki push-based shuffle (`shuffleMergedRemoteBlocksFetched` itd.), metryki puli wątków (`threadpool.activeTasks`, `threadpool.completeTasks`)
- **ExecutorMetrics** (wymaga `spark.metrics.executorMetricsSource.enabled=true`, domyślnie włączone): metryki pamięci JVM on/off-heap, liczniki GC (`MinorGCCount`, `MajorGCCount`), oraz metryki ProcessTree (`ProcessTreeJVMRSSMemory` itd. – wymaga `/proc` i `spark.executor.processTreeMetrics.enabled=true`). Aktualizowane co `spark.executor.heartbeatInterval` (domyślnie 10s), opcjonalnie szybciej przez `spark.executor.metrics.pollingInterval`
- **NettyBlockTransfer**: użycie pamięci direct/heap przez klienta/serwer shuffle

### Pozostałe komponenty

- **JVM Source** (wymaga `spark.metrics.staticSources.enabled=true`): metryki puli buforów, GC, użycia pamięci (dostępne dla drivera, executora i innych instancji)
- **ApplicationMaster** (tylko YARN): `numExecutorsRunning`, `numExecutorsFailed`, `numContainersPendingAllocate`
- **Master / Worker (Standalone)**: `workers`, `aliveWorkers`, `apps`, `coresUsed`, `memUsed_MB`
- **ShuffleService**: `blockTransferRate`, `openBlockRequestLatencyMillis`, metryki push-based shuffle (`blockBytesWritten`, `staleBlockPushes` itd.)

---

## 7. Zaawansowana instrumentacja

### Narzędzia zewnętrzne

- **Ganglia** – monitorowanie wykorzystania całego klastra, pomaga zidentyfikować, czy problemem jest dysk, sieć, czy CPU
- **dstat**, **iostat**, **iotop** – szczegółowe profilowanie na poziomie systemu operacyjnego/węzła (I/O dysku, procesy)
- **jstack**, **jmap**, **jstat**, **jconsole** – narzędzia JVM do stack trace'ów, dumpów sterty, statystyk czasowych JVM i wizualnego przeglądania właściwości JVM

### Spark Plugin API

Pozwala na własną instrumentację przez implementację interfejsu `org.apache.spark.api.plugin.SparkPlugin`. Konfiguracja przez dwie właściwości (listy klas po przecinku):

```
spark.plugins=<klasy-pluginów>
spark.plugins.defaultList=<domyślne-klasy-pluginów>
```

Pluginy mogą rejestrować własne metryki, widoczne w systemie metryk pod namespace `plugin.<Nazwa klasy pluginu>`.

---

## Kluczowe zasady

- **Web UI (port 4040)** działa tylko podczas życia aplikacji – do analizy po fakcie potrzebny jest **History Server** oparty na logach zdarzeń (`spark.eventLog.enabled=true`).
- **REST API** daje dostęp programistyczny do tych samych danych co UI, w stabilnym, wersjonowanym formacie JSON (endpointy i pola nigdy nie znikają).
- **System metryk oparty na Dropwizard** jest w pełni konfigurowalny – ten sam zestaw metryk można kierować równolegle do wielu sinków (konsola, JMX, Graphite, Prometheus, StatsD, Ganglia).
- Wiele przydatnych źródeł metryk (appStatus, executor memory metrics, Structured Streaming metrics) jest **opcjonalnych i sterowanych flagami** (`spark.metrics.appStatusSource.enabled`, `spark.metrics.executorMetricsSource.enabled`, `spark.sql.streaming.metricsEnabled`) – część domyślnie włączona, część nie.
- Do pełnego obrazu kondycji klastra warto łączyć metryki Sparka z narzędziami systemowymi (Ganglia, dstat, jstack/jmap) – Spark pokazuje, *co* robi aplikacja, a narzędzia OS/JVM pokazują *dlaczego* to wolno działa (I/O, GC, CPU).
- **Spark Plugin API** pozwala rozszerzyć system metryk o własne, specyficzne dla aplikacji wskaźniki bez modyfikacji kodu Sparka.
