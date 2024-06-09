# Define the Software class
class Software {
    [string]$Name
    [string]$Id
    [string]$Version
}

# Function to parse winget output
function Parse-WingetOutput {
    param (
        [string]$wingetOutput
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $lines = $wingetOutput.Split([Environment]::NewLine)

    # Find the line that starts with Name, it contains the header
    $fl = 0
    while ($fl -lt $lines.Length -and -not $lines[$fl].StartsWith("Name")) {
        $fl++
    }

    # Ensure we found the header
    if ($fl -ge $lines.Length) {
        Write-Host "No header line found in winget output."
        return @()
    }

    # Line $fl has the header, we can find char positions for ID and Version
    $idStart = $lines[$fl].IndexOf("Id")
    $versionStart = $lines[$fl].IndexOf("Version")

    Write-Host "Full: $($lines[$fl])"
    Write-Host "IdStart: $idStart VersionStart: $versionStart"



    # Ensure the indices are valid
    if ($idStart -eq -1 -or $versionStart -eq -1 -or $sourceStart -eq -1) {
        Write-Host "Invalid header format in winget output."
        return @()
    }

    # Now cycle in real package and split accordingly
    $softwareList = @()
    for ($i = $fl + 1; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Length -gt ($sourceStart + 1) -and -not $line.StartsWith('-')) {
            try {
                
                $nameEnd = $line.IndexOf(' ', 0) 
                $name = $line.Substring(0, $nameEnd).TrimEnd()

                write-host "got name: $name"

                $idEnd = $line.IndexOf(' ', $idStart) 
                $id = $line.Substring($idStart, $idEnd - $idStart).TrimEnd()
                
                write-host "$idStart $idEnd    -- got id: {$id}"

                $versionEnd = $line.IndexOf(' ', $versionStart)
                $version = $line.Substring($versionStart, $versionEnd - $versionStart).TrimEnd()
                write-host "$versionStart $versionEnd  got version: $version"
                
                $software = [Software]::new()
                $software.Name = $name
                $software.Id = $id
                $software.Version = $version
                
                $softwareList += $software
            } catch {
                Write-Host "Error parsing line: $line"
            }
        }
    }

    return $softwareList
}





function Invoke-OnlineSearchDialog {
    <#

    .SYNOPSIS
        Enable Editable Text box Alternate Scartch path

    .PARAMETER Button
    #>

    #$sync.WPFMicrowinISOScratchDir.IsChecked 





# Function to handle the Search button click event in the modal dialog
$Search_Click = {
        # Retrieve the value from the TextBox in the modal dialog
        $inputValue = $ModalWindow.FindName("InputTextBox").Text

        Write-Host "Input Value: $inputValue"
        
        # Check if the input value is empty or whitespace
        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            Write-Host "Error: Input value cannot be empty or whitespace."
            return
        }

        # Check if winget is available
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-Host "winget is not installed on this system."
            return
        }

        Write-Host "Running winget..."
        $wingetOutput = & winget search $inputValue | Out-String -Stream
        
        Write-Host "Done!"

        # Check if the command ran successfully
        if ($LASTEXITCODE -ne 0) {
            Write-Host "An error occurred while running winget search: $wingetOutputString"
            return
        }

        # Parse winget output
        $results = Parse-WingetOutput -wingetOutput ($wingetOutput -join "`n")

        $dataGrid = $ModalWindow.FindName("ResultsDataGrid")
        $dataGrid.ItemsSource = $results


    ################## end seach click

}


$selectAllCheckBox_Click = {
    param (
        $sender, $eventArgs
    )
    $isChecked = $sender.IsChecked
    foreach ($item in $resultsDataGrid.ItemsSource) {
        $item.IsSelected = $isChecked
    }
    $resultsDataGrid.Items.Refresh()
}




$Add_Click = {
    $selectedSoftware = $resultsDataGrid.ItemsSource | Where-Object { $_.IsSelected }
    $checkboxXaml = ""

    foreach ($software in $selectedSoftware) {
        $cleanId = ($software.Id -replace '[^a-zA-Z]', '')
        $checkboxXaml += "<CheckBox Name='WPFOnline$cleanId' Content='$($software.Id)' ToolTip='$($software.Name)' Margin='0,0,2,0'/>`n"
        Write-Host $checkboxXaml
    }
    $newXAML = @"
    <StackPanel Background="transparent" SnapsToDevicePixels="True">
    <Label Name="WPFLabelOnline" Content="Online Other " FontSize="16"/>
    $checkboxXaml
    </StackPanel>
"@

Write-Host $newXAML

$BorderElement = $sync["Form"].FindName("Border_applications_Panel0")

# Check if the Border element is found
if ($BorderElement -eq $null) {
    Write-Host "Border element 'Border_applications_Panel0' not found."
    return
}

# Check if the Border element has a child and if it's a StackPanel
if ($BorderElement.Child -isnot [Windows.Controls.StackPanel]) {
    Write-Host "The child of the Border element is not a StackPanel."
    return
}

$StackPanel = [Windows.Controls.StackPanel]$BorderElement.Child

# Retrieve the current XAML of the StackPanel
$currentXaml = [Windows.Markup.XamlWriter]::Save($StackPanel)

# Print the current XAML for debugging
Write-Debug "Current XAML of StackPanel:"
Write-Debug $currentXaml

# Manually construct the updated XAML
$insertIndex = $currentXaml.IndexOf(">") + 1
$updatedXaml = $currentXaml.Insert($insertIndex, $newXaml)

# Print the updated XAML for debugging
Write-Debug "Updated XAML of StackPanel:"
Write-Debug $updatedXaml

# Parse the updated XAML to create a new StackPanel
$newStackPanel = [Windows.Markup.XamlReader]::Parse($updatedXaml)

# Replace the existing StackPanel with the new one
$BorderElement.Child = $newStackPanel
}











 
    $Close_Click = {
        # Close the modal window
        $ModalWindow.Close()
    }



    # Load the modal window
    $ModalWindow = [Windows.Markup.XamlReader]::Parse($internetSearchXaml)
    
    #Add the event handlers for the buttons
    $ModalWindow.FindName("AddButton").Add_Click($Add_Click)
    $ModalWindow.FindName("CloseButton").Add_Click($Close_Click)
    $ModalWindow.FindName("SelectAllCheckBox").Add_Click($SelectAllCheckBox_Click)
    
    $ModalWindow.FindName("SearchButton").Add_Click($Search_Click)


# Set focus to the InputTextBox when the window is loaded
$ModalWindow.Add_Loaded({
    $ModalWindow.FindName("InputTextBox").Focus() | Out-Null
})

# # Add the KeyBinding to handle Enter key press for the Search button
# $ModalWindow.InputBindings.Add((New-Object System.Windows.Input.KeyBinding ([System.Windows.Input.ApplicationCommands]::Find, "Enter", "None")))


$ModalWindow.Add_MouseLeftButtonDown({
    $ModalWindow.DragMove()
})



    $ModalWindow.Owner = $sync["Form"] 
    # Show the modal window
    $ModalWindow.ShowDialog()
    
    #$sync.MicrowinScratchDir.Text =  Join-Path $filePath "\"
}
