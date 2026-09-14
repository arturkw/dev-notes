# Porównaj formaty parquet, avro, orc

## Wprowadzenie

Wybór formatu przechowywania danych ma ogromny wpływ na wydajność, koszt storage'u i elastyczność ewolucji schematu w systemach big data. Parquet, avro i orc to trzy najpopularniejsze formaty binarne używane w ekosystemie Spark/Hadoop/Hive/Kafka. Każdy z nich powstał z myślą o innym typowym obciążeniu (workload) i mają fundamentalnie różny układ danych na dysku (storage layout).

---

## Parquet

**Parquet** to **columnar** (kolumnowy) format storage'u, stworzony przez Twitter i Cloudera, dziś rozwijany jako projekt Apache. Jest domyślnym formatem w Spark SQL (`df.write.parquet(...)` / po prostu `df.write.save(...)`).

Kluczowe cechy:
- **Columnar storage** — wartości z tej samej kolumny są zapisywane razem, sekwencyjnie. To pozwala na bardzo efektywną kompresję (podobne wartości blisko siebie) oraz na czytanie tylko potrzebnych kolumn (column pruning) — jeśli zapytanie potrzebuje 3 z 50 kolumn, silnik czyta tylko te 3.
- **Kompresja per kolumna** — każda kolumna może mieć osobny compression codec (snappy, gzip, zstd, lz4), dobrany do typu danych. Kolumny homogeniczne kompresują się znacznie lepiej niż wiersze mieszające różne typy.
- **Predicate pushdown** — parquet przechowuje statystyki (min/max, liczbę wartości null) na poziomie row group i column chunk w metadanych pliku. Silnik zapytań (np. Catalyst) może dzięki temu pominąć całe bloki danych, które na pewno nie spełniają warunku `WHERE`, bez ich fizycznego odczytu.
- **Schema evolution** — obsługiwana, ale ograniczona: można dodawać kolumny (nowe pliki będą je mieć, stare będą zwracać null), trudniej zmienić typ istniejącej kolumny czy ją usunąć bez migracji.
- **Struktura pliku** — plik podzielony jest na row groups (logiczne partycje wierszy), a w ich obrębie na column chunki, z metadanymi (footer) na końcu pliku zawierającymi schemat i statystyki.
- Świetnie integruje się z silnikami wektorowymi (Spark, Presto/Trino, Impala) dzięki wsparciu dla **vectorized reading** (czytanie batchami kolumnowymi zamiast wiersz po wierszu).

**Kiedy używać:** analityka OLAP, read-heavy workloads, data lake, gdzie zapytania filtrują/agregują po podzbiorze kolumn.

---

## Avro

**Avro** to **row-based** (wierszowy) format serializacji danych, stworzony w ramach projektu Hadoop, szeroko wykorzystywany w Apache Kafka (jako format wiadomości, często ze Schema Registry).

Kluczowe cechy:
- **Row-based storage** — cały wiersz zapisywany jest razem, sekwencyjnie. Dobre dla scenariuszy, gdzie odczytujemy/zapisujemy całe rekordy, a nie pojedyncze kolumny.
- **Schema zapisany razem z danymi** (lub osobno, np. w Schema Registry) w formacie JSON — Avro jest **self-describing**. Dane binarne są kompaktowe, bo nie powtarzają nazw pól przy każdym rekordzie (schemat jest zapisany raz).
- **Doskonała obsługa schema evolution** — Avro ma jasno zdefiniowane reguały kompatybilności (backward, forward, full compatibility): można dodawać/usuwać pola z wartościami domyślnymi, zmieniać kolejność pól, bez łamania starych czytników/pisarzy. To kluczowa przewaga nad Parquet/ORC w systemach, gdzie schemat ewoluuje często (np. mikroserwisy publikujące eventy do Kafki).
- **Write-heavy / streaming friendly** — zapis pojedynczego rekordu jest tani (nie trzeba buforować całych row groups jak w formatach kolumnowych), więc Avro dobrze nadaje się do strumieniowego zapisu rekord po rekordzie.
- Brak natywnego column pruning i słabszy predicate pushdown niż w formatach kolumnowych — do analitycznych skanów po pojedynczych kolumnach jest mniej efektywny.
- Kompresja działa na poziomie bloku danych (nie per kolumna), więc zazwyczaj gorsze współczynniki kompresji niż Parquet/ORC dla danych analitycznych.

**Kiedy używać:** streaming (Kafka producer/consumer), systemy z często zmieniającym się schematem, RPC/serializacja (Avro RPC), write-heavy pipeline'y, warstwa "raw"/landing w architekturze medallion (bronze layer), gdzie priorytetem jest szybki zapis i odporność na zmiany schematu.

---

## ORC (Optimized Row Columnar)

**ORC** to również format **columnar**, stworzony przez zespół Hortonworks specjalnie z myślą o optymalizacji Hive (nazwa mówi wprost: zoptymalizowany format zastępujący RCFile).

