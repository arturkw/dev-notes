# Structured Streaming: geneza, model programowania, źródła, transformacje stanowe, joiny i tuning

Structured Streaming to silnik strumieniowy Sparka zbudowany na Spark SQL (Catalyst, patrz [catalyst-optimizer.md](catalyst-optimizer.md)) i tym samym DataFrame/Dataset API, które służy do przetwarzania wsadowego (patrz [rdd-vs-dataframe-vs-dataset.md](rdd-vs-dataframe-vs-dataset.md)). Guiding philosophy: **pisanie strumienia ma być tak proste jak pisanie zapytania batchowego** — ten sam kod, inna metoda uruchomienia (`readStream`/`writeStream` zamiast `read`/`write`).

## 1. Geneza silnika streamingowego Sparka

Ewolucja przetwarzania strumieniowego w Sparku przebiegała w trzech etapach:

**Record-at-a-time processing (model tradycyjny)**
Rozproszony graf węzłów, w którym każdy węzeł przetwarza rekordy pojedynczo i przekazuje dalej. Zaleta: bardzo niska latencja (milisekundy). Wada: kosztowne i wolne odzyskiwanie po awarii węzła lub strugglera — albo dużo zapasowych zasobów dla szybkiego failovera, albo wolne odzyskiwanie przy minimalnych zasobach.

**Micro-batch processing (Spark Streaming / DStreams)**
Spark rzucił wyzwanie temu modelowi, dzieląc strumień na serię małych, deterministycznych zadań batchowych (mikro-batchy, np. co 1 sekundę). Zalety:
- Szybkie i tanie odzyskiwanie po awarii dzięki reschedulowaniu tasków na innych executorach (ta sama mechanika co w batchu).
- Deterministyczność tasków → **exactly-once** processing (ten sam input zawsze daje ten sam output, niezależnie od liczby reexecucji).

Cena: latencja rzędu sekund (czasem poniżej sekundy), a nie milisekund — akceptowalne dla większości pipeline'ów, bo albo dalsze etapy i tak czytają dane godzinowo, albo opóźnienia po stronie źródła (np. batchowanie zapisów do Kafki) i tak dominują nad latencją przetwarzania.

**Ograniczenia DStreams, które doprowadziły do Structured Streaming:**
- Brak jednego API dla batcha i streamu — mimo spójnej semantyki RDD/DStream trzeba było jawnie przepisywać kod przy konwersji zadania batchowego na streamingowe.
- Brak rozdziału logicznego planu od fizycznego — DStreams wykonywały operacje dokładnie w kolejności zdefiniowanej przez developera, bez automatycznych optymalizacji (developer musiał ręcznie tuningować kod).
- Brak natywnej obsługi okien opartych na event-time — DStreams okienkowały tylko po processing-time (czasie odebrania rekordu), co utrudniało poprawne agregacje przy opóźnionych/nieuporządkowanych danych.

Te braki ukształtowały filozofię projektową Structured Streaming: pojedynczy, ujednolicony model programowania dla batcha i streamu oraz szersza definicja przetwarzania strumieniowego (obejmująca też joby uruchamiane cyklicznie, np. co kilka godzin).

## 2. Model programowania Structured Streaming

Kluczowa koncepcja: strumień danych to **nieograniczona (unbounded), ciągle dopisywana tabela wejściowa**. Każdy nowy rekord w strumieniu = nowy wiersz dopisany do tej tabeli.

Developer definiuje zapytanie na tej koncepcyjnej tabeli wejściowej tak, jakby była statyczna, tworząc **tabelę wynikową**, która jest zapisywana do sinka. Structured Streaming automatycznie tłumaczy to zapytanie batchowe na plan wykonawczy strumieniowy — proces zwany **inkrementalizacją**: silnik ustala, jaki stan trzeba utrzymywać, żeby po przyjściu nowego rekordu zaktualizować wynik bez przeliczania wszystkiego od nowa.

