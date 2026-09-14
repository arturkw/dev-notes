# Czym jest Tungsten?

## Definicja

**Project Tungsten** to inicjatywa (zestaw zmian w silniku wykonawczym Sparka), której celem jest maksymalne wykorzystanie sprzętu (CPU i pamięci) przez ograniczenie narzutu JVM oraz Javy przy przetwarzaniu danych. Tungsten dotyczy przede wszystkim warstwy fizycznego wykonania zapytań DataFrame/DataSet/Spark SQL (współpracuje z Catalyst Optimizerem, który generuje plan, a Tungsten go efektywnie wykonuje).

Motywacja: w typowych obciążeniach Sparka wąskim gardłem przestał być I/O (sieć/dysk), a stał się **CPU i narzut zarządzania pamięcią/obiektami przez JVM** — Tungsten adresuje właśnie to.

## Główne filary Tungsten

### 1. Zarządzanie pamięcią poza stertą (off-heap) i binarny format danych

Zamiast trzymać dane jako obiekty Java (np. `Row` jako obiekt z polami, boxing typów prymitywnych, narzut nagłówków obiektów, wskaźników), Tungsten wprowadza własny **binarny format wierszy** (`UnsafeRow`) operujący bezpośrednio na tablicach bajtów, zarządzany ręcznie (poprzez `sun.misc.Unsafe` / off-heap memory).

Korzyści:
- Brak narzutu na nagłówki obiektów Java i boxing/unboxing typów prymitywnych.
- Mniejsze zużycie pamięci (compact binary encoding zamiast grafu obiektów).
- Możliwość operowania na danych bez pełnej deserializacji do obiektów Java (np. porównywanie kluczy bezpośrednio na bajtach).
- Ominięcie narzutu **Garbage Collectora** — mniej obiektów na stercie = mniej pracy dla GC, co przy dużych zbiorach danych i długo działających aplikacjach potrafi być głównym wąskim gardłem.

### 2. Cache-aware computation (algorithms i struktury danych świadome hierarchii pamięci CPU)

Tungsten projektuje struktury danych i algorytmy (np. sortowanie) tak, aby maksymalizować trafienia w cache L1/L2/L3 procesora — np. sortowanie wskaźników do rekordów w sposób przyjazny dla cache'a (zamiast losowego dostępu do rozproszonych obiektów w pamięci), co znacząco przyspiesza operacje typu `sort`, `join`, `aggregate`.

### 3. Whole-Stage Code Generation (whole-stage codegen)

Zamiast interpretować plan zapytania operator-po-operatorze (klasyczny model iteratorowy "Volcano", gdzie każdy operator wywołuje `next()` na kolejnym, z narzutem wywołań wirtualnych), Tungsten **generuje na bieżąco kod Java bajtowy** dla całego fragmentu planu (stage'a) i kompiluje go w locie (JIT). Efekt:
- eliminacja narzutu wywołań wirtualnych między operatorami,
- eliminacja alokacji obiektów pośrednich między operatorami w ramach stage'a,
- kod działa niemal tak szybko, jakby był ręcznie napisaną, zoptymalizowaną pętlą.

To jedna z największych pojedynczych optymalizacji wydajności wprowadzonych w Sparku (Spark 2.0), często dająca kilkukrotne przyspieszenie zapytań SQL/DataFrame.

## Tungsten a RDD

Te optymalizacje dotyczą głównie DataFrame/DataSet/Spark SQL, ponieważ wymagają znajomości schematu danych (typów kolumn) — Catalyst zna schemat i może wygenerować efektywny kod operujący na konkretnym layoucie binarnym. Surowe RDD (`RDD[T]` z dowolnymi obiektami Java/Scala) nie mają takiej informacji o strukturze z wyprzedzeniem, więc nie mogą w pełni korzystać z Tungsten — to jeden z głównych powodów, dla których DataFrame/DataSet są znacznie wydajniejsze niż RDD przy porównywalnych operacjach.

## Podsumowanie (na rozmowę kwalifikacyjną)

> Tungsten to warstwa silnika Sparka odpowiedzialna za efektywne fizyczne wykonanie zapytań — zarządza pamięcią off-heap w binarnym formacie (`UnsafeRow`) zamiast obiektów Java, projektuje struktury danych świadome cache'u CPU oraz generuje w locie skompilowany kod (whole-stage codegen) dla całych fragmentów planu zapytania, eliminując narzut interpretacji operator-po-operatorze i pracy Garbage Collectora. Działa w parze z Catalyst Optimizerem i jest głównym powodem, dla którego DataFrame/DataSet są szybsze niż surowe RDD.
