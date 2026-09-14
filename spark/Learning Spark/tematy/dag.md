# Czym jest DAG?

## Definicja

DAG (Directed Acyclic Graph, graf skierowany acykliczny) to struktura danych, za pomocą której Spark reprezentuje ciąg obliczeń, jakie trzeba wykonać, aby uzyskać wynik zażądany przez akcję (action). Węzłami grafu są RDD (a na wyższym poziomie abstrakcji operacje na DataFrame/DataSet), a krawędziami — transformacje (transformations) łączące te RDD w kolejne kroki przetwarzania.

- **Directed** — krawędzie mają kierunek: dane płyną od RDD wejściowego do RDD wynikowego.
- **Acyclic** — graf nie zawiera cykli, więc nie ma ryzyka nieskończonej pętli obliczeniowej; obliczenia zawsze da się uporządkować topologicznie.

## Skąd bierze się DAG

Gdy piszemy kod z transformacjami (`map`, `filter`, `join`, `groupBy` itd.), Spark **nie wykonuje ich od razu** — buduje logiczny plan (lazy evaluation). Każda transformacja dodaje nowy węzeł do grafu zależności (lineage) pomiędzy RDD. Dopiero wywołanie akcji (`collect`, `count`, `save...`) powoduje, że:

1. DAGScheduler analizuje zbudowany graf.
2. Dzieli go na **stages** — grupy transformacji, które można wykonać bez shuffle'a (czyli oddzielone granicami operacji wide, np. `groupByKey`, `join`, `repartition`).
3. Każdy stage jest dalej dzielony na **taski** — po jednym na partycję danych.
4. Taski są zlecane executorom przez TaskScheduler.

## Po co Sparkowi DAG (a nie np. klasyczny model MapReduce)

- **Optymalizacja globalna** — ponieważ Spark zna cały łańcuch operacji zanim cokolwiek wykona, może optymalizować plan jako całość (np. łączyć operacje, eliminować niepotrzebne kroki), zamiast wykonywać każdy krok osobno i zapisywać wynik pośredni na dysk, jak robił to klasyczny Hadoop MapReduce (każdy job MapReduce = osobny odczyt/zapis z HDFS).
- **Odporność na awarie (fault tolerance)** — DAG razem z lineage (informacją, z jakich transformacji powstał dany RDD) pozwala odtworzyć utraconą partycję danych, przeliczając tylko brakujący fragment grafu, a nie całe obliczenie od nowa. To alternatywa dla replikacji danych.
- **Pipelining** — operacje typu narrow (np. ciąg `map`+`filter`) mogą być wykonane w jednym przebiegu, bez materializowania wyników pośrednich — DAG pozwala to rozpoznać i zoptymalizować.
- **Równoległość** — DAG jasno pokazuje, które fragmenty obliczeń są od siebie niezależne i mogą być wykonywane równolegle (różne stage'e bez wzajemnych zależności, różne partycje w ramach stage'a).

## DAG a stages i tasks

- Granice między stage'ami wyznaczają operacje **wide** (wymagające shuffle'a, np. `reduceByKey`, `join`, `distinct`, `repartition`) — dane trzeba przetasować między partycjami/węzłami, więc nie da się ich wykonać w ramach jednego pipeline'u.
- W ramach jednego stage'a operacje **narrow** (`map`, `filter`, `union`) są łączone (fused) w jeden ciąg wykonywany task-po-tasku na danej partycji, bez zapisu pośredniego.

## Wizualizacja

DAG dla danego joba można podejrzeć w **Spark UI** (zakładka "Jobs" → konkretny job → "DAG Visualization"), co jest bardzo pomocne przy debugowaniu wydajności — widać tam podział na stage'e i miejsca, gdzie następuje shuffle.

## Krótkie podsumowanie (na rozmowę kwalifikacyjną)

> DAG to logiczny plan wykonania budowany leniwie na podstawie transformacji zadeklarowanych na RDD/DataFrame. Dopiero akcja wyzwala jego analizę przez DAGScheduler, podział na stage'e (według granic shuffle'a) i taski, a następnie wykonanie przez executory. DAG umożliwia Sparkowi globalną optymalizację planu, pipelining operacji narrow oraz efektywne odzyskiwanie danych po awarii dzięki lineage — bez potrzeby zapisywania wyników pośrednich na dysk, jak w klasycznym MapReduce.
