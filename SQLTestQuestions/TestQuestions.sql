USE PERSONDATABASE

/*********************
Hello! 

Please use the test data provided in the file 'PersonDatabase' to answer the following
questions. Please also import the dbo.Contracts flat file to a table for use. 

All answers should be written in SQL. 


***********************

QUESTION 1


The table dbo.Person contains basic demographic information. The source system users 
input nicknames as strings inside parenthesis. Write a query or group of queries to 
return the full name and nickname of each person. The nickname should contain only letters 
or be blank if no nickname exists.

**********************/

GO
--Create schema
IF NOT EXISTS(SELECT TOP 1 [name] FROM sys.schemas WHERE [name] = 'Utility')
BEGIN
	EXEC('CREATE SCHEMA Utility')
	PRINT 'CREATED SCHEMA'
END
GO
--Create function
IF OBJECT_ID('Utility.fnuRemoveNonAlphabetical') IS NULL EXEC('CREATE FUNCTION Utility.fnuRemoveNonAlphabetical(@int int) returns int as begin return @int end')
GO
ALTER FUNCTION Utility.fnuRemoveNonAlphabetical
(
	@vc_ValuePassed VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
	SET @vc_ValuePassed = REPLACE(@vc_ValuePassed, substring(@vc_ValuePassed, patindex('%[^a-zA-Z ]%', @vc_ValuePassed), 1), '') --<== Blatently stolen without remorse from: https://searchsqlserver.techtarget.com/tip/Replacing-non-alphanumeric-characters-in-strings-using-T-SQL
	RETURN @vc_ValuePassed
END
GO

--Do actual work
SELECT	REPLACE(LTRIM(RTRIM(Utility.fnuRemoveNonAlphabetical(REPLACE(PersonName,SUBSTRING(PersonName, CASE WHEN Pos1 > 0 THEN Pos1 ELSE 0 END, CASE WHEN Pos2 > 0 THEN Pos2 - Pos1 + 1 ELSE Pos1 END),'')))),' ',' ') AS PersonName
		,LTRIM(RTRIM(Utility.fnuRemoveNonAlphabetical(SUBSTRING(PersonName, CASE WHEN Pos1 > 0 THEN Pos1 + 1 ELSE 0 END, CASE WHEN Pos2 > 0 THEN Pos2 - Pos1 - 1 ELSE Pos1 END)))) AS PersonNickName
FROM(
	SELECT	CHARINDEX('(',PersonName,1) AS Pos1
			,CHARINDEX(')',PersonName,1) AS Pos2
			,PersonName
	FROM	dbo.Person
)X


/**********************

QUESTION 2


The dbo.Risk table contains risk and risk level data for persons over time for various 
payers. Write a query that returns patient name and their current risk level. 
For patients with multiple current risk levels return only one level so that Gold > Silver > Bronze.


**********************/

WITH cte_AllRiskLevels AS (
	SELECT		PersonName, RiskLevel, RiskDateTime
				,ROW_NUMBER()OVER(PARTITION BY PersonName ORDER BY RiskDateTime DESC, CASE WHEN  RiskLevel = 'Gold' THEN 1 WHEN RiskLevel = 'Silver' THEN 2 WHEN RiskLevel = 'Bronze' THEN 3 ELSE 9 END) AS SequenceId
	FROM		dbo.Risk R
	INNER JOIN	dbo.Person P
				ON P.PersonID = R.PersonID
)

SELECT	PersonName, RiskLevel
FROM	cte_AllRiskLevels
WHERE	SequenceId = 1





/**********************

QUESTION 3

Create a patient matching stored procedure that accepts (first name, last name, dob and sex) as parameters and 
and calculates a match score from the Person table based on the parameters given. If the parameters do not match the existing 
data exactly, create a partial match check using the weights below to assign partial credit for each. Return PatientIDs and the
 calculated match score. Feel free to modify or create any objects necessary in PersonDatabase.  

FirstName 
	Full Credit = 1
	Partial Credit = .5

LastName 
	Full Credit = .8
	Partial Credit = .4

Dob 
	Full Credit = .75
	Partial Credit = .3

Sex 
	Full Credit = .6
	Partial Credit = .25


**********************/

IF OBJECT_ID('dbo.spuPatientPatching') IS NULL EXEC('CREATE PROCEDURE dbo.spuPatientPatching AS SELECT 1 AS [A]')
GO
ALTER PROCEDURE dbo.spuPatientPatching(
	@vc_FirstName VARCHAR(255)
	,@vc_LastName VARCHAR(255)
	,@dte_DOB DATE
	,@vc_Sex VARCHAR(10)
)
AS
	/*Testing
		DECLARE @vc_FirstName VARCHAR(255) = 'Azra'
		DECLARE @vc_LastName VARCHAR(255) = 'MagnuDDs'
		DECLARE @dte_DOB DATE = '1997-07-24'
		DECLARE @vc_Sex CHAR(1) = 'M'
	--*/
	DECLARE @tbl_PersonMatch TABLE (
		PersonId INT
		,MatchScore NUMERIC(4,2)
	)

	--For exact matchines
	INSERT INTO @tbl_PersonMatch
	SELECT	PersonId, 3.15
	FROM(
		SELECT	REPLACE(LTRIM(RTRIM(Utility.fnuRemoveNonAlphabetical(REPLACE(PersonName,SUBSTRING(PersonName, CASE WHEN Pos1 > 0 THEN Pos1 ELSE 0 END, CASE WHEN Pos2 > 0 THEN Pos2 - Pos1 + 1 ELSE Pos1 END),'')))),'  ',' ') AS PersonName
				,DateOfBirth, Sex, PersonId
		FROM(
			SELECT	CHARINDEX('(',PersonName,1) AS Pos1
					,CHARINDEX(')',PersonName,1) AS Pos2
					,PersonName
					,CAST(DateOfBirth AS DATE) AS DateOfBirth
					,Sex
					,PersonId
			FROM	dbo.Person
		)X
	)X
	WHERE	X.PersonName = LTRIM(RTRIM(@vc_FirstName)) + ' ' + LTRIM(RTRIM(@vc_LastName))
			AND X.DateOfBirth = @dte_DOB
			AND X.Sex = @vc_Sex

	IF EXISTS(SELECT TOP 1 PersonId FROM @tbl_PersonMatch) 
	BEGIN
		SELECT	PersonId, 'Perfect Match' AS MatchResult
		FROM	@tbl_PersonMatch
	END
	
	--For when there is no exact match
	IF NOT EXISTS(SELECT TOP 1 PersonId FROM @tbl_PersonMatch) 
	BEGIN
		;WITH cte_Formatting AS (--Setup data for formatting
			SELECT	SUBSTRING(PersonName, 1, CHARINDEX(' ', PersonName,1) - 1) AS FirstName
					,SUBSTRING(PersonName, CHARINDEX(' ', PersonName,1) + 1, 255) AS LastName
					,DateOfBirth, Sex, PersonId
			FROM(
				SELECT	REPLACE(LTRIM(RTRIM(Utility.fnuRemoveNonAlphabetical(REPLACE(PersonName,SUBSTRING(PersonName, CASE WHEN Pos1 > 0 THEN Pos1 ELSE 0 END, CASE WHEN Pos2 > 0 THEN Pos2 - Pos1 + 1 ELSE Pos1 END),'')))),'  ',' ') AS PersonName
						,DateOfBirth, Sex, PersonId
				FROM(
					SELECT	CHARINDEX('(',PersonName,1) AS Pos1
							,CHARINDEX(')',PersonName,1) AS Pos2
							,PersonName
							,CAST(DateOfBirth AS DATE) AS DateOfBirth
							,Sex
							,PersonId
					FROM	dbo.Person
				)X
			)X
		)
		, cte_Calculation AS (--Use formatted data for calc as indicated above
			SELECT	PersonId
					,CASE WHEN FirstName = LTRIM(RTRIM(@vc_FirstName)) THEN 1
						WHEN DIFFERENCE(FirstName,LTRIM(RTRIM(@vc_FirstName))) >= 3 THEN 0.5
						ELSE 0 END AS FirstNameScore
					,CASE WHEN LastName = LTRIM(RTRIM(@vc_FirstName)) THEN 0.8
						WHEN DIFFERENCE(LastName,LTRIM(RTRIM(@vc_FirstName))) >= 3 THEN 0.4
						ELSE 0 END AS LastNameScore
					,CASE WHEN DateOfBirth = @dte_DOB THEN 0.75
						WHEN DIFFERENCE(DateOfBirth,@dte_DOB) >= 3 THEN 0.3
						ELSE 0 END AS DOBScore
					,CASE WHEN Sex = @vc_Sex THEN 0.6
						WHEN DIFFERENCE(Sex,@vc_Sex) >= 3 THEN 0.25
						ELSE 0 END AS SexScore
			FROM	cte_Formatting
		)
		
		INSERT INTO @tbl_PersonMatch
		SELECT	PersonId, FirstNameScore + LastNameScore + DOBScore + SexScore
		FROM	cte_Calculation
		
		--Display match score
		SELECT	PersonId, 'Match score is ' + CAST(MatchScore AS VARCHAR(5)) + ' out of possible 3.15. Percent of match is ' + CAST(CAST(MatchScore/3.15 * 100 AS NUMERIC(5,2)) AS VARCHAR(10)) AS MatchResult
		FROM	@tbl_PersonMatch
		WHERE	MatchScore > 1
	END
GO









/**********************

QUESTION 4

A. Looking at the script 'PersonDatabase', what change(s) to the tables could be made to improve the database structure?  

B. What method(s) could we use to standardize the data allowed in dbo.Person (Sex) to only allow 'Male' or 'Female'?

C. Assuming these tables will grow very large, what other database tools/objects could we use to ensure they remain
efficient when queried?


**********************/

/*
A.
	Create file groups to be used by tables/indexes of or tables of differing types/usage.
	Create primary keys
	Create foreign key constraints
	Build clustered/non-clustered
	I'd like to use Date for DOB instead of DateTime

B.
	In order of my preference:
		1) add a constraint to check of allowed values
		2) Build a foreign key reference to a dimGender table
		3) Apply a trigger to checks the values inserted/updated and throws an error or applies some form of correction based on DIFFERENCE or pre-known values such as changing M to Male.

	
C.	
	Build out address table to join on person table for cases where multiple persons reside at the same residence
	Partition tables by relevant column(s)
		maybe we could split PersonName into First, Middle, Last, NickName and partition by last name, or DatOfBirth depending on data and usage
		We could partition Risk by date, or risklevel, or even PersonId, or some combination thereof.
	Build out necessary indexes from question A, but also implement a maintenance plan to reorg/rebuild these indexes.



*/	








/**********************

QUESTION 5

Write a query to return risk data for all patients, all contracts and a moving average of risk for that patient and contract 
in dbo.Risk. 

**********************/

SELECT		r.*,c.ContractStartDate
			,AVG(RiskScore) OVER (ORDER BY RiskDateTime ASC ROWS 3 PRECEDING) 
FROM		dbo.Risk r
INNER JOIN	dbo.Person p
			ON p.PersonID = r.PersonID
--INNER JOIN	dbo.Contracts c
--			ON c.PersonId = p.PersonId
--INNER JOIN	dbo.Dates d
--			ON d.DateValue  BETWEEN c.ContractStartDate AND c.ContractEndDate 







/**********************

QUESTION 6

Write script to load the dbo.Dates table with all applicable data elements for dates 
between 1/1/2010 and 500 days past the current date.


**********************/

GO
TRUNCATE TABLE dbo.Dates

;WITH cte_DateList AS (
	SELECT CAST('2010-01-1' AS DATE) AS DateValue
	UNION ALL
	SELECT DATEADD(D,1,DateValue)
	FROM   cte_DateList
	WHERE  DateValue <= DATEADD(D,500,GETDATE())
)

INSERT INTO dbo.Dates
SELECT	DateValue
		,DATEPART(D,DateValue) AS DateDayofMonth
		,DATEPART(DY,DateValue) AS DateDayofYear
		--,ROW_NUMBER()OVER(PARTITION BY YEAR(DateValue), DATEPART(Q,DateValue) ORDER BY DateValue) AS DateQuarter /*Day of the quarter, or the quarter?*/
		,DATEPART(QQ,DateValue) AS DateQuarter
		,DATEPART(DW,DateValue) AS DateWeekdayName
		,DATENAME(MONTH,DateValue) AS DateMonthName
		--,CAST(YEAR(DateValue) AS CHAR(4)) + ' - ' + DATENAME(MONTH,DateValue) AS DateYearMonth 
		,CAST(YEAR(DateValue) AS CHAR(4)) + RIGHT('0' + CAST(DATEPART(MM,DateValue) AS VARCHAR(2)),2)
FROM	cte_DateList
OPTION	(MAXRECURSION 0)
--In the interest of full discloser, I used google to figure out the keywords for each of the date parts.

--SELECT * FROM dbo.Dates





/**********************

QUESTION 7

Please import the data from the flat file dbo.Contracts.txt to a table to complete this question. 

Using the data in dbo.Contracts, create a query that returns 

	(PersonID, AttributionStartDate, AttributionEndDate) 

The data should be structured so that rows with contiguous ranges are merged into a single row. Rows that contain a 
break in time of 1 day or more should be entered as a new record in the output. Restarting a row for a new 
month or year is not necessary.

Use the dbo.Dates table if helpful.

**********************/
--Inserted into dbo.Contracts using SSMS GUI task


/*Sincere apologies for what you are about to encounter*/
ALTER TABLE dbo.Contracts
ADD ContractId INT

/*Setup a sequence/order to utilize in the updates*/
;WITH cte_Contracts AS (
	SELECT	*,ROW_NUMBER()OVER(ORDER BY PersonId, ContractStartDate) AS SequenceId
	FROM	dbo.Contracts
)

UPDATE	cte_Contracts
SET		ContractId = SequenceId

/*Delete Duplicate or completely encompassed dates*/
DELETE	dbo.Contracts_Test1 
WHERE	ContractId IN (
	SELECT		CASE WHEN c1.ContractStartDate = c2.ContractStartDate AND c1.ContractEndDate = c2.ContractEndDate AND c1.ContractId > c2.ContractId THEN NULL ELSE c2.ContractId END AS ContractId
	FROM		dbo.Contracts_Test1 c1
	inner join	dbo.Contracts_Test1 c2
				on c2.PersonId = c1.PersonId
				AND c2.ContractId != c1.ContractId
				AND c2.ContractStartDate BETWEEN c1.ContractStartDate AND c1.ContractEndDate
				AND c2.ContractEndDate BETWEEN c1.ContractStartDate AND c1.ContractEndDate
	)

/*Reference data for identifying what are overlaps*/
IF OBJECT_ID('tempdb..#TempBase') IS NOT NULL DROP TABLE #TempBase
SELECT	ContractId, PersonID, ContractStartDate, ContractEndDate
		,lead(Contractid,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS NextContractid
		,lead(ContractStartDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS NextStartDate
		,lead(ContractEndDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS NextEndDate
		,lag(Contractid,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS PriorContractid
		,lag(ContractStartDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS PriorStartDate
		,lag(ContractEndDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) AS PriorEndDate
		,CASE WHEN lead(ContractStartDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) BETWEEN ContractStartDate AND dateadd(d,1,ContractEndDate) THEN 1 
			WHEN lag(ContractEndDate,1) OVER(PARTITION BY PersonId ORDER BY ContractStartDate, ContractId) BETWEEN dateadd(d,-1,ContractStartDate) AND ContractEndDate THEN 1
			ELSE 0 END AS UpdatesNeeded
		,CAST(NULL AS VARCHAR(100)) AS UpdateInfo
INTO	#TempBase
FROM	dbo.Contracts

/*Easy identification of source start date*/
UPDATE #TempBase
SET		UpdateInfo = CASE WHEN ContractStartDate BETWEEN PriorStartDate AND DATEADD(D,1,PriorEndDate) THEN 'Continue' ELSE 'Restart' END 
		

/*Big 'ole crazy, 2AM loop*/
DECLARE @int_PersonId INT 
DECLARE @dte_ContractStartDate DATE
DECLARE @int_ContractId INT = 1
WHILE @int_ContractId <= (SELECT MAX(ContractId) FROM #TempBase)
BEGIN
	IF(SELECT UpdateInfo FROM #TempBase WHERE ContractId = @int_ContractId) = 'Restart'
	BEGIN
		SET @dte_ContractStartDate = (SELECT ContractStartDate FROM #TempBase WHERE ContractId = @int_ContractId)
		SET @int_PersonId = (SELECT PersonId FROM #TempBase WHERE ContractId = @int_ContractId)
		UPDATE	#TempBase 
		SET		UpdateInfo = @dte_ContractStartDate
		WHERE	ContractId = @int_ContractId
	END
	IF(SELECT UpdatesNeeded FROM #TempBase WHERE ContractId = @int_ContractId) = 1 AND (SELECT UpdateInfo FROM #TempBase WHERE ContractId = @int_ContractId) = 'Continue'
	BEGIN
		WHILE(SELECT UpdatesNeeded FROM #TempBase WHERE ContractId = @int_ContractId) = 1 
			AND (SELECT UpdateInfo FROM #TempBase WHERE ContractId = @int_ContractId) = 'Continue'
			AND (SELECT PersonId FROM #TempBase WHERE ContractId = @int_ContractId) = @int_PersonId
		BEGIN
			UPDATE	#TempBase 
			SET		UpdateInfo = @dte_ContractStartDate
			WHERE	ContractId = @int_ContractId

			SET @int_ContractId += 1
			PRINT 'Inner Loop' + CAST(@int_ContractId AS VARCHAR(2))
		END
	END
	ELSE
	BEGIN
		SET @int_ContractId += 1	
	END
	PRINT 'End Loop ' + CAST(@int_ContractId AS VARCHAR(2))
	
END

/*Cleanup*/
ALTER TABLE dbo.Contracts DROP COLUMN Contractid
TRUNCATE TABLE dbo.Contracts

/*Updated Information*/
INSERT INTO dbo.Contracts
SELECT		PersonId, CAST(UpdateInfo AS DATE) AS ContractStartDate, MAX(ContractEndDate) AS ContractEndDate
FROM		#TempBase
GROUP BY	PersonId, CAST(UpdateInfo AS DATE) 

