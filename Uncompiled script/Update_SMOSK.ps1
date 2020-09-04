
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework




function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}






Function update {


    $url = "http://www.smosk.net/downloads/AddonManager.zip"
    $outfile = ".\Downloads\updater.zip"


    Invoke-WebRequest -Uri $url -OutFile $outfile


    Unzip -outpath ".\Downloads\" -zipfile $outfile

    Copy-Item -Path ".\Downloads\AddonManager\SMOSK.exe" -Destination .\SMOSK.exe -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Uncompiled script\SMOSK_AddonManager.ps1" -Destination ".\Uncompiled script\SMOSK_AddonManager.ps1" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Uncompiled script\Update_SMOSK.ps1" -Destination ".\Uncompiled script\Update_SMOSK.ps1" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\Title_Icon.ico" -Destination ".\Resources\Title_Icon.ico" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\Splash.png" -Destination ".\Resources\Splash.png" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\Wallpaper.png" -Destination ".\Resources\wallpaper.png" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\wallpaper_search.png" -Destination ".\Resources\wallpaper_search.png" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\close.png" -Destination ".\Resources\close.png" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\minimize.png" -Destination ".\Resources\minimize.png" -Recurse -Force
    Copy-Item -Path ".\Downloads\AddonManager\Resources\search.png" -Destination ".\Resources\search.png" -Recurse -Force

    Remove-Item -LiteralPath ".\Downloads\AddonManager\" -Force -Recurse
    Remove-Item -LiteralPath ".\Downloads\updater.zip" -Force -Recurse

    [System.Windows.MessageBox]::Show("Updated to latest Version of SMOSK!",'SMOSK! Updater','OK','Information')

}