Cykl wykonania (dla trybów mikro-batchowych):
1. Trigger uruchamia sprawdzenie nowych danych w źródle.
2. Jeśli są nowe dane — generowany jest zoptymalizowany plan wykonawczy, który czyta nowe dane, inkrementalnie liczy zaktualizowany wynik i zapisuje output do sinka zgodnie z trybem wyjścia.

### Tryby wyjścia (output modes)

- **Append mode** — do sinka trafiają tylko nowe wiersze dopisane do tabeli wynikowej od ostatniego triggera. Stosowalne tylko tam, gdzie istniejące wiersze wyniku nigdy się nie zmieniają (np. mapowanie strumienia bez agregacji).
- **Update mode** — do sinka trafiają tylko wiersze, które zostały zaktualizowane od ostatniego triggera (działa dla sinków wspierających update-in-place, np. tabela MySQL).
- **Complete mode** — cała zaktualizowana tabela wynikowa jest zapisywana do sinka przy każdym triggerze.

Dopóki nie wybrano complete mode, tabela wynikowa **nie jest w pełni materializowana** — silnik trzyma w pamięci tylko tyle informacji ("stan"), ile potrzeba, by poprawnie liczyć aktualizacje i output.

## 3. Fundamenty zapytania streamingowego — pięć kroków

### Krok 1: Zdefiniowanie źródła wejściowego
Zamiast `spark.read` (który tworzy `DataFrameReader`) używa się `spark.readStream`, który tworzy `DataStreamReader` — o niemal identycznym API.

```python
# In Python
spark = SparkSession...
lines = (spark
  .readStream.format("socket")
  .option("host", "localhost")
  .option("port", 9999)
  .load())
```

`spark.readStream` (podobnie jak `spark.read`) tylko konfiguruje odczyt — faktyczne czytanie danych zaczyna się dopiero po jawnym starcie zapytania.

### Krok 2: Transformacja danych
Te same operacje DataFrame co w batchu:

```python
from pyspark.sql.functions import *
words = lines.select(split(col("value"), "\\s").alias("word"))
counts = words.groupBy("word").count()
```

Operacje dzielą się na **stateless** (select, filter, map, flatMap — przetwarzają każdy rekord niezależnie) i **stateful** (agregacje, joiny, grupowanie — wymagają utrzymywania stanu między mikro-batchami). Rozwinięcie w sekcji 5.

### Krok 3: Zdefiniowanie sinka i trybu wyjścia
`DataFrame.writeStream` (zamiast `DataFrame.write`) tworzy `DataStreamWriter`:

```python
writer = counts.writeStream.format("console").outputMode("complete")
```

### Krok 4: Szczegóły przetwarzania (trigger + checkpoint)

**Triggery** — decydują, kiedy uruchamiać kolejne mikro-batche:
- **Default** — kolejny mikro-batch startuje natychmiast po zakończeniu poprzedniego.
- **Processing time z interwałem** (`Trigger.ProcessingTime("1 second")`) — mikro-batche uruchamiane w stałych odstępach.
- **Once** — zapytanie wykonuje dokładnie jeden mikro-batch obejmujący wszystkie dostępne dane i zatrzymuje się; przydatne przy sterowaniu z zewnętrznego schedulera (np. cron uruchamiający job raz dziennie dla oszczędności kosztów).
- **Continuous** (eksperymentalne w Spark 3.0) — przetwarzanie ciągłe zamiast mikro-batchowego, latencja rzędu milisekund, ale wspiera tylko wąski podzbiór operacji.

**Checkpoint location** — katalog w systemie plików zgodnym z HDFS, w którym zapytanie zapisuje informacje o postępie. Po awarii ta metadana pozwala wznowić zapytanie dokładnie tam, gdzie skończyło. Ustawienie tej opcji jest wymagane dla exactly-once recovery.

```python
checkpointDir = "..."
writer2 = writer.trigger(processingTime="1 second").option("checkpointLocation", checkpointDir)
```

### Krok 5: Start zapytania

