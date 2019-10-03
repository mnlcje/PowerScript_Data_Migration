param (
    [string]$oFlowDBName,
    [string]$oFlowPlantID
)

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent; . ("$ScriptDirectory\CommonFunction.ps1");

$msSqlConString = "Server=usubofldbpv1.global.iff.com;Database=$oFlowDBName;Integrated Security=true;";
$mySqlConString = "server=oflowdev.cwm3ubatqbgi.us-east-1.rds.amazonaws.com;port=3306;uid=oFlowDevuser;pwd=#7ZNbeba9fHG;database=oflow-app;Pooling=FALSE";

$queryInsert = '';

function insertMaterials($oFlowV1Con, $oFlowV2Con) {
    $sourceQuery = "SELECT Material, MatDesc, Plant, HAZ, DEA, FTZ, CITES FROM OF_IMPMasterData";


    $materials = ExecuteSQLQuery $oFlowV1Con $sourceQuery "MSSQL";
    Write-Host ("Found " + $materials.rows.count + " rows...") -ForegroundColor Yellow;

    $iMaterialCout = $materials.rows.count; $iLoop = 0;
    foreach($material in $materials)
    {
        #Write-Host $material.Material $material.MatDesc;
        
        $queryInsert = "INSERT INTO Import_MaterialInfo (PlantID, MaterialNo, DeliveredToPlant, HeatAffectedZone, " + 
                       "DrugEnforcementAdministration, ForeignTradeZone, Cites, CreatedBy, CreatedOn) VALUES ('" + $oFlowPlantID + "', " + 
                       "'" + $material.Material.PadLeft(18, "0") + "', '" + $material.Plant + "', '" + $(If ($material.HAZ -eq "") {null} Else {$material.HAZ}) + "', '" + $material.DEA + "', '" + $material.FTZ + "', '" + 
                       $material.CITES + "', 'NXD7826', NOW());"
        
        $iLoop = $iLoop + 1;$progressTitle = $material.MatDesc;
        Write-Progress -Activity Updating -Status "Inserting $progressTitle" -PercentComplete ($iLoop / $iMaterialCout * 100)
        ExecuteNonQuery $oFlowV2Con $queryInsert "MySQL";
    }
}

function insertConsolidation($oFlowV1Con, $oFlowV2Con) {
    $oFlowConID = 999;
    $sourceQuery = "SELECT idCons, ConsType, IntInvoiceNo, Vessel, Line, BLInfo, Container, Packages, Shipper, Country, InvoiceInfo, ISF, 
                    ShipTerms, Location, COFMA, ITNumber, DeliverTo, LoadingPortStaging, LoadingPortStagingDate, LoadingPortFinDest, 
                    LoadingPortFinDestDate, Comments, Creator, CRTimeStamp, ContainerType, Creator, CONVERT(VARCHAR, CRTimeStamp, 121) AS CRTimeStamp FROM OF_IMPCons";

    $consolidations = ExecuteSQLQuery $oFlowV1Con $sourceQuery "MSSQL";
    #Write-Host ("Found " + $consolidation.rows.count + " rows...") -ForegroundColor Yellow;

    $iConsolidationCount = $consolidations.rows.count; $iLoop = 0;
    foreach($consolidation in $consolidations)
    {
        if($consolidation.idCons -ge 7) { 
            $oFlowConID = $oFlowConID + 1;
            $queryInsert = "INSERT INTO Import_Consolidation (ConsolidationID, PlantID, Type, InvoiceNo, Vessel, Line, BLInfo, Container, Shipper, Country, 
                            InvoiceInfo, ISF, ShipTerms, ContainerType, COFMA, ITNumber, DeliverTo, LoadingPortStaging, LoadingPortStagingDate, LoadingPortFinDestDate, 
                            Comments, CreatedBy, CreatedOn) VALUES ('" + $oFlowConID + "', '" + $oFlowPlantID + "', '" + $consolidation.ConsType + "', '" + $consolidation.IntInvoiceNo + 
                            "', '" + $consolidation.Vessel + "', '" + $consolidation.Line + "', '" + $consolidation.BLInfo + "', '" + $consolidation.Container + 
                            "', '" + $consolidation.Shipper + "', '" + $consolidation.Country + "', '" + $consolidation.InvoiceInfo + "', '" + $consolidation.ISF + 
                            "', '" + $consolidation.ShipTerms + "', '" + $consolidation.ContainerType + "', '" + $consolidation.COFMA + "', '" + $consolidation.ITNumber + 
                            "', '" + $consolidation.DeliverTo + "', '" + $consolidation.LoadingPortStaging + "', '" + $consolidation.LoadingPortStagingDate + 
                            "', '" + $consolidation.LoadingPortFinDest + "', '" + $consolidation.Comments + "', '" + $consolidation.Creator + "', CAST('" + $consolidation.CRTimeStamp + "' AS DATETIME));";
            $progressTitle = $consolidation.Vessel;
            $rowAffected = ExecuteNonQuery $oFlowV2Con $queryInsert "MySQL";
            insertConsolidationPO $oFlowV1Con $oFlowV2Con $oFlowConID $consolidation.idCons; #insert Cons PO
        }
        $iLoop = $iLoop + 1;
        Write-Progress -Activity Updating -Status "Inserting Consolidation $progressTitle" -PercentComplete ($iLoop / $iConsolidationCount * 100)
    }

    DataCleanupActivity $oFlowV2Con;
}

