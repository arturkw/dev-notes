# Czym jest Catalyst Optimizer?

Catalyst to **wewnętrzny, rozszerzalny optymalizator zapytań** Spark SQL, napisany w Scali z wykorzystaniem mechanizmów dopasowania wzorców (pattern matching) i drzew reguł (rule-based transformations). To on odpowiada za to, że kod napisany deklaratywnie (SQL, DataFrame, Dataset) jest przekształcany w efektywny plan wykonania, niezależnie od tego, którego z trzech API użył programista.

Catalyst pracuje na wewnętrznej reprezentacji drzewa (`TreeNode`), do którego stosuje kolejne zestawy reguł. Cały proces dzieli się na **cztery fazy**.

## 1. Analysis (analiza)

Surowy, nieprzetworzony plan logiczny (np. z parsera SQL albo z wywołań DataFrame API) zawiera nierozwiązane odwołania — np. kolumnę `age`, o której jeszcze nie wiadomo, czy istnieje i jakiego jest typu. W fazie analizy Catalyst:

- odpytuje **katalog** (Catalog/metastore) o istniejące tabele, kolumny i ich typy,
- wiąże (resolve) nierozwiązane atrybuty i funkcje do konkretnych kolumn/UDF-ów,
- sprawdza poprawność typów,
- w razie błędu (np. nieistniejąca kolumna) rzuca `AnalysisException`.

Efekt: **resolved logical plan**.

## 2. Logical Optimization (optymalizacja logiczna)

Na zresolvowanym planie logicznym Catalyst stosuje reguły oparte na regułach (rule-based optimization), niezależne od silnika wykonawczego — czyli takie, które są korzystne "zawsze", bez potrzeby znajomości statystyk fizycznych. Typowe przykłady:

- **Predicate pushdown** — przesunięcie warunków `WHERE`/`filter` jak najbliżej źródła danych (np. do samego czytnika Parquet), żeby odfiltrować dane zanim zostaną wczytane do pamięci.
- **Column pruning** — usunięcie kolumn, które nie są używane w dalszej części zapytania, tak by czytać z dysku tylko potrzebne kolumny (szczególnie istotne dla formatów kolumnowych jak Parquet/ORC).
- **Constant folding** — obliczenie wyrażeń stałych w czasie planowania (np. `2 + 3` zamienia się na `5`).
- **Boolean expression simplification** — uproszczenie wyrażeń logicznych (np. eliminacja zawsze prawdziwych/fałszywych warunków).
- **Łączenie sąsiadujących operatorów** (np. dwóch kolejnych `filter` w jeden).

Efekt: **optimized logical plan** — wciąż niezależny od tego, *jak* fizycznie wykonać zapytanie, tylko *co* trzeba policzyć i w jakiej logicznej kolejności.

## 3. Physical Planning (planowanie fizyczne)

Z jednego planu logicznego Catalyst generuje **jeden lub więcej planów fizycznych**, korzystając z konkretnych operatorów silnika wykonawczego Sparka (np. `SortMergeJoinExec`, `BroadcastHashJoinExec`, `HashAggregateExec`). Następnie stosuje **model kosztowy (cost-based optimization, CBO)**, opierając się m.in. na statystykach tabel (rozmiar, liczba wierszy, histogramy — jeśli zebrane przez `ANALYZE TABLE`), żeby wybrać najtańszy plan.

Typowa decyzja podejmowana na tym etapie: **czy użyć broadcast joina, czy sort-merge joina** — jeśli jedna z tabel jest mniejsza niż `spark.sql.autoBroadcastJoinThreshold` (domyślnie 10 MB), Catalyst wybierze broadcast hash join zamiast droższego, wymagającego shuffle sort-merge joina. Zobacz [Operacja spark join](spark-join.md).

Efekt: **selected physical plan**, gotowy do wykonania przez silnik Sparka (RDD-level operacje pod spodem).

## 4. Code Generation (Whole-Stage Code Generation)

Ostatni etap to **generowanie kodu Java bajtkodowo** dla wybranego planu fizycznego — mechanizm nazywany **whole-stage code generation** (część projektu Tungsten). Zamiast interpretować drzewo operatorów wiersz po wierszu (co wiąże się z narzutem wirtualnych wywołań między operatorami), Catalyst **łączy wiele sąsiadujących operatorów w jedną funkcję Javy**, kompilowaną just-in-time przez JVM. Dzięki temu procesor CPU wykonuje ciasną pętlę bardzo zbliżoną do ręcznie napisanego, zoptymalizowanego kodu, zamiast przechodzić przez warstwy abstrakcji operatorów Volcano-style.

## Podsumowanie przepływu

```
SQL / DataFrame / Dataset
        │
        ▼
  Unresolved Logical Plan
        │  (Analysis – katalog, rozwiązywanie odwołań)
        ▼
  Resolved Logical Plan
        │  (Logical Optimization – reguły: predicate pushdown, column pruning, constant folding...)
        ▼
  Optimized Logical Plan
        │  (Physical Planning – kandydaci + cost-based optimizer)
        ▼
  Selected Physical Plan
        │  (Whole-Stage Code Generation – Tungsten)
        ▼
     RDD-level bytecode → wykonanie na executorach
```

## Rozszerzalność

Catalyst jest zaprojektowany jako **rozszerzalny** — nowe reguły optymalizacyjne, źródła danych (Data Source API V2) czy typy danych można dodawać bez modyfikowania rdzenia silnika. To m.in. dzięki temu Spark SQL łatwo integruje się z nowymi formatami plików i systemami zewnętrznymi.

## Jak podejrzeć pracę Catalysta

```python
df.explain(True)  # pokazuje wszystkie cztery etapy planu
```

`explain(True)` wypisze: Parsed Logical Plan, Analyzed Logical Plan, Optimized Logical Plan oraz Physical Plan — bardzo przydatne narzędzie do debugowania wydajności zapytań.

## Kluczowe zasady

- Catalyst to **rule-based + cost-based** optymalizator działający na drzewach planu logicznego/fizycznego.
- Niezależnie od API (SQL/DataFrame/Dataset), zapytanie przechodzi przez te same cztery fazy.
- Whole-stage code generation (Tungsten) eliminuje narzut interpretacji operator-po-operatorze, generując skompilowany bajtkod.
- `df.explain(True)` to podstawowe narzędzie do zrozumienia, jak Catalyst zoptymalizował konkretne zapytanie.
