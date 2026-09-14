# Jakie są kwestie związane z wydajnością DataSet?

To pytanie zazwyczaj pada jako rozwinięcie tematu [RDD vs DataFrame vs DataSet](rdd-vs-dataframe-vs-dataset.md) oraz [DataSet encoder](dataset-encoder-serializacja.md) — poniżej zebrane w jednym miejscu główne czynniki wpływające na wydajność pracy z DataSet.

## 1. Operacje kolumnowe vs funkcyjne (lambdy)

Największy czynnik wydajnościowy w praktyce:

- **Operacje kolumnowe** (`select`, `filter($"col" > x)`, wyrażenia SQL, wbudowane funkcje) — w pełni optymalizowane przez Catalyst (predicate pushdown, column pruning, constant folding) i kompilowane do zoptymalizowanego kodu przez Tungsten (whole-stage code generation). Dane nie muszą być deserializowane do obiektów JVM.
- **Operacje typu `map`/`filter`/`flatMap` z lambdą operującą na obiekcie `T`** — wymuszają deserializację z formatu binarnego Tungsten do pełnego obiektu JVM, wykonanie funkcji, ponowną serializację. Catalyst traktuje taką lambdę jak czarną skrzynkę — nie może np. przesunąć jej przed/za inną operację ani ocenić, których kolumn faktycznie dotyczy.

**Wniosek**: nadużywanie API funkcyjnego na DataSet (typowy nawyk programistów przyzwyczajonych do RDD) potrafi zniwelować większość przewagi wydajnościowej DataSet nad RDD.

## 2. Koszt encoderów dla nietypowych typów

- Dla typów prymitywnych i case classes / JavaBeans Spark generuje wyspecjalizowane, szybkie encodery (code-gen).
- Dla typów złożonych bez wbudowanego wsparcia (np. generyczne kolekcje, `Any`) trzeba użyć `Encoders.kryo`/`Encoders.javaSerialization` — to fallback generyczny, wolniejszy, i co ważne: cała wartość trafia do schematu jako nieprzezroczyste pole binarne, więc Catalyst nie widzi jej struktury i nie może jej optymalizować (np. filtrować po pojedynczym polu bez pełnej deserializacji).

## 3. Ograniczenie do Scala/Java

- DataSet nie istnieje w PySpark/R. W PySpark DataFrame pełni tę samą rolę operacyjnie (bez silnego typowania), więc pytanie o wydajność DataSet dotyczy praktycznie tylko ekosystemu JVM (Scala/Java) — kod Scala/Java operujący funkcyjnie na DataSet ma taki sam narzut serializacji jak analogiczny kod Pythonowy operujący przez UDF, tylko bez dodatkowego kosztu przekraczania granicy JVM ↔ proces Pythona.

## 4. Porównanie z DataFrame przy tych samych operacjach

Gdy DataSet jest używany wyłącznie operacjami kolumnowymi (bez `map`/lambdy na obiektach), jego wydajność jest **identyczna** jak DataFrame — bo pod spodem to ten sam plan wykonania Catalyst/Tungsten. Różnica ujawnia się dopiero przy mieszaniu stylu funkcyjnego z kolumnowym.

## 5. Praktyczne rekomendacje

- Maksymalizuj użycie wyrażeń kolumnowych; sięgaj po `map`/`mapPartitions` tylko tam, gdzie logika biznesowa naprawdę tego wymaga (np. złożona logika obiektowa niewyrażalna prostym wyrażeniem SQL).
- Gdy musisz użyć operacji funkcyjnej, preferuj `mapPartitions` nad `map`, żeby zamortyzować koszt inicjalizacji zasobów (np. połączeń do zewnętrznych systemów) na partycję, a nie na każdy rekord.
- Unikaj typów wymagających `Encoders.kryo` w danych o dużym wolumenie/na gorącej ścieżce — jeśli to możliwe, spłaszcz strukturę danych do typów wspieranych natywnie (case class, typy proste, kolekcje typów prostych).
- Jeśli wydajność jest priorytetem, a bezpieczeństwo typów w compile-time nie jest krytyczne, rozważ pozostanie przy czystym DataFrame — mniej pokus, by nieświadomie wypaść z zoptymalizowanej ścieżki kolumnowej.
- Monitoruj plan fizyczny (`.explain()`) — obecność węzłów `DeserializeToObject`/`SerializeFromObject` w planie to sygnał, że w danym miejscu następuje kosztowne przejście obiekt ↔ format binarny.
