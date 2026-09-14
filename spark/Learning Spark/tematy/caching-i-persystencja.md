# Cachowanie i persystencja danych

## Po co cache'ować

Spark stosuje **lazy evaluation** — transformacje na RDD/DataFrame nie są wykonywane od razu, tylko budują DAG, który jest liczony dopiero przy akcji. Jeśli ten sam DataFrame/RDD jest wykorzystywany w **wielu akcjach** (np. `count()`, potem `write`, potem kolejny `groupBy().show()`), to bez cache'owania Spark **za każdym razem przeliczy cały DAG od źródła** — łącznie z ponownym czytaniem danych z dysku/sieci i powtórzeniem wszystkich wcześniejszych transformacji.

`cache()` / `persist()` pozwala zapamiętać wynik pośredni po jego pierwszym wyliczeniu, tak by kolejne akcje korzystały z zapamiętanej wersji zamiast liczyć wszystko od nowa.

```python
df = spark.read.parquet("s3://bucket/big_table")
filtered = df.filter(df.status == "ACTIVE").cache()

filtered.count()              # akcja #1 — liczy DAG i zapisuje wynik w cache
filtered.groupBy("country").count().show()   # akcja #2 — czyta z cache, nie od nowa z S3
```

**Ważne**: `cache()` samo w sobie nic nie liczy (to wciąż transformacja / lazy operacja) — materializacja następuje dopiero przy pierwszej akcji wykonanej na tym DataFrame.

## `cache()` vs `persist()`

- `cache()` to skrót (alias) na `persist()` z domyślnym storage level.
  - Dla RDD: `MEMORY_ONLY` (w Scali/Javie) — Dataset/DataFrame: `MEMORY_AND_DISK` (deserialized).
- `persist(storageLevel)` pozwala jawnie wybrać, **jak i gdzie** dane mają być przechowane.

```scala
import org.apache.spark.storage.StorageLevel

df.persist(StorageLevel.MEMORY_AND_DISK_SER)
```

## Dostępne StorageLevel

| StorageLevel | Pamięć | Dysk | Serializacja | Replikacja | Kiedy stosować |
|---|---|---|---|---|---|
| `MEMORY_ONLY` | ✅ | ❌ | deserialized (obiekty Java) | 1x | Dane mieszczą się w pamięci, priorytet: szybkość dostępu. Jeśli nie zmieści się — partycje po prostu nie są cache'owane (przeliczane w razie potrzeby). |
| `MEMORY_AND_DISK` | ✅ | ✅ (fallback) | deserialized | 1x | Jak wyżej, ale gdy dane nie mieszczą się w pamięci — nadmiar spilluje na dysk zamiast być przeliczany od nowa. Domyślne dla DataFrame/Dataset. |
| `MEMORY_ONLY_SER` | ✅ | ❌ | serialized (bajty) | 1x | Mniejsze zużycie pamięci (mniej narzutu obiektów JVM) kosztem CPU na deserializację przy każdym odczycie. |
| `MEMORY_AND_DISK_SER` | ✅ | ✅ | serialized | 1x | Kompromis pamięć/CPU + fallback na dysk. |
| `DISK_ONLY` | ❌ | ✅ | serialized | 1x | Dane zbyt duże na pamięć, ale wciąż chcemy uniknąć przeliczania od zera. |
| `*_2` (np. `MEMORY_ONLY_2`) | — | — | — | 2x | Replikacja na 2 węzły — odporność na utratę executora bez konieczności przeliczania partycji. Kosztowne (2x pamięć/sieć). |
| `OFF_HEAP` | ✅ (poza stertą JVM) | opcjonalnie | serialized | 1x | Pamięć poza stertą JVM (mniejszy narzut GC), wymaga skonfigurowania `spark.memory.offHeap.enabled` i `spark.memory.offHeap.size`. |

## Koszt cache'owania

Cache nie jest "darmowy":
- Zajmuje **storage memory** w unified memory managerze executora — może wypierać inne cache'owane dane albo (pośrednio) ograniczać execution memory dostępną dla shuffle/joinów (patrz [resource-allocation-i-memory.md](resource-allocation-i-memory.md)).
- Materializacja (pierwsza akcja po `cache()`) ma dodatkowy narzut na zapis do pamięci/dysku.
- Serializacja/deserializacja (przy `*_SER`) kosztuje CPU.
- Cache'owanie danych, które są użyte **tylko raz**, jest czystą stratą — DAG i tak trzeba policzyć raz, a dodatkowo płacimy za zapis do cache, którego nikt nie odczyta drugi raz.

**Zasada**: cache'uj tylko wtedy, gdy dany DataFrame/RDD jest rzeczywiście reużywany w więcej niż jednej akcji (albo w wielu gałęziach DAG-a, np. join sam ze sobą, iteracyjne algorytmy ML, wielokrotne odpytywanie w interaktywnej eksploracji).

## `unpersist()`

Zwalnia zajęte miejsce w pamięci/dysku, gdy dany zbiór nie będzie już potrzebny:

```python
filtered.unpersist()          # asynchronicznie (domyślnie)
filtered.unpersist(blocking=True)   # czeka na faktyczne zwolnienie
```

Spark i tak w razie potrzeby pamięci usuwa najstarsze cache'owane bloki (LRU) automatycznie, ale jawny `unpersist()` jest dobrą praktyką, gdy z góry wiadomo, że dany zbiór nie będzie już potrzebny — pozwala uniknąć niepotrzebnej presji na pamięć i evictions innych, wciąż potrzebnych bloków.

## Sprawdzanie stanu cache

- Zakładka **Storage** w Spark UI pokazuje, które RDD/DataFrame są cache'owane, ile partycji jest w pamięci vs na dysku, poziom fraction cache'a itd.
- `df.storageLevel` / `spark.catalog.isCached("table_name")` pozwalają sprawdzić stan programistycznie.

## Cache a Spark SQL / tabele

Dla nazwanych tabel/widoków można też użyć SQL-owo:

```sql
CACHE TABLE sales;
UNCACHE TABLE sales;
```

albo `spark.catalog.cacheTable("sales")`.
