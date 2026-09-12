# Apache Spark – Submitting Applications (streszczenie)

Źródło: [spark.apache.org/docs/latest/submitting-applications.html](https://spark.apache.org/docs/latest/submitting-applications.html)

Dokument opisuje skrypt `bin/spark-submit` – uniwersalne narzędzie do uruchamiania aplikacji Sparka na klastrze, niezależnie od menedżera klastra (Standalone, YARN, Kubernetes) i trybu wdrożenia.

## Spis treści

1. [Pakowanie zależności aplikacji](#1-pakowanie-zależności-aplikacji)
2. [Składnia i opcje spark-submit](#2-składnia-i-opcje-spark-submit)
3. [Adresy URL mastera](#3-adresy-url-mastera)
4. [Przykłady uruchamiania](#4-przykłady-uruchamiania)
5. [Ładowanie konfiguracji z pliku](#5-ładowanie-konfiguracji-z-pliku)
6. [Zaawansowane zarządzanie zależnościami](#6-zaawansowane-zarządzanie-zależnościami)
7. [Kluczowe zasady](#kluczowe-zasady)

---

## 1. Pakowanie zależności aplikacji

### Java/Scala

Należy zbudować **assembly jar** (tzw. "uber jar" / "fat jar") zawierający kod aplikacji wraz z jego zależnościami.

- **SBT** – wtyczka [sbt-assembly](https://github.com/sbt/sbt-assembly)
- **Maven** – [maven-shade-plugin](http://maven.apache.org/plugins/maven-shade-plugin/)

**Ważne**: Spark i Hadoop powinny być oznaczone jako zależności `provided` – nie trzeba ich pakować do jara, ponieważ dostarcza je menedżer klastra w czasie wykonania.

### Python

Do dystrybucji dodatkowych plików `.py`, `.zip` lub `.egg` służy opcja `--py-files`. Kilka plików Pythona najlepiej spakować do `.zip` lub `.egg`. Zależności zewnętrzne opisuje osobny przewodnik [Python Package Management](https://spark.apache.org/docs/latest/api/python/tutorial/python_packaging.html).

---

## 2. Składnia i opcje spark-submit

### Struktura polecenia

```bash
./bin/spark-submit \
  --class <główna-klasa> \
  --master <adres-mastera> \
  --deploy-mode <tryb-wdrożenia> \
  --conf <klucz>=<wartość> \
  ... # inne opcje
  <application-jar> \
  [argumenty-aplikacji]
```

### Najważniejsze opcje

| Opcja | Znaczenie | Przykład |
|---|---|---|
| `--class` | Punkt wejścia aplikacji (główna klasa) | `org.apache.spark.examples.SparkPi` |
| `--master` | Adres URL mastera klastra | `spark://23.195.26.187:7077`, `yarn` |
| `--deploy-mode` | `client` (domyślny) lub `cluster` | `client` / `cluster` |
| `--conf` | Dowolna właściwość konfiguracyjna Sparka w formacie `klucz=wartość`; w cudzysłowie, jeśli zawiera spacje; można podać wielokrotnie | `--conf spark.executor.memory=4g` |
| `application-jar` | Ścieżka do zbudowanego jara z aplikacją i zależnościami; musi być globalnie widoczna (`hdfs://` lub `file://` na wszystkich węzłach) | `/path/to/examples.jar` |
| `application-arguments` | Argumenty przekazywane do metody `main` | `100` |

### Tryby wdrożenia (`--deploy-mode`)

**client (domyślny)**
- Sterownik (driver) uruchamia się bezpośrednio w procesie `spark-submit`, jako klient klastra.
- Wejście/wyjście podłączone do konsoli.
- Dobry wybór dla: aplikacji typu REPL, maszyn bramowych współlokowanych z workerami, dewelopmentu lokalnego.

**cluster**
- Sterownik uruchamia się na jednym z węzłów roboczych (worker).
- Minimalizuje opóźnienia sieciowe między sterownikiem a executorami.
- Dobry wybór dla: aplikacji zgłaszanych ze zdalnej maszyny (np. laptopa).
- **Ograniczenie**: Spark Standalone nie wspiera trybu cluster dla aplikacji w Pythonie.

---

## 3. Adresy URL mastera

| Master URL | Znaczenie |
|---|---|
| `local` | Spark lokalnie, jeden wątek roboczy (brak równoległości) |
| `local[K]` | Spark lokalnie, K wątków roboczych (K = liczba rdzeni maszyny) |
| `local[K,F]` | Jak wyżej + F oznacza `spark.task.maxFailures` |
| `local[*]` | Spark lokalnie, tyle wątków, ile logicznych rdzeni |
| `local[*,F]` | Jak wyżej + parametr F (`maxFailures`) |
| `local-cluster[N,C,M]` | Tryb lokalnego klastra (tylko testy jednostkowe) – emuluje rozproszony klaster w jednej JVM: N workerów, C rdzeni/worker, M MiB pamięci/worker |
| `spark://HOST:PORT` | Klaster Standalone Sparka (domyślny port: 7077) |
| `spark://HOST1:PORT1,HOST2:PORT2` | Klaster Standalone z masterami zapasowymi (Zookeeper) – lista wszystkich hostów masterów |
| `yarn` | Klaster YARN (użyje `HADOOP_CONF_DIR` lub `YARN_CONF_DIR` do odnalezienia klastra) |
| `k8s://HOST:PORT` | Klaster Kubernetes (domyślnie TLS; `k8s://http://HOST:PORT` dla połączenia niezabezpieczonego) |

---

## 4. Przykłady uruchamiania

**Lokalnie, 8 rdzeni:**
```bash
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master "local[8]" \
  /path/to/examples.jar \
  100
```

**Klaster Standalone, tryb client:**
```bash
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master spark://207.184.161.138:7077 \
  --executor-memory 20G \
  --total-executor-cores 100 \
  /path/to/examples.jar \
  1000
```

**Klaster Standalone, tryb cluster z `--supervise`** (automatyczny restart drivera po awarii):
```bash
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master spark://207.184.161.138:7077 \
  --deploy-mode cluster \
  --supervise \
  --executor-memory 20G \
  --total-executor-cores 100 \
  /path/to/examples.jar \
  1000
```

**Klaster YARN:**
```bash
export HADOOP_CONF_DIR=XXX
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 20G \
  --num-executors 50 \
  /path/to/examples.jar \
  1000
```

**Aplikacja w Pythonie (Standalone):**
```bash
./bin/spark-submit \
  --master spark://207.184.161.138:7077 \
  examples/src/main/python/pi.py \
  1000
```

**Klaster Kubernetes:**
```bash
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master k8s://xx.yy.zz.ww:443 \
  --deploy-mode cluster \
  --executor-memory 20G \
  --num-executors 50 \
  http://path/to/examples.jar \
  1000
```

---

## 5. Ładowanie konfiguracji z pliku

- **Plik domyślny**: `conf/spark-defaults.conf` (w katalogu `SPARK_HOME`)
- **Plik niestandardowy**: parametr `--properties-file`

### Kolejność pierwszeństwa konfiguracji (od najwyższego)

1. Wartości ustawione bezpośrednio w kodzie na obiekcie `SparkConf`
2. Flagi przekazane do `spark-submit`
3. Wartości z pliku domyślnego

### Dodatkowe flagi

- `--properties-file` – wczytanie konfiguracji z niestandardowego pliku
- `--load-spark-defaults` – wymusza wczytanie również `conf/spark-defaults.conf`, nawet gdy podano `--properties-file` (przydatne przy łączeniu ustawień systemowych z ustawieniami użytkownika/klastra)
- `--verbose` – wypisuje szczegółowe informacje debugowe o źródłach konfiguracji

**Wygoda**: jeśli `spark.master` jest ustawione w pliku domyślnym, flagę `--master` można pominąć przy wywołaniu `spark-submit`.

---

## 6. Zaawansowane zarządzanie zależnościami

### Zależności JAR – `--jars`

```bash
./bin/spark-submit --jars jar1.jar,jar2.jar,...
```

- Jar aplikacji oraz jary podane w `--jars` są automatycznie przesyłane do klastra.
- Adresy URL rozdzielone przecinkami.
- Trafiają na classpath sterownika i executorów.
- **Uwaga**: `--jars` nie rozwija katalogów (nie zadziała ze ścieżką do folderu).

### Schematy URL dla dystrybucji jarów

| Schemat | Zachowanie |
|---|---|
| `file:` | Ścieżki bezwzględne / URI `file:/` obsługiwane przez serwer HTTP sterownika; każdy executor pobiera plik od drivera |
| `hdfs:`, `http:`, `https:`, `ftp:` | Pliki i jary pobierane bezpośrednio spod podanego URI |
| `local:` | URI `local:/` – plik ma istnieć lokalnie na każdym węźle roboczym; brak ruchu sieciowego; dobre dla dużych plików/jarów rozesłanych na każdy worker albo współdzielonych przez NFS/GlusterFS |

### Współrzędne Mavena – `--packages`

```bash
./bin/spark-submit --packages org.grupa:artefakt:wersja,org.grupa2:artefakt2:wersja
```

- Lista współrzędnych Mavena rozdzielona przecinkami.
- Wszystkie zależności tranzytywne są obsługiwane automatycznie.
- Działa zarówno z `pyspark`, `spark-shell`, jak i `spark-submit`.

### Dodatkowe repozytoria – `--repositories`

```bash
./bin/spark-submit --repositories https://repo.example.com,https://user:password@repo.secure.com
```

- Lista repozytoriów rozdzielona przecinkami.
- Dane logowania można osadzić w URI repozytorium (ostrożnie: `https://user:password@host/...`).

### Zależności Pythona

- `--py-files` służy do dystrybucji bibliotek `.egg`, `.zip` i `.py` do executorów – odpowiednik `--jars` dla aplikacji Python.

### Sprzątanie plików tymczasowych

- **YARN**: sprzątanie odbywa się automatycznie.
- **Spark Standalone**: konfigurowalne przez właściwość `spark.worker.cleanup.appDataTtl`.
- Jary i pliki są kopiowane do katalogu roboczego każdego `SparkContext` na węzłach executorów, co z czasem zajmuje miejsce na dysku i wymaga sprzątania.

---

## Kluczowe zasady

- `spark-submit` to jeden, uniwersalny sposób uruchamiania aplikacji niezależnie od menedżera klastra (Standalone, YARN, Kubernetes) i języka (Java, Scala, Python).
- Zależności Sparka/Hadoopa oznaczaj jako `provided` w buildzie – dostarcza je klaster, nie trzeba ich pakować.
- Wybór `--deploy-mode` (`client` vs `cluster`) zależy od tego, gdzie fizycznie ma działać sterownik – blisko klastra (mniej opóźnień) czy blisko użytkownika (łatwiejszy dostęp do konsoli/REPL).
- Konfigurację można ustawiać na trzech poziomach z jasną hierarchią pierwszeństwa: kod (`SparkConf`) > flagi CLI > plik `spark-defaults.conf`.
- Do zarządzania zależnościami zewnętrznymi lepiej używać `--packages` (współrzędne Mavena, automatyczne zależności tranzytywne) niż ręcznie zarządzać pojedynczymi jarami przez `--jars`, chyba że chodzi o pliki niepublikowane w repozytorium Maven.
