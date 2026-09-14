# Czym jest DataSet encoder, serializacja / deserializacja w DS, a kwestie wydajności

## Problem, który rozwiązuje Encoder

`Dataset[T]` to silnie typowana kolekcja obiektów JVM (np. case class w Scali), ale wewnętrznie Spark SQL przechowuje i przetwarza dane w swoim własnym, zwartym **binarnym formacie wierszy** zarządzanym przez Tungsten (poza stertą JVM, bez narzutu obiektowego Javy). Potrzebny jest więc mechanizm tłumaczący między:

- obiektem JVM typu `T` (np. `case class Person(name: String, age: Int)`), a
- wewnętrzną binarną reprezentacją Tungsten (`InternalRow`).

Tym mechanizmem jest **Encoder[T]**.

## Czym jest Encoder

`Encoder[T]` to komponent Spark SQL odpowiedzialny za **serializację i deserializację** obiektów JVM do/z wewnętrznego formatu binarnego Sparka, ale — w odróżnieniu od standardowej serializacji Java/Kryo — robi to w sposób **świadomy schematu i zoptymalizowany przez code generation**:

- Zna dokładny schemat typu `T` (nazwy i typy pól), więc generuje **dedykowany, wyspecjalizowany kod bajtowy** (bytecode) do konwersji obiekt ↔ binarny wiersz, zamiast korzystać z generycznej, refleksyjnej serializacji.
- Pozwala Sparkowi operować na danych **bez deserializacji do pełnych obiektów JVM** tam, gdzie to możliwe (np. filtrowanie po polu może działać bezpośrednio na formacie binarnym) — to kluczowa różnica względem RDD, gdzie każda operacja wymaga pełnego obiektu.
- Umożliwia Tungsten zarządzanie pamięcią off-heap w zwartym layout (bez narzutu nagłówków obiektów Javy, boxing itd.).

### Rodzaje encoderów

- **Encodery wbudowane** — generowane automatycznie przez Sparka dla typów prymitywnych, case classes (Scala) i JavaBeans (Java) poprzez `import spark.implicits._` (Scala) lub `Encoders.bean(Class)` (Java).
- **Encoder Kryo/Java** (`Encoders.kryo[T]`, `Encoders.javaSerialization[T]`) — generyczny fallback dla dowolnego typu (np. `Map[String, Any]`), gdy Spark nie potrafi automatycznie wygenerować wyspecjalizowanego encodera. Traktuje cały obiekt jako jedno zserializowane binarne pole (`binary` w schemacie) — **traci strukturę kolumnową**, więc Catalyst nie może optymalizować operacji na jego wnętrzu.

```scala
case class Person(name: String, age: Long)

import spark.implicits._                 // dostarcza encodery dla case classes i typów prostych
val ds: Dataset[Person] = Seq(Person("Andy", 32)).toDS()

// Java: Encoder trzeba podać jawnie
Encoder<Person> personEncoder = Encoders.bean(Person.class);
Dataset<Person> javaBeanDS = spark.createDataset(list, personEncoder);

// generyczny fallback dla typu bez wbudowanego encodera
implicit val mapEncoder: Encoder[Map[String, Any]] =
  org.apache.spark.sql.Encoders.kryo[Map[String, Any]]
```

## Serializacja/deserializacja a wydajność

- **Operacje kolumnowe** (`select`, `filter($"age" > 18)`, wyrażenia SQL) — Catalyst operuje bezpośrednio na planie logicznym/binarnym formacie, **bez pełnej deserializacji do obiektu `T`**. To jest szybka ścieżka, tak samo szybka jak w DataFrame.
- **Operacje funkcyjne** (`map(obj => ...)`, `filter(obj => ...)`, `mapPartitions`) — wymagają dla każdego rekordu:
  1. deserializacji z formatu binarnego Tungsten do pełnego obiektu JVM (`T`),
  2. wykonania funkcji lambda na tym obiekcie,
  3. ponownej serializacji wyniku do formatu binarnego.

  Ten cykl deserializacja → lambda → serializacja jest kosztowny — dla optymalizatora Catalyst lambda jest "czarną skrzynką" (podobnie jak UDF), więc traci się część optymalizacji dostępnych dla czysto kolumnowych operacji.

- **Porównanie z RDD**: mimo tego narzutu, DataSet i tak zwykle wygrywa z RDD, bo:
  - encoder generuje wyspecjalizowany bytecode (zamiast generycznej refleksyjnej serializacji Java/Kryo używanej w RDD),
  - format binarny jest bardziej zwarty pamięciowo (off-heap, brak narzutu obiektów Javy),
  - Catalyst wciąż optymalizuje te fragmenty planu, które są czysto kolumnowe (np. filtr przed operacją `map`).

## Praktyczne wnioski dotyczące wydajności

- Preferuj operacje kolumnowe (wyrażenia typu `$"col"`, `select`, wbudowane funkcje SQL) zamiast `map`/`filter` z lambdami operującymi na całym obiekcie — zwłaszcza w gorących ścieżkach przetwarzania dużych wolumenów danych.
- Jeśli musisz użyć `map`/`mapPartitions`, rozważ operowanie na `mapPartitions` zamiast `map`, żeby zamortyzować koszt inicjalizacji (np. połączeń, zasobów) na partycję zamiast na rekord.
- Unikaj typów wymagających fallbacku na `Encoders.kryo`/`Encoders.java` w gorących ścieżkach — tracisz wtedy strukturę kolumnową i możliwość optymalizacji przez Catalyst (cała kolumna staje się nieprzezroczystym `binary`).
- Jeśli wydajność jest krytyczna, a nie potrzebujesz bezpieczeństwa typów w compile-time, DataFrame z czysto kolumnowym API bywa prostszą i równie szybką alternatywą.