```python
streamingQuery = writer2.start()
```

`start()` jest nieblokujący — zwraca obiekt `StreamingQuery` reprezentujący aktywne zapytanie w tle. `streamingQuery.awaitTermination()` blokuje wątek główny do zakończenia (i propaguje wyjątek, jeśli zapytanie padło); `streamingQuery.stop()` jawnie zatrzymuje zapytanie.

### Pod maską aktywnego zapytania

Po starcie: operacje DataFrame → logiczny plan → Spark SQL analizuje i optymalizuje plan tak, by dało się go wykonywać inkrementalnie → w tle startuje wątek wykonujący pętlę: (a) sprawdzenie dostępności nowych danych zgodnie z interwałem triggera, (b) jeśli są dane — wygenerowanie zoptymalizowanego planu wykonawczego dla mikro-batcha i zapis outputu, (c) zapisanie w checkpoint location dokładnego zakresu przetworzonych danych (np. offsetów Kafki) i powiązanego stanu. Pętla trwa do zakończenia zapytania (błąd, jawny `stop()`, lub — dla triggera `Once` — samoistne zatrzymanie po jednym mikro-batchu).

### Odzyskiwanie po awariach z gwarancją exactly-once

Restart terminated zapytania wymaga nowego `SparkSession`, ponownego zdefiniowania DataFrame'ów oraz startu z **tym samym checkpoint location**. Ten katalog stanowi unikalną tożsamość zapytania — usunięcie go lub zmiana lokalizacji to w praktyce start nowego zapytania od zera. Checkpointy przechowują informacje o zakresie danych na poziomie rekordów (np. offsety Kafki) współwersjonowane ze stanem, więc po awarii silnik reprocessuje dokładnie ten sam zakres danych z tym samym stanem, co przed awarią — dając ten sam output.

Warunki end-to-end exactly-once:
- **Replayable streaming sources** — zakres danych ostatniego niedokończonego mikro-batcha da się odczytać ponownie ze źródła.
- **Deterministic computations** — te same dane wejściowe zawsze dają ten sam wynik.
- **Idempotent streaming sink** — sink rozpoznaje i ignoruje zduplikowane zapisy spowodowane restartem.

Między restartami można modyfikować: transformacje DataFrame (np. dodać filtr odrzucający uszkodzone rekordy), niektóre opcje źródła/sinka (nie te definiujące tożsamość źródła, np. host/port socketu) oraz szczegóły przetwarzania jak interwał triggera — ale **nie** lokalizację checkpointu.

### Monitorowanie aktywnego zapytania

- `streamingQuery.lastProgress()` — zwraca `StreamingQueryProgress` (JSON/dict) z metrykami ostatniego mikro-batcha: `id` (stały dla checkpointu), `runId` (zmienia się przy każdym restarcie), `numInputRows`, `inputRowsPerSecond`, `processedRowsPerSecond` (jeśli trwale niższy niż input rate — sygnał, że query nie nadąża), szczegóły `sources`/`sink`.
- `streamingQuery.status()` — bieżący status wątku w tle (np. `"isDataAvailable"`, `"isTriggerActive"`).
- **Dropwizard Metrics** — publikacja metryk do zewnętrznych systemów (Ganglia, Graphite); trzeba jawnie włączyć `spark.sql.streaming.metricsEnabled=true`.
- **Custom `StreamingQueryListener`** (Scala/Java) — interfejs z metodami `onQueryStarted`, `onQueryProgress`, `onQueryTerminated`, rejestrowany przez `spark.streams.addListener(...)`; pozwala na ciągłe publikowanie dowolnej logiki monitoringu.

## 4. Streaming Data Sources and Sinks

Tworzone przez `SparkSession.readStream()` (źródła) i `DataFrame.writeStream()` (sinki), z formatem wskazywanym przez `.format(...)`.