Function DrawGUI {

    #*** Close Smosk.exe ******************************************************************************************************
    $CloseSMOSK = New-Object System.Windows.Forms.Form
    $CloseSMOSK.Text ="SMOSK - Classic Addon Manager"
    $CloseSMOSK.minimumSize = New-Object System.Drawing.Size(500,250) 
    $CloseSMOSK.maximumSize = New-Object System.Drawing.Size(500,250) 
    $CloseSMOSK.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen 
    $CloseSMOSK.AutoSize = $true
    $CloseSMOSK.SizeGripStyle = "Hide"
    $CloseSMOSK.FormBorderStyle = [System.Windows.Forms.BorderStyle]::"None"
    $CloseSMOSK.BackColor = [System.Drawing.Color]::Black
    $CloseSMOSK.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\Splash.png")
    $CloseSMOSK.BackgroundImageLayout = "Zoom"


    #*** Button close
    $ButtonClose = New-Object System.Windows.Forms.Button
    $ButtonClose.Name = "ButtonCloseMainForm"
    $ButtonClose.Anchor = "Top","Left"
    $ButtonClose.Location = New-Object System.Drawing.Point(475, 5)
    $ButtonClose.Size = New-Object System.Drawing.Size(20, 20)
    $ButtonClose.TextAlign = "BottomCenter"
    $ButtonClose.FlatStyle = "PopUp"
    $ButtonClose.UseVisualStyleBackColor = $true
    $ButtonClose.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\close.png")
    $ButtonClose.BackgroundImageLayout = "Zoom"
    $ButtonClose.ForeColor = [System.Drawing.Color]::White
    $ButtonClose.BackColor = [System.Drawing.Color]::Black
    $ButtonClose.UseMnemonic = $true
    $ButtonClose.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $CloseSMOSK.Controls.Add($ButtonClose)

    #*** Button minimize
    $ButtonMinimize = New-Object System.Windows.Forms.Button
    $ButtonMinimize.Name = "ButtonCloseMainForm"
    $ButtonMinimize.Anchor = "Top","Left"
    $ButtonMinimize.Location = New-Object System.Drawing.Point(450, 5)
    $ButtonMinimize.Size = New-Object System.Drawing.Size(20, 20)
    #$ButtonMinimize.Text = "_"
    $ButtonMinimize.FlatStyle = "PopUp"
    $ButtonMinimize.UseVisualStyleBackColor = $true
    $ButtonMinimize.BackgroundImage = [system.drawing.image]::FromFile(".\Resources\minimize.png")
    $ButtonMinimize.BackgroundImageLayout = "Zoom"
    $ButtonMinimize.ForeColor = [System.Drawing.Color]::White
    $ButtonMinimize.BackColor = [System.Drawing.Color]::Black
    
    $ButtonMinimize.Add_Click({
        $CloseSMOSK.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })

    $CloseSMOSK.Controls.Add($ButtonMinimize)

    #*** Label 
    $LabelUpdate = New-Object System.Windows.Forms.Label
    $LabelUpdate.Text = "SMOSK! Updater" 
    $LabelUpdate.Location  = New-Object System.Drawing.Point(0,50)
    $LabelUpdate.Size = New-Object System.Drawing.Size(500,50)
    $LabelUpdate.TextAlign = "MiddleCenter"
    $LabelUpdate.BackColor = [System.Drawing.Color]::Transparent
    $LabelUpdate.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $LabelUpdate.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($LabelUpdate)

    #*** Label 
    $LabelStatus = New-Object System.Windows.Forms.Label
    $LabelStatus.Text = "Smosk.exe is still running
click update to close the program and continue" 
    $LabelStatus.Location  = New-Object System.Drawing.Point(0,100)
    $LabelStatus.Size = New-Object System.Drawing.Size(500,50)
    $LabelStatus.TextAlign = "MiddleCenter"
    $LabelStatus.BackColor = [System.Drawing.Color]::Transparent
    $LabelStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffa500")
    $LabelStatus.Font = [System.Drawing.Font]::new("Georgia", 10, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($LabelStatus)


    #*** Button Continue
    $ButtonContinue = New-Object System.Windows.Forms.Button
    $ButtonContinue.Location = New-Object System.Drawing.Size(200,150)
    $ButtonContinue.Size = New-Object System.Drawing.Size(100,40)
    $ButtonContinue.Text = "Update"
    $ButtonContinue.FlatStyle = "Popup"
    $ButtonContinue.Anchor = "Bottom,Left"
    $ButtonContinue.ForeColor = [System.Drawing.Color]::White
    $ButtonContinue.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0063b1")
    $ButtonContinue.Font = [System.Drawing.Font]::new("Georgia", 7, [System.Drawing.FontStyle]::Bold)
    $CloseSMOSK.Controls.Add($ButtonContinue)

    $ButtonContinue.Add_Click({
        
            
        get-process | where-object {$_.path -eq (resolve-path -LiteralPath ".\SMOSK.exe").Path} | Stop-Process -Force
        update
        Start-Process ".\SMOSK.exe"
        $CloseSMOSK.Dispose()
        
    })

 



    $CloseSMOSK.ShowDialog()
    
    $CloseSMOSK.Dispose()

    
}



try {

    if(get-process | where-object {$_.path -eq (resolve-path -LiteralPath ".\SMOSK.exe").Path}){
        DrawGUI
    } else {
        update
    }

} catch {
    $OSInfo = (get-computerinfo | select-object -property OSName, OSVersion)
    if (Test-Path ".\Resources\update_log.txt") {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\update_log.txt" -Append
        $_ | Out-File ".\Resources\update_log.txt" -Append
    } else {
        "******* " + (get-date -Format "yyyy-MM-dd hh:mm") + " | " + $OSInfo.OSName + " - " + $OSInfo.OSVersion + " *******" | Out-File ".\Resources\update_log.txt"
        $_ | Out-File ".\Resources\update_log.txt" -Append
        
    }
    [System.Windows.MessageBox]::Show("Something have caused the updater to fail. 

Make sure that the download folder is empty.

See error log for more info.
.\Resources\update_log.txt",'SMOSK! Error','OK','Information')

}










 

