# Apache Spark – Cluster Mode Overview (streszczenie)

Źródło: [spark.apache.org/docs/latest/cluster-overview.html](https://spark.apache.org/docs/latest/cluster-overview.html) (Spark 4.2.0)

Przegląd architektury działania aplikacji Sparka na klastrze: jakie procesy biorą w tym udział, jak się ze sobą komunikują oraz jakie menedżery klastra są obsługiwane.

## Spis treści

1. Komponenty klastra Sparka
2. Ważne uwagi dotyczące architektury
3. Typy menedżerów klastra
4. Wysyłanie aplikacji
5. Monitorowanie
6. Planowanie zadań (job scheduling)
7. Terminologia/glosariusz
8. Kluczowe zasady

---

## 1. Komponenty klastra Sparka

Aplikacje Sparka działają jako niezależne zestawy procesów na klastrze, koordynowane przez obiekt **SparkContext** w programie głównym (nazywanym **programem sterującym**, driver program).

**Przepływ interakcji między komponentami:**
1. `SparkContext` łączy się z **menedżerem klastra** (Standalone, YARN lub Kubernetes).
2. Menedżer klastra przydziela zasoby pomiędzy aplikacjami.
3. Spark pozyskuje **executory** na węzłach roboczych (worker nodes) w klastrze.
4. Executory to procesy, które wykonują obliczenia i przechowują dane.
5. Kod aplikacji (JAR lub pliki Pythona) jest wysyłany do executorów przez `SparkContext`.
6. `SparkContext` wysyła **zadania (tasks)** do executorów do wykonania.

| Komponent | Rola |
|---|---|
| **Driver Program** | Uruchamia funkcję `main()`, tworzy `SparkContext`, planuje zadania |
| **SparkContext** | Koordynuje zasoby klastra i dystrybucję zadań |
| **Cluster Manager** | Zewnętrzna usługa pozyskująca zasoby klastra |
| **Worker Node** | Węzeł zdolny do uruchamiania kodu aplikacji |
| **Executor** | Proces na węźle roboczym wykonujący zadania i przechowujący dane |
| **Task** | Jednostka pracy wysyłana do executora |

## 2. Ważne uwagi dotyczące architektury

1. **Izolacja aplikacji**
   - Każda aplikacja otrzymuje własne procesy executorów.
   - Executory pozostają aktywne przez cały czas trwania aplikacji i uruchamiają zadania w wielu wątkach.
   - Izolacja występuje zarówno po stronie planowania (każdy driver planuje własne zadania), jak i po stronie wykonania (zadania różnych aplikacji działają w osobnych JVM).
   - **Ograniczenie**: dane nie mogą być współdzielone pomiędzy różnymi aplikacjami Sparka bez zewnętrznego systemu przechowywania danych.

2. **Niezależność od menedżera klastra**
   - Spark działa z dowolnym menedżerem klastra, który potrafi pozyskać procesy executorów zdolne do wzajemnej komunikacji.
   - Łatwo uruchamia się na menedżerach klastra obsługujących też inne aplikacje (YARN/Kubernetes).

3. **Wymagania sieciowe**
   - Program sterujący musi nasłuchiwać i akceptować połączenia przychodzące od executorów przez cały czas swojego działania.
   - Driver musi być adresowalny sieciowo z węzłów roboczych (patrz parametr `spark.driver.port` w konfiguracji sieciowej).

4. **Topologia wdrożenia**
   - Driver powinien działać blisko węzłów roboczych, najlepiej w tej samej sieci lokalnej.
   - Przy zdalnym zlecaniu operacji na klaster lepiej otworzyć RPC do drivera i zlecać operacje lokalnie niż uruchamiać driver zdalnie, z dala od węzłów roboczych.

## 3. Typy menedżerów klastra

- **[Standalone](https://spark.apache.org/docs/latest/spark-standalone.html)** – prosty menedżer klastra dołączony do Sparka, ułatwiający uruchomienie klastra.
- **[Hadoop YARN](https://spark.apache.org/docs/latest/running-on-yarn.html)** – menedżer zasobów z Hadoop 3.
- **[Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)** – system open source do automatyzacji wdrażania, skalowania i zarządzania aplikacjami skonteneryzowanymi.

## 4. Wysyłanie aplikacji

Aplikacje wysyła się do dowolnego typu klastra za pomocą skryptu **`spark-submit`**. Szczegóły w [przewodniku wysyłania aplikacji](https://spark.apache.org/docs/latest/submitting-applications.html).

## 5. Monitorowanie

**Web UI drivera:**
- Domyślnie dostępne na porcie **4040**.
- Pokazuje informacje o: uruchomionych zadaniach, executorach, wykorzystaniu pamięci/storage.
- Dostęp przez: `http://<driver-node>:4040`.

Więcej opcji monitorowania opisano w [przewodniku monitorowania](https://spark.apache.org/docs/latest/monitoring.html).

## 6. Planowanie zadań (Job Scheduling)

Spark umożliwia kontrolę nad przydziałem zasobów na dwóch poziomach:
- **Pomiędzy aplikacjami** – na poziomie menedżera klastra.
- **Wewnątrz aplikacji** – dla wielu obliczeń działających na tym samym `SparkContext`.

Szczegóły w [przeglądzie planowania zadań](https://spark.apache.org/docs/latest/job-scheduling.html).

## 7. Terminologia/glosariusz

| Termin | Znaczenie |
|---|---|
| **Application** | Program użytkownika zbudowany na Sparku, składający się z programu sterującego i executorów |
| **Application jar** | JAR zawierający aplikację Sparka użytkownika; może zawierać zależności, ale NIE powinien zawierać bibliotek Hadoop ani Sparka (dodawanych w czasie wykonania); może być "uber jar" |
| **Driver program** | Proces uruchamiający funkcję `main()` i tworzący `SparkContext` |
| **Cluster manager** | Zewnętrzna usługa do pozyskiwania zasobów klastra (standalone, YARN, Kubernetes) |
| **Deploy mode** | Rozróżnia lokalizację procesu drivera: tryb "cluster" (framework uruchamia driver wewnątrz klastra) lub "client" (osoba zlecająca uruchamia driver poza klastrem) |
| **Worker node** | Dowolny węzeł zdolny do uruchamiania kodu aplikacji w klastrze |
| **Executor** | Proces na węźle roboczym uruchamiający zadania i przechowujący dane w pamięci/na dysku; każda aplikacja ma własne executory |
| **Task** | Jednostka pracy wysyłana do jednego executora |
| **Job** | Równoległe obliczenie złożone z wielu zadań, wywołane przez akcję Sparka (np. `save`, `collect`); widoczne w logach drivera |
| **Stage** | Mniejszy zbiór zadań w ramach joba, powiązanych zależnościami (podobnie do etapów map/reduce w MapReduce); widoczny w logach drivera |

---

## Kluczowe zasady

- **Model driver–executor** – jeden program sterujący koordynuje wiele procesów executorów rozproszonych na węzłach roboczych.
- **Izolacja aplikacji** – każda aplikacja ma własne executory; dane nie są współdzielone między aplikacjami bez zewnętrznego storage'u.
- **Niezależność od menedżera klastra** – ten sam model działa na Standalone, YARN i Kubernetes.
- **Bliskość sieciowa driver–workers** – driver musi być adresowalny z workerów i najlepiej powinien działać blisko nich (ta sama sieć lokalna).
- **Dwupoziomowe planowanie zasobów** – pomiędzy aplikacjami (menedżer klastra) i wewnątrz aplikacji (SparkContext).
