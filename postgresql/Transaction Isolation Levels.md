# Transaction Isolation Levels w PostgreSQL

Poziom izolacji określa, jak bardzo transakcja jest odizolowana od zmian robionych
równolegle przez inne transakcje. Im wyższy poziom izolacji, tym mniej anomalii
(niespójności odczytu), ale też więcej konfliktów kończących się błędem
`could not serialize access` i koniecznością retry po stronie aplikacji.

Standard SQL definiuje 4 poziomy: `READ UNCOMMITTED`, `READ COMMITTED`,
`REPEATABLE READ`, `SERIALIZABLE`. PostgreSQL implementuje je wszystkie, ale
**tylko 3 są realnie różne** - `READ UNCOMMITTED` w Postgresie zachowuje się
dokładnie jak `READ COMMITTED`, bo silnik w ogóle nie pozwala czytać
niezacommitowanych danych innej transakcji (dirty read jest niemożliwy
niezależnie od poziomu izolacji, dzięki MVCC).

## Anomalie, które poziomy izolacji mają rozwiązywać

| Anomalia                               | Opis                                                                                                                                                                                                                                                                                                     |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dirty read**                         | Czytasz dane, które inna transakcja zapisała, ale jeszcze nie zacommitowała (i może zrobić rollback).                                                                                                                                                                                                    |
| **Non-repeatable read**                | W ramach jednej transakcji dwa razy czytasz ten sam wiersz i dostajesz różne wartości, bo ktoś inny go w międzyczasie zmienił i zacommitował.                                                                                                                                                            |
| **Phantom read**                       | W ramach jednej transakcji dwa razy wykonujesz to samo zapytanie zakresowe (`WHERE`) i za drugim razem pojawiają się/znikają wiersze, bo ktoś inny je wstawił/usunął i zacommitował.                                                                                                                     |
| **Lost update**                        | Dwie transakcje czytają tę samą wartość, każda liczy nową wartość na jej podstawie i zapisuje - jedna z modyfikacji "znika", bo została nadpisana.                                                                                                                                                       |
| **Serialization anomaly (write skew)** | Dwie transakcje niezależnie czytają różne, ale powiązane wiersze, i na tej podstawie modyfikują *inne* wiersze tak, że wynik końcowy narusza niezmiennik, który każda z osobna próbowała chronić. Nie da się tego złapać przez zwykły lock na wierszu, bo transakcje nie modyfikują tych samych wierszy. |

## Tabela: standard SQL vs rzeczywiste zachowanie PostgreSQL

| Poziom                                             | Dirty read | Non-repeatable read | Phantom read   | Serialization anomaly |
| -------------------------------------------------- | ---------- | ------------------- | -------------- | --------------------- |
| Read Uncommitted (standard)                        | możliwy    | możliwy             | możliwy        | możliwy               |
| **Read Uncommitted (Postgres)**                    | niemożliwy | możliwy             | możliwy        | możliwy               |
| Read Committed (standard i Postgres, **domyślny**) | niemożliwy | możliwy             | możliwy        | możliwy               |
| Repeatable Read (standard)                         | niemożliwy | niemożliwy          | możliwy        | możliwy               |
| **Repeatable Read (Postgres)**                     | niemożliwy | niemożliwy          | **niemożliwy** | możliwy (write skew)  |
| Serializable (standard i Postgres)                 | niemożliwy | niemożliwy          | niemożliwy     | niemożliwy            |

PostgreSQL jest tu **ostrzejszy niż wymaga standard**: `REPEATABLE READ` w
Postgresie eliminuje też phantom read, bo implementacja opiera się na
snapshot isolation - cała transakcja widzi jeden, stały snapshot bazy zrobiony
w momencie pierwszego zapytania, więc zarówno "ten sam wiersz", jak i "ten sam
zakres" wyglądają identycznie przy każdym odczycie w ramach transakcji.

## Jak działa to pod spodem (bardzo skrótowo)

- **Read Committed** (domyślny w Postgresie): każde pojedyncze *zapytanie* w
  transakcji dostaje świeży snapshot bazy z momentu jego startu. Stąd
  non-repeatable/phantom read - kolejne zapytanie w tej samej transakcji może
  zobaczyć zmiany zacommitowane między nimi.
- **Repeatable Read**: cała *transakcja* dostaje jeden snapshot zrobiony przy
  pierwszym zapytaniu (`SELECT`/`INSERT`/`UPDATE`/...) i widzi bazę tak, jakby
  nic więcej się nie działo, aż do commitu. Jeśli transakcja próbuje
  zmodyfikować wiersz, który równolegle zmieniła i zacommitowała inna
  transakcja - Postgres nie cichcem nadpisuje, tylko zwraca błąd
  `ERROR: could not serialize access due to concurrent update` (chroni przed
  lost update na tym samym wierszu).