### Pliki
Odczyt i zapis w tych samych formatach co batch: plain text, CSV, JSON, Parquet, ORC. Kluczowe zasady:
- Wszystkie pliki muszą mieć ten sam format i schemat (naruszenie prowadzi do błędnych `null` lub błędów zapytania).
- Każdy plik musi pojawić się w katalogu **atomowo** — cały plik dostępny naraz; zmiany w już przetworzonym pliku są ignorowane.
- Gdy jest więcej nowych plików niż limit (`maxFilesPerTrigger`), wybierane są pliki z najwcześniejszymi timestampami; w obrębie mikro-batcha kolejność odczytu nie jest zdefiniowana.

Zapis do plików wspiera **tylko append mode** (trudno modyfikować istniejące pliki wynikowe w miejscu). Exactly-once przy zapisie do plików zapewnia log w podkatalogu `_spark_metadata` — inne silniki nieświadome tego logu mogą nie dostać tej samej gwarancji.

### Apache Kafka
Natywne wsparcie czytania i pisania. Odczyt (schemat DataFrame: `key`, `value`, `topic`, `partition`, `offset`, `timestamp`, `timestampType`):

```python
inputDF = (spark.readStream.format("kafka")
  .option("kafka.bootstrap.servers", "host1:port1,host2:port2")
  .option("subscribe", "events")
  .load())
```

Zapis wymaga kolumn `value` (wymagana), opcjonalnie `key` i `topic`. Wspiera wszystkie trzy tryby wyjścia, choć complete mode nie jest zalecany (powtarzalny zapis tych samych rekordów).

### Custom Streaming Sources and Sinks
Dla systemów bez natywnego wsparcia:
- **`foreachBatch()`** — funkcja wywoływana z DataFrame'em outputu każdego mikro-batcha plus jego identyfikatorem (`batchId`). Pozwala reużyć istniejące źródła batchowe (np. Spark Cassandra Connector) do zapisu strumienia, zapisać output do wielu lokalizacji (z `persist()`/`unpersist()`, by uniknąć ponownego liczenia), oraz zastosować operacje DataFrame niewspierane natywnie w streamingu. Gwarantuje tylko **at-least-once** (exactly-once trzeba samemu zaimplementować, deduplikując po `batchId`).
- **`foreach()`** — customowa logika per-wiersz przez metody `open()`, `process()`, `close()` (klasa `ForeachWriter`); używane, gdy nie ma odpowiedniego batchowego data writera.
- Budowa customowych źródeł (nie tylko sinków) była w Spark 3.0 wciąż eksperymentalna (DataSourceV2).

## 5. Data Transformations — stateless vs stateful

Catalyst konwertuje operacje DataFrame na zoptymalizowany logiczny plan, a planner Spark SQL — rozpoznając plan streamingowy — generuje ciągłą sekwencję planów wykonawczych zamiast jednorazowego planu fizycznego. Każde wykonanie to mikro-batch, a informacja przekazywana między wykonaniami to **stan streamingowy**.

- **Stateless transformations** (`select()`, `explode()`, `map()`, `filter()`, `where()`) — przetwarzają każdy rekord niezależnie, bez informacji o wcześniejszych wierszach. Wspierają append i update mode, ale nie complete (przechowywanie stale rosnącego wyniku byłoby zbyt kosztowne).
- **Stateful transformations** (`groupBy().count()`, joiny, agregacje) — wymagają stanu łączącego dane między wieloma wierszami. Niektóre kombinacje są niewspierane, bo są obliczeniowo trudne lub niewykonalne inkrementalnie (np. `cube()`/`rollup()` rzucają `UnsupportedOperationException`).

### Zarządzanie stanem — rozproszone i odporne na awarie

