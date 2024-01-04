/* 
Denna SQL-kod syftar till att analysera f�rs�ljningstrender, kundbeteenden och effektivitet f�r att ge 
f�retaget en �verblick �ver f�rs�ljningsresultaten och m�jligg�ra strategiska beslut.
*/

USE AdventureWorks2022
GO

/* Sammanst�llning utav f�rs�ljningssiffror m�nad f�r m�nad f�r att se om f�retagets f�rs�ljningsint�kter �kar eller minskar �ver tiden.
*/
SELECT
		YEAR(OrderDate) AS �r,
		MONTH(OrderDate) AS M�nad,
		CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS F�rs�ljningsint�kt
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY �r, M�nad ASC



/* Sammanst�llning utav f�rs�ljningstillv�xt j�mf�rt med f�reg�ende m�nad. Hur har tillv�xten varit varje m�nad?
Jag vill se trender i den m�natliga f�rs�ljningen, se om man kan hitta variationer f�r att anpassa ink�p och lager men �ven 
f�r att se om vi har stora skillnader i �kningar eller minskningar f�r att djupdyka mer och se vad det kan bero p�!
LAG --> anv�nder jag f�r att h�mta f�rs�ljningsint�kten fr�n f�rg�ende m�nad och jag vill ordna det efter �r och m�nad som innan.
CASE --> anv�nder jag f�r att ber�kna tillv�xten mellan nuvarande m�nad j�mf�rt med f�rg�ende m�nad. F�rsta m�naden har vi inget att 
j�mf�ra med d�rf�r v�ljer jag att den ska visas som NULL om det inte finns n�got att j�mf�ra och ber�kna med.
*/
WITH M�natligfsg AS (
    SELECT
        YEAR(OrderDate) AS �r,
        MONTH(OrderDate) AS M�nad,
        CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS F�rs�ljningsInt�kt
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT 
    �r,
    M�nad, 
    F�rs�ljningsInt�kt,
    LAG(F�rs�ljningsInt�kt) OVER (ORDER BY �r, M�nad) AS TidigareM�nad,
    CASE
        WHEN LAG(F�rs�ljningsInt�kt) OVER (ORDER BY �r, M�nad) IS NULL THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (F�rs�ljningsInt�kt - LAG(F�rs�ljningsInt�kt) OVER(ORDER BY �r, M�nad)) / LAG(F�rs�ljningsInt�kt) OVER(ORDER BY �r, M�nad))
    END AS F�rs�ljningsTillv�xt
FROM M�natligfsg
ORDER BY �r, M�nad;



/* Sammanst�llning utav f�rs�ljningstillv�xt �r f�r �r, hur har tillv�xten varit varje �r?
Efter att ha identifierat tillv�xten m�nad f�r m�nad vill jag �ven se hur den �rliga varit f�r att f� en �verblick om f�retaget v�xer.
*/

WITH �rligfsg AS (
	SELECT
		YEAR(OrderDate) AS �r,
		CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS F�rs�ljningsint�kt
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate)
)
SELECT 
	�r, 
	F�rs�ljningsint�kt,
	LAG(F�rs�ljningsint�kt) OVER (ORDER BY �r) AS 'Tidigare �r',
	CASE
		WHEN LAG(F�rs�ljningsint�kt) OVER (ORDER BY �r) IS NULL THEN NULL
		ELSE CONVERT(DECIMAL(10, 2), (F�rs�ljningsint�kt - LAG(F�rs�ljningsint�kt) OVER(ORDER BY �r)) / LAG(F�rs�ljningsint�kt) OVER(ORDER BY �r))
	END AS F�rs�ljningstillv�xt
FROM �rligfsg
ORDER BY �r;

/* Kunders K�pbeteende f�r att kategorisera och identifiera v�ra Stora, Medel och sm� kunder. 
Bra f�r framtida planerade kundaktiviteter f�r att maximera och effektivisera f�retagets f�rs�ljningsstrategier
riktade mot dessa kunder.
*/

SELECT 
	A.CustomerID AS 'Kund ID',
	A.PersonID AS 'Personal ID',
	A.StoreID AS 'Butik',
	A.TerritoryID,
	COUNT(B.SalesOrderID) AS 'Antal Ordrar',
	CONVERT(DECIMAL(10, 2), SUM(B.TotalDue)) AS 'Kund Int�kt',
	CASE
		WHEN SUM(B.TotalDue) > 100000 THEN 'Stor Kund'
		WHEN SUM(B.TotalDue) BETWEEN 10000 AND 100000 THEN 'Medel Kund' 
		ELSE 'Liten Kund'
	END AS 'Kund Kategori'
