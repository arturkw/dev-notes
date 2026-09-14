# Różnice pomiędzy RDD, DataFrame, DataSet, kiedy stosować które, jakie są kwestie związane z wydajnością

## Trzy poziomy abstrakcji w Sparku

Spark oferuje trzy API do pracy z rozproszonymi danymi, zbudowane jedno na drugim, korzystające z tego samego silnika wykonawczego:

```
RDD  →  DataFrame (Dataset[Row])  →  Dataset[T]
```

### RDD (Resilient Distributed Dataset)

- Najniższy poziom abstrakcji — rozproszona kolekcja obiektów JVM (lub obiektów Pythona przy PySpark), bez informacji o schemacie/strukturze danych.
- Operacje to zwykłe funkcje/lambdy działające na obiektach (`map`, `filter`, `reduce`).
- Spark **nie wie nic** o strukturze danych wewnątrz obiektu — dla silnika to "czarna skrzynka" (opaque object), więc **nie może zastosować optymalizacji Catalyst/Tungsten**.
- Dostępny we wszystkich językach (Scala, Java, Python, R).

### DataFrame

- `Dataset[Row]` — rozproszona kolekcja danych zorganizowana w **nazwane kolumny** z jawnym schematem, koncepcyjnie jak tabela SQL.
- Operacje wyrażane deklaratywnie (`select`, `filter`, `groupBy`, wyrażenia kolumnowe) — Spark **rozumie strukturę danych i semantykę operacji**, dzięki czemu może zoptymalizować plan wykonania przez **Catalyst Optimizer** i wygenerować zoptymalizowany bytecode przez **Tungsten** (whole-stage code generation, zarządzanie pamięcią off-heap w binarnym formacie wierszy).
- Dostępny w Python, Scala, Java, R — w Pythonie i R jest to jedyna opcja (brak silnie typowanego Dataset).

### DataSet

- Silnie typowana wersja DataFrame — `Dataset[T]`, gdzie `T` to konkretny typ (np. case class w Scali, JavaBean w Javie).
- Łączy zalety RDD (bezpieczeństwo typów na etapie kompilacji, programowanie funkcyjne z lambdami — `map`, `filter` operujące na obiektach `T`) z optymalizacjami silnika Spark SQL (Catalyst/Tungsten) — dzięki mechanizmowi **Encoder**, który tłumaczy obiekty JVM na wewnętrzny binarny format Tungsten i z powrotem.
- **Dostępność językowa: tylko Scala i Java.** Python i R nie mają API Dataset, ponieważ są językami dynamicznie typowanymi — nie da się wymusić bezpieczeństwa typów na etapie kompilacji. W PySpark `DataFrame` pełni obie role.

## Tabela porównawcza

| Cecha | RDD | DataFrame | DataSet |
|---|---|---|---|
| Poziom abstrakcji | niski (obiekty) | wysoki (kolumny/schemat) | wysoki + typowanie |
| Bezpieczeństwo typów (compile-time) | tak | nie (błędy dopiero w runtime) | tak |
| Dostępne języki | Scala, Java, Python, R | Scala, Java, Python, R | tylko Scala, Java |
| Optymalizacja Catalyst | **nie** | tak | tak |
| Optymalizacja Tungsten (off-heap, code gen) | **nie** | tak | tak |
| Serializacja | Java/Kryo (pełne obiekty) | binarny format wewnętrzny (Tungsten row) | Encoder → binarny format Tungsten |
| Styl API | imperatywny (funkcje/lambdy) | deklaratywny (SQL-like) | hybrydowy (deklaratywny + lambdy na typach) |
| Czytelność błędów | błędy typów w compile-time | błędy w runtime (Analysis Exception) | błędy typów w compile-time |

## Kwestie wydajnościowe

- **RDD jest najwolniejszy** dla typowych zadań analitycznych, bo:
  - brak optymalizacji planu (Catalyst) — Spark wykonuje operacje dokładnie tak, jak zostały napisane, bez reorderingu filtrów, column pruning itd.,
  - obiekty JVM trzymane są na stercie (on-heap) z pełnym narzutem obiektowym Javy (nagłówki obiektów, boxing typów prymitywnych, wskaźniki) — więcej GC, więcej pamięci,
  - serializacja pełnych obiektów (Java/Kryo) jest wolniejsza niż binarny format Tungsten.
- **DataFrame i DataSet** korzystają z tego samego zoptymalizowanego silnika (Catalyst generuje plan fizyczny, Tungsten generuje kod wykonawczy i zarządza pamięcią off-heap w zwartym formacie binarnym) — więc **pod względem czystej wydajności silnika są sobie równe**.
- Różnica DataFrame vs DataSet w praktyce:
  - DataSet w Scali, korzystając z operacji typu `map`/`filter` z lambdami operującymi na obiektach `T` (a nie na wyrażeniach kolumnowych), **traci część korzyści Catalyst** — bo lambda to znów "czarna skrzynka" dla optymalizatora (podobnie jak UDF). Za każdym razem, gdy używasz `.map(obj => ...)` na Dataset, Spark musi zdeserializować dane z formatu Tungsten do obiektu JVM, wykonać funkcję, po czym ponownie zserializować wynik — to dodatkowy narzut (podobny do kosztu UDF).
  - Jeśli używasz na DataSet głównie operacji kolumnowych (`select`, `filter($"col" > 1)`), korzystasz z pełnej optymalizacji Catalyst tak samo jak DataFrame.
- **RDD bywa nadal potrzebny**, gdy: potrzebujesz pełnej kontroli nad niskopoziomowym partycjonowaniem/fizycznym rozmieszczeniem danych, pracujesz z niestrukturyzowanymi danymi bez sensownego schematu, lub korzystasz z API, które nie ma odpowiednika w DataFrame (rzadkie w nowoczesnym Sparku).

## Kiedy stosować które

- **DataFrame** — domyślny wybór w 90% przypadków, szczególnie w PySpark (jedyna opcja z pełną optymalizacją) i przy typowych zadaniach ETL/analitycznych.
- **DataSet** — gdy pracujesz w Scali/Javie i zależy Ci na bezpieczeństwie typów w compile-time (łatwiejsze wychwytywanie błędów, lepsze wsparcie IDE) przy zachowaniu operacji kolumnowych tam, gdzie to możliwe; unikaj nadużywania `map`/`filter` z lambdami na obiektach, jeśli zależy Ci na wydajności.
- **RDD** — gdy potrzebujesz niskopoziomowej kontroli, pracujesz z danymi bez struktury, lub migrujesz/utrzymujesz starszy kod. Dla nowych projektów rzadko jest to pierwszy wybór.