Stan agregacji (np. bieżące liczniki `groupBy().count()`) jest partycjonowany i rozproszony tak jak każde inne przetwarzanie w Sparku — cachowany w pamięci executorów dla szybkiego dostępu. Każdy mikro-batch: shuffle'uje nowe rekordy tak, by trafiły do tego samego executora co odpowiadający im stan, liczy nowe wartości lokalnie i aktualizuje stan w pamięci. Żeby przetrwać awarię, zmiany stanu (key/value change logs) są synchronicznie zapisywane do checkpoint location, współwersjonowane z zakresem offsetów przetworzonych w danym batchu — po awarii Spark odtwarza stan, reprocessując ten sam mikro-batch z tymi samymi danymi wejściowymi.

### Typy operacji stanowych

- **Managed stateful operations** — silnik automatycznie identyfikuje i czyści "stary" stan (definicja "starości" jest per-operacja i konfigurowalna): agregacje strumieniowe, stream–stream joins, deduplikacja strumieniowa.
- **Unmanaged stateful operations** — developer definiuje własną logikę czyszczenia stanu: `mapGroupsWithState()` i `flatMapGroupsWithState()`, pozwalające na dowolnie złożone operacje stanowe (np. sesjonizacja).

## 6. Stateful Streaming Aggregations

### Agregacje niezwiązane z czasem
- **Global aggregations** — po całym strumieniu, np. `sensorReadings.groupBy().count()`.
- **Grouped aggregations** — w ramach każdej grupy/klucza, np. `sensorReadings.groupBy("sensorId").mean("value")`.

Uwaga: bezpośrednich agregacji `DataFrame.count()` / `Dataset.reduce()` **nie da się** stosować na streaming DataFrame — na danych statycznych zwracają one od razu policzony wynik, a na strumieniu musi on być ciągle aktualizowany, więc trzeba zawsze przejść przez `groupBy()`/`groupByKey()`. Wspierane są wszystkie wbudowane funkcje agregujące (`sum()`, `mean()`, `stddev()`, `countDistinct()`, `collect_set()` itd.), wiele agregacji naraz w jednym `agg(...)` oraz user-defined aggregation functions.

### Agregacje z oknami event-time

Zamiast agregować po całym strumieniu, częściej trzeba agregować dane w oknach czasowych — i to liczonych po **event time** (czas wygenerowania danych, np. na czujniku), a nie processing time (czas odebrania), bo opóźnienia transportowe zniekształcałyby wynik.

```python
(sensorReadings
  .groupBy("sensorId", window("eventTime", "5 minute"))
  .count())
```

Funkcja `window()` dynamicznie generuje kolumnę grupującą — dla każdego rekordu: liczy okno 5-minutowe na podstawie `eventTime`, grupuje po złożonym kluczu `(okno, sensorId)`, aktualizuje licznik grupy. Okna mogą być **tumbling** (nienachodzące, np. `window("eventTime", "5 minute")`) lub **overlapping/sliding** (np. `window("eventTime", "10 minute", "5 minute")` — okna 10-minutowe przesuwane co 5 minut, każdy rekord trafia wtedy do dwóch grup naraz). Spóźnione i nieuporządkowane zdarzenia są obsługiwane automatycznie — event jest zawsze przypisywany do grupy na podstawie swojego event time, niezależnie od kiedy faktycznie dotarł.

### Watermarks — obsługa spóźnionych danych

Problem: bez ograniczenia stan rósłby w nieskończoność (wciąż nowe okna czasowe, a stare czekają na ewentualne spóźnione dane). **Watermark** to ruchomy próg w event-time, który podąża za maksymalnym widzianym dotąd event time z opóźnieniem (**watermark delay**) — po przekroczeniu progu dla danego okna silnik finalizuje jego agregat i usuwa go ze stanu.

```python
(sensorReadings
  .withWatermark("eventTime", "10 minutes")
  .groupBy("sensorId", window("eventTime", "10 minutes", "5 minutes"))
  .mean("value"))
```

`withWatermark()` musi być wywołane **przed** `groupBy()` i na tej samej kolumnie timestampu, co okno. Dane spóźnione o więcej niż watermark delay są ignorowane, a okna starsze niż próg — czyszczone ze stanu.