- **Serializable**: to co Repeatable Read (snapshot isolation) plus dodatkowy
  mechanizm **SSI (Serializable Snapshot Isolation)**, który śledzi zależności
  odczyt-zapis między transakcjami i wykrywa układy, które *nie mogłyby*
  wystąpić, gdyby transakcje wykonały się jedna po drugiej (szeregowo). Gdy
  wykryje taki układ, przerywa jedną z transakcji błędem
  `ERROR: could not serialize access due to read/write dependencies among
  transactions`. To jedyny poziom chroniący przed write skew.

Wniosek praktyczny: przy `REPEATABLE READ` i `SERIALIZABLE` aplikacja **musi**
umieć złapać błąd serializacji i zrobić retry całej transakcji - to nie jest
sytuacja wyjątkowa, tylko normalny element działania tych poziomów.

## Ustawianie poziomu izolacji

```sql
-- per transakcja
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
...
COMMIT;

-- albo skrót
BEGIN ISOLATION LEVEL SERIALIZABLE;
...
COMMIT;

-- domyślny poziom dla sesji/bazy
SET default_transaction_isolation = 'read committed';
```

## Kiedy używać czego

- **Read Committed** - domyślny, wystarcza w zdecydowanej większości
  przypadków (proste CRUD-y, gdzie każde zapytanie ma sens osobno). Trzeba
  uważać na wzorzec "read-modify-write" (np. `SELECT` salda, policz nową
  wartość w aplikacji, `UPDATE`) - to jest podatne na lost update. Rozwiązanie
  bez zmiany poziomu izolacji: `UPDATE accounts SET balance = balance - 10
  WHERE id = 1` (atomowo w jednym statemencie) albo `SELECT ... FOR UPDATE`.
- **Repeatable Read** - gdy transakcja robi kilka odczytów, które muszą być
  spójne ze sobą (np. raport liczący sumy z kilku zapytań) i/albo
  read-modify-write na wielu wierszach, a chcesz mieć gwarancję, że ktoś ci
  nie nadepnie na te same wiersze bez błędu.
- **Serializable** - gdy niezmiennik biznesowy rozciąga się na *wiele
  wierszy* powiązanych logicznie, ale nie tym samym wierszem (klasyczny
  przykład: "przynajmniej jeden lekarz na dyżurze", limity/budżety liczone
  z wielu rekordów). To najdroższy poziom (narzut na śledzenie zależności,
  więcej abortów wymagających retry), więc stosuje się go tam, gdzie
  faktycznie chroni realny niezmiennik, nie wszędzie "na zapas".

## Demonstracja w Dockerze

Pliki demonstracji: `isolation-levels-demo/docker-compose.yml`,
`isolation-levels-demo/init.sql` (obok tego pliku).

```bash
cd isolation-levels-demo
docker compose up -d
```

Albo bez compose, samym `docker run` + ręczne stworzenie tabel z `init.sql`:

```bash
docker run --name pg-isolation-demo \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=isolation_demo \
  -p 5432:5432 -d postgres:16

docker cp isolation-levels-demo/init.sql pg-isolation-demo:/init.sql
docker exec -it pg-isolation-demo psql -U postgres -d isolation_demo -f /init.sql
```

Do każdej z poniższych demonstracji otwórz **dwa terminale** i w obu wejdź do
`psql`:

```bash
docker exec -it pg-isolation-demo psql -U postgres -d isolation_demo
```

Poniżej `A>` i `B>` oznaczają komendy wpisywane w, odpowiednio, pierwszej
i drugiej sesji `psql` - w kolejności, w jakiej trzeba je wykonać.

### 1. Non-repeatable read (Read Committed vs Repeatable Read)

Rozwiązuje ją poziom `REPEATABLE READ`.

```sql
-- READ COMMITTED (domyślny) - problem WYSTĘPUJE
A> BEGIN;
A> SELECT balance FROM accounts WHERE id = 1;        -- 100

B> UPDATE accounts SET balance = 200 WHERE id = 1;
B> COMMIT;

A> SELECT balance FROM accounts WHERE id = 1;        -- 200 !! zmieniło się w tej samej transakcji
A> COMMIT;
```

```sql
-- REPEATABLE READ - problem ZNIKA
A> BEGIN ISOLATION LEVEL REPEATABLE READ;
A> SELECT balance FROM accounts WHERE id = 1;        -- 100

B> UPDATE accounts SET balance = 999 WHERE id = 1;
B> COMMIT;

A> SELECT balance FROM accounts WHERE id = 1;        -- nadal 100, snapshot sprzed transakcji A
A> COMMIT;
A> SELECT balance FROM accounts WHERE id = 1;        -- dopiero teraz 999
```

### 2. Phantom read (Read Committed vs Repeatable Read)

W standardzie SQL rozwiązuje ją dopiero `SERIALIZABLE`, ale w PostgreSQL
wystarczy `REPEATABLE READ` (patrz tabela wyżej).

```sql
-- READ COMMITTED - problem WYSTĘPUJE
A> BEGIN;
A> SELECT count(*) FROM accounts WHERE balance > 50;  -- 1 (tylko alice)

B> INSERT INTO accounts VALUES (4, 'dave', 500);
B> COMMIT;

A> SELECT count(*) FROM accounts WHERE balance > 50;  -- 2 !! nowy wiersz "wyfantomował się"
A> COMMIT;
```

