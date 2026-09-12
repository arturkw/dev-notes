# Apache Spark – Tuning Guide (streszczenie)

Źródło: [spark.apache.org/docs/latest/tuning.html](https://spark.apache.org/docs/latest/tuning.html) (Spark 4.2.0)

Przewodnik po strojeniu wydajności aplikacji Spark. Programy Sparka mogą być ograniczane przez CPU, przepustowość sieci lub pamięć – gdy dane mieszczą się w pamięci, głównym wąskim gardłem jest zwykle sieć. Przewodnik skupia się na dwóch głównych tematach: **serializacji danych** (kluczowej dla wydajności sieci i zużycia pamięci) oraz **strojeniu pamięci**, a także na kilku mniejszych zagadnieniach.

## Spis treści

1. [Serializacja danych](#1-serializacja-danych)
2. [Strojenie pamięci (Memory Tuning)](#2-strojenie-pamięci-memory-tuning)
3. [Zarządzanie pamięcią – przegląd](#3-zarządzanie-pamięcią--przegląd)
4. [Określanie zużycia pamięci](#4-określanie-zużycia-pamięci)
5. [Tuning struktur danych](#5-tuning-struktur-danych)
6. [Przechowywanie RDD w formie zserializowanej](#6-przechowywanie-rdd-w-formie-zserializowanej)
7. [Strojenie garbage collection](#7-strojenie-garbage-collection)
8. [Poziom równoległości](#8-poziom-równoległości)
9. [Równoległe listowanie ścieżek wejściowych](#9-równoległe-listowanie-ścieżek-wejściowych)
10. [Zużycie pamięci przez zadania redukujące](#10-zużycie-pamięci-przez-zadania-redukujące)
11. [Broadcasting dużych zmiennych](#11-broadcasting-dużych-zmiennych)
12. [Lokalność danych (Data Locality)](#12-lokalność-danych-data-locality)

---

## 1. Serializacja danych

Serializacja ma krytyczne znaczenie dla wydajności aplikacji rozproszonych – wolne formaty serializacji i duży rozmiar bajtowy znacząco spowalniają obliczenia. Spark udostępnia dwie biblioteki serializacji:

### Serializacja Java (domyślna)
- Wykorzystuje mechanizm `ObjectOutputStream` z Javy.
- Działa z dowolną klasą implementującą `java.io.Serializable`.
- Wydajność można poprawić, implementując `java.io.Externalizable`.
- **Wada**: elastyczna, ale wolna; generuje duże zserializowane formaty.

### Serializacja Kryo
- **Wydajność**: nawet 10x szybsza i bardziej kompaktowa niż serializacja Java.
- Wersja: Kryo 4.
- **Wada**: nie obsługuje wszystkich typów `Serializable`; wymaga wcześniejszej rejestracji klas dla najlepszej wydajności.
- **Zaleta**: od Sparku 2.0.0 używana wewnętrznie do shuffle'owania RDD z prostymi typami, tablicami lub stringami.

**Przełączenie na Kryo**:

```scala
val conf = new SparkConf().setMaster(...).setAppName(...)
conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
val sc = new SparkContext(conf)
```

**Rejestrowanie własnych klas w Kryo**:

```scala
val conf = new SparkConf().setMaster(...).setAppName(...)
conf.registerKryoClasses(Array(classOf[MyClass1], classOf[MyClass2]))
val sc = new SparkContext(conf)
```

Spark automatycznie dołącza serializery Kryo dla popularnych klas Scali dzięki `AllScalaRegistrar` z biblioteki Twitter chill.

**Uwagi konfiguracyjne**:
- Zwiększ `spark.kryoserializer.buffer`, jeśli obiekty są duże – bufor musi pomieścić *największy* serializowany obiekt.
- Jeśli własne klasy nie zostaną zarejestrowane, Kryo przechowuje pełną nazwę klasy przy każdym obiekcie (marnotrawstwo miejsca).
- Zaawansowane opcje rejestracji – patrz [dokumentacja Kryo](https://github.com/EsotericSoftware/kryo).

---

## 2. Strojenie pamięci (Memory Tuning)

Trzy kluczowe aspekty do rozważenia:
1. **Ilość** pamięci zajmowanej przez obiekty (czy cały zbiór danych zmieści się w pamięci).
2. **Koszt** dostępu do obiektów.
3. **Narzut garbage collection** przy dużej rotacji obiektów.

### Narzut obiektów Javy

Domyślnie obiekty Javy zajmują 2-5x więcej miejsca niż surowe dane, ponieważ:
- **Nagłówek obiektu**: ok. 16 bajtów na obiekt (zawiera wskaźnik klasy).
- **Stringi w Javie**: ok. 40 bajtów narzutu + znaki przechowywane jako 2 bajty (UTF-16); 10-znakowy string zajmuje ok. 60 bajtów.
- **Kolekcje** (`HashMap`, `LinkedList`): struktury wiązane z obiektami-wrapperami dla każdego wpisu + 8-bajtowe wskaźniki.
- **Boksowane typy prymitywne**: `java.lang.Integer` i podobne klasy opakowujące.

---

## 3. Zarządzanie pamięcią – przegląd

Zużycie pamięci dzieli się na dwie kategorie:
- **Pamięć wykonawcza (execution memory)** – obliczenia w shuffle'ach, joinach, sortowaniach, agregacjach.
- **Pamięć magazynująca (storage memory)** – cache i wewnętrzna propagacja danych.

### Zunifikowany region pamięci

- **M** = zunifikowany region pamięci (współdzielony przez execution i storage).
- **R** = podregion storage, w którym zcache'owane bloki **nigdy** nie są wypierane przez execution.
- Execution może wyprzeć storage tylko do momentu, aż całkowite zużycie storage spadnie poniżej progu R.
- Storage nie może wyprzeć execution (ze względu na złożoność implementacyjną).

**Domyślna konfiguracja**:

| Parametr | Domyślna wartość | Znaczenie |
|---|---|---|
| `spark.memory.fraction` | `0.6` | Rozmiar M jako ułamek (przestrzeń sterty JVM − 300 MiB); pozostałe 40% jest zarezerwowane na struktury danych użytkownika, metadane Sparka i zabezpieczenie przed OOM. |
| `spark.memory.storageFraction` | `0.5` | Rozmiar R jako ułamek M; przestrzeń storage odporna na wyparcie przez execution. |

**Właściwości projektu**:
1. Aplikacje bez cache'owania wykorzystują całą przestrzeń na execution.
2. Aplikacje cache'ujące rezerwują minimalną przestrzeń storage (R) odporną na wyparcie.
3. Rozsądna wydajność "out of the box" bez potrzeby eksperckiej wiedzy użytkownika.

**Uwaga**: `spark.memory.fraction` powinno mieścić się wygodnie w generacji "old"/"tenured" JVM (patrz strojenie GC).

---

## 4. Określanie zużycia pamięci

**Dobra praktyka – strona "Storage" w web UI**:
1. Utwórz RDD.
2. Umieść je w cache.
3. Sprawdź stronę "Storage" w web UI, żeby zobaczyć zajętość pamięci.

**Szacowanie programistyczne**: metoda `SizeEstimator.estimate()` pozwala:
- eksperymentować z różnymi układami danych, żeby zmniejszyć zużycie pamięci,
- określić, ile miejsca na stercie executora zajmują zmienne broadcast.

---

## 5. Tuning struktur danych

Sposoby na zmniejszenie zużycia pamięci przez unikanie narzutu Javy:

1. **Używaj tablic obiektów i typów prymitywnych** zamiast standardowych kolekcji Java/Scala.
   - Do kolekcji typów prymitywnych warto użyć biblioteki [fastutil](http://fastutil.di.unimi.it), kompatybilnej ze standardową biblioteką Javy.
2. **Unikaj zagnieżdżonych struktur** z wieloma małymi obiektami i wskaźnikami.
3. **Używaj identyfikatorów numerycznych lub enumów** zamiast stringów jako kluczy.
4. **Dla maszyn z <32 GiB RAM**: ustaw flagę JVM `-XX:+UseCompressedOops`, aby wskaźniki miały 4 bajty zamiast 8 (dodaj w [`spark-env.sh`](configuration.html#environment-variables)).

---

## 6. Przechowywanie RDD w formie zserializowanej

Gdy obiekty pozostają zbyt duże mimo tuningu struktur danych, warto przechowywać je w **formie zserializowanej**:

```scala
// Użyj zserializowanego poziomu przechowywania w API persystencji RDD
MEMORY_ONLY_SER
```

**Korzyści i kompromisy**:
- **Korzyść**: znacząco zmniejsza zużycie pamięci.
- **Wada**: wolniejszy dostęp (deserializacja "w locie").
- **Rekomendacja**: do zserializowanego cache'owania używaj **Kryo** – daje dużo mniejsze obiekty niż serializacja Java.

---

## 7. Strojenie garbage collection

### Kiedy GC jest problemem

Problemy z GC pojawiają się przy dużej "rotacji" (churn) obiektów w przechowywanych RDD (zwykle nie jest to problem dla RDD odczytywanych raz i przetwarzanych wieloma operacjami).

**Kluczowa zasada**: koszt GC jest proporcjonalny do liczby obiektów Javy.
- Używaj struktur danych z mniejszą liczbą obiektów (np. tablica `Int` zamiast `LinkedList`).
- **Najlepsza metoda**: przechowuj obiekty w formie zserializowanej (jedna tablica bajtów na partycję RDD).

### Mierzenie wpływu GC

Dodaj do opcji Javy:
```
-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCTimeStamps
```

Uwaga: logi pojawiają się na **węzłach roboczych** (w `stdout` katalogów roboczych), nie w programie sterującym. Sposób przekazywania opcji Javy do zadań Sparka – patrz [przewodnik konfiguracji](configuration.html#dynamically-loading-spark-properties).

### Zaawansowane strojenie GC

**Struktura sterty JVM**:
- **Young generation** – obiekty krótko żyjące (podregiony: Eden, Survivor1, Survivor2).
- **Old generation** – obiekty długo żyjące.

**Uproszczona procedura GC**:
1. Eden się zapełnia → uruchamia się minor GC na Eden.
2. Żywe obiekty z Eden i Survivor1 są kopiowane do Survivor2.
3. Regiony Survivor są zamieniane miejscami.
4. Obiekty stare lub zapełniony Survivor2 → przenoszone do Old.
5. Old bliski zapełnienia → wywoływany jest full GC.

**Cel strojenia GC**: zapewnić, żeby w Old generation trafiały tylko długo żyjące RDD, a Young generation był wystarczająco duży dla obiektów krótkotrwałych – tak by unikać pełnych GC zbierających tymczasowe obiekty z wykonania zadań.

**Kroki strojenia**:

1. **Zbierz statystyki GC**, żeby zidentyfikować nadmiarowe kolekcje.
   - Jeśli full GC wywoływany jest wielokrotnie zanim zadanie się zakończy – oznacza to niewystarczającą ilość pamięci execution.
2. **Zbyt wiele minor collections** (ale bez major GC):
   - Przydziel więcej pamięci dla Eden.
   - Jeśli zadanie potrzebuje pamięci `E`, ustaw rozmiar Young generation: `-Xmn=4/3*E` (współczynnik 4/3 uwzględnia regiony survivor).
3. **Jeśli OldGen jest bliski zapełnienia**:
   - Zmniejsz cache, obniżając `spark.memory.fraction`.
   - Lub zmniejsz rozmiar Young generation (niższe `-Xmn` albo dostosuj `NewRatio`).
   - `NewRatio` domyślnie = 2 (Old generation = 2/3 sterty) – powinno przekraczać `spark.memory.fraction`.
4. **Spark 4.0.0+ używa JDK 17 z domyślnym G1GC**: dla dużych sterty executora zwiększ rozmiar regionu G1: `-XX:G1HeapRegionSize`.
5. **Przykładowe wyliczenie** (odczyt danych z HDFS): zdekompresowany blok jest zwykle 2-3x większy niż skompresowany. Dla przestrzeni roboczej na 3-4 zadania przy bloku HDFS 128 MiB:
   ```
   Eden size ≈ 4 * 3 * 128 MiB
   ```
6. **Monitoruj zmiany** częstotliwości i czasu trwania GC po wprowadzeniu nowych ustawień.

**Konfiguracja GC ustawiana przez**:
```
spark.executor.defaultJavaOptions
spark.executor.extraJavaOptions
```

---

## 8. Poziom równoległości

Klaster jest niedostatecznie wykorzystywany bez wystarczającego poziomu równoległości w każdej operacji.

- **Automatycznie**: Spark ustawia liczbę zadań "map" na podstawie rozmiaru pliku (można to kontrolować parametrami `SparkContext.textFile`).
- **Rozproszone operacje "reduce"** (`groupByKey`, `reduceByKey`): używają liczby partycji największego RDD-rodzica.
- **Własny poziom równoległości**: podaj jako drugi argument operacji lub ustaw parametr konfiguracyjny `spark.default.parallelism`.
- **Rekomendacja**: 2-3 zadania na rdzeń CPU w klastrze.

---

## 9. Równoległe listowanie ścieżek wejściowych

Dla jobów z dużą liczbą katalogów (zwłaszcza wobec magazynów obiektowych, np. S3) warto zwiększyć równoległość listowania katalogów.

**RDD z formatami wejściowymi Hadoop**:
```
spark.hadoop.mapreduce.input.fileinputformat.list-status.num-threads
(domyślnie = 1)
```

**Źródła plikowe Spark SQL** – parametry do dostrojenia:
```
spark.sql.sources.parallelPartitionDiscovery.threshold
spark.sql.sources.parallelPartitionDiscovery.parallelism
```

Szczegóły – patrz [przewodnik strojenia wydajności Spark SQL](sql-performance-tuning.html).

---

## 10. Zużycie pamięci przez zadania redukujące

`OutOfMemoryError` może wynikać nie z samych RDD, lecz z roboczego zbioru danych pojedynczego zadania (np. zadania redukującego `groupByKey`).

**Przyczyna**: operacje shuffle (`sortByKey`, `groupByKey`, `reduceByKey`, `join`) budują tablice haszujące per zadanie.

**Rozwiązanie**: **zwiększenie poziomu równoległości**:
- mniejszy zbiór wejściowy na zadanie,
- Spark efektywnie obsługuje zadania trwające ok. 200 ms,
- executor JVM jest wielokrotnie wykorzystywany, więc koszt uruchamiania zadań jest niski,
- liczba zadań może bezpiecznie przekraczać liczbę rdzeni w klastrze.

---

## 11. Broadcasting dużych zmiennych

Wykorzystanie [mechanizmu broadcast](rdd-programming-guide.html#broadcast-variables) w `SparkContext` pozwala:
- zmniejszyć rozmiar zserializowanego zadania,
- zmniejszyć koszt uruchamiania jobów na klastrze,
- współdzielić duże obiekty (np. statyczne tablice przeglądowe) z drivera do zadań.

**Wskazówki**:
- Spark wypisuje rozmiar zserializowanego zadania na masterze.
- Zadania większe niż **20 KiB** prawdopodobnie warto zoptymalizować.

---

## 12. Lokalność danych (Data Locality)

Ma duży wpływ na wydajność – szybciej jest przenieść zserializowany kod niż fragmenty danych.

**Poziomy lokalności (od najbliższego do najdalszego)**:

| Poziom | Opis |
|---|---|
| `PROCESS_LOCAL` | Dane w tej samej JVM co uruchomiony kod (najlepszy przypadek). |
| `NODE_LOCAL` | Dane na tym samym węźle (np. HDFS, executor na tym samym węźle). |
| `NO_PREF` | Dostęp równie szybki z dowolnego miejsca. |
| `RACK_LOCAL` | Dane na tym samym rack'u (inny serwer, jeden switch). |
| `ANY` | Dane gdzie indziej w sieci, na innym rack'u. |

**Strategia planowania Sparka**:
- Preferuje najlepszy dostępny poziom lokalności.
- Jeśli na wolnym executorze nie ma nieprzetworzonych danych, spada do niższych poziomów.
- Wybór: a) czekać, aż zwolni się zajęty CPU, czy b) uruchomić zadanie dalej (przenosząc dane).
- **Domyślne zachowanie**: krótkie oczekiwanie, a po przekroczeniu limitu czasu – przeniesienie danych.

**Konfiguracja**: parametry timeoutów per-poziom i łączne – `spark.locality.*` na [stronie konfiguracji](configuration.html#scheduling). Warto zwiększyć wartości, jeśli zadania są długie, a lokalność słaba – domyślne ustawienia zwykle działają dobrze.

---

## Kluczowe zasady

1. **Serializacja danych** jest najważniejszym czynnikiem wydajności – przełącz się na **Kryo** i rejestruj własne klasy.
2. **Strojenie pamięci** – rozumiej narzut obiektów Javy, dostosuj struktury danych, rozważ przechowywanie RDD w formie zserializowanej.
3. Dla większości programów **Kryo + zserializowana persystencja danych** rozwiązuje najczęstsze problemy wydajnościowe.
4. Właściwy **poziom równoległości** (2-3 zadania/rdzeń) i unikanie zbyt dużych zadań redukujących zapobiega `OutOfMemoryError`.
5. **Broadcast** dużych zmiennych i dbałość o **lokalność danych** zmniejszają narzut sieciowy i koszt uruchamiania zadań.
6. Dodatkowe dobre praktyki – patrz [lista mailingowa Sparka](https://spark.apache.org/community.html).
