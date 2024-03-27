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

## Bezpieczeństwo operacyjne - model zagrożeń dla API
- błędem jest skupianie się przez architektów i programistów wyłącznie na dostarczaniu wartości biznesowej w pierwszym etapie pracy nad projektem i zostawianie problemów związanych z bezpieczeństwem aż do zakończenia prac: ostatecznie zwiększa to koszty. 
- podstawą do oceny zagrożeń może być `OWASP API Security Top 10` https://owasp.org/www-project-api-security/ 
- średni koszt włamania do firmy notowanej na giełdzie wyniósł **116.000.000$**
- **modelowanie zagrożeń** to technika pomagająca w identyfikowaniu zagrożeń, ataków, luk w zabezpieczeniach oraz innych środków, które mogą mieć wpływ na aplikację
- **Diagramy przepływu danych** (data flow diagrams, DFD) ułatwia sprawdzenie jak dane przepływają przez system
### Modelowanie zagrożeń
1. Określ cele: cele dotyczące bezpieczeństwa są często celami biznesowymi np: *uniknij wycieku danych i kary związanej z RODO.*
2. Zbierz informacje i rozłóż system na czynniki: stwórz diagram przepływu danych 
3. Określ zagrożenia np przy użyciu metody **STRIDE**
4. Oceń ryzyko związane z zagrożeniami - możesz użyć metody **DREAD**
5. Przeprowadź weryfikację - czy cele związane z bezpieczeństwem zostały zapewnione?
### Metoda STRIDE
1. Spoofing - podszywanie się pod użytkownika
2. Tampering - modyfikowanie danych użytkownika
3. Repudiation - niezaufany użytkownik przeprowadzający niedozwoloną operację
4. Information disclosure - ujawnienie informacji, np odczytanie pliku do którego użytkownik nie powinien mieć dostępu
5. Denial of Service - tymczasowa niedostępność systemu spowodowana jego celowym przeciążeniem
6. Elevation of privilege - podniesienie uprawnień
### Metoda DREAD
1. Damage - jak niszczycielski jest atak
2. Reproducibility - czy atak jest łatwy do odtworzenia
3. Exploitability - jak łatwo można przygotować zakończony sukcesem atak
4. Affected Users - jak duża jest potencjalna grupa ofiar ataku
5. Discoverability - jakie jest prawdopodobieństwo odkrycia danego zagrożenia








**Terminy do wyjaśnienia:**

1. API North-South vs East-West
2. Ruch North-South kontrolowany jest przez API-Gateway
3. Ruch East-West kontrolowany jest przez service mesh
4. Diagramy typu C4
5. Dokumenty ADR
6. Proxy vs Reverse-Proxy
7. 