**Gwarancja semantyczna**: watermark 10 minut gwarantuje, że silnik **nigdy nie odrzuci** danych spóźnionych o mniej niż 10 minut, ale nie gwarantuje odrzucenia danych spóźnionych o więcej — to zależy od dokładnego timingu przetwarzania.

**Wspierane tryby wyjścia** dla agregacji okienkowych:
- **Update mode** — najbardziej efektywny; watermarking regularnie czyści stan; nie da się jednak pisać do sinków append-only (np. plików, chyba że przez Delta Lake).
- **Complete mode** — działa, ale stan nigdy nie jest czyszczony (trzeba zachować wszystkie przeszłe agregaty) — stosować ostrożnie ze względu na rosnące zużycie pamięci.
- **Append mode** — wymaga watermarkingu; output pojawia się dopiero, gdy watermark gwarantuje, że dany klucz się już nie zaktualizuje (czyli z opóźnieniem równym watermark delay), ale za to pozwala pisać do sinków append-only.

## 7. Streaming Joins

### Stream–static joins
Łączenie strumienia ze statycznym Datasetem — np. dopasowanie eventów kliknięć (stream) do statycznej tabeli wyświetleń reklam (impressions):

```python
matched = clicksStream.join(impressionsStatic, "adId")
```

Kod identyczny jak dla dwóch statycznych DataFrame'ów — różnica tylko w `readStream` vs `read`. Wspierane: inner join oraz **left outer** (gdy lewa strona jest streamem) i **right outer** (gdy prawa strona jest streamem); pozostałe kombinacje outer nie są wspierane, bo trudno je liczyć inkrementalnie. Kluczowe cechy: stream–static joins są **bezstanowe** (nie wymagają watermarkingu), statyczny DataFrame jest odczytywany ponownie przy każdym mikro-batchu (warto go cachować), a widoczność zmian danych źródłowych statycznej strony zależy od jej typu źródła (np. zmiany w plikach nie zostaną zauważone bez restartu zapytania).

### Stream–stream joins
Trudność: w danym momencie widok żadnej ze stron nie jest kompletny, a pasujące eventy mogą przyjść w dowolnej kolejności z dowolnym opóźnieniem. Structured Streaming buforuje dane z obu stron jako stan i na bieżąco sprawdza dopasowania.

**Inner joins z opcjonalnym watermarkingiem** — kod identyczny jak dla stream–static, ale silnik rozpoznaje to jako stream–stream join i buforuje obie strony. Bez ograniczeń czasowych stan rośnie bez ograniczeń, więc trzeba określić:
1. **Watermarki na obu wejściach** (jak dla agregacji).
2. **Ograniczenie event-time między stronami** — przez warunek zakresu czasowego w warunku joina (np. `clickTime BETWEEN impressionTime AND impressionTime + interval 1 hour`) albo przez join na oknach event-time.

```python
impressionsWithWatermark = (impressions
  .selectExpr("adId AS impressionAdId", "impressionTime")
  .withWatermark("impressionTime", "2 hours"))
clicksWithWatermark = (clicks
  .selectExpr("adId AS clickAdId", "clickTime")
  .withWatermark("clickTime", "3 hours"))

(impressionsWithWatermark.join(clicksWithWatermark, expr("""
    clickAdId = impressionAdId AND
    clickTime BETWEEN impressionTime AND impressionTime + interval 1 hour""")))
```

Na podstawie tych ograniczeń silnik automatycznie liczy, jak długo buforować każdą stronę (np. impresje trzeba trzymać do 4h — 3h opóźnienia po stronie clicków + do 1h okna dopasowania; klicki do 2h analogicznie). Watermarking i ograniczenia czasowe są dla inner joinów **opcjonalne** (bez nich stan może rosnąć w nieskończoność, ale zapytanie zadziała), watermark delay gwarantuje niepominięcie danych spóźnionych mniej niż podany próg.

