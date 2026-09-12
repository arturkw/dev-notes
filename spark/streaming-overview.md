# Apache Spark – Structured Streaming (Overview)

Źródło: [spark.apache.org/docs/latest/streaming/index.html](https://spark.apache.org/docs/latest/streaming/index.html) (Spark 4.2.0)

Strona przeglądowa modułu streamingowego Sparka. Współcześnie adres ten prowadzi do wprowadzenia w **Structured Streaming** – rekomendowanego, nowszego silnika do przetwarzania strumieniowego, zbudowanego na silniku Spark SQL.

## Czym jest Structured Streaming

Skalowalny i odporny na awarie silnik przetwarzania strumieniowego zbudowany na Spark SQL. Kluczowa idea: strumieniowe obliczenia wyraża się **tym samym API**, którego używa się do obliczeń wsadowych (batch) na danych statycznych – silnik Sparka sam dba o przyrostowe i ciągłe wykonywanie zapytania w miarę napływu danych.

**Najważniejsze cechy:**
- korzysta z zoptymalizowanego silnika Spark SQL (Catalyst) do wykonania,
- wspiera API Dataset/DataFrame w Scali, Javie, Pythonie i R,
- gwarancje **end-to-end exactly-once** dzięki checkpointingowi i Write-Ahead Logs,
- wspiera agregacje strumieniowe, okna czasu zdarzeń (event-time windows) oraz łączenie strumienia z danymi wsadowymi (stream-to-batch joins).

## Modele przetwarzania

| Model | Opóźnienie end-to-end | Gwarancje | Uwagi |
|---|---|---|---|
| **Micro-batch** (domyślny) | od ok. 100 ms | exactly-once | dane przetwarzane jako seria małych zadań wsadowych |
| **Continuous Processing** (od Spark 2.3) | od ok. 1 ms | at-least-once | ten sam kod/API, zmiana trybu bez modyfikacji zapytania |

## Powiązane podstrony

1. **Getting Started** – wprowadzenie i konfiguracja pierwszego streamu
2. **APIs on DataFrames and Datasets** – referencja API
3. **Performance Tips** – optymalizacja, szczegóły trybu Continuous Processing
4. **Additional Information** – materiały dodatkowe

## Structured Streaming vs. Spark Streaming (DStreams)

Dokumentacja Sparka rozróżnia dwa API do streamingu:
- **Spark Streaming (DStreams)** – starsze, niskopoziomowe API oparte na RDD (opisane osobno, patrz [streaming-programming-guide.md](./streaming-programming-guide.md)),
- **Structured Streaming** – nowsze, rekomendowane podejście zbudowane na Spark SQL/DataFrame, z wyższym poziomem abstrakcji i lepszą optymalizacją zapytań.

Ta strona (index) pełni rolę punktu wejścia kierującego do pełnego przewodnika Structured Streaming.
