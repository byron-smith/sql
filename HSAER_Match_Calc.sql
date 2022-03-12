USE [xxxxxx]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/************************************************************************************************************************************
Created by:            Byron Smith
Description:           Calculates the HSA employer contribution tied to the HSAEC earning code. Variations by pay frequency and medical plan.
HSAEC:
VAL(STR(tablevaluelookup("select 'M' as m, dbo.SF_2_HSAER('" + Str(MbtEEID) + "','" + Str(MbtCoID) + "') as Rate ",'m','M','Rate')))


************************************************************************************************************************************/
ALTER function [dbo].[SF_2_HSAER] (@EeID CHAR(12), @CoID CHAR(5))
	RETURNS DECIMAL(16, 4)

BEGIN

DECLARE @StartProRateDayCount DECIMAL(16, 4),
	@StopProRateDayCount DECIMAL(16, 4),
	@StartAndStopDayCount DECIMAL(16, 4),
	@EedStartDate DATE,
	@EedStopDate DATE,
	@DedCode VARCHAR(5),
	@DedOption VARCHAR(6),
	@HSARATE DECIMAL(16, 4),
	@Frequency VARCHAR(1),
	@MonthDays int,
	@PeriodStartDate DATE,
	@PeriodEndDate DATE


	SET @DedCode = (SELECT rtrim(ltrim(eedDedcode)) from EmpDed WITH ( NOLOCK ) 
					where eedeeid = @EeID
					and eedcoid = @CoID
					and eeddedcode in ('HD1A','HD2A','HD1H','HD2H','HD1B','HD2B','HD1E','HD2E','HD1V','HD2V','HD1S','HD2S')
					and (eedbenstatus = 'A' OR (eedbenstatus in ('T','C') AND eedstopdate > @PeriodStartDate)));
/*
	SET @EedStartDate = (SELECT TOP 1 eedstartdate from EmpDedFull WITH ( NOLOCK )
						 where eedeeid = @EeID
						 and eedcoid = @CoID
						 and eeddedcode = @DedCode
						 and eedstartdate = (select top 1 eedstartdate from empdedfull 
												where eedeeid = @EeID
												and eedcoid = @CoID
												and eeddedcode = @DedCode
												order by 1 desc));
*/


	SET @EedStartDate = (Select eedstartdate
							FROM dbo.EmpDedTV TV WITH (NOLOCK)
							INNER JOIN dbo.EmpDedTI TI WITH (NOLOCK) ON TV.EedEmpDedTIAuditKey = TI.AuditKey
							WHERE EedTVStartDate = ( SELECT MAX(EedTVStartDate) FROM dbo.EmpDedTV TV2 WITH ( NOLOCK )
							INNER JOIN ( SELECT TOP 1 SessionDate FROM   dbo.fnGetSessionDate()) x ON SessionDate >= TV2.EedTVStartDate WHERE    TI.AuditKey = TV2.EedEmpDedTIAuditKey) AND EedDeleted = 0
							and eedeeid = @EeID
							and eedcoid = @CoID
							and eeddedcode = @DedCode);

	SET @EedStopDate =  (Select eedstopdate
							FROM dbo.EmpDedTV TV WITH (NOLOCK)
							INNER JOIN dbo.EmpDedTI TI WITH (NOLOCK) ON TV.EedEmpDedTIAuditKey = TI.AuditKey
							WHERE EedTVStartDate = ( SELECT MAX(EedTVStartDate) FROM dbo.EmpDedTV TV2 WITH ( NOLOCK )
							INNER JOIN ( SELECT TOP 1 SessionDate FROM   dbo.fnGetSessionDate()) x ON SessionDate >= TV2.EedTVStartDate WHERE    TI.AuditKey = TV2.EedEmpDedTIAuditKey) AND EedDeleted = 0
							and eedeeid = @EeID
							and eedcoid = @CoID
							and eeddedcode = @DedCode);