**Outer joins z watermarkingiem** — zmiana tylko typu joina (`leftOuter`), ale tu watermarking i ograniczenia event-time są **obowiązkowe**, bo silnik musi wiedzieć, kiedy dany event na pewno się już nie dopasuje, żeby móc wygenerować wynik z `NULL`. Wynikające z tego NULL-e pojawiają się z opóźnieniem — silnik musi poczekać maksymalny bufor danego eventu (te same 4h/2h co wyżej), zanim uzna, że dopasowania nie będzie.

## 8. Arbitrary Stateful Computations

Dla logiki wykraczającej poza standardowe operacje SQL (np. śledzenie statusu użytkownika — signed in / busy / idle na podstawie historii aktywności) służą `mapGroupsWithState()` i bardziej elastyczne `flatMapGroupsWithState()` — dostępne (w Spark 3.0) tylko w Scali i Javie.

### `mapGroupsWithState()`
Stan o dowolnym schemacie modelowany jako funkcja użytkownika przyjmująca poprzednią wartość stanu i nowe dane, zwracająca zaktualizowany stan i wynik:

```scala
def arbitraryStateUpdateFunction(
    key: K,
    newDataForKey: Iterator[V],
    previousStateForKey: GroupState[S]
): U
```

gdzie `K` — typ klucza, `V` — typ danych wejściowych, `S` — typ przechowywanego stanu, `U` — typ wyniku (wszystkie muszą być kodowalne przez Spark SQL encoders, patrz [dataset-encoder-serializacja.md](dataset-encoder-serializacja.md)). Funkcja jest wywoływana raz na mikro-batch, dla każdego unikalnego klucza obecnego w danych tego batcha (kolejność rekordów w `newDataForKey` nie jest zdefiniowana — trzeba ją ustalić samemu, jeśli jest istotna).

```scala
inputDataset
  .groupByKey(keyFunction)
  .mapGroupsWithState(arbitraryStateUpdateFunction)
```

Jeśli klucz staje się nieaktywny (brak nowych danych) — funkcja domyślnie **nie jest wywoływana** dla niego przez dłuższy czas, więc bez dodatkowego mechanizmu stan takiego klucza nigdy nie zostanie wyczyszczony.

### Timeouty — czyszczenie nieaktywnych grup

`mapGroupsWithState()` wspiera dwa typy timeoutów oparte na dwóch pojęciach czasu:

- **Processing-time timeouts** (`GroupStateTimeout.ProcessingTimeTimeout`) — oparte na czasie systemowym (wall clock); jeśli klucz nie dostał danych przez skonfigurowany czas trwania od ostatniego odebrania danych, kolejny mikro-batch wywoła funkcję z pustym iteratorem danych i `GroupState.hasTimedOut() == true`. Proste w użyciu, ale niezbyt precyzyjne (timing zależy od interwału triggera) i podatne na spurious timeouty przy przestojach/zwolnieniach zapytania (po restarcie po długiej przerwie wszystkie klucze mogą się naraz wytimeoutować).
- **Event-time timeouts** (`GroupStateTimeout.EventTimeTimeout`) — oparte na event-time i watermarku; klucz konfigurowany jest z konkretnym timestampem progu (a nie duration), a timeout następuje, gdy watermark przekroczy ten próg. Odporne na przestoje i wolne przetwarzanie, bo watermark porusza się w tempie danych, a nie zegara systemowego. Wymaga zdefiniowania watermarka na wejściowym Datasetcie oraz ustawienia progu timeoutu na wartość większą niż bieżący watermark (np. `currentWatermark + 1 hour`).

Timeouty resetują się automatycznie przy każdym wywołaniu funkcji (nowe dane lub sam timeout) — trzeba je jawnie ustawiać za każdym razem.

### `flatMapGroupsWithState()` — uogólnienie

