-- Dane wyjściowe do demonstracji non-repeatable read / phantom read / lost update
CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    owner   TEXT NOT NULL,
    balance NUMERIC NOT NULL
);

INSERT INTO accounts (id, owner, balance) VALUES
    (1, 'alice', 100),
    (2, 'bob',   50),
    (3, 'carol', 30);

-- Dane wyjściowe do demonstracji write skew (serialization anomaly)
CREATE TABLE doctors (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    on_call BOOLEAN NOT NULL
);

INSERT INTO doctors (name, on_call) VALUES
    ('Alice', true),
    ('Bob',   true);

-- Reguła biznesowa, której pilnujemy ręcznie w aplikacji (nie ma jej jako CHECK,
-- bo CHECK nie widzi innych wierszy) - przynajmniej jeden lekarz musi być on-call.