/*
	SET @EedStopDate = CASE 
							WHEN (SELECT eedstopdate from EmpDed WITH ( NOLOCK ) where eedeeid = @EeID and eedcoid = @CoID and eeddedcode = @DedCode) IS NOT NULL 
							THEN (SELECT eedstopdate from EmpDed WITH ( NOLOCK ) where eedeeid = @EeID and eedcoid = @CoID and eeddedcode = @DedCode) 
							else NULL end;
*/	
	SET @DedOption = (SELECT rtrim(ltrim(eedbenoption)) from EmpDed WITH ( NOLOCK )
						where eedeeid = @EeID
						 and eedcoid = @CoID
						 and eeddedcode = @DedCode);

	SET @Frequency = (SELECT rtrim(ltrim(eecpayperiod)) from EmpComp WITH ( NOLOCK )
						where eeceeid = @EeID
						and eeccoid = @CoID);

	SET @MonthDays = (SELECT (datediff(dd, MbtPeriodStartDate, MbtPeriodEndDate) + 1) from M_batch WITH ( NOLOCK )
						where Mbtseqnum = '1'
						and mbteeid = @EeID
						and mbtcoid = @CoID);

	SET @PeriodStartDate = (select MbtPeriodStartDate from M_Batch WITH ( NOLOCK )
						where Mbtseqnum = '1'
						and mbteeid = @EeId
						and mbtcoid = @CoID); 

	SET @PeriodEndDate = (select MbtPeriodEndDate from M_Batch WITH ( NOLOCK )
						where Mbtseqnum = '1'
						and mbteeid = @EeId
						and mbtcoid = @CoID); 

	SET @StartProRateDayCount = DATEDIFF(dd, @Eedstartdate, @PeriodEndDate) + 1; 

	SET @StopProRateDayCount = CASE WHEN DATEDIFF(dd, @PeriodStartDate, @EedStopDate) + 1 < 32 THEN DATEDIFF(dd, @PeriodStartDate, @EedStopDate) + 1 ELSE 0 END;

	SET @StartAndStopDayCount = DATEDIFF(dd, @EedStartdate, @EedStopdate) + 1;

	SET @HSARATE = 
	
	CASE
	-- Condition for Start and Stop of code in same pay period
		WHEN @EedStartDate > @PeriodStartDate AND @EedStopdate <= @PeriodEndDate AND @Frequency = 'B'
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP', 'EEDP','DPSP','EECH', 'FAM','EEDPCH','DPFAM','DPCH') THEN (73.08/14) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (53.85/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN (80.77/14) * @StartAndStopDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (80.77/14) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (38.46/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (53.85/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (69.23/14) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (61.54/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1B','HD1E','HD1V','HD1S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (23.07/14) * @StartAndStopDayCount 
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (34.61/14) * @StartAndStopDayCount 
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (46.15/14) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2B','HD2E','HD2V','HD2S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (9.62/14) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (57.69/14) * @StartAndStopDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StartAndStopDayCount
							ELSE NULL
						END
					ELSE NULL
				END

		--Full amount conditions
		WHEN @EedStartDate <= @PeriodStartDate AND @Frequency = 'B' AND (@EedStopDate >= @PeriodEndDate OR @EedStopDate is null)
			THEN
				CASE 
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE 
							WHEN @DedOption = 'EE' THEN '46.15'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN '73.08'
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '53.85'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN '80.77'
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN '80.77'
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '38.46'
							WHEN @DedOption in ('EESP', 'EEDP','DPSP') THEN '53.85'
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN '69.23'
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '46.15'
							WHEN @DedOption in ('EESP', 'EEDP','DPSP') THEN '61.54'
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN '76.92'
							ELSE NULL
						END
				WHEN @DedCode in ('HD1B','HD1E','HD1V','HD1S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '23.07'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN '34.61'
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN '46.15'
							ELSE NULL
						END
				WHEN @DedCode in ('HD2B','HD2E','HD2V','HD2S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '9.62'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN '57.69'
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN '76.92'
							ELSE NULL
						END
			END
		-- New Hires mid pay period conditions
		WHEN @EedStartDate > @PeriodStartDate AND @EedStartDate <= @PeriodEndDate AND @Frequency = 'B' AND (@EedStopdate > @PeriodEndDate OR @EedStopDate is null)
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StartProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (73.08/14) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (53.85/14) * @StartProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN (80.77/14) * @StartProRateDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (80.77/14) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (38.46/14) * @StartProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (53.85/14) * @StartProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (69.23/14) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StartProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (61.54/14) * @StartProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1B','HD1E','HD1V','HD1S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (23.07/14) * @StartProRateDayCount 
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (34.61/14) * @StartProRateDayCount 
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (46.15/14) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2B','HD2E','HD2V','HD2S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (9.62/14) * @StartProRateDayCount
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (57.69/14) * @StartProRateDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StartProRateDayCount
							ELSE NULL
						END
					ELSE NULL
				END
		--Termination mid pay period conditions
		WHEN @EedStopDate >= @PeriodStartDate AND @EedStopDate < @PeriodEndDate AND @Frequency = 'B'
		--CAST(CONVERT(DATETIME, @EedStopDate) AS FLOAT) >= CAST(CONVERT(DATETIME, @PeriodStartDate) AS FLOAT) AND CAST(CONVERT(DATETIME, @EedStopDate) AS FLOAT) < CAST(CONVERT(DATETIME, @PeriodEndDate) AS FLOAT) AND @Frequency = 'B'
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StopProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (73.08/14) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (53.85/14) * @StopProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH','DPSP') THEN (80.77/14) * @StopProRateDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (80.77/14) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (38.46/14) * @StopProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (53.85/14) * @StopProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (69.23/14) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (46.15/14) * @StopProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (61.54/14) * @StopProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1B','HD1E','HD1V','HD1S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (23.07/14) * @StopProRateDayCount 
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (34.61/14) * @StopProRateDayCount 
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (46.15/14) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2B','HD2E','HD2V','HD2S')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (9.62/14) * @StopProRateDayCount
							WHEN @DedOption in ('EESP','EEDP', 'EECH','DPSP') THEN (57.69/14) * @StopProRateDayCount
							WHEN @DedOption in ('FAM','EEDPCH','DPFAM','DPCH') THEN (76.92/14) * @StopProRateDayCount
							ELSE NULL

						END

				END

--MONTHLY CALCS

-- Condition for Start and Stop of code in same pay period
		WHEN @EedStartDate > @PeriodStartDate AND @EedStopdate <= @PeriodEndDate AND @Frequency = 'M'
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (158.33/@MonthDays) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (116.67/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (175.00/@MonthDays) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (83.33/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (116.67/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (150.00/@MonthDays) * @StartAndStopDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (133.33/@MonthDays) * @StartAndStopDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (166.67/@MonthDays) * @StartAndStopDayCount
							ELSE NULL
						END
				END


--Full amount conditions
		WHEN @EedStartDate <= @PeriodStartDate AND @Frequency = 'M' AND (@EedStopDate >= @PeriodEndDate OR @EedStopDate is null)
			THEN
				CASE 
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE 
							WHEN @DedOption = 'EE' THEN '100.00'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN '158.33'
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '116.67'
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN '175.00'
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '83.33'
							WHEN @DedOption in ('EESP', 'EEDP','DPSP') THEN '116.67'
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN '150.00'
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN '100.00'
							WHEN @DedOption in ('EESP', 'EEDP','DPSP') THEN '133.33'
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN '166.67'
							ELSE NULL
						END
			END
		-- New Hires mid pay period conditions
		WHEN @EedStartDate > @PeriodStartDate AND @EedStartDate <= @PeriodEndDate AND @Frequency = 'M' AND (@EedStopdate > @PeriodEndDate OR @EedStopDate is null)
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (158.33/@MonthDays) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (116.67/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (175.00/@MonthDays) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (83.33/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (116.67/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (150.00/@MonthDays) * @StartProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (133.33/@MonthDays) * @StartProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (166.67/@MonthDays) * @StartProRateDayCount
							ELSE NULL
						END
				END
		--Termination mid pay period conditions
		WHEN @EedStopDate >= @PeriodStartDate AND @EedStopDate < @PeriodEndDate AND @Frequency = 'M'
			THEN
				CASE
				WHEN @DedCode in ('HD1A') 
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (158.33/@MonthDays) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2A')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (116.67/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EESP', 'EEDP', 'EECH', 'FAM','EEDPCH','DPFAM','DPCH','DPSP') THEN (175.00/@MonthDays) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD1H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (83.33/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (116.67/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (150.00/@MonthDays) * @StopProRateDayCount
							ELSE NULL
						END
				WHEN @DedCode in ('HD2H')
					THEN
						CASE
							WHEN @DedOption = 'EE' THEN (100.00/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EESP','EEDP','DPSP') THEN (133.33/@MonthDays) * @StopProRateDayCount
							WHEN @DedOption in ('EECH','FAM','EEDPCH','DPFAM','DPCH') THEN (166.67/@MonthDays) * @StopProRateDayCount
							ELSE NULL
						END

			END
ELSE NULL

END
RETURN @HSARATE;
end
GO
