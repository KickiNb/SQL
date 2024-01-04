/* 
Denna SQL-kod syftar till att analysera försäljningstrender, kundbeteenden och effektivitet för att ge 
företaget en överblick över försäljningsresultaten och möjliggöra strategiska beslut.
*/

USE AdventureWorks2022
GO

/* Sammanställning utav försäljningssiffror månad för månad för att se om företagets försäljningsintäkter ökar eller minskar över tiden.
*/
SELECT
		YEAR(OrderDate) AS År,
		MONTH(OrderDate) AS Månad,
		CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS Försäljningsintäkt
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY År, Månad ASC



/* Sammanställning utav försäljningstillväxt jämfört med föregående månad. Hur har tillväxten varit varje månad?
Jag vill se trender i den månatliga försäljningen, se om man kan hitta variationer för att anpassa inköp och lager men även 
för att se om vi har stora skillnader i ökningar eller minskningar för att djupdyka mer och se vad det kan bero på!
LAG --> använder jag för att hämta försäljningsintäkten från förgående månad och jag vill ordna det efter år och månad som innan.
CASE --> använder jag för att beräkna tillväxten mellan nuvarande månad jämfört med förgående månad. Första månaden har vi inget att 
jämföra med därför väljer jag att den ska visas som NULL om det inte finns något att jämföra och beräkna med.
*/
WITH Månatligfsg AS (
    SELECT
        YEAR(OrderDate) AS År,
        MONTH(OrderDate) AS Månad,
        CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS FörsäljningsIntäkt
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT 
    År,
    Månad, 
    FörsäljningsIntäkt,
    LAG(FörsäljningsIntäkt) OVER (ORDER BY År, Månad) AS TidigareMånad,
    CASE
        WHEN LAG(FörsäljningsIntäkt) OVER (ORDER BY År, Månad) IS NULL THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (FörsäljningsIntäkt - LAG(FörsäljningsIntäkt) OVER(ORDER BY År, Månad)) / LAG(FörsäljningsIntäkt) OVER(ORDER BY År, Månad))
    END AS FörsäljningsTillväxt
FROM Månatligfsg
ORDER BY År, Månad;



/* Sammanställning utav försäljningstillväxt År för år, hur har tillväxten varit varje År?
Efter att ha identifierat tillväxten månad för månad vill jag även se hur den årliga varit för att få en överblick om företaget växer.
*/

WITH Årligfsg AS (
	SELECT
		YEAR(OrderDate) AS År,
		CONVERT(DECIMAL(10, 2), SUM(TotalDue)) AS Försäljningsintäkt
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate)
)
SELECT 
	År, 
	Försäljningsintäkt,
	LAG(Försäljningsintäkt) OVER (ORDER BY År) AS 'Tidigare År',
	CASE
		WHEN LAG(Försäljningsintäkt) OVER (ORDER BY År) IS NULL THEN NULL
		ELSE CONVERT(DECIMAL(10, 2), (Försäljningsintäkt - LAG(Försäljningsintäkt) OVER(ORDER BY År)) / LAG(Försäljningsintäkt) OVER(ORDER BY År))
	END AS Försäljningstillväxt
FROM Årligfsg
ORDER BY År;

/* Kunders Köpbeteende för att kategorisera och identifiera våra Stora, Medel och små kunder. 
Bra för framtida planerade kundaktiviteter för att maximera och effektivisera företagets försäljningsstrategier
riktade mot dessa kunder.
*/

SELECT 
	A.CustomerID AS 'Kund ID',
	A.PersonID AS 'Personal ID',
	A.StoreID AS 'Butik',
	A.TerritoryID,
	COUNT(B.SalesOrderID) AS 'Antal Ordrar',
	CONVERT(DECIMAL(10, 2), SUM(B.TotalDue)) AS 'Kund Intäkt',
	CASE
		WHEN SUM(B.TotalDue) > 100000 THEN 'Stor Kund'
		WHEN SUM(B.TotalDue) BETWEEN 10000 AND 100000 THEN 'Medel Kund' 
		ELSE 'Liten Kund'
	END AS 'Kund Kategori'