FROM Sales.Customer AS A
	INNER JOIN Sales.SalesOrderHeader AS B ON A.CustomerID = B.CustomerID
GROUP BY A.CustomerID, A.PersonID, A.StoreID, A.TerritoryID
ORDER BY 'Kund Int�kt' DESC;

/* Produkter som s�ljs b�st, jag ville se vilka produkter f�retaget s�ljer allra b�st. 
P� s� s�tt kan vi se vad som g�r bra och vad som g�r mindre bra, var beh�ver vi l�gga in resurser
*/

WITH ProduktFsg AS (
    SELECT 
        D.Name AS ProduktKategori,
        CONVERT(DECIMAL(10, 2), SUM(A.LineTotal)) AS F�rs�ljningsInt�kt
    FROM Sales.SalesOrderDetail AS A
    INNER JOIN Production.Product AS B ON A.ProductID = B.ProductID
    INNER JOIN Production.ProductSubcategory AS C ON B.ProductSubcategoryID = C.ProductSubcategoryID
    INNER JOIN Production.ProductCategory AS D ON C.ProductCategoryID = D.ProductCategoryID
    GROUP BY D.Name
)
SELECT 
    ProduktKategori,
    F�rs�ljningsInt�kt,
    ROW_NUMBER() OVER (ORDER BY F�rs�ljningsInt�kt DESC) AS Rankning
FROM ProduktFsg;

/* I n�sta steg vill jag se vilka regioner som s�ljer b�sta, ger oss en �verblick i var vi presterar b�ttre eller mindre bra,
vi kanske beh�ver skapa marknadsf�ringskampanjer f�r att ut�ka v�r synlighet. �r det andra brister som vi beh�ver uppm�rksamma 
och p� s� se vilka insatser beh�ver s�ttas in! 
*/

-- Jag b�rjar med att tittat p� Region som helhet och vill f� fram den Totala F�rs�ljningen �ver tid 

SELECT 
    B.Name AS Region,
    CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS F�rs�ljningsInt�kt
FROM Sales.SalesOrderHeader AS A
	INNER JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
GROUP BY B.Name
ORDER BY F�rs�ljningsInt�kt DESC;

/* Jag vill djupduka i varje Land f�r sig och vill ha en sammanst�llning utav m�natliga f�rs�ljningstillv�xten efter Region
Jag vill se vilka l�nder f�retagets produkter har en stark tillv�xt och vilka l�nder s�ljer s�mre, f�r att se Trender och avvikleser.
*/

WITH M�nRegionFsg AS (
    SELECT 
        B.Name AS Land,
        YEAR(A.OrderDate) AS �r,
        MONTH(A.OrderDate) AS M�nad,
        CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS F�rs�ljningsInt�kt
    FROM Sales.SalesOrderHeader AS A 
    JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
    GROUP BY B.Name, YEAR(A.OrderDate), MONTH(A.OrderDate)
)
SELECT
    Land,
    �r,
    M�nad,
    F�rs�ljningsInt�kt,
    LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r, M�nad) AS Tidigare�rFsg,
    CASE
        WHEN LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r, M�nad) = 0 THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (F�rs�ljningsInt�kt - LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r, M�nad)) / LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r, M�nad))
    END AS F�rs�ljningsTillv�xt
FROM M�nRegionFsg 
ORDER BY Land, �r, M�nad;


-- Sammanst�llning utav den �rliga f�rs�ljningstillv�xten efter Land.  

WITH �rligRegionalF�rs�ljning AS (
    SELECT 
        B.Name AS Land,
        YEAR(A.OrderDate) AS �r,
        CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS F�rs�ljningsInt�kt
    FROM Sales.SalesOrderHeader AS A
    INNER JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
    GROUP BY B.Name, YEAR(A.OrderDate)
)
SELECT
    Land,
    �r,
    F�rs�ljningsInt�kt,
    LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r) AS Tidigare�rFsg,
    CASE
        WHEN LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r) = 0 THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (F�rs�ljningsInt�kt - LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r)) / LAG(F�rs�ljningsInt�kt) OVER (PARTITION BY Land ORDER BY �r))
    END AS F�rs�ljningsTillv�xt
FROM �rligRegionalF�rs�ljning
ORDER BY Land, �r;





