<#
Update IIS log to 
Create DB: 

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].DataBrowsingIISLog(
	[date] [varchar](MAX) NULL,
	[time] [varchar](MAX) NULL,
	[s-ip] [varchar](MAX) NULL,
	[cs-method] [varchar](MAX) NULL,
	[cs-uri-stem] [varchar](MAX) NULL,
	[cs-uri-query] [varchar](MAX) NULL,
	[s-port] [varchar](MAX) NULL,
	[cs-username] [varchar](MAX) NULL,
	[c-ip] [varchar](MAX) NULL,
	[cs(User-Agent)] [varchar](MAX) NULL,
	[cs(Referer)] [varchar](MAX) NULL,
	[sc-status] [varchar](MAX) NULL,
	[sc-substatus] [varchar](MAX) NULL,
	[sc-win32-status] [varchar](MAX) NULL,
	[time-taken] [varchar](MAX) NULL
) ON [PRIMARY]
GO

#>
function Convert-IISLogsToObject {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path -Path $_ })]
        [string[]]
        $path
    )

    Process {
        forEach($filePath in $path) {
            $headers = (Get-Content -Path $filePath -TotalCount 4 | Select -First 1 -Skip 3) -replace '#Fields: ' -split ' '
            Get-Content $filePath | Select-String -Pattern '^#' -NotMatch | ConvertFrom-Csv -Delimiter ' ' -Header $headers
        }
    }
}


function Get-Type 
{ 
    param($type) 
 
$types = @( 
'System.Boolean', 
'System.Byte[]', 
'System.Byte', 
'System.Char', 
'System.Datetime', 
'System.Decimal', 
'System.Double', 
'System.Guid', 
'System.Int16', 
'System.Int32', 
'System.Int64', 
'System.Single', 
'System.UInt16', 
'System.UInt32', 
'System.UInt64') 
 
    if ( $types -contains $type ) { 
        Write-Output "$type" 
    } 
    else { 
        Write-Output 'System.String' 
         
    } 
}

function Out-DataTable 
{ 
    [CmdletBinding()] 
    param([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$InputObject) 
 
    Begin 
    { 
        $dt = new-object Data.datatable   
        $First = $true  
    } 
    Process 
    { 
        foreach ($object in $InputObject) 
        { 
            $DR = $DT.NewRow()   
            foreach($property in $object.PsObject.get_properties()) 
            {   
                if ($first) 
                {   
                    $Col =  new-object Data.DataColumn   
                    $Col.ColumnName = $property.Name.ToString()   
                    if ($property.value) 
                    { 
                        if ($property.value -isnot [System.DBNull]) { 
                            $Col.DataType = [System.Type]::GetType("$(Get-Type $property.TypeNameOfValue)") 
                         } 
                    } 
                    $DT.Columns.Add($Col) 
                }   
                if ($property.Gettype().IsArray) { 
                    $DR.Item($property.Name) =$property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1 
                }   
               else { 
                    $DR.Item($property.Name) = $property.value 
                } 
            }   
            $DT.Rows.Add($DR)   
            $First = $false 
        } 
    }  
      
    End 
    { 
        Write-Output @(,($dt)) 
    } 
 
} #Out-DataTable

$logfiles = "IIS Log Files" #\LogFiles\W3SVC1\*
$dbserver="DB Server"
$database="Db Name"
$tablename="DataBrowsingIISLog"
$connectstring = "Data Source=$dbserver;Integrated Security=SSPI;Initial Catalog=$database"

$cn = new-object System.Data.SqlClient.SqlConnection($connectstring);
$cn.Open()
$bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn
$bc.BatchSize = 10000;
$bc.BulkCopyTimeout = 1000
$bc.DestinationTableName = $tablename

$data = ls $logfiles | Convert-IISLogsToObject | Out-DataTable

$bc.WriteToServer($data)