Kluczowe cechy:
- Podobny do Parquet: dane kolumnowe, podzielone na **stripes** (odpowiednik row groups w Parquet), z indeksami i statystykami (min/max, bloom filters) umożliwiającymi predicate pushdown i column pruning.
- **Wbudowane wsparcie dla ACID transactions w Hive** (insert/update/delete) — ORC był pierwszym formatem, który dobrze obsłużył transakcyjne tabele Hive (Hive ACID / transactional tables), czego natywnie brakuje Parquetowi.
- **Lightweight indexes oraz bloom filtery** na poziomie stripe'a — pozwalają jeszcze skuteczniej pomijać dane niepasujące do filtra niż w Parquet w niektórych scenariuszach.
- Bardzo mocno zintegrowany z ekosystemem **Hive/Hadoop** — to jego "natywny" format. Poza Hive używany jest rzadziej niż Parquet (np. Spark, Presto/Trino czy narzędzia chmurowe typu Snowflake/Databricks częściej domyślnie wspierają/preferują Parquet).
- Kompresja zwykle porównywalna lub nieco lepsza niż Parquet (zależnie od danych i codeca — zlib, snappy, zstd).

**Kiedy używać:** środowiska mocno oparte na Hive (szczególnie transakcyjne tabele Hive ACID), legacy klastry Hadoop, gdzie ORC jest standardem organizacyjnym.

---

## Tabela porównawcza

| Cecha | Parquet | Avro | ORC |
|---|---|---|---|
| Storage layout | columnar | row-based | columnar |
| Typowe zastosowanie | analityka/OLAP, data lake | streaming, Kafka, RPC, write-heavy | Hive, tabele transakcyjne (ACID) |
| Schema evolution | ograniczona (dodawanie kolumn łatwe, zmiana typu trudna) | bardzo dobra, jasne reguły kompatybilności | ograniczona, podobnie do Parquet |
| Kompresja | bardzo dobra, per kolumna | umiarkowana, per blok | bardzo dobra, per kolumna, często minimalnie lepsza niż Parquet |
| Predicate pushdown / column pruning | tak, statystyki min/max per row group | nie / słabo | tak, plus bloom filters |
| Wydajność odczytu (analityka, wąski zestaw kolumn) | bardzo dobra | słaba | bardzo dobra |
| Wydajność zapisu (pojedyncze rekordy, streaming) | słabsza (bufor row group) | bardzo dobra | słabsza |
| Self-describing (schema w pliku) | tak (footer) | tak (JSON schema) | tak (footer) |
| Integracja | Spark (domyślny format), Presto/Trino, Databricks | Kafka + Schema Registry, Hadoop RPC | Hive (natywny), Hadoop |
| ACID / transactional tables | brak natywnego wsparcia (Delta Lake/Iceberg/Hudi nakładają to na Parquet) | nie dotyczy | natywne wsparcie w Hive ACID |

---

## Przykład w PySpark

```python
# Parquet
df.write.mode("overwrite").parquet("/data/output/parquet")
df_parquet = spark.read.parquet("/data/output/parquet")

# Avro (wymaga pakietu org.apache.spark:spark-avro)
df.write.mode("overwrite").format("avro").save("/data/output/avro")
df_avro = spark.read.format("avro").load("/data/output/avro")

# ORC
df.write.mode("overwrite").orc("/data/output/orc")
df_orc = spark.read.orc("/data/output/orc")
```

---

## Kiedy wybrać który format — praktyczne scenariusze

- **Data lake analityczny / warstwa silver-gold w architekturze medallion, zapytania BI/ad-hoc SQL** → **Parquet** (najszersza kompatybilność z silnikami zapytań, dobra kompresja, świetny predicate/column pruning; to też fundament formatów table-format typu Delta Lake, Iceberg, Hudi).
- **Streaming, integracja z Kafka, systemy gdzie producenci i konsumenci są rozwijani niezależnie i schemat się zmienia** → **Avro** (schema evolution, Schema Registry, tani zapis rekord po rekordzie).
- **Klaster mocno oparty o Hive, potrzeba transakcyjnych (ACID) tabel Hive, legacy Hadoop stack** → **ORC** (natywna integracja i wsparcie transakcji w Hive).
- Warstwa "bronze"/raw (surowe dane wejściowe, często ze streamingu) → często **Avro** albo JSON; po przetworzeniu i przygotowaniu do analityki dane konwertuje się do **Parquet** dla warstw silver/gold.

W praktyce w nowoczesnych stackach Spark/Databricks/data lakehouse dominującym wyborem jest **Parquet** (jako podkład dla Delta Lake/Iceberg), a Avro pojawia się głównie na granicy ze streamingiem/Kafką, natomiast ORC jest wybierany głównie w środowiskach silnie związanych z Hive.
