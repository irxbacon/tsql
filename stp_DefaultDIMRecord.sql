USE [EDW]
GO

/****** Object:  StoredProcedure [dbo].[stp_dim_DefaultRecord]    Script Date: 12/13/2016 9:07:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:        Brian Cox
-- Create date: 12-2-2016
-- Description:    iterates through each dimension table (dim_) that has a single warehouse key (wk_) and populates a record with a 0 ID.  
-- supplies the following defaults for not nullable fields
-- =============================================
-- CurrentMember : 1
-- EffectiveStartDate :1/1/1900 
-- EffectiveEndDate : 12/31/2070
-- int : 0
-- Decimal : 0
-- bit : 0
-- date 2005-04-26 (Phil Noakes was being difficult)
-- datetime : 2013-08-01 04:23:58 (Phil Noakes was being difficult)
-- varchar : Unknown
-- nvarchar : Unknown
-- char : N (we only used char(1) for boolean fields

-- =============================================
-- usage
-- exec [dbo].[stp_dim_DefaultRecord]
-- =============================================
/* left here for testing
	select * from  dim_Account where wk_account = 0
	delete from dim_Account where wk_account = 0
	delete from dim_ActivityCallType where wk_ActivityCallType = 0
	delete from dim_Contact where wk_contact = 0
*/	


CREATE PROCEDURE  [dbo].[stp_dim_DefaultRecord]
     
AS
BEGIN
SET NOCOUNT ON;
DECLARE @dimCount   int                = 0;
DECLARE @Counter     int                = 0;
DECLARE @tablename         nvarchar(max)    = '';
DECLARE @keyname        nvarchar(max)    = '';
DECLARE @recordCheck         nvarchar(max)    = '';
DECLARE @dimName    nvarchar(200)    = ''
DECLARE @dims as TABLE ( rownum int identity(1,1), 
                        tablename nvarchar(200), 
                        columnname nvarchar(200), 
                        Primary Key clustered  (rownum)
                        );
IF OBJECT_ID('tempdb..#fields') IS NOT NULL DROP TABLE #fields
create table #fields (  rownum int identity(1,1), 
        fieldname nvarchar(200), 
        typename nvarchar(200), 
        Primary Key clustered  (rownum)
    );


INSERT INTO  @dims (tablename, columnname)
select t.name, max(c.name)--, count(*)
from sys.tables t join sys.columns c on t.object_id = c.object_id
where t.schema_id = 1 and t.name like 'dim%' and c.name like 'wk%' -- and t.name = 'dim_OpportunityBookingGroupBridge'
group by t.name 
having count(*) =1;


SET @dimCount = SCOPE_IDENTITY();