Rozwiązuje dwa ograniczenia `mapGroupsWithState()`:
- `mapGroupsWithState()` musi zwrócić dokładnie jeden rekord za każdym wywołaniem — `flatMapGroupsWithState()` zwraca **iterator**, więc można zwrócić dowolną liczbę rekordów (w tym zero).
- Dodatkowy parametr **operator output mode** (append vs update) informuje silnik, czy generowane rekordy są nowymi, dopisywanymi wpisami (`OutputMode.Append`) czy aktualizacjami istniejących par klucz/wartość (`OutputMode.Update`) — co wpływa na to, jakie dalsze operacje i sinki są dozwolone (np. append do plików nie jest wspierany po `mapGroupsWithState()`, ale jest po `flatMapGroupsWithState()` z `OutputMode.Append`).

Typowe zastosowanie: generowanie zero lub więcej alertów per klucz na podstawie zmian stanu (np. sesjonizacja, wykrywanie anomalii).

## 9. Performance Tuning

Structured Streaming działa na silniku Spark SQL, więc obowiązują te same parametry co przy tuningu batchowym (patrz [resource-allocation-i-memory.md](resource-allocation-i-memory.md)), ale klaster streamingowy pracujący 24/7 na mniejszych wolumenach danych per mikro-batch wymaga innego podejścia:

- **Cluster resource provisioning** — underprovisioning powoduje narastające opóźnienia mikro-batchy, overprovisioning generuje niepotrzebne koszty. Alokacja zależy od charakteru zapytań: bezstanowe wymagają więcej rdzeni, stanowe — więcej pamięci.
- **Liczba partycji shuffle** — dla streamingu zwykle trzeba ją ustawić dużo niżej niż domyślne 200 (`spark.sql.shuffle.partitions`), bo zbyt duża liczba partycji zwiększa narzut przy krótkich mikro-batchach; rekomendacja to ok. 2–3x liczby przydzielonych rdzeni. Operacje stanowe mają dodatkowo wyższy narzut per-task ze względu na checkpointing.
- **Source rate limits** — dla stabilności warto ograniczyć maksymalną szybkość konsumpcji danych ze źródła (np. Kafka, pliki) przez limity, by nagłe skoki wolumenu danych nie generowały nieoczekiwanie dużych mikro-batchy. Uwaga: zbyt niski limit powoduje niedowykorzystanie zasobów i opóźnienia względem tempa napływu danych, a limity nie chronią przed **trwałym** wzrostem tempa napływu — dane wciąż będą się buforować w źródle, rosnąc end-to-end latency.
- **Wiele zapytań streamingowych w jednym SparkSession/SparkContext** — pozwala na dzielenie zasobów, ale każde zapytanie zużywa zasoby na driverze w sposób ciągły, co ogranicza liczbę równoległych zapytań (ryzyko wąskiego gardła schedulera lub przekroczenia limitów pamięci na driverze). Sprawiedliwszą alokację między zapytaniami zapewniają osobne scheduler pools:

```scala
spark.sparkContext.setLocalProperty("spark.scheduler.pool", "pool1")
df.writeStream.queryName("query1").format("parquet").start(path1)

spark.sparkContext.setLocalProperty("spark.scheduler.pool", "pool2")
df.writeStream.queryName("query2").format("parquet").start(path2)
```

## Podsumowanie

Structured Streaming ujednolica przetwarzanie batchowe i strumieniowe pod jednym DataFrame/Dataset API, traktując strumień jako nieograniczoną tabelę. Developer definiuje: źródło (`readStream`), transformacje (stateless/stateful), sink i tryb wyjścia (`writeStream`), trigger i checkpoint location, po czym startuje zapytanie. Zarządzanie stanem (agregacje, joiny stream-stream, deduplikacja) jest w dużej mierze automatyczne dzięki watermarkom ograniczającym rozmiar stanu, a dla bardziej złożonych scenariuszy dostępne są `mapGroupsWithState()`/`flatMapGroupsWithState()` z pełną kontrolą nad stanem i timeoutami. Całość działa na silniku Spark SQL, więc korzysta z tych samych optymalizacji (Catalyst) i wymaga podobnego, choć inaczej rozłożonego, tuningu wydajności.