FROM Sales.Customer AS A
	INNER JOIN Sales.SalesOrderHeader AS B ON A.CustomerID = B.CustomerID
GROUP BY A.CustomerID, A.PersonID, A.StoreID, A.TerritoryID
ORDER BY 'Kund Intäkt' DESC;

/* Produkter som säljs bäst, jag ville se vilka produkter företaget säljer allra bäst. 
På så sätt kan vi se vad som går bra och vad som går mindre bra, var behöver vi lägga in resurser
*/

WITH ProduktFsg AS (
    SELECT 
        D.Name AS ProduktKategori,
        CONVERT(DECIMAL(10, 2), SUM(A.LineTotal)) AS FörsäljningsIntäkt
    FROM Sales.SalesOrderDetail AS A
    INNER JOIN Production.Product AS B ON A.ProductID = B.ProductID
    INNER JOIN Production.ProductSubcategory AS C ON B.ProductSubcategoryID = C.ProductSubcategoryID
    INNER JOIN Production.ProductCategory AS D ON C.ProductCategoryID = D.ProductCategoryID
    GROUP BY D.Name
)
SELECT 
    ProduktKategori,
    FörsäljningsIntäkt,
    ROW_NUMBER() OVER (ORDER BY FörsäljningsIntäkt DESC) AS Rankning
FROM ProduktFsg;

/* I nästa steg vill jag se vilka regioner som säljer bästa, ger oss en överblick i var vi presterar bättre eller mindre bra,
vi kanske behöver skapa marknadsföringskampanjer för att utöka vår synlighet. Är det andra brister som vi behöver uppmärksamma 
och på så se vilka insatser behöver sättas in! 
*/

-- Jag börjar med att tittat på Region som helhet och vill få fram den Totala Försäljningen över tid 

SELECT 
    B.Name AS Region,
    CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS FörsäljningsIntäkt
FROM Sales.SalesOrderHeader AS A
	INNER JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
GROUP BY B.Name
ORDER BY FörsäljningsIntäkt DESC;

/* Jag vill djupduka i varje Land för sig och vill ha en sammanställning utav månatliga försäljningstillväxten efter Region
Jag vill se vilka länder företagets produkter har en stark tillväxt och vilka länder säljer sämre, för att se Trender och avvikleser.
*/

WITH MånRegionFsg AS (
    SELECT 
        B.Name AS Land,
        YEAR(A.OrderDate) AS År,
        MONTH(A.OrderDate) AS Månad,
        CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS FörsäljningsIntäkt
    FROM Sales.SalesOrderHeader AS A 
    JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
    GROUP BY B.Name, YEAR(A.OrderDate), MONTH(A.OrderDate)
)
SELECT
    Land,
    År,
    Månad,
    FörsäljningsIntäkt,
    LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År, Månad) AS TidigareÅrFsg,
    CASE
        WHEN LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År, Månad) = 0 THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (FörsäljningsIntäkt - LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År, Månad)) / LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År, Månad))
    END AS FörsäljningsTillväxt
FROM MånRegionFsg 
ORDER BY Land, År, Månad;


-- Sammanställning utav den årliga försäljningstillväxten efter Land.  

WITH ÅrligRegionalFörsäljning AS (
    SELECT 
        B.Name AS Land,
        YEAR(A.OrderDate) AS År,
        CONVERT(DECIMAL(10, 2), SUM(A.TotalDue)) AS FörsäljningsIntäkt
    FROM Sales.SalesOrderHeader AS A
    INNER JOIN Sales.SalesTerritory AS B ON A.TerritoryID = B.TerritoryID
    GROUP BY B.Name, YEAR(A.OrderDate)
)
SELECT
    Land,
    År,
    FörsäljningsIntäkt,
    LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År) AS TidigareÅrFsg,
    CASE
        WHEN LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År) = 0 THEN NULL
        ELSE CONVERT(DECIMAL(10, 2), (FörsäljningsIntäkt - LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År)) / LAG(FörsäljningsIntäkt) OVER (PARTITION BY Land ORDER BY År))
    END AS FörsäljningsTillväxt
FROM ÅrligRegionalFörsäljning
ORDER BY Land, År;





