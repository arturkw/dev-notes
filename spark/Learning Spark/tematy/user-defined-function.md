# Czym jest user defined function?

## Definicja

**User Defined Function (UDF)** to funkcja zdefiniowana przez użytkownika (w Pythonie, Scali, Javie), którą rejestruje się w Sparku, żeby użyć jej wewnątrz zapytań DataFrame/SQL tam, gdzie brakuje odpowiedniej wbudowanej funkcji. UDF pozwala wykonać dowolną logikę biznesową na poziomie pojedynczego wiersza (skalarne UDF) — jest formą rozszerzenia API Spark SQL o niestandardową logikę.

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import StringType

def classify(age):
    return "adult" if age >= 18 else "minor"

classify_udf = udf(classify, StringType())
df.withColumn("category", classify_udf(df.age)).show()
```

```scala
import org.apache.spark.sql.functions.udf

val classify = udf((age: Long) => if (age >= 18) "adult" else "minor")
df.withColumn("category", classify($"age")).show()
```

```sql
-- rejestracja i użycie UDF w czystym SQL
spark.udf.register("classify_udf", classify)
SELECT classify_udf(age) FROM people;
```

Obok skalarnych UDF istnieją też:
- **UDAF (User Defined Aggregate Function)** — funkcja agregująca zwracająca jedną wartość dla grupy wierszy (odpowiednik `SUM`, `AVG`, ale niestandardowa).
- **UDTF** — funkcja tabelaryczna, zwracająca wiele wierszy/kolumn na wejściu.

## Dlaczego UDF bywają problematyczne pod kątem wydajności

UDF są wygodne, ale mają istotne wady wydajnościowe wynikające z tego, jak działa Catalyst Optimizer:

### 1. "Czarna skrzynka" dla Catalyst

Catalyst analizuje plan logiczny zapytania i optymalizuje go, opierając się na **znanej semantyce** wbudowanych operacji i funkcji (wie np., że `col > 5 AND col < 10` można uprościć, że filtr można przesunąć przed join, że nieużywaną kolumnę można odrzucić). UDF jest dla optymalizatora nieprzezroczysta — Spark nie wie, co funkcja robi w środku, więc:

- **nie może** zoptymalizować/uprościć wyrażenia zawierającego UDF,
- **nie może** zastosować predicate pushdown w takim samym stopniu, jeśli filtr zależy od wyniku UDF,
- **nie generuje** dla UDF zoptymalizowanego kodu maszynowego w ramach whole-stage code generation (Tungsten) tak, jak dla wbudowanych funkcji — wykonanie UDF przerywa wygenerowany, zoptymalizowany pipeline.

### 2. Narzut serializacji/deserializacji

- W Scali/Javie UDF operuje na zdeserializowanych obiektach JVM — podobny narzut jak przy operacjach `map` na DataSet (patrz [DataSet encoder](dataset-encoder-serializacja.md)).
- W **PySpark klasyczny UDF jest znacznie droższy**: dane muszą zostać zserializowane w JVM, przesłane do osobnego procesu Pythona (przez pipe), zdeserializowane, przetworzone przez interpreter Pythona **wiersz po wierszu**, ponownie zserializowane i przesłane z powrotem do JVM. Ten narzut komunikacji międzyprocesowej (JVM ↔ Python) oraz brak wektoryzacji sprawiają, że klasyczne UDF w Pythonie bywają rzędy wielkości wolniejsze niż odpowiednik w wyrażeniach kolumnowych.

### 3. Brak wsparcia dla null-handling i typowania w czasie kompilacji

- Trzeba samodzielnie obsłużyć `null` wewnątrz UDF (Spark nie robi tego automatycznie tak jak dla wbudowanych funkcji).
- Błędy typów ujawniają się dopiero w runtime, nie na etapie budowy planu.

## Alternatywy zmniejszające narzut

- **Wbudowane funkcje `pyspark.sql.functions` / Spark SQL** — zawsze pierwszy wybór, jeśli istnieje odpowiednik (`when`, `regexp_extract`, `array_contains` itd.) — w pełni zoptymalizowane przez Catalyst/Tungsten.
- **Pandas UDF (vectorized UDF)** — w PySpark, zamiast operować wiersz po wierszu, operują na całych **batchach danych jako obiektach Pandas (Apache Arrow)**. Dzięki Apache Arrow dane przesyłane są między JVM a Pythonem w formacie kolumnowym, zserializowane/zdeserializowane zbiorczo (batch), a logika wewnątrz może korzystać z wektoryzowanych operacji NumPy/Pandas — znacząco mniejszy narzut niż klasyczny UDF wiersz-po-wierszu.

  ```python
  import pandas as pd
  from pyspark.sql.functions import pandas_udf

  @pandas_udf("string")
  def classify_pandas(age: pd.Series) -> pd.Series:
      return (age >= 18).map({True: "adult", False: "minor"})

  df.withColumn("category", classify_pandas(df.age)).show()
  ```

- **Natywna kompozycja wbudowanych funkcji zamiast UDF** — często to, co "wymaga" UDF, da się wyrazić kombinacją `when`/`otherwise`, wyrażeń SQL czy funkcji wyższego rzędu na kolumnach typu array/map (`transform`, `filter`, `aggregate` w Spark SQL) — to pozostaje w pełni zoptymalizowanej ścieżce.

## Podsumowanie

UDF to narzędzie ostatniej deski ratunku — daje elastyczność, ale kosztem utraty większości optymalizacji Catalyst/Tungsten. Zasada: najpierw szukaj wbudowanej funkcji, potem rozważ Pandas UDF (jeśli PySpark), a klasyczny skalarny UDF stosuj tylko wtedy, gdy logika naprawdę nie daje się wyrazić inaczej.
