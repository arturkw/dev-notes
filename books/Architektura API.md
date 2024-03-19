## Wprowadzenie

**Tworzenie architektury można porównać do drogi bez celu - zmiany (postęp) w technologii i nowe wymagania biznesowe uniemożliwiają wymuszają zmiany w architekturze (ewolucyjna architektura). `API-First` to podejście w którym programiści i architekci projektują API zorientowane na potrzeby klienta.**

## Rozdział 1: Opracowywanie, budowanie i określanie API
### Model dojrzałości Richardsona
Każdy kolejny poziom reprezentuje wyższy stopień dojrzałości i zgodności z ideą `REST`: 
1. Poziom 0: jedno URI, endpoint reaguje na poszczególne komendy opisane w ciele requestu
2. Poziom 1: API zorganizowane wokół zasobów ale bez wykorzystania metod HTTP
3. Poziom 2: Czasowniki HTTP (GET, POST, PUT, DELETE,..) wykorzystane do operacji na zasobach, użyto kodów stanów HTTP 
4. Poziom 3: Użycie Hipermediów **HATEOAS**

Używaj `REST` do komunikacji północ-południe i `gRPC` do komunikacji wschód-zachód.
Dobre `REST API` pozwala na:
 - stronicowanie kolekcji
 - filtrowanie kolekcji
 - obsługa błędów
 - jest dostarczona specyfikacja (np `OpenAPI`)
 - wersjonowanie API


**Terminy do wyjaśnienia:**

**1. API North-South vs East-West**

**2. Ruch North-South kontrolowany jest przez API-Gateway**

**3. Ruch East-West kontrolowany jest przez service mesh**

**4. Diagramy typu C4**

**5. Dokumenty ADR**