WHILE(@Counter <  @dimCount) BEGIN
    SET @Counter = @Counter+1;
       
    SELECT  @tablename = tablename , @keyname = columnname        
    FROM    @dims
    WHERE    rownum = @Counter;
       
       exec('select * from  ' + @tablename +' where ' + @keyname + ' = 0') 
       --select @recordCheck =  (select count(*) from '@tablename')
						
	   if @@ROWCOUNT = 0 BEGIN
					truncate table #fields
					print @tablename + ' :: needs record'
                   
				    DECLARE @fieldCount   int                = 0;
					DECLARE @Counter2     int                = 0;
                          
					insert into #fields(fieldname, typename) 
                        select c.name, ty.name --, c.*  
                        from sys.tables t join sys.columns c on t.object_id = c.object_id
                        join sys.types ty on c.system_type_id =ty.system_type_id
                        where t.schema_id = 1 and t.name like @tablename and ty.name <> 'sysname' 
                        and c.is_nullable = 0 
                         
						select @fieldCount =  count(*) from #fields
						select * from #fields  -- debugging help

						if @fieldCount > 0  begin
						DECLARE @insertfields nvarchar(max)    = '';
						DECLARE @insertvalues nvarchar(max)    = '';
						DECLARE @insertfield nvarchar(max)    = '';
						DECLARE @insertvalue nvarchar(max)    = '';
						DECLARE @insertrecord nvarchar(max)    = '';
                        
                        WHILE(@Counter2 < @fieldCount) BEGIN
                                  SET @Counter2 = @Counter2+1;
									                 
                                  SELECT  @insertfield = fieldname , @insertvalue = typename           
                                  FROM    #fields
                                  WHERE    rownum = @Counter2;

                                  select 
                                         @insertfields = case 
                                                when @counter2 = 1 then 
                                                       @insertfield
                                                else @insertfields + ', ' + @insertfield
                                                end,
                                         @insertvalues = case
                                                when @counter2 = 1 and @insertfield = 'CurrentMember' then 
                                                       '1'
                                                when @counter2 != 1 and @insertfield = 'CurrentMember' then 
                                                       @insertvalues +  ', 1' 

                                                when @counter2 = 1 and @insertfield = 'EffectiveStartDate' then 
                                                        '''1900-01-01'''
                                                when @counter2 != 1 and @insertfield = 'EffectiveStartDate' then 
                                                       @insertvalues +  ', ''1900-01-01'''

												when @counter2 = 1 and @insertfield = 'EffectiveEndDate' then 
                                                        '''2070-12-31'''
                                                when @counter2 != 1 and @insertfield = 'EffectiveEndDate' then 
                                                       @insertvalues +  ', ''2070-12-31'''

                                                when @counter2 = 1 and @insertvalue like '%int' then 
                                                       '0'
                                                when @counter2 != 1 and @insertvalue like '%int' then 
                                                       @insertvalues +  ', 0' 

                                                when @counter2 = 1 and @insertvalue like 'decimal' then 
                                                       '0'
                                                when @counter2 != 1 and @insertvalue like 'decimal' then 
                                                       @insertvalues +  ', 0' 

                                                when @counter2 = 1 and @insertvalue = 'bit' then 
                                                       '0'
                                                when @counter2 != 1 and @insertvalue = 'bit' then 
                                                       @insertvalues +  ', 0' 

                                                when @counter2 = 1 and @insertvalue = 'date' then 
                                                       '''2005-04-26'''
                                                when @counter2 != 1 and @insertvalue = 'date' then 
                                                       @insertvalues +  ', ''2005-04-26'''

                                                when @counter2 = 1 and @insertvalue = 'datetime' then 
                                                       '''2013-08-01 04:23:58'''
                                                when @counter2 != 1 and @insertvalue = 'datetime' then 
                                                       @insertvalues +  ', ''2013-08-01 04:23:58'''

                                                when @counter2 = 1 and (@insertvalue = 'varchar'  or @insertvalue = 'nvarchar' ) then 
                                                       '''Unknown'''
                                                when @counter2 != 1 and (@insertvalue = 'varchar'  or @insertvalue = 'nvarchar' ) then 
                                                       @insertvalues +  ', ''Unknown''' 

                                                 when @counter2 = 1 and (@insertvalue = 'char') then 
                                                       '''N'''
                                                when @counter2 != 1 and (@insertvalue = 'char') then 
                                                       @insertvalues +  ', ''N''' 
                                                else @insertvalues
                                         end
                        -- print 'a  ' + cast(@counter2 as varchar(20)) + ' :: ' + @insertfields + ' :: ' +@insertvalues 
                           
                        select @insertrecord = 'set identity_insert ' + @tablename + ' on; insert into ' +@tablename +'('+ @insertfields + ' ) values ( ' + @insertvalues + ')'
						
                        end   
                   

       BEGIN TRY
                           print @insertrecord -- debugging, print out the attempted insert
						   --exec ('set identity_insert ' + @tablename + ' on;')  -- this is now part of the insert record
                           exec(@insertrecord) 
                           exec ('set identity_insert ' + @tablename + ' off')

		END TRY 
		BEGIN CATCH
			Print ('ERROR inserting into - ' + @tablename + ' // ' + ERROR_MESSAGE());
			print @insertrecord
		END CATCH
		end
END;    
end
END


GO


