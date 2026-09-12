# Apache Spark – RDD Programming Guide (streszczenie)

Źródło: [spark.apache.org/docs/latest/rdd-programming-guide.html](https://spark.apache.org/docs/latest/rdd-programming-guide.html) (Spark 4.2.0)

Oficjalny przewodnik programowania w Apache Spark, skupiony na **RDD (Resilient Distributed Datasets)** – podstawowym, niskopoziomowym modelu przetwarzania danych w Sparku, zanim wprowadzono DataFrame/SQL.

## Spis treści

1. Inicjalizacja
2. Czym jest RDD
3. Operacje na RDD (transformacje i akcje)
4. Operacje na parach klucz-wartość
5. Domknięcia i zasięg zmiennych
6. [Persystencja/cache'owanie RDD](#6-persystencjacacheowanie-rdd)
7. [Zmienne współdzielone](#7-zmienne-współdzielone)
8. [Operacje shuffle](#8-operacje-shuffle)
9. Formaty danych zewnętrznych
10. Wdrażanie aplikacji

---

## 1. Inicjalizacja

Jak utworzyć `SparkContext`/`SparkConf`, zależności (Maven dla Java/Scala, pip dla Pythona), praca w trybie interaktywnym (`pyspark`, `spark-shell`), wymagania (Python 3.10+).

## 2. Czym jest RDD

Odporna na awarie, rozproszona kolekcja elementów, na której można wykonywać operacje równolegle. Dwa sposoby tworzenia:
- ze zrównoleglonej kolekcji: `sc.parallelize(data)`
- z zewnętrznego źródła danych: `sc.textFile("plik.txt")`

## 3. Operacje na RDD – dwa rodzaje

- **Transformacje** (leniwe, tworzą nowe RDD, nic się nie liczy dopóki nie zajdzie akcja): `map`, `filter`, `flatMap`, `groupByKey`, `reduceByKey`, `join`, `sortByKey`, `union`, `distinct`
- **Akcje** (uruchamiają obliczenia, zwracają wynik do sterownika): `reduce`, `collect`, `count`, `first`, `take`, `foreach`, `saveAsTextFile`

## 4. Operacje na parach klucz-wartość

Klasyczny przykład zliczania wystąpień (word count) przez `map` + `reduceByKey`.

## 5. Domknięcia (closures) i zasięg zmiennych

Częsty błąd: modyfikowanie zmiennej lokalnej wewnątrz `foreach`/`map` nie działa tak jak w programowaniu jednowątkowym, bo kod wykonuje się na osobnych węzłach – każdy dostaje kopię zmiennej. Rozwiązanie: **akumulatory** (patrz sekcja 7).

---

## 6. Persystencja/cache'owanie RDD

Spark pozwala oznaczyć RDD jako *persistowane* (zachowane) metodami `persist()` lub `cache()` – dane obliczone raz w ramach akcji zostają w pamięci/na dysku węzłów i mogą być wielokrotnie ponownie wykorzystane bez przeliczania od zera.

```python
lineLengths.persist()
totalLength = lineLengths.reduce(lambda a, b: a + b)
```

```scala
lineLengths.persist()
val totalLength = lineLengths.reduce((a, b) => a + b)
```

```java
lineLengths.persist(StorageLevel.MEMORY_ONLY());
int totalLength = lineLengths.reduce((a, b) -> a + b);
```

`cache()` to skrót od `persist()` z domyślnym poziomem `MEMORY_ONLY`. Cache Sparka jest **odporny na awarie** – jeśli partycja zostanie utracona, zostanie automatycznie przeliczona na podstawie transformacji, które ją utworzyły (lineage).

### Poziomy przechowywania (Storage Levels)

| Poziom | Znaczenie |
|---|---|
| **MEMORY_ONLY** (domyślny) | Zdeserializowane obiekty Javy w JVM. Jeśli RDD nie mieści się w pamięci, część partycji nie zostanie zcache'owana i będzie przeliczana na bieżąco przy każdym użyciu. |
| **MEMORY_AND_DISK** | Jak wyżej, ale partycje, które się nie mieszczą, są zapisywane na dysk i odczytywane stamtąd zamiast przeliczania. |
| **MEMORY_ONLY_SER** (Java/Scala) | Obiekty serializowane (jeden tablica bajtów na partycję) – zajmuje mniej pamięci, ale odczyt jest bardziej kosztowny obliczeniowo. |
| **MEMORY_AND_DISK_SER** (Java/Scala) | Jak `MEMORY_ONLY_SER`, ale spill na dysk zamiast przeliczania. |
| **DISK_ONLY** | Wyłącznie dysk. |
| **MEMORY_ONLY_2, MEMORY_AND_DISK_2, itd.** | Jak powyższe, ale z replikacją każdej partycji na dwóch węzłach klastra. |
| **OFF_HEAP** (eksperymentalny) | Jak `MEMORY_ONLY_SER`, ale dane trzymane poza stertą JVM (off-heap); wymaga włączenia pamięci off-heap. |

**Python**: obiekty zawsze są serializowane biblioteką Pickle, więc wybór poziomu serializowanego nie ma znaczenia. Dostępne poziomy: `MEMORY_ONLY`, `MEMORY_ONLY_2`, `MEMORY_AND_DISK`, `MEMORY_AND_DISK_2`, `DISK_ONLY`, `DISK_ONLY_2`, `DISK_ONLY_3`.

### Jak wybrać poziom przechowywania

Zalecany proces decyzyjny:

1. Jeśli RDD mieści się wygodnie w pamięci przy domyślnym `MEMORY_ONLY` – zostaw tak. To najbardziej efektywny CPU-owo wariant.
2. Jeśli nie, spróbuj `MEMORY_ONLY_SER` z szybką biblioteką serializacji – dużo bardziej oszczędne pamięciowo, wciąż dość szybkie.
3. Nie spilluj na dysk, chyba że funkcje liczące dany zbiór są bardzo kosztowne lub filtrują dużą ilość danych – w innym wypadku przeliczenie partycji bywa równie szybkie co odczyt z dysku.
4. Użyj poziomów replikowanych, gdy zależy Ci na szybkim odzyskiwaniu po awarii (np. Spark obsługujący żądania aplikacji webowej) – wszystkie poziomy są odporne na awarie (przez przeliczenie), ale replikacja pozwala kontynuować pracę bez czekania na przeliczenie utraconej partycji.

### Usuwanie danych z cache

- **Automatyczne (LRU)**: Spark monitoruje wykorzystanie cache na każdym węźle i usuwa najstarsze (least-recently-used) partycje, gdy brakuje miejsca.
- **Ręczne – `unpersist()`**: pozwala jawnie usunąć RDD z cache zamiast czekać, aż zostanie wyrzucony przez LRU.

```python
rdd.unpersist()               # domyślnie nieblokujące
rdd.unpersist(blocking=True)  # blokuje do zwolnienia zasobów
```

```scala
rdd.unpersist()
rdd.unpersist(blocking = true)
```

```java
rdd.unpersist();
rdd.unpersist(true);
```

**Automatyczna persystencja przy shuffle**: Spark sam persystuje pewne dane pośrednie podczas operacji typu shuffle (np. `reduceByKey`), nawet bez wywołania `persist` przez użytkownika – dzięki temu w razie awarii węzła podczas shuffle nie trzeba przeliczać całego wejścia od nowa.

---

## 7. Zmienne współdzielone

Zwykle, gdy funkcja przekazana do operacji Sparka (`map`, `reduce` itp.) jest wykonywana na zdalnym węźle klastra, działa na **osobnych kopiach** wszystkich zmiennych użytych w funkcji. Kopie są wysyłane do każdej maszyny, a zmiany w nich nie są propagowane z powrotem do programu sterującego (driver). Dla dwóch typowych wzorców Spark udostępnia ograniczone typy **zmiennych współdzielonych**: zmienne rozgłaszane (broadcast) i akumulatory.

### Zmienne rozgłaszane (Broadcast Variables)

**Jak działają**: pozwalają utrzymać zmienną **tylko do odczytu** zcache'owaną na każdej maszynie, zamiast wysyłać jej kopię z każdym zadaniem (task). Przydatne np. do rozdania każdemu węzłowi kopii dużego zbioru danych wejściowych w efektywny sposób – Spark stara się dystrybuować je efektywnymi algorytmami broadcastu, by zmniejszyć koszt komunikacji.

**Kiedy warto ich używać jawnie**: akcje Sparka wykonują się w etapach (stages) rozdzielonych operacjami shuffle, a Spark i tak automatycznie rozgłasza wspólne dane potrzebne zadaniom w ramach jednego etapu (cache'owane w formie zserializowanej, deserializowane przed uruchomieniem zadania). Jawne tworzenie zmiennej broadcast ma sens, gdy:
- zadania w **wielu różnych etapach** potrzebują tych samych danych, lub
- ważne jest cache'owanie danych w postaci **zdeserializowanej**.

**API**:

```python
broadcastVar = sc.broadcast([1, 2, 3])
broadcastVar.value  # [1, 2, 3]
```

```scala
val broadcastVar = sc.broadcast(Array(1, 2, 3))
broadcastVar.value  // Array(1, 2, 3)
```

```java
Broadcast<int[]> broadcastVar = sc.broadcast(new int[] {1, 2, 3});
broadcastVar.value();  // [1, 2, 3]
```

**Zasady użycia**: po utworzeniu zmiennej broadcast należy używać jej zamiast oryginalnej wartości `v` w funkcjach uruchamianych na klastrze, tak żeby `v` nie było wysyłane do węzłów więcej niż raz. Obiektu `v` **nie należy modyfikować** po rozgłoszeniu – gwarantuje to, że wszystkie węzły widzą tę samą wartość (istotne, jeśli zmienna zostanie później wysłana do nowego węzła).

**Zwalnianie zasobów**:
- `broadcastVar.unpersist()` – zwalnia kopię danych na executorach; jeśli broadcast zostanie użyty ponownie, zostanie ponownie rozesłany.
- `broadcastVar.destroy()` – trwale zwalnia wszystkie zasoby; po tym zmienna nie może być już używana.

Obie metody domyślnie nie blokują – aby poczekać na zwolnienie zasobów, trzeba przekazać `blocking=True`.

### Akumulatory (Accumulators)

**Jak działają**: to zmienne, do których można tylko "dodawać" poprzez operację **łączną i przemienną** (associative & commutative), dzięki czemu mogą być efektywnie wspierane równolegle. Służą np. do implementacji liczników (jak w MapReduce) lub sum.

- Zadania na klastrze mogą dodawać wartość metodą `add()` lub operatorem `+=`.
- Zadania **nie mogą odczytać** wartości akumulatora.
- Tylko **program sterujący (driver)** może odczytać wartość, metodą `value`.

**Akumulatory liczbowe** – wbudowane wsparcie:

```python
accum = sc.accumulator(0)
sc.parallelize([1, 2, 3, 4]).foreach(lambda x: accum.add(x))
accum.value  # 10
```

```scala
val accum = sc.longAccumulator("My Accumulator")
sc.parallelize(Array(1, 2, 3, 4)).foreach(x => accum.add(x))
accum.value  // 10
```

```java
LongAccumulator accum = jsc.sc().longAccumulator();
sc.parallelize(Arrays.asList(1, 2, 3, 4)).foreach(x -> accum.add(x));
accum.value();  // 10
```

Tworzone przez `SparkContext.longAccumulator()` (typ Long) lub `SparkContext.doubleAccumulator()` (typ Double). Nazwany akumulator (np. `"My Accumulator"`) pojawia się w Spark UI.

**Własne akumulatory** – przez podklasę `AccumulatorV2` (Scala/Java) lub `AccumulatorParam` (Python). `AccumulatorV2` wymaga nadpisania m.in.:
- `reset()` – wyzerowanie akumulatora,
- `add()` – dodanie kolejnej wartości,
- `merge()` – połączenie z innym akumulatorem tego samego typu.

Typ wynikowy akumulatora może być **inny** niż typ dodawanych elementów.

```scala
class VectorAccumulatorV2 extends AccumulatorV2[MyVector, MyVector] {
  private val myVector: MyVector = MyVector.createZeroVector
  def reset(): Unit = myVector.reset()
  def add(v: MyVector): Unit = myVector.add(v)
  // ... pozostałe wymagane metody
}

val myVectorAcc = new VectorAccumulatorV2
sc.register(myVectorAcc, "MyVectorAcc1")
```

**Odporność na awarie akumulatorów**:
- W przypadku aktualizacji wykonywanych **wyłącznie w akcjach**, Spark gwarantuje, że aktualizacja każdego zadania zostanie zastosowana dokładnie raz (restart zadania nie zaktualizuje wartości ponownie).
- W **transformacjach** aktualizacja może zostać zastosowana **więcej niż raz**, jeśli zadanie lub etap zostaną ponownie wykonane.
- Jeśli scalenie aktualizacji zadania z akumulatorem się nie powiedzie, Spark **ignoruje ten błąd** i oznacza zadanie jako zakończone sukcesem – błędny akumulator nie wpłynie na powodzenie joba, ale jego wartość może być niepoprawna mimo sukcesu joba.

**Akumulatory a leniwa ewaluacja**: aktualizacje wewnątrz transformacji (np. `map()`) **nie są gwarantowane**, dopóki jakaś akcja nie wymusi obliczenia danego RDD:

```python
accum = sc.accumulator(0)
def g(x):
    accum.add(x)
    return f(x)
data.map(g)
# accum wciąż ma wartość 0 – żadna akcja nie wymusiła obliczenia `map`
```

Akumulatory nie zmieniają modelu leniwej ewaluacji Sparka – ich wartość aktualizuje się dopiero, gdy dany RDD zostanie faktycznie obliczony w ramach akcji.

---

## 8. Operacje shuffle

### Które operacje powodują shuffle

- **Operacje repartycjonowania**: `repartition`, `coalesce`
- **Operacje `...ByKey`** (poza liczeniem): `groupByKey`, `reduceByKey`
- **Operacje łączenia**: `cogroup`, `join`

### Jak działa shuffle "pod maską"

Na przykładzie `reduceByKey`: operacja ta tworzy nowe RDD, w którym wszystkie wartości dla danego klucza są połączone w krotkę (klucz + wynik funkcji redukującej zastosowanej do wszystkich wartości dla tego klucza).

**Problem**: wartości dla jednego klucza niekoniecznie znajdują się na tej samej partycji, a nawet na tej samej maszynie – a muszą zostać zebrane razem, żeby policzyć wynik.

**Rozwiązanie Sparka**: dane co do zasady nie są rozmieszczone w partycjach w sposób odpowiedni dla konkretnej operacji – pojedyncze zadanie operuje na pojedynczej partycji. Aby zorganizować dane potrzebne dla jednego zadania `reduceByKey`, Spark musi wykonać operację **"wszyscy do wszystkich" (all-to-all)**:
1. odczytać wszystkie partycje, żeby znaleźć wszystkie wartości dla wszystkich kluczy,
2. zebrać wartości z różnych partycji, żeby policzyć wynik końcowy dla każdego klucza.

To właśnie nazywa się **shuffle**.

**Determinizm i kolejność**: zbiór elementów w każdej partycji nowych, przetasowanych danych jest deterministyczny (podobnie jak kolejność samych partycji), ale **kolejność elementów wewnątrz partycji nie jest deterministyczna**. Jeśli zależy nam na przewidywalnie uporządkowanych danych po shuffle, można użyć:
- `mapPartitions` + sortowanie każdej partycji (np. `.sorted`),
- `repartitionAndSortWithinPartitions` – efektywnie sortuje partycje jednocześnie je repartycjonując,
- `sortBy` – tworzy globalnie posortowane RDD.

### Dlaczego shuffle jest kosztowny

Shuffle to **droga operacja**, ponieważ wymaga:
- operacji dyskowych (I/O),
- serializacji danych,
- operacji sieciowych (I/O).

### Mechanika wewnętrzna i zużycie zasobów

Do organizacji danych na potrzeby shuffle Spark generuje zestawy zadań (nazewnictwo wzięte z MapReduce, niezwiązane bezpośrednio z operacjami `map`/`reduce` Sparka):
- **zadania typu map** – organizują dane,
- **zadania typu reduce** – agregują je.

Po stronie map: wyniki poszczególnych zadań są trzymane w pamięci, dopóki się mieszczą, następnie są sortowane według docelowej partycji i zapisywane do jednego pliku. Po stronie reduce: zadania odczytują odpowiednie posortowane bloki.

**Zużycie pamięci i spill na dysk**: niektóre operacje shuffle mogą zużywać sporo pamięci sterty (heap), bo wykorzystują struktury danych w pamięci do organizacji rekordów przed/po transferze:
- `reduceByKey` i `aggregateByKey` tworzą takie struktury po stronie map,
- operacje `...ByKey` generują je po stronie reduce.

Gdy dane nie mieszczą się w pamięci, Spark spilluje te struktury na dysk, co powoduje dodatkowy narzut I/O dyskowego oraz zwiększone garbage collection.

**Pliki pośrednie i sprzątanie**: shuffle generuje też dużą liczbę plików pośrednich na dysku. Od Spark 1.3 pliki te są zachowywane, dopóki odpowiadające im RDD nie przestaną być używane i nie zostaną wyczyszczone przez garbage collector – dzięki temu nie trzeba ponownie tworzyć plików shuffle przy ponownym przeliczaniu lineage. GC może jednak nastąpić dopiero po długim czasie (jeśli aplikacja trzyma referencje do tych RDD albo GC nie uruchamia się często), przez co długo działające joby Sparka mogą zużywać dużo miejsca na dysku. Katalog tymczasowy określa parametr konfiguracyjny `spark.local.dir`.

**Strojenie**: zachowanie shuffle można konfigurować wieloma parametrami – szczegóły w sekcji "Shuffle Behavior" [Spark Configuration Guide](https://spark.apache.org/docs/latest/configuration.html).

---

## 9. Formaty danych zewnętrznych

Spark obsługuje pliki tekstowe (`textFile`), SequenceFile, formaty Hadoop InputFormat/OutputFormat, zpickle'owane obiekty Pythona, `wholeTextFiles()`.

## 10. Wdrażanie aplikacji

Uruchamianie przez `bin/spark-submit`, wybór mastera (lub tryb `local` do testów), uruchamianie zadań programowo z Java/Scala (`org.apache.spark.launcher`), testy jednostkowe z lokalnym SparkContext.

---

## Kluczowe zasady projektowe Sparka

- **Leniwa ewaluacja** – transformacje liczą się dopiero przy akcji.
- **Odporność na awarie** – RDD odtwarza dane dzięki lineage (historii transformacji).
- **Przetwarzanie w pamięci** – cache przyspiesza iteracyjne obliczenia.
- **Przetwarzanie rozproszone** – operacje działają równolegle na partycjach.
- **Niemutowalność** – transformacje zawsze tworzą nowe RDD.

Przewodnik zawiera równoległe przykłady kodu w Pythonie, Scali i Javie oraz linki do dokumentacji API i przewodników konfiguracji/strojenia. To fundament przed przejściem do wyższopoziomowego API DataFrame/SQL.
