# Apache Spark – Streaming Programming Guide (streszczenie)

Źródło: [spark.apache.org/docs/latest/streaming-programming-guide.html](https://spark.apache.org/docs/latest/streaming-programming-guide.html) (Spark 4.2.0)

> **Uwaga z dokumentacji**: Spark Streaming (DStreams) to *poprzednia generacja* silnika strumieniowego Sparka i jest projektem **legacy** – nie jest już rozwijany. Do nowych aplikacji zaleca się **Structured Streaming**. Ten dokument opisuje "stary" model DStream, wciąż spotykany w istniejących systemach.

## Spis treści

1. Wprowadzenie i architektura
2. Inicjalizacja StreamingContext
3. Pojęcie DStream
4. Przykład: Network Word Count
5. Źródła danych wejściowych
6. Transformacje na DStream
7. Operacje okienkowe (window operations)
8. Operacje join
9. Operacje wyjściowe (output operations) i wzorce `foreachRDD`
10. DataFrame i SQL na danych strumieniowych
11. Cache'owanie/persystencja
12. Checkpointing
13. Akumulatory i zmienne broadcast w streamingu
14. [Strojenie wydajności (Performance Tuning)](#14-strojenie-wydajności-performance-tuning)
15. [Semantyka odporności na awarie (Fault-Tolerance Semantics)](#15-semantyka-odporności-na-awarie-fault-tolerance-semantics)
16. [Monitorowanie aplikacji](#16-monitorowanie-aplikacji)
17. Wdrażanie aplikacji strumieniowych
18. Structured Streaming vs Spark Streaming

---

## 1. Wprowadzenie i architektura

Spark Streaming to rozszerzenie podstawowego API Sparka umożliwiające skalowalne, o wysokiej przepustowości, odporne na awarie przetwarzanie strumieni danych na żywo (Kafka, Kinesis, gniazda TCP i inne). Wyniki mogą trafiać do systemów plików, baz danych czy dashboardów.

Wewnętrznie Spark Streaming dzieli strumień danych wejściowych na **paczki (batches)**, które silnik Sparka przetwarza tak jak zwykłe RDD, generując strumień wyników. Reprezentacją strumienia jest **DStream** (*discretized stream*) – ciągła seria RDD.

## 2. Inicjalizacja StreamingContext

`StreamingContext` to główny punkt wejścia do API Spark Streaming.

```python
from pyspark import SparkContext
from pyspark.streaming import StreamingContext

sc = SparkContext(master, appName)
ssc = StreamingContext(sc, 1)  # interwał paczki: 1 sekunda
```

```scala
val conf = new SparkConf().setMaster("local[2]").setAppName("NetworkWordCount")
val ssc = new StreamingContext(conf, Seconds(1))
```

```java
SparkConf conf = new SparkConf().setMaster("local[2]").setAppName("NetworkWordCount");
JavaStreamingContext jssc = new JavaStreamingContext(conf, Durations.seconds(1));
```

**Ważne zasady**:
- W trybie lokalnym używać `"local[n]"`, gdzie `n` > liczba odbiorników (receiverów) – inaczej dojdzie do zagłodzenia wątków.
- Po uruchomieniu (`start()`) nie można dodawać nowych obliczeń strumieniowych.
- Zatrzymanego kontekstu (`stop()`) nie da się ponownie uruchomić.
- W jednej JVM może być aktywny tylko **jeden** `StreamingContext`.
- `stop()` domyślnie zatrzymuje też `SparkContext` (chyba że ustawi się `stopSparkContext=false`).

## 3. Pojęcie DStream

**DStream** to podstawowa abstrakcja reprezentująca ciągły strumień danych – wejściowy albo wynik przetworzenia. Wewnętrznie to ciągła seria RDD, gdzie każde RDD zawiera dane z określonego przedziału czasu. Operacje na DStream przekładają się na operacje na leżących u podstaw RDD.

## 4. Przykład: Network Word Count

Zliczanie słów napływających przez gniazdo TCP.

```python
sc = SparkContext("local[2]", "NetworkWordCount")
ssc = StreamingContext(sc, 1)

lines = ssc.socketTextStream("localhost", 9999)
words = lines.flatMap(lambda line: line.split(" "))
pairs = words.map(lambda word: (word, 1))
wordCounts = pairs.reduceByKey(lambda x, y: x + y)

wordCounts.pprint()

ssc.start()
ssc.awaitTermination()
```

```scala
val conf = new SparkConf().setMaster("local[2]").setAppName("NetworkWordCount")
val ssc = new StreamingContext(conf, Seconds(1))

val lines = ssc.socketTextStream("localhost", 9999)
val words = lines.flatMap(_.split(" "))
val pairs = words.map(word => (word, 1))
val wordCounts = pairs.reduceByKey(_ + _)

wordCounts.print()

ssc.start()
ssc.awaitTermination()
```

```java
JavaStreamingContext jssc = new JavaStreamingContext(conf, Durations.seconds(1));
JavaReceiverInputDStream<String> lines = jssc.socketTextStream("localhost", 9999);
JavaDStream<String> words = lines.flatMap(x -> Arrays.asList(x.split(" ")).iterator());
JavaPairDStream<String, Integer> pairs = words.mapToPair(s -> new Tuple2<>(s, 1));
JavaPairDStream<String, Integer> wordCounts = pairs.reduceByKey((i1, i2) -> i1 + i2);

wordCounts.print();
jssc.start();
jssc.awaitTermination();
```

Uruchomienie:
```bash
# Terminal 1
$ nc -lk 9999
# Terminal 2
$ ./bin/spark-submit examples/src/main/python/streaming/network_wordcount.py localhost 9999
```

## 5. Źródła danych wejściowych

### Źródła podstawowe (Basic Sources)

**Strumienie plikowe** – nie wymagają odbiornika (receivera), więc nie zużywają dodatkowych rdzeni:

```python
streamingContext.textFileStream(dataDirectory)
```

Zasady monitorowania katalogu:
- monitorowany może być prosty katalog (`hdfs://namenode:8040/logs/`) lub wzorzec glob POSIX (`.../logs/2017/*`),
- wszystkie pliki muszą mieć ten sam format,
- o zaliczeniu pliku decyduje czas modyfikacji, nie utworzenia,
- zmiany w plikach w obrębie bieżącego okna są ignorowane.

**Kolejka RDD jako strumień** – przydatne do testów:
```python
streamingContext.queueStream(queueOfRDDs)
```
Każde RDD włożone do kolejki jest traktowane jako jedna paczka danych w DStream.

### Źródła zaawansowane (Advanced Sources)

Wymagają dodatkowych zależności:

| Źródło | Artefakt |
|---|---|
| Kafka | `spark-streaming-kafka-0-10_2.13` |
| Kinesis | `spark-streaming-kinesis-asl_2.13` |

Od Spark 4.2.0 Kafka i Kinesis są dostępne również w Python API.

### Niezawodność odbiorników (Receiver Reliability)

- **Reliable Receiver** – poprawnie potwierdza odbiór danych do źródła (np. Kafka), gdy dane zostały zapisane z replikacją.
- **Unreliable Receiver** – nie wysyła potwierdzenia; stosowany dla źródeł, które go nie wspierają.

## 6. Transformacje na DStream

| Transformacja | Znaczenie |
|---|---|
| `map(func)` | przekształca każdy element |
| `flatMap(func)` | jak `map`, ale każdy element może dać 0 lub więcej wyników |
| `filter(func)` | zostawia elementy spełniające warunek |
| `repartition(n)` | zmienia poziom równoległości |
| `union(otherStream)` | łączy z innym strumieniem |
| `count()` | liczy elementy w każdym RDD |
| `reduce(func)` | agreguje elementy funkcją łączną |
| `countByValue()` | liczy częstość wystąpień wartości |
| `reduceByKey(func)` | agreguje wartości po kluczu |
| `join(otherStream)` | łączy dwa strumienie (K,V) |
| `cogroup(otherStream)` | grupuje dwa strumienie (K,V) po kluczu |
| `transform(func)` | dowolna funkcja RDD→RDD zastosowana do każdego RDD |
| `updateStateByKey(func)` | utrzymuje dowolny stan, aktualizowany nowymi wartościami |

### updateStateByKey

Utrzymuje dowolny stan aktualizowany w czasie – **wymaga skonfigurowanego checkpointingu**.

```python
def updateFunction(newValues, runningCount):
    if runningCount is None:
        runningCount = 0
    return sum(newValues, runningCount)

runningCounts = pairs.updateStateByKey(updateFunction)
```

```scala
def updateFunction(newValues: Seq[Int], runningCount: Option[Int]): Option[Int] = {
  val newCount = ... // dodaj nowe wartości do poprzedniego stanu
  Some(newCount)
}
val runningCounts = pairs.updateStateByKey[Int](updateFunction _)
```

### transform

Pozwala zastosować dowolną funkcję RDD-na-RDD do każdego RDD w DStream (np. połączenie z RDD spoza strumienia):

```python
spamInfoRDD = sc.pickleFile(...)
cleanedDStream = wordCounts.transform(lambda rdd: rdd.join(spamInfoRDD).filter(...))
```

## 7. Operacje okienkowe (window operations)

Pozwalają stosować transformacje na "przesuwnym oknie" danych. Wymagają dwóch parametrów, oba muszą być wielokrotnością interwału paczki:
- **window length** – długość okna,
- **sliding interval** – co ile czasu okno jest przeliczane.

Przykład – zliczanie słów z ostatnich 30 sekund, co 10 sekund, z użyciem wersji z funkcją odwrotną (inkrementalną):

```python
windowedWordCounts = pairs.reduceByKeyAndWindow(
    lambda x, y: x + y,
    lambda x, y: x - y,
    30, 10
)
```

```scala
val windowedWordCounts = pairs.reduceByKeyAndWindow(
    (a: Int, b: Int) => a + b, Seconds(30), Seconds(10))
```

| Operacja | Znaczenie |
|---|---|
| `window(windowLength, slideInterval)` | zwraca nowy DStream oparty na oknie paczek |
| `countByWindow(windowLength, slideInterval)` | liczba elementów w przesuwnym oknie |
| `reduceByWindow(func, windowLength, slideInterval)` | agregacja funkcją w oknie |
| `reduceByKeyAndWindow(func, windowLength, slideInterval)` | agregacja po kluczu w oknie |
| `reduceByKeyAndWindow(func, invFunc, windowLength, slideInterval)` | wersja inkrementalna z funkcją odwrotną (wydajniejsza) |
| `countByValueAndWindow(windowLength, slideInterval)` | częstość wartości w oknie |

## 8. Operacje join

**Stream-stream join** – łączy RDD z tego samego interwału paczki z dwóch strumieni:
```python
joinedStream = stream1.join(stream2)
```
Dostępne też `leftOuterJoin`, `rightOuterJoin`, `fullOuterJoin`.

**Windowed stream join**:
```python
windowedStream1 = stream1.window(20)
windowedStream2 = stream2.window(60)
joinedStream = windowedStream1.join(windowedStream2)
```

**Stream-dataset join** (łączenie strumienia ze statycznym RDD):
```python
dataset = ...  # jakieś RDD
windowedStream = stream.window(20)
joinedStream = windowedStream.transform(lambda rdd: rdd.join(dataset))
```

## 9. Operacje wyjściowe (output operations)

Operacje wyjściowe wypychają dane DStream do systemów zewnętrznych i **uruchamiają faktyczne wykonanie obliczeń** (podobnie jak akcje na RDD) – bez nich nic się nie liczy.

| Operacja | Znaczenie |
|---|---|
| `print()` / `pprint()` (Python) | wypisuje pierwsze 10 elementów na konsolę |
| `saveAsTextFiles(prefix, [suffix])` | zapis jako pliki tekstowe z nazwą zawierającą znacznik czasu |
| `saveAsObjectFiles(prefix, [suffix])` | zapis jako SequenceFile zserializowanych obiektów (brak w Pythonie) |
| `saveAsHadoopFiles(prefix, [suffix])` | zapis jako pliki Hadoop (brak w Pythonie) |
| `foreachRDD(func)` | najbardziej ogólny operator – dowolna funkcja na każdym RDD |

Domyślnie operacje wyjściowe wykonują się **jedna po drugiej, w kolejności zdefiniowania**.

### Wzorce i pułapki `foreachRDD`

**Błąd 1 – tworzenie połączenia na driverze** i próba użycia go w `rdd.foreach`:
```python
def sendRecord(rdd):
    connection = createNewConnection()  # wykonywane na driverze
    rdd.foreach(lambda record: connection.send(record))  # błąd serializacji
    connection.close()

dstream.foreachRDD(sendRecord)
```
Problem: obiekt połączenia musiałby zostać zserializowany i wysłany do workerów, co zwykle się nie udaje.

**Błąd 2 – tworzenie połączenia dla każdego rekordu** (bardzo nieefektywne):
```python
def sendRecord(record):
    connection = createNewConnection()
    connection.send(record)
    connection.close()

dstream.foreachRDD(lambda rdd: rdd.foreach(sendRecord))
```

**Lepiej – jedno połączenie na partycję**:
```python
def sendPartition(iter):
    connection = createNewConnection()
    for record in iter:
        connection.send(record)
    connection.close()

dstream.foreachRDD(lambda rdd: rdd.foreachPartition(sendPartition))
```

**Najlepiej – pula połączeń (connection pool)**, statyczna, leniwie inicjalizowana:
```python
def sendPartition(iter):
    connection = ConnectionPool.getConnection()
    for record in iter:
        connection.send(record)
    ConnectionPool.returnConnection(connection)

dstream.foreachRDD(lambda rdd: rdd.foreachPartition(sendPartition))
```

## 10. DataFrame i SQL na danych strumieniowych

Można używać DataFrame/SQL na danych z DStream przez leniwie tworzony singleton `SparkSession`:

```python
def getSparkSessionInstance(sparkConf):
    if "sparkSessionSingletonInstance" not in globals():
        globals()["sparkSessionSingletonInstance"] = SparkSession \
            .builder.config(conf=sparkConf).getOrCreate()
    return globals()["sparkSessionSingletonInstance"]

def process(time, rdd):
    spark = getSparkSessionInstance(rdd.context.getConf())
    rowRdd = rdd.map(lambda w: Row(word=w))
    wordsDataFrame = spark.createDataFrame(rowRdd)
    wordsDataFrame.createOrReplaceTempView("words")
    spark.sql("select word, count(*) as total from words group by word").show()

words.foreachRDD(process)
```

Do asynchronicznych zapytań SQL (mogących trwać dłużej niż domyślna retencja danych) trzeba wywołać `streamingContext.remember(Minutes(5))`.

## 11. Cache'owanie/persystencja

Podobnie jak RDD, DStream można persystować w pamięci: `dstream.persist()`. Przydatne, gdy dane będą liczone wielokrotnie (operacje okienkowe i stanowe robią to niejawnie).

Domyślne poziomy persystencji (inne niż w RDD Core!):
- strumienie wejściowe sieciowe (Kafka, sockets) – replikowane do 2 węzłów,
- w przeciwieństwie do domyślnego `MEMORY_ONLY` dla zwykłych RDD, DStream domyślnie trzyma dane **zserializowane** w pamięci, by zmniejszyć narzut garbage collection.

## 12. Checkpointing

Aplikacje strumieniowe muszą działać 24/7 i odzyskiwać się po awariach niezwiązanych z logiką aplikacji. Checkpointing zapisuje niezbędne informacje do odpornego na awarie magazynu.

### Dwa rodzaje checkpointów

1. **Metadata checkpointing** – zapisuje informacje definiujące obliczenia strumieniowe (konfigurację, operacje DStream, niedokończone paczki) – potrzebne do odzyskania **drivera**.
2. **Data checkpointing** – zapisuje wygenerowane RDD do niezawodnego magazynu – niezbędne dla transformacji stanowych łączących dane z wielu paczek, ucina łańcuch zależności (lineage), by czas odzyskiwania nie rósł w nieskończoność.

### Kiedy włączyć checkpointing

Wymagany dla:
- transformacji stanowych (`updateStateByKey`, `reduceByKeyAndWindow` z funkcją odwrotną),
- odzyskiwania po awariach drivera.

Niewymagany dla prostego streamingu bez transformacji stanowych.

### Konfiguracja

```python
def functionToCreateContext():
    sc = SparkContext(...)
    ssc = StreamingContext(...)
    lines = ssc.socketTextStream(...)
    ssc.checkpoint(checkpointDirectory)
    return ssc

context = StreamingContext.getOrCreate(checkpointDirectory, functionToCreateContext)
context.start()
context.awaitTermination()
```

**Interwał checkpointu RDD**: domyślnie wielokrotność interwału paczki, minimum 10 sekund; ustawiany przez `dstream.checkpoint(checkpointInterval)`. Zalecenie: 5–10 interwałów przesunięcia (sliding interval) danego DStream jako punkt wyjścia. Zbyt częsty checkpoint zwiększa opóźnienie (koszt zapisu do trwałego magazynu), zbyt rzadki – powoduje narastanie lineage i rozmiaru zadań.

## 13. Akumulatory i zmienne broadcast w streamingu

**Akumulatory i zmienne broadcast nie są odtwarzane z checkpointu.** Jeśli używa się checkpointingu razem z nimi, trzeba tworzyć je jako leniwie inicjalizowane singletony:

```python
def getWordExcludeList(sparkContext):
    if "wordExcludeList" not in globals():
        globals()["wordExcludeList"] = sparkContext.broadcast(["a", "b", "c"])
    return globals()["wordExcludeList"]

def getDroppedWordsCounter(sparkContext):
    if "droppedWordsCounter" not in globals():
        globals()["droppedWordsCounter"] = sparkContext.accumulator(0)
    return globals()["droppedWordsCounter"]

def echo(time, rdd):
    excludeList = getWordExcludeList(rdd.context)
    droppedWordsCounter = getDroppedWordsCounter(rdd.context)

    def filterFunc(wordCount):
        if wordCount[0] in excludeList.value:
            droppedWordsCounter.add(wordCount[1])
            return False
        return True

    counts = rdd.filter(filterFunc).collect()

wordCounts.foreachRDD(echo)
```

```scala
object WordExcludeList {
  @volatile private var instance: Broadcast[Seq[String]] = null
  def getInstance(sc: SparkContext): Broadcast[Seq[String]] = {
    if (instance == null) {
      synchronized {
        if (instance == null) instance = sc.broadcast(Seq("a", "b", "c"))
      }
    }
    instance
  }
}
```

Wzorzec double-checked locking (Scala/Java) lub sprawdzanie obecności w globalnym słowniku (Python) zapewnia, że po odtworzeniu drivera z checkpointu obiekty broadcast/akumulator zostaną utworzone na nowo, zamiast próby (nieudanej) deserializacji starych.

---

## 14. Strojenie wydajności (Performance Tuning)

### Redukcja czasu przetwarzania paczki

**Poziom równoległości przy odbiorze danych**

Odbiór danych sieciowych może stać się wąskim gardłem. Rozwiązanie: wiele wejściowych DStreamów (każdy tworzy jeden receiver na jednej maszynie) połączonych przez `union`:

```python
numStreams = 5
kafkaStreams = [KafkaUtils.createStream(...) for _ in range(numStreams)]
unifiedStream = streamingContext.union(*kafkaStreams)
unifiedStream.pprint()
```

Konfiguracja `spark.streaming.blockInterval`: odebrane dane są scalane w bloki przed zapisem do pamięci Sparka. Liczba zadań na receiver na paczkę ≈ *(interwał paczki / block interval)*. Przykład: block interval 200 ms daje 10 zadań na paczkę 2-sekundową. **Zalecane minimum block interval: ok. 50 ms** – poniżej tej wartości narzut uruchamiania zadań staje się problemem. Alternatywa: jawne `inputStream.repartition(<liczba partycji>)`.

**Poziom równoległości przy przetwarzaniu danych**

Dla rozproszonych operacji redukujących (`reduceByKey`, `reduceByKeyAndWindow`) domyślną liczbę zadań kontroluje `spark.default.parallelism` – można ją zmienić globalnie lub przekazać jako argument do konkretnej operacji.

**Serializacja danych**

Dwa rodzaje serializacji:
- **Dane wejściowe**: domyślnie przechowywane z `StorageLevel.MEMORY_AND_DISK_SER_2` (serializowane, replikowane) – receiver musi deserializować odebrane dane i ponownie zserializować je formatem Sparka, co niesie narzut.
- **RDD generowane przez operacje strumieniowe**: w przeciwieństwie do domyślnego `MEMORY_ONLY` w Spark Core, streaming domyślnie używa `StorageLevel.MEMORY_ONLY_SER`, by zminimalizować narzut GC.

Zalecenia: użyć **serializacji Kryo** (mniejszy narzut CPU i pamięci), zarejestrować własne klasy i wyłączyć śledzenie referencji obiektów. Dla małych ilości retencjonowanych danych (np. batch interval rzędu kilku sekund, bez operacji okienkowych) można jawnie wyłączyć serializację w persystencji, redukując narzut CPU kosztem minimalnego wzrostu GC.

### Ustawienie właściwego interwału paczki

System jest stabilny, gdy przetwarza dane co najmniej tak szybko, jak są generowane. Sprawdzać w web UI, czy **czas przetwarzania paczki jest mniejszy niż interwał paczki** – jeśli nie, system zaczyna zostawać w tyle.

Podejście do strojenia:
1. Zacząć zachowawczo: interwał paczki 5–10 sekund, niski wolumen danych testowych.
2. Zweryfikować stabilność: monitorować "Total delay" w logach drivera lub przez `StreamingListener` – stabilnie, gdy opóźnienie pozostaje porównywalne z rozmiarem paczki; niestabilnie, gdy opóźnienie stale rośnie.
3. Iterować: po znalezieniu stabilnej konfiguracji zwiększać wolumen danych i/lub zmniejszać interwał paczki, dopuszczając chwilowe wzrosty opóźnienia (np. przy skokach ruchu), o ile wraca ono poniżej rozmiaru paczki.

### Strojenie pamięci

Wymagania pamięciowe klastra silnie zależą od typu transformacji:
- operacje okienkowe (np. ostatnie 10 minut) wymagają utrzymania w pamięci 10 minut danych,
- `updateStateByKey` z dużą liczbą kluczy wymaga proporcjonalnie dużo pamięci,
- proste `map`-`filter`-`store` – niskie wymagania pamięciowe.

Dane, które się nie mieszczą w pamięci, są spillowane na dysk, co obniża wydajność – najlepiej testować na małą skalę i odpowiednio oszacować potrzeby.

Domyślne poziomy persystencji: dane wejściowe – `MEMORY_AND_DISK_SER_2`; RDD ze strumienia – `MEMORY_ONLY_SER`.

**Czyszczenie starych danych**: DStream automatycznie zapomina RDD starsze niż najdłuższe okno/operacja stanowa. Domyślny czas zapamiętywania można wydłużyć: `streamingContext.remember(Minutes(5))` – przydatne przy asynchronicznych zapytaniach SQL trwających dłużej niż domyślna retencja.

**Strojenie GC**: dla wymagań niskiego opóźnienia warto sięgnąć po ogólny [Tuning Guide](./tuning.md) (kolektor CMS, rozmiary generacji, redukcja pauz GC).

---

## 15. Semantyka odporności na awarie (Fault-Tolerance Semantics)

### Definicje

- **At least once** (co najmniej raz) – dane mogą zostać przetworzone jeden lub więcej razy.
- **At most once** (co najwyżej raz) – dane mogą zostać utracone, ale nie zostaną przetworzone więcej niż raz.
- **Exactly once** (dokładnie raz) – dane są przetwarzane dokładnie jeden raz.

### Semantyka odebranych danych

**Bez Write Ahead Logs (WAL)**: odporność na awarie opiera się na replikacji danych wewnątrz Sparka. W razie awarii workera zreplikowane dane można odzyskać z innych węzłów. Jeśli jednak driver ulegnie awarii, zanim odebrane dane zostaną przetworzone, te niesprzetworzone dane zostaną **utracone**.

**Z Write Ahead Logs** (`spark.streaming.receiver.writeAheadLog.enable=true`): wszystkie dane odebrane przez receiver są dodatkowo zapisywane do write-ahead logu w katalogu checkpointu (najlepiej na replikowanym systemie plików, np. HDFS). Dzięki temu:
- awaria workera – dane można odzyskać z WAL,
- awaria drivera – dane pozostają zachowane w WAL i mogą zostać ponownie przetworzone po odzyskaniu, co pozwala osiągnąć **semantykę exactly-once** dla odbioru danych.

Gdy WAL jest włączony, można wyłączyć wewnętrzną replikację danych wejściowych w Sparku (log już jest replikowany).

### Semantyka operacji wyjściowych (`foreachRDD`)

Ponieważ `foreachRDD` jest wykonywane na driverze i może zostać powtórzone po awarii, kluczowym wyzwaniem jest obsługa potencjalnych zduplikowanych zapisów. Dokumentacja zaleca dwa wzorce, by osiągnąć semantykę exactly-once po stronie wyjścia:
1. **Zapisy idempotentne** – zaprojektowane tak, by wielokrotny zapis tych samych danych dawał taki sam efekt jak zapis jednokrotny.
2. **Zapisy transakcyjne** – użycie transakcji zapewniających atomowość zapisu (wszystko albo nic).

---

## 16. Monitorowanie aplikacji

### Zakładka Streaming w Spark Web UI

Gdy używany jest `StreamingContext`, Spark Web UI pokazuje dodatkową zakładkę **Streaming** z:
- **statystykami receiverów** – czy są aktywne, liczba odebranych rekordów, błędy receiverów,
- **statystykami paczek** – czas przetwarzania, opóźnienia w kolejce.

### Kluczowe metryki

1. **Processing Time** – czas przetworzenia jednej paczki danych.
2. **Scheduling Delay** – czas oczekiwania paczki w kolejce na zakończenie poprzednich.

Jeśli czas przetwarzania paczki systematycznie przekracza interwał paczki lub opóźnienie w kolejce stale rośnie – system nie nadąża; należy zredukować czas przetwarzania (patrz sekcja 14).

### Interfejs StreamingListener

`StreamingListener` pozwala monitorować status receiverów, czasy przetwarzania i śledzić własne metryki. To API deweloperskie (developer API), które może być rozbudowywane o kolejne informacje w przyszłości.

---

## 17. Wdrażanie aplikacji strumieniowych

Wymagania:

1. **Klaster z menedżerem klastra** – jak dla każdej aplikacji Sparka.
2. **Spakowanie JAR-a aplikacji** – przy zaawansowanych źródłach (Kafka, Kinesis) trzeba dołączyć dodatkowe artefakty i zależności tranzytywne (np. `spark-streaming-kafka-0-10_2.13` dla `KafkaUtils`).
3. **Wystarczająca pamięć executorów** – dane odebrane muszą się zmieścić w pamięci; np. dla okna 10-minutowego trzeba trzymać co najmniej ostatnie 10 minut danych.
4. **Konfiguracja checkpointingu** – katalog kompatybilny z Hadoop API (HDFS, S3 itd.), jeśli strumień tego wymaga.
5. **Automatyczny restart drivera** – infrastruktura wdrożeniowa musi monitorować proces drivera i wznawiać go po awarii:
   - **Spark Standalone**: driver może działać w trybie *cluster* z opcją *supervise*,
   - **YARN**: wspiera analogiczny mechanizm automatycznego restartu.
6. **Write-Ahead Logs** (od Spark 1.2) – wszystkie dane z receiverów zapisywane do WAL w katalogu checkpointu, zapewniając **zero data loss**. Włączenie: `spark.streaming.receiver.writeAheadLog.enable=true`. Kompromis: może obniżyć przepustowość pojedynczego receivera – rekompensuje się to większą liczbą receiverów działających równolegle. Przy WAL warto wyłączyć replikację danych w Sparku i ustawić poziom przechowywania na `MEMORY_AND_DISK_SER`. Dla S3 i systemów plików bez wsparcia flush: włączyć `spark.streaming.driver.writeAheadLog.closeFileAfterWrite` i `spark.streaming.receiver.writeAheadLog.closeFileAfterWrite`. Spark nie szyfruje danych WAL nawet przy włączonym szyfrowaniu I/O – potrzebne szyfrowanie na poziomie systemu plików.
7. **Ograniczenie maksymalnego tempa odbioru** – gdy zasoby klastra nie nadążają:
   - `spark.streaming.receiver.maxRate` – dla zwykłych receiverów,
   - `spark.streaming.kafka.maxRatePerPartition` – dla podejścia Direct Kafka.
   - **Backpressure** (od Spark 1.5, `spark.streaming.backpressure.enabled=true`) – eliminuje potrzebę ręcznego ustawiania limitów, Spark sam dobiera i dynamicznie dostosowuje tempo.

### Aktualizacja kodu aplikacji

1. **Wdrożenie równoległe** (bez przestoju) – nowa (zaktualizowana) aplikacja startuje równolegle do starej i odbiera te same dane; po "rozgrzaniu" nowej, stara jest zamykana. Wymaga źródła danych wspierającego wysyłkę do dwóch odbiorców jednocześnie.
2. **Łagodne zatrzymanie + restart** – zatrzymanie istniejącej aplikacji przez `StreamingContext.stop(...)` (dokańcza przetwarzanie odebranych danych), a następnie start zaktualizowanej aplikacji. Wymaga źródła ze wsparciem buforowania po stronie źródła (np. Kafka). **Nie da się** wystartować z checkpointu sprzed aktualizacji (zawiera zserializowane obiekty – deserializacja ze zmienionymi klasami powoduje błędy) – trzeba użyć innego katalogu checkpointu lub usunąć poprzedni.

---

## 18. Structured Streaming vs Spark Streaming

Cytat z dokumentacji:

> Spark Streaming is the previous generation of Spark's streaming engine. There are no longer updates to Spark Streaming and it's a legacy project. There is a newer and easier to use streaming engine in Spark called Structured Streaming. You should use Spark Structured Streaming for your streaming applications and pipelines.

- Spark Streaming opiera się na **DStreams** (na bazie RDD).
- **Structured Streaming** to zalecany, nowoczesny odpowiednik (patrz osobny plik `structured-streaming-index.md`).

---

## Kluczowe zasady

- DStream = ciągła seria RDD; operacje na DStream = operacje na leżących u podstaw RDD w każdej paczce.
- Transformacje stanowe (`updateStateByKey`, `reduceByKeyAndWindow` z funkcją odwrotną) **wymagają checkpointingu**.
- `foreachRDD` to najbardziej ogólna operacja wyjściowa – połączenia do systemów zewnętrznych najlepiej tworzyć **per partycja** (albo z puli połączeń), nigdy per rekord ani na driverze.
- Domyślnie dane w streamingu są trzymane **zserializowane** (inaczej niż w RDD Core) – kompromis CPU/GC.
- Interwał paczki musi być większy niż czas jej przetwarzania – inaczej system traci stabilność (rosnące opóźnienie w kolejce).
- Write-Ahead Logs + checkpointing = odzyskiwanie po awarii drivera bez utraty danych (semantyka exactly-once po stronie odbioru); po stronie wyjścia exactly-once wymaga zapisów idempotentnych lub transakcyjnych.
- Akumulatory i zmienne broadcast **nie przetrwają** checkpointu – trzeba je odtwarzać jako leniwe singletony.
- Spark Streaming to legacy – nowe projekty powinny używać Structured Streaming.
