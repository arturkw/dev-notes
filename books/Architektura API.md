## Wprowadzenie

**Tworzenie architektury można porównać do drogi bez celu - zmiany (postęp) w technologii i nowe wymagania biznesowe uniemożliwiają wymuszają zmiany w architekturze (ewolucyjna architektura). `API-First` to podejście w którym programiści i architekci projektują API zorientowane na potrzeby klienta.**

## Opracowywanie, budowanie i określanie API
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

## Testowanie API
1. Testy jednostkowe stanowią podstawę piramidy testów.
2. Testowanie kontraktu może pomóc w opracowaniu spójnego API i przetestowaniu jego współdziałania z innymi API
3. Używaj testów E2E do odtwarzania podstawowych sposobów używania API przez użytkowników.

## API Gateway
### Dlaczego warto używać API Gateway
1. Wspólna fasada łącząca API pochodzących z różnych aplikacji
2. Uproszczenie sposobu użycia API przez agregację i tłumaczenie usług backednu
3. Ochrona API przed nadużyciami (szyfrowanie, uwierzytelnianie i autoryzacja, lista dozwolonych IP, throttling)
4. Monitorowanie (czas odpowiedzi, jakie API wywoływano, błędne requesty)
5. Translacja protokołów

## Infrastruktura typu service mesh
Service mesh to infrastruktura służąca do zarządzania komunikacją pomiędzy usługami (komunikacja wschód-zachód) w ramach rozproszonego systemu oprogramowania. Service mesh zapewnia obsługę zadań takich jak weryfikacja użytkownika, monitoring, ograniczenie liczby żądań, zdefiniowanie przekroczenia czasu oczekiwania oraz liczby powtórzeń. 

## Release API
Używaj `feature flag` ale nie tak jak tutaj: [[https://blog.statsig.com/how-to-lose-half-a-billion-dollars-with-bad-feature-flags-ccebb26adeec]]
Monitorowanie (logi, event tracing) jest przydatne w procesie releasu - można wykryć błędy :) To wszystko zostało opisane w tym rozdziale na przestrzeni "zaledwie" 20 stron :) 






**Terminy do wyjaśnienia:**

1. API North-South vs East-West
2. Ruch North-South kontrolowany jest przez API-Gateway
3. Ruch East-West kontrolowany jest przez service mesh
4. Diagramy typu C4
5. Dokumenty ADR
6. Proxy vs Reverse-Proxy
7. 



