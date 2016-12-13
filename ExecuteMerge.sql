CREATE PROCEDURE etl.ExecuteMerge
	@Schema VARCHAR(50)
	,@Table VARCHAR(50)
	,@NK VARCHAR(50)
	,@NK2 VARCHAR(50) = ''
	,@WHERE VARCHAR(500) = ''
	,@Deactivate BIT = 0
AS

DECLARE @SQL VARCHAR(MAX),@Column VARCHAR(50),@WhenMatched VARCHAR(MAX),@Update VARCHAR(MAX),@Insert VARCHAR(MAX),@Values VARCHAR(MAX)

SELECT @SQL = 'MERGE INTO ' + @Schema + '.' + @Table + ' Dest
USING (
	SELECT * FROM etl.v' + @Table + CASE WHEN @WHERE = '' THEN '' ELSE ' ' + @WHERE END + '
) AS Src
ON Dest.' + @NK + ' = Src.' + @NK + 
CASE WHEN @NK2 = '' THEN '' ELSE '
AND Dest.' + @NK2 + ' = Src.' + @NK2 END
,@WhenMatched = ''
,@Update = ''
,@Insert = ''
,@Values = ''

DECLARE _CURSOR_ CURSOR FOR
--SELECT b.name FROM sys.objects a INNER JOIN sys.columns b ON a.object_id = b.object_id AND a.name = @Table AND b.column_id <> 1
select COLUMN_NAME
from INFORMATION_SCHEMA.COLUMNS
where TABLE_SCHEMA = @Schema 
and TABLE_NAME = @Table
and ORDINAL_POSITION != 1
and DATA_TYPE != 'geography'
order by ORDINAL_POSITION


OPEN _CURSOR_
FETCH NEXT FROM _CURSOR_ INTO @Column
WHILE @@FETCH_STATUS = 0
BEGIN
	
	IF @Column NOT IN ('CreateUser','CreateDateTime','LastUpdateDateTime','LastUpdateUser',@NK,@NK2)
	BEGIN
		SELECT @WhenMatched = @WhenMatched + 'Src.' + @Column + ' != Dest.' + @Column + ' OR (Src.' + @Column + ' IS NULL AND Dest.' + @Column + ' IS NOT NULL) OR (Src.' + @Column + ' IS NOT NULL AND Dest.' + @Column + ' IS NULL) OR '
		SELECT @Update = @Update + @Column + ' = Src.' + @Column + ','
	END
	SELECT @Insert = @Insert + @Column + ',' 
	SELECT @Values = @Values + 'Src.' + @Column + ','

	FETCH NEXT FROM _CURSOR_ INTO @Column
END

CLOSE _CURSOR_
DEALLOCATE _CURSOR_

SELECT @SQL = @SQL + 
CASE WHEN LEN(@WhenMatched) = 0 THEN '' ELSE '
WHEN MATCHED AND Dest.IsActive = 1
AND (' + SUBSTRING(@WhenMatched,1,LEN(@WhenMatched)-3) + ')
THEN UPDATE SET ' + SUBSTRING(@Update,1,LEN(@Update)-1) + ',LastUpdateDateTime = Src.LastUpdateDateTime,LastUpdateUser = Src.LastUpdateUser' END + '
WHEN NOT MATCHED BY TARGET 
THEN INSERT(' + SUBSTRING(@Insert,1,LEN(@Insert)-1) + ')
VALUES(' + SUBSTRING(@Values,1,LEN(@Values)-1) + ')'

IF @Deactivate = 1 SELECT @SQL = @SQL + '
WHEN NOT MATCHED BY SOURCE AND (Dest.IsActive = 1)
THEN UPDATE
SET IsActive = 0
	,LastUpdateUser = ''ETL''
	,LastUpdateDateTime = GETDATE()'

SELECT @SQL = @SQL + '
;

INSERT INTO etl.RowCountLog(Name,RowCnt,ParentName) VALUES(''' + @Table + ''',@@ROWCOUNT,''ETL - Merge'')
	
UPDATE STATISTICS ' + @Schema + '.' + @Table + ';'

--PRINT @SQL
EXEC(@SQL)

--EXEC etl.ExecuteMerge 'Prefix','PrefixString'
--EXEC etl.ExecuteMerge 'Company','SourceID'