function insertConsolidationPO($oFlowV1Con, $oFlowV2Con, $newConsolidationNo, $olsConsolidationNo) {
    if($olsConsolidationNo -ge 7) { 
        $sourceQuery = "SELECT idCons, PONumber, Material, Delivery, OrdQty, RecQty, GRWt, UOM, PackCount, PackType, Buyer, Comments, idShowRow, POLinenumber 
                        FROM OF_IMPPO WHERE IdCons = $olsConsolidationNo";

        $consolidationsPOs = ExecuteSQLQuery $oFlowV1Con $sourceQuery "MSSQL";

        foreach($conPO in $consolidationsPOs)
        {
            $queryInsert = "INSERT INTO Import_ConsolidationPurchaseOrders(ConsolidationID, PlantID, PurchaseOrderNo, PurchaseOrderItemNo, MaterialNo, Delivery, 
                            OrderQuantity, RequirementQuantity, GRWT, PackCount, PackType, Buyer, SortOrder, Comments, CreatedBy, CreatedOn) VALUES ('" + $newConsolidationNo + 
                            "', '" + $oFlowPlantID + "', '" + $conPO.PONumber + "', '" + $conPO.POLinenumber + "', '" + $conPO.Material.PadLeft(18, "0") + "', '" + $conPO.Delivery + "', '" + $conPO.OrdQty + 
                            "', '" + $conPO.RecQty + "', '" + $conPO.GRWt + "', '" + $conPO.PackCount + "', '" + $conPO.PackType + "', '" + $conPO.Buyer + "', '" + $conPO.idShowRow + "', '" + $conPO.Comments + "', 'NXD7826', NOW());";
            $rowAffected = ExecuteNonQuery $oFlowV2Con $queryInsert "MySQL";
            ConsolidationStatus $oFlowV1Con $oFlowV2Con $newConsolidationNo $olsConsolidationNo;
        }
    }
}

function ConsolidationStatus($oFlowV1Con, $oFlowV2Con, $newConsolidationNo, $olsConsolidationNo) {
    if($olsConsolidationNo -ge 7) { 
        $sourceQuery = "SELECT idCons, Status, CONVERT(VARCHAR, ETAPort, 23) AS ETAPort, CONVERT(VARCHAR, ETAPlant, 23) AS ETAPlant, Comment, Commenter, CONVERT(VARCHAR, CTimeStamp, 121) AS CTimeStamp FROM OF_IMPCStat WHERE IdCons = $olsConsolidationNo";
        $consolidationsStatus = ExecuteSQLQuery $oFlowV1Con $sourceQuery "MSSQL";

        foreach($conStatus in $consolidationsStatus)
        {
            $queryInsert = "INSERT INTO Import_ConsolidationStatus (ConsolidationID, Status, ETAPort, ETAPlant, Comment, CreatedBy, CreatedOn) VALUES ('" + $newConsolidationNo + 
            "', '" + $conStatus.Status + "', CAST('" + $conStatus.ETAPort + "' AS DATETIME), CAST('" + $conStatus.ETAPlant + "' AS DATETIME), '" + $conStatus.Comment + "', '" + $conStatus.Commenter + "', CAST('" + $conStatus.CTimeStamp + "' AS DATETIME));";
            $rowAffected = ExecuteNonQuery $oFlowV2Con $queryInsert "MySQL";
        }
    }
}

function DataCleanupActivity($oFlowV2Con) {
    $cleanupUpdate = "UPDATE Import_Consolidation SET Country = NULL WHERE Country = 'Select Country';",
                    "UPDATE Import_Consolidation SET ISF = NULL WHERE ISF = '-- Select ';",
                    "UPDATE Import_Consolidation SET ContainerType = NULL WHERE ContainerType = '-- Select ';",
                    "UPDATE Import_Consolidation SET Container = NULL WHERE Container = '';",
                    "UPDATE Import_Consolidation SET InvoiceNo = NULL WHERE InvoiceNo = '';",
                    "UPDATE Import_Consolidation SET ITNumber = NULL WHERE ITNumber = '';",
                    "UPDATE Import_Consolidation SET Comments = NULL WHERE Comments = '';",
                    "UPDATE Import_Consolidation SET LoadingPortStaging = NULL WHERE LoadingPortStaging = '';",
                    "UPDATE Import_Consolidation SET InvoiceInfo = NULL WHERE InvoiceInfo = '';",
                    "UPDATE Import_Consolidation SET Vessel = NULL WHERE Vessel = '';",
                    "UPDATE Import_Consolidation SET ShipTerms = NULL WHERE ShipTerms = '-- Select ';",
                    "UPDATE Import_Consolidation SET Country = NULL WHERE Country = 'Select Country';",
                    "UPDATE Import_Consolidation SET COFMA = NULL WHERE COFMA = '-- Select ';";
    foreach ($clean in $cleanupUpdate)
    {
        $consolidationsStatus = ExecuteSQLQuery $oFlowV2Con $clean "MySQL";
    }
}

Try
{
    $oFlowV1Con = ConnectSQL $msSqlConString "usubofldbpv1.global.iff.com" "MSSQL";
    $oFlowV2Con = ConnectSQL $mySqlConString "oflowdev.cwm3ubatqbgi.us-east-1.rds.amazonaws.com" "MySQL";
    
    #insertMaterials $oFlowV1Con $oFlowV2Con;
    insertConsolidation $oFlowV1Con $oFlowV2Con;
}
Catch
{
    Write-Host "ERROR : Unable to run query : $queryInsert `n$Error[0]" -ForegroundColor Red
}
Finally
{
    DisconnectSQL $oFlowV1Con; DisconnectSQL $oFlowV2Con;
    Write-Host "Closing Connection." -ForegroundColor Red
}

# To Run
# .Migrate_Import_Data_To_Aurora.ps1 -oFlowDBName:"oFlowTFR" -oFlowPlantID:"0373"
