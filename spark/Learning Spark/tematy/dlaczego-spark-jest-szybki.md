# Dlaczego Spark jest szybki?

Szybkość Sparka nie wynika z jednej sztuczki, tylko z kombinacji decyzji architektonicznych na wielu poziomach: od modelu wykonania, przez zarządzanie pamięcią, po optymalizator zapytań. Poniżej najważniejsze czynniki.

## 1. Przetwarzanie in-memory

Spark stara się trzymać dane pośrednie **w pamięci RAM** executorów pomiędzy kolejnymi operacjami, zamiast zapisywać je na dysk po każdym kroku (jak robił to klasyczny Hadoop MapReduce). Odczyt/zapis z pamięci jest o rzędy wielkości szybszy niż z dysku (nawet SSD), co przy iteracyjnych obliczeniach (np. algorytmy ML, joiny wielokrotne na tych samych danych) daje ogromne przyspieszenie. Warto pamiętać, że "in-memory" nie oznacza, że Spark *zawsze* trzyma wszystko w RAM — dzieje się to celowo przy `cache()`/`persist()`, a poza tym dane pośrednie między stage'ami i tak muszą trafić na dysk lokalny przy operacjach shuffle.

## 2. Leniwa ewaluacja (lazy evaluation) i optymalizacja DAG

Transformacje nie są wykonywane od razu — budują logiczny plan (DAG). Dzięki temu Spark widzi **cały łańcuch obliczeń** zanim cokolwiek uruchomi i może go zoptymalizować jako całość:
- łączyć (fuse) operacje narrow w jeden przebieg (pipelining),
- eliminować zbędne operacje,
- przesuwać filtry bliżej źródła danych (predicate pushdown),
- wybierać tylko potrzebne kolumny (projection pushdown).

Zobacz też: [DAG](dag.md).

## 3. Catalyst Optimizer i Tungsten

Dla DataFrame/DataSet/Spark SQL dochodzi dodatkowa warstwa optymalizacji:
- **Catalyst Optimizer** przekształca logiczny plan zapytania w zoptymalizowany plan fizyczny (reguły optymalizacji, cost-based optimization, wybór strategii joina itd.) — zobacz [Catalyst Optimizer](catalyst-optimizer.md).
- **Project Tungsten** optymalizuje wykonanie na niskim poziomie: zarządzanie pamięcią poza stertą JVM, generowanie kodu bajtowego "na miejscu" (whole-stage code generation), operacje na binarnym formacie danych zamiast na obiektach Java. Zobacz [Tungsten](tungsten.md).

## 4. Partycjonowanie i przetwarzanie równoległe

Dane są dzielone na partycje rozproszone po klastrze, a każda partycja przetwarzana jest równolegle przez osobny task na executorze. Liczba dostępnych rdzeni CPU w klastrze bezpośrednio przekłada się na stopień równoległości. Zobacz [partycje i repartition](partycje-i-repartition.md).

## 5. Fault tolerance bez kosztownej replikacji

Odporność na awarie Spark osiąga dzięki **lineage** (informacji, jak dany RDD powstał z innych RDD poprzez transformacje), a nie przez pełną replikację danych na dysku (jak HDFS robi domyślnie 3x). Utracone partycje są po prostu przeliczane na nowo z lineage, co jest tańsze niż ciągłe utrzymywanie replik i pozwala oszczędzać I/O.

## 6. Minimalizacja operacji I/O i sieci

- Pipelining operacji narrow ogranicza liczbę odczytów/zapisów pośrednich.
- Predicate/projection pushdown (przy czytaniu z formatów kolumnowych jak Parquet) pozwala czytać z dysku tylko potrzebne dane.
- Broadcast joins (przy małych tabelach) eliminują kosztowny shuffle sieciowy — zobacz [spark join](spark-join.md).

## 7. Wysokopoziomowe API z niskopoziomową kontrolą

DataFrame/DataSet dają deklaratywność (jak SQL) — Spark sam decyduje o najlepszym planie fizycznym, zamiast programista musiał ręcznie sterować każdym krokiem jak w czystym RDD. To pozwala silnikowi stosować optymalizacje niedostępne dla ręcznie napisanego kodu niskopoziomowego.

## Podsumowanie porównawcze

| Czynnik | Efekt na wydajność |
|---|---|
| In-memory processing | Mniej I/O na dysk między krokami |
| Lazy evaluation + DAG | Globalna optymalizacja planu, pipelining |
| Catalyst Optimizer | Optymalny plan fizyczny zapytania |
| Tungsten | Efektywne zarządzanie pamięcią, whole-stage codegen |
| Partycjonowanie | Równoległość na wielu rdzeniach/węzłach |
| Lineage zamiast replikacji | Tańszy fault tolerance |
| Predicate/projection pushdown | Mniej odczytanych danych z dysku |
| Broadcast join | Unikanie kosztownego shuffle'a |

## Krótkie podsumowanie (na rozmowę kwalifikacyjną)

> Spark jest szybki dzięki połączeniu przetwarzania in-memory, leniwej ewaluacji pozwalającej na globalną optymalizację DAG-a, warstwy Catalyst Optimizer (plan zapytania) i Tungsten (efektywność na poziomie pamięci/CPU), masowej równoległości opartej na partycjonowaniu danych oraz taniego mechanizmu fault tolerance opartego na lineage zamiast pełnej replikacji danych.
