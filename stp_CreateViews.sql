USE [EDW]
GO

/****** Object:  StoredProcedure [dbo].[stp_ViewRefresh]    Script Date: 12/13/2016 9:07:48 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE  [dbo].[stp_ViewRefresh]
	
AS
BEGIN
SET NOCOUNT ON;
DECLARE @ViewCount   int                = 0;
DECLARE @Counter     int                = 0;
DECLARE @sql_drop         nvarchar(max)    = '';
DECLARE @sql_insert         nvarchar(max)    = '';
DECLARE @viewName    nvarchar(200)    = ''
DECLARE @Views    as TABLE (  rownum int identity(1,1), 
                              name nvarchar(200), 
                              Primary Key clustered  (rownum)
                            );

INSERT INTO  @Views (name)
SELECT       name 
FROM         sys.tables where schema_id = 1;

SET          @ViewCount = SCOPE_IDENTITY();

WHILE(@Counter < @ViewCount) BEGIN
    SET @Counter = @Counter+1;

	SELECT  @sql_drop = 'IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME = ''' + name +'_v'') 
						BEGIN 
							DROP VIEW ' + name +'_v; 
						END', @viewName = name
    FROM    @Views
    WHERE    rownum = @Counter;

	
	SELECT  @sql_insert = 'create view ' + name +'_v as select * from ' + name +';', @viewName = name
    FROM    @Views
    WHERE    rownum = @Counter;



    BEGIN TRY
        exec(@sql_drop); --careful you're not accepting user input here!
        --Print (@sql_drop);
		exec(@sql_insert); --careful you're not accepting user input here!
        --Print (@sql_insert);
    END TRY BEGIN CATCH
        Print ('ERROR querying view - ' + @viewname + ' // ' + ERROR_MESSAGE());
    END CATCH
END;    

END

GO


