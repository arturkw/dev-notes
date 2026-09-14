# Dlaczego Spark jest szybszy od Hadoop?

"Hadoop" w tym kontekście oznacza klasyczny silnik przetwarzania **MapReduce** (nie cały ekosystem Hadoop — HDFS czy YARN Spark nadal może wykorzystywać jako storage/cluster manager). Porównanie dotyczy więc modelu wykonania MapReduce vs Spark.

## Kluczowe różnice

### 1. Model I/O: dysk vs pamięć

- **MapReduce**: każdy job (map + reduce) czyta dane wejściowe z HDFS i **zapisuje wynik z powrotem na dysk (HDFS)**. Jeśli obliczenie wymaga wielu kroków (np. iteracyjny algorytm, wieloetapowy pipeline), każdy krok to osobny job MapReduce z pełnym zapisem/odczytem z dysku pomiędzy nimi.
- **Spark**: dane pośrednie między transformacjami mogą pozostać **w pamięci RAM** executorów (szczególnie gdy jawnie użyjemy `cache()`/`persist()`, ale nawet bez tego pipeline operacji narrow działa w pamięci w ramach jednego stage'a). Zapis na dysk następuje głównie przy shuffle'u (między stage'ami) i przy jawnym cache'owaniu z poziomem `DISK`.

To największy pojedynczy czynnik przewagi Sparka — przy obliczeniach iteracyjnych (ML, grafowe, wielokrotne zapytania na tym samym zbiorze) różnica bywa rzędu 10-100x.

### 2. Model programowania: sztywny map-reduce vs DAG

- **MapReduce** wymusza dwuetapowy model: `map` → `shuffle` → `reduce`. Każdy bardziej złożony pipeline (np. join, kilka filtrów, agregacja, kolejny join) trzeba ręcznie rozbić na osobne jobs MapReduce, co mnoży liczbę zapisów/odczytów z HDFS i narzut na uruchamianie kolejnych jobów.
- **Spark** buduje dowolnie złożony **DAG** transformacji, dzielony na stage'e tylko tam, gdzie faktycznie potrzebny jest shuffle. Wiele operacji (map, filter, kolejne map) łączy się (pipelining) w jeden przebieg bez materializacji pośredniej. Zobacz [DAG](dag.md).

### 3. Leniwa ewaluacja i globalna optymalizacja

Spark odkłada wykonanie do momentu akcji i widzi cały plan na raz, dzięki czemu może go zoptymalizować globalnie (np. połączyć operacje, zastosować predicate pushdown). MapReduce wykonuje każdy job osobno, bez wiedzy o kolejnych krokach pipeline'u — nie ma możliwości optymalizacji między jobami.

### 4. Narzut startowy (task/job scheduling overhead)

Uruchomienie joba MapReduce (JVM startup dla każdego taska, komunikacja z JobTrackerem/ResourceManagerem) ma relatywnie wysoki narzut. Spark wykorzystuje długo żyjące procesy executorów (JVM uruchomione raz na czas życia aplikacji), które wykonują wiele tasków bez ponownego uruchamiania JVM za każdym razem — to znacząco redukuje narzut, szczególnie przy dużej liczbie małych zadań.

### 5. Wyższy poziom abstrakcji i optymalizator zapytań

Spark SQL/DataFrame korzysta z **Catalyst Optimizer** i **Tungsten**, dających optymalizację planu zapytania oraz efektywne wykonanie na poziomie pamięci/CPU (generowanie kodu, binarny format danych). Klasyczny MapReduce nie ma odpowiednika — logikę map/reduce trzeba pisać ręcznie, bez automatycznej optymalizacji planu.

### 6. Bogatsze API i cache

Spark oferuje API do jawnego cache'owania danych w pamięci między wieloma akcjami (`cache()`/`persist()`) — kluczowe dla iteracyjnych algorytmów (np. gradient descent w ML, PageRank), gdzie te same dane są wielokrotnie przetwarzane. W MapReduce trzeba by je za każdym razem odczytywać z HDFS na nowo.

## Podsumowanie porównawcze

| Aspekt | Hadoop MapReduce | Spark |
|---|---|---|
| Dane pośrednie | Zapis/odczyt z HDFS między jobami | Głównie w pamięci (in-memory) |
| Model obliczeń | Sztywny map → shuffle → reduce | Dowolny DAG transformacji |
| Optymalizacja planu | Brak (każdy job niezależny) | Globalna (DAG, Catalyst) |
| Uruchamianie zadań | Nowa JVM per task | Długo żyjące executory |
| Iteracyjne obliczenia (ML) | Bardzo kosztowne (powtarzalny I/O) | Efektywne dzięki cache w RAM |
| Optymalizator zapytań SQL | Brak wbudowanego | Catalyst Optimizer + Tungsten |

## Zastrzeżenie

Spark nie zastępuje HDFS ani YARN — nadal może z nich korzystać jako warstwy przechowywania i zarządzania zasobami. Przewaga Sparka dotyczy **silnika obliczeniowego** (execution engine), a nie warstwy storage.

## Podsumowanie (na rozmowę kwalifikacyjną)

> Spark jest szybszy od klasycznego Hadoop MapReduce przede wszystkim dlatego, że minimalizuje zapisy/odczyty z dysku między krokami obliczeń (przetwarzanie in-memory zamiast zapisu wyników każdego joba do HDFS), buduje elastyczny DAG operacji zamiast sztywnego modelu map-reduce, wykorzystuje długo żyjące executory zamiast uruchamiania nowej JVM na każdy task, oraz — dla DataFrame/SQL — korzysta z optymalizatora zapytań (Catalyst) i zoptymalizowanego silnika wykonania (Tungsten), których MapReduce w ogóle nie posiada.
