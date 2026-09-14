# Typy cluster managerów

## Rola cluster managera

Cluster manager to zewnętrzny wobec logiki Sparka komponent odpowiedzialny za **przydzielanie zasobów** (CPU, pamięć) aplikacjom Sparka w ramach klastra — uruchamia i nadzoruje procesy executorów (i opcjonalnie driver, w cluster mode) na fizycznych/wirtualnych węzłach. Driver łączy się z cluster managerem, żąda zasobów, a cluster manager decyduje, gdzie i ile procesów uruchomić.

Spark jest **agnostyczny** względem cluster managera — ten sam kod aplikacji działa niezależnie od wybranego cluster managera (zmienia się tylko konfiguracja `--master`/wdrożenie).

## Typy cluster managerów

### 1. Standalone

Wbudowany, najprostszy cluster manager dostarczany razem ze Sparkiem — nie wymaga instalowania niczego dodatkowego.

- Składa się z procesu **Master** (zarządza klastrem, przydziela zasoby) i procesów **Worker** (uruchamiają executory na poszczególnych maszynach).
- Dobry do: testów, mniejszych dedykowanych klastrów wyłącznie pod Sparka, prostych wdrożeń bez potrzeby współdzielenia zasobów z innymi frameworkami.
- Ograniczenia: brak zaawansowanego multi-tenancy, mniej funkcji zarządzania zasobami niż YARN/K8s (choć wspiera podstawową dynamiczną alokację).

### 2. Apache YARN (Yet Another Resource Negotiator)

Cluster manager z ekosystemu Hadoop, bardzo popularny w środowiskach, gdzie Spark współdzieli klaster z innymi frameworkami Hadoop (Hive, MapReduce, itd.) i danymi na HDFS.

- Komponenty: **ResourceManager** (globalny arbiter zasobów), **NodeManager** (na każdym węźle, uruchamia kontenery), **ApplicationMaster** (koordynuje pojedynczą aplikację — w Sparku driver w cluster mode działa właśnie jako ApplicationMaster).
- Zalety: dojrzały, sprawdzony w środowiskach korporacyjnych/on-prem, dobra integracja z HDFS i resztą ekosystemu Hadoop, wsparcie dla kolejek i multi-tenancy (kilka zespołów/aplikacji dzieli ten sam klaster wg polityk zasobowych).
- Typowy wybór dla on-premise klastrów Hadoop.

### 3. Kubernetes (K8s)

Natywna integracja Sparka z Kubernetesem — executory (i driver) uruchamiane są jako **pody Kubernetesa**.

- Zalety: standard w chmurze/nowoczesnej infrastrukturze kontenerowej, łatwa izolacja zasobów przez namespace'y, natywne wsparcie w chmurach publicznych (EKS, GKE, AKS), elastyczne skalowanie, spójność z resztą stosu DevOps opartego o K8s.
- Ograniczenia historyczne: przez dłuższy czas brak pełnego wsparcia dla External Shuffle Service (kluczowego dla bezpiecznej dynamicznej alokacji) — sytuacja poprawia się w nowszych wersjach Sparka.
- Coraz częstszy wybór w nowych wdrożeniach, szczególnie w chmurze.

### 4. Mesos (historycznie)

Ogólnego przeznaczenia cluster manager (nie tylko dla Sparka), jeden z pierwszych wspieranych przez Sparka.

- W praktyce **przestarzały** dla Sparka — wsparcie zostało usunięte w Spark 3.2+ (deprecated wcześniej). Wymieniany głównie ze względów historycznych/na egzaminach.

### 5. Tryb lokalny (local mode) — nie jest "prawdziwym" cluster managerem

`local[*]` / `local[N]` — Spark uruchamia driver i "executory" jako wątki w ramach jednej JVM na jednej maszynie, bez żadnego zewnętrznego menedżera zasobów. Używany do developmentu, testów jednostkowych, nauki — nie do produkcji.

## Porównanie

| Cluster manager | Typowe środowisko | Uwagi |
|---|---|---|
| Standalone | Dedykowany klaster tylko pod Sparka | Prosty, wbudowany |
| YARN | On-premise Hadoop | Dojrzały, dobra integracja z HDFS/Hive, multi-tenancy |
| Kubernetes | Chmura, infrastruktura kontenerowa | Nowoczesny standard, rosnące wsparcie |
| Mesos | (historyczne) | Usunięty w Spark 3.2+ |
| local[*] | Dev/testy | Brak prawdziwego klastra |

## Jak driver wybiera cluster managera

Parametr `--master` przy `spark-submit` (lub `.master(...)` w `SparkSession.builder()`), np.:

```
spark-submit --master yarn ...
spark-submit --master spark://host:7077 ...
spark-submit --master k8s://https://<k8s-api-server>:<port> ...
spark-submit --master local[4] ...
```

## Podsumowanie (na rozmowę kwalifikacyjną)

> Cluster manager odpowiada za alokację zasobów (CPU/pamięć) i uruchamianie procesów executorów (oraz driver w cluster mode) w klastrze. Spark wspiera kilka cluster managerów: wbudowany Standalone (prosty, dedykowany), YARN (dojrzały, typowy dla on-premise Hadoop, dobra integracja z HDFS), Kubernetes (nowoczesny, rosnący standard w chmurze) oraz historyczny, już nieobsługiwany Mesos. Sam kod aplikacji jest niezależny od wyboru cluster managera — zmienia się tylko sposób wdrożenia i konfiguracja `--master`.