```sql
-- REPEATABLE READ - problem ZNIKA
A> BEGIN ISOLATION LEVEL REPEATABLE READ;
A> SELECT count(*) FROM accounts WHERE balance > 50;  -- 1

B> INSERT INTO accounts VALUES (5, 'erin', 500);
B> COMMIT;

A> SELECT count(*) FROM accounts WHERE balance > 50;  -- nadal 1
A> COMMIT;
```

(Pamiętaj posprzątać dodane wiersze przed kolejnymi demo: `DELETE FROM
accounts WHERE id IN (4,5);`)

### 3. Lost update (Read Committed vs Repeatable Read)

Rozwiązuje ją `REPEATABLE READ` (i `SERIALIZABLE`) - nie milcząco, tylko przez
jawny błąd, który wymusza retry.

```sql
-- READ COMMITTED - update "wygrywa" cicho, ale liczony na bazie już nieaktualnych danych
A> BEGIN;
A> SELECT balance FROM accounts WHERE id = 2;         -- 50

B> UPDATE accounts SET balance = balance - 10 WHERE id = 2;
B> COMMIT;                                             -- saldo teraz 40

A> UPDATE accounts SET balance = balance - 10 WHERE id = 2;  -- wykona się bez błędu
A> COMMIT;                                             -- saldo 30, ALE liczone z perspektywy "50",
                                                        -- nie z "40" - odjęcie B zostało zignorowane
```

```sql
-- REPEATABLE READ - Postgres wykrywa konflikt i odmawia
A> BEGIN ISOLATION LEVEL REPEATABLE READ;
A> SELECT balance FROM accounts WHERE id = 3;         -- 30

B> UPDATE accounts SET balance = balance - 10 WHERE id = 3;
B> COMMIT;

A> UPDATE accounts SET balance = balance - 10 WHERE id = 3;
-- ERROR: could not serialize access due to concurrent update
A> ROLLBACK;                                           -- aplikacja musi zrobić retry całej transakcji
```

### 4. Write skew / serialization anomaly (Repeatable Read vs Serializable)

To jedyna anomalia, którą rozwiązuje wyłącznie `SERIALIZABLE`. Niezmiennik
biznesowy: **przynajmniej jeden lekarz musi być on-call**. Obie transakcje
z osobna sprawdzają warunek poprawnie, ale razem go łamią, bo modyfikują
różne wiersze.

```sql
-- Reset danych przed demo
-- UPDATE doctors SET on_call = true;

-- REPEATABLE READ - anomalia WYSTĘPUJE
A> BEGIN ISOLATION LEVEL REPEATABLE READ;
A> SELECT count(*) FROM doctors WHERE on_call;   -- 2, więc Alice może zejść z dyżuru
A> UPDATE doctors SET on_call = false WHERE name = 'Alice';

B> BEGIN ISOLATION LEVEL REPEATABLE READ;
B> SELECT count(*) FROM doctors WHERE on_call;   -- też widzi 2 (snapshot sprzed A), więc Bob też może zejść
B> UPDATE doctors SET on_call = false WHERE name = 'Bob';

A> COMMIT;                                        -- przechodzi
B> COMMIT;                                        -- też przechodzi!

-- SELECT * FROM doctors;  -- obaj on_call = false -> niezmiennik złamany, nikt nie dyżuruje
```

```sql
-- Reset: UPDATE doctors SET on_call = true;

-- SERIALIZABLE - anomalia ZOSTAJE ZŁAPANA
A> BEGIN ISOLATION LEVEL SERIALIZABLE;
A> SELECT count(*) FROM doctors WHERE on_call;   -- 2
A> UPDATE doctors SET on_call = false WHERE name = 'Alice';

B> BEGIN ISOLATION LEVEL SERIALIZABLE;
B> SELECT count(*) FROM doctors WHERE on_call;   -- 2
B> UPDATE doctors SET on_call = false WHERE name = 'Bob';

A> COMMIT;                                        -- przechodzi jako pierwsza
B> COMMIT;
-- ERROR: could not serialize access due to read/write dependencies among transactions
-- B musi zrobić ROLLBACK i retry - przy retry zobaczy Alice już offline i sam się nie wyloguje
```

## Podsumowanie: który poziom rozwiązuje jaki problem

| Problem | Minimalny poziom w Postgresie, który go rozwiązuje |
|---|---|
| Dirty read | dowolny (zawsze niemożliwy dzięki MVCC) |
| Non-repeatable read | Repeatable Read |
| Phantom read | Repeatable Read (w Postgresie, nie w standardzie SQL) |
| Lost update | Repeatable Read (zamienia cichy błąd logiczny na jawny błąd serializacji) |
| Write skew / serialization anomaly | Serializable |

Koszt: każdy krok w górę = mniej anomalii, ale więcej `ERROR: could not
serialize access...` i konieczność implementacji retry w aplikacji. W
praktyce dla Repeatable Read/Serializable retry robi się jako pętla łapiąca
kody błędów SQLSTATE `40001` (serialization_failure) i `40P01`
(deadlock_detected).
