CREATE PROCEDURE etl.ExecuteType2Merge
  @Schema VARCHAR(5)
	,@Table VARCHAR(50)
	,@NK VARCHAR(50)
	,@NK2 VARCHAR(50) = ''
	,@WHERE VARCHAR(500) = ''
	,@Deactivate BIT = 0
AS

DECLARE @SQL NVARCHAR(MAX),@Column VARCHAR(128),@WhenMatched VARCHAR(MAX),@Update VARCHAR(MAX),@Insert VARCHAR(MAX),@Values VARCHAR(MAX), @TempTableSQL VARCHAR(MAX), @DataType VARCHAR(128), @MaxLength VARCHAR(128)

select @SQL = '', @TempTableSQL = '', @WhenMatched = '', @Update = '', @Insert = '', @Values = ''

DECLARE _CURSOR_ CURSOR FOR
select COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
from INFORMATION_SCHEMA.COLUMNS
where TABLE_SCHEMA = @Schema 
and TABLE_NAME = @Table
and ORDINAL_POSITION != 1
order by ORDINAL_POSITION

OPEN _CURSOR_
FETCH NEXT FROM _CURSOR_ INTO @Column, @DataType, @MaxLength
WHILE @@FETCH_STATUS = 0
BEGIN
	--PRINT @Column
	IF @Column NOT IN ('CreateUser','CreateDateTime','LastUpdateDateTime','LastUpdateUser',@NK,@NK2)
	BEGIN
		If @Column NOT IN ('CurrentRecordIndicator','BeginEffectiveDate','EndEffectiveDate')
			if @DataType = 'geography'
				SELECT @WhenMatched = @WhenMatched + 'convert(varchar(1000), Src.' + @Column + ') != convert(varchar(1000), Dest.' + @Column + ') OR (Src.' + @Column + ' IS NULL AND Dest.' + @Column + ' IS NOT NULL) OR (Src.' + @Column + ' IS NOT NULL AND Dest.' + @Column + ' IS NULL) OR '
			else
				SELECT @WhenMatched = @WhenMatched + 'Src.' + @Column + ' != Dest.' + @Column + ' OR (Src.' + @Column + ' IS NULL AND Dest.' + @Column + ' IS NOT NULL) OR (Src.' + @Column + ' IS NOT NULL AND Dest.' + @Column + ' IS NULL) OR '
			
		SELECT @Update = @Update + @Column + ' = Src.' + @Column + ','
	END

	IF @Column NOT IN ('CurrentRecordIndicator','BeginEffectiveDate','EndEffectiveDate')
		SELECT @Values = @Values + 'Src.' + @Column + ','
		
	SELECT @Insert = @Insert + @Column + ',' 
	
	if @MaxLength is null or @DataType = 'geography'
		SELECT @TempTableSQL = @TempTableSQL + '[' + @Column + '] ' + @DataType + ',' 
	else
		if @MaxLength = -1
			SELECT @TempTableSQL = @TempTableSQL + '[' + @Column + '] ' + @DataType + '(MAX),' 
		else
			SELECT @TempTableSQL = @TempTableSQL + '[' + @Column + '] ' + @DataType + '(' + @MaxLength + '),' 

	FETCH NEXT FROM _CURSOR_ INTO @Column, @DataType, @MaxLength
END

CLOSE _CURSOR_
DEALLOCATE _CURSOR_

--Create temp table based on target
SELECT @SQL = 'DECLARE @' + @Table + ' TABLE (
		' + SUBSTRING(@TempTableSQL,1,LEN(RTRIM(@TempTableSQL))-1) + ')

'

--Create merge statement
SELECT @SQL = @SQL + 'INSERT INTO @' + @Table + '
SELECT ' + SUBSTRING(@Insert,1,LEN(@Insert)-1) + '
FROM (
MERGE ' + @Schema + '.' + @Table + ' Dest
USING etl.v' + @Table + ' Src
ON Dest.' + @NK	+ ' = Src.' + @NK +
CASE WHEN @NK2 = '' THEN '' ELSE '
AND Dest.' + @NK2 + ' = Src.' + @NK2 END + '
WHEN NOT MATCHED THEN
INSERT VALUES (' + SUBSTRING(@Values,1,LEN(@Values)-1) + ', 1, getdate()-1, cast(''12/31/9999'' as date))
WHEN MATCHED AND Dest.CurrentRecordIndicator = 1
AND (
' + SUBSTRING(@WhenMatched,1,LEN(@WhenMatched)-3) + '
) THEN
UPDATE SET Dest.CurrentRecordIndicator = 0, Dest.EndEffectiveDate = getdate()- 2
OUTPUT $Action Action_Out, ' + SUBSTRING(@Values,1,LEN(@Values)-1) + ', getdate()-1 as BeginEffectiveDate, cast(''12/31/9999'' as date) as EndEffectiveDate, 1 as CurrentRecordIndicator
) AS MERGE_OUT
WHERE MERGE_OUT.Action_Out = ''UPDATE''

'

SELECT @SQL = @SQL + 'INSERT INTO ' + @Schema + '.' + @Table + '
SELECT ' + SUBSTRING(@Insert,1,LEN(@Insert)-1) + '
FROM @' + @Table + '

INSERT INTO etl.RowCountLog(Name,RowCnt,ParentName) VALUES(''' + @Table + ''',@@ROWCOUNT,''ETL - Merge'')
	
UPDATE STATISTICS ' + @Schema + '.' + @Table + ';'

--SELECT @SQL
EXEC (@SQL)

--EXEC etl.ExecuteType2Merge 'Member','MemberId'
--EXEC etl.ExecuteType2Merge 'CampaignMember','CampaignMemberID'