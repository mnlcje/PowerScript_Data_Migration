$assemblylist = "MySql.Data", "Microsoft.SqlServer.Smo";

#Install-Module SqlServer

foreach ($asm in $assemblylist)
{  
    $asm = [Reflection.Assembly]::LoadWithPartialName($asm)  
}

Add-Type -AssemblyName System.Data

function ConnectSQL([string]$conString, [string]$MSSQLHost, [string]$mode) {
    #$conn = null;
    try {
        Write-Host "Trying to connect $MSSQLHost..." -ForegroundColor Green
        if($mode -eq "MySQL")
        {
            $conn = New-Object MySql.Data.MySqlClient.MySqlConnection($conString);
        } else {
            $conn = New-Object System.Data.SqlClient.SqlConnection($conString);
        }
        $conn.Open();
    }
    catch [System.Management.Automation.PSArgumentException] {
         Write-Host "Do you have the MSSQL connector installed..?"; Write-Host $_ ; Exit;
    }
    catch {
        Write-Host "Unable to connect to $MSSQLHost server..."
        Write-Host $_.Exception.GetType().FullName; Write-Host $_.Exception.Message; Exit;
    }
    Write-Host "Connected to $MSSQLHost..." -ForegroundColor Yellow;
    return $conn
}

function ExecuteSQLQuery($conn, [string]$query, [string]$mode) {
    $dataSet = New-Object System.Data.DataSet
    if($mode -eq 'MySQL')
    {
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $conn)
        $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd)
    } else
    {
        $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
        $dataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    }
    $dataAdapter.Fill($dataSet, "TableData") | Out-Null
    $cmd.Dispose();
    return $dataSet.Tables["TableData"]
}

function ExecuteNonQuery($conn, [string]$query, [string]$mode) {
    try {
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand $query, $conn
        $cmd.ExecuteNonQuery();
    }
    catch {
        Write-Host $query;
    }
}

function DisconnectSQL($conn) {
  $conn.Close();
}
