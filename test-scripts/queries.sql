-- ============================================================================
-- TEST-SKRIPT FOR OBLIG 1
-- ============================================================================

-- Oppgave 5.1: Vis alle sykler
SELECT *
FROM bikes;

-- Oppgave 5.2: Etternavn, fornavn og mobilnummer for alle kunder, sortert på etternavn
SELECT last_name, first_name, phone
FROM customers
ORDER BY last_name, first_name;

-- Oppgave 5.3: Sykler tatt i bruk etter 1. april 2023
SELECT bike_id, model, in_service_since
FROM bikes
WHERE in_service_since > DATE '2023-04-01'
ORDER BY in_service_since;

-- Oppgave 5.4: Antall kunder
SELECT COUNT(*) AS antall_kunder
FROM customers;

-- Oppgave 5.5: Alle kunder og antall utleier per kunde (inkl. 0)
SELECT c.customer_id, c.first_name, c.last_name, COUNT(r.rental_id) AS antall_utleier
FROM customers c
LEFT JOIN rentals r ON r.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY c.customer_id;

-- Oppgave 5.6: Kunder som aldri har leid
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
LEFT JOIN rentals r ON r.customer_id = c.customer_id
WHERE r.rental_id IS NULL
ORDER BY c.customer_id;

-- Oppgave 5.7: Sykler som aldri har vært utleid
SELECT b.bike_id, b.model
FROM bikes b
LEFT JOIN rentals r ON r.bike_id = b.bike_id
WHERE r.rental_id IS NULL
ORDER BY b.bike_id;

-- Oppgave 5.8: Sykler som ikke er levert tilbake etter ett døgn (med kundeinfo)
SELECT b.bike_id, b.model,
       c.customer_id, c.first_name, c.last_name,
       r.start_time
FROM rentals r
JOIN bikes b ON b.bike_id = r.bike_id
JOIN customers c ON c.customer_id = r.customer_id
WHERE r.end_time IS NULL
  AND r.start_time < NOW() - INTERVAL '1 day'
ORDER BY r.start_time;
