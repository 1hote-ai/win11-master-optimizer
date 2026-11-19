# Safety.psm1 - Module for System Restore Point creation, state snapshots, and rollback engine
# Encoding: UTF-8

Set-StrictMode -Version Latest

$Script:BackupDir = Join-Path -Path $PSScriptRoot -ChildPath "..\Backups"

function Initialize-SafetyModule {
    if (-not (Test-Path -Path $Script:BackupDir)) {
        New-Item -Path $Script:BackupDir -ItemType Directory -Force | Out-Null
    }
}

function New-OptimizerRestorePoint {
    [CmdletBinding()]
    param(
        [string]$Description = "Win11Optimizer_Checkpoint"
    )

    Initialize-SafetyModule

    Write-Host "[Safety] Подготовка точки восстановления системы..." -ForegroundColor Cyan

    try {
        # Проверяем и запускаем службу теневого копирования / восстановления
        $srService = Get-Service -Name "srservice" -ErrorAction SilentlyContinue
        if ($srService -and $srService.Status -ne 'Running') {
            Start-Service -Name "srservice" -ErrorAction SilentlyContinue
        }
        $vssService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if ($vssService -and $vssService.Status -ne 'Running') {
            Start-Service -Name "VSS" -ErrorAction SilentlyContinue
        }

        # Включаем защиту системы на системном диске, если выключена
        $systemDrive = $env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($systemDrive)) { $systemDrive = "C:" }
        try {
            Enable-ComputerRestore -Drive "$systemDrive\" -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Enable-ComputerRestore notice: $_"
        }

        # Обход 24-часового лимита Windows на создание точек восстановления через реестр
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        if (Test-Path $srKey) {
            Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $pointDesc = "${Description}_$timestamp"
        Checkpoint-Computer -Description $pointDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[Safety] Точка восстановления успешно создана: $pointDesc" -ForegroundColor Green
        return @{ Success = $true; Description = $pointDesc }
    }
    catch {
        Write-Host "[Safety WARNING] Не удалось создать точку восстановления: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[Safety] Резервные копии реестра будут сохранены локально в папку Backups." -ForegroundColor Yellow
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Save-RegistrySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [array]$RegistryTargets, # Array of @{ Path = '...'; Name = '...'; Hive = 'HKLM/HKCU' }
        [switch]$DryRun = $false
    )

    if ($DryRun) {
        return $null
    }

    Initialize-SafetyModule

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFileName = "Backup_${Category}_$timestamp.json"
    $backupFilePath = Join-Path -Path $Script:BackupDir -ChildPath $backupFileName

    $snapshotData = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($target in $RegistryTargets) {
        $path = $target.Path
        $name = $target.Name

        $entry = [PSCustomObject]@{
            Path        = $path
            Name        = $name
            KeyExists   = $false
            ValueExists = $false
            Value       = $null
            Type        = $null
        }

        if (Test-Path -Path $path) {
            $entry.KeyExists = $true
            try {
                $prop = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
                $entry.ValueExists = $true
                $entry.Value = $prop.$name
                
                # Определение типа реестра через .NET Microsoft.Win32.Registry
                $regKey = Get-Item -Path $path
                $valKind = $regKey.GetValueKind($name)
                $entry.Type = $valKind.ToString()
            } catch {
                # Значение не существует в существующем ключе
                $entry.ValueExists = $false
            }
        } else {
            $entry.KeyExists = $false
            $entry.ValueExists = $false
        }

        $snapshotData.Add($entry)
    }

    $finalPayload = [PSCustomObject]@{
        Category  = $Category
        Timestamp = $timestamp
        Date      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Entries   = $snapshotData
    }

    $json = $finalPayload | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($backupFilePath, $json, [System.Text.Encoding]::UTF8)

    Write-Host "[Safety] Снимок состояния реестра сохранен: $backupFileName" -ForegroundColor Cyan
    return $backupFilePath
}

function Restore-RegistrySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Category = "",
        [Parameter(Mandatory = $false)]
        [string]$BackupFilePath = ""
    )

    Initialize-SafetyModule

    $targetFile = $null

    if (-not [string]::IsNullOrWhiteSpace($BackupFilePath) -and (Test-Path $BackupFilePath)) {
        $targetFile = $BackupFilePath
    } elseif (-not [string]::IsNullOrWhiteSpace($Category)) {
        # Ищем самый свежий бэкап категории
        $files = Get-ChildItem -Path $Script:BackupDir -Filter "Backup_${Category}_*.json" | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt 0) {
            $targetFile = $files[0].FullName
        }
    } else {
        # Ищем самый свежий бэкап вообще
        $files = Get-ChildItem -Path $Script:BackupDir -Filter "Backup_*.json" | Sort-Object LastWriteTime -Descending
        if ($files.Count -gt 0) {
            $targetFile = $files[0].FullName
        }
    }

    if (-not $targetFile -or -not (Test-Path $targetFile)) {
        Write-Host "[Safety WARNING] Файл резервной копии не найден." -ForegroundColor Yellow
        return $false
    }

    Write-Host "[Safety] Откат из снимка: $(Split-Path $targetFile -Leaf)..." -ForegroundColor Yellow
    $rawJson = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
    $payload = $rawJson | ConvertFrom-Json

    $restoredCount = 0

    foreach ($entry in $payload.Entries) {
        $path = $entry.Path
        $name = $entry.Name

        try {
            if (-not $entry.KeyExists) {
                # Ключа раньше не существовало — удаляем созданное значение, и если ключ стал пуст — удаляем ключ
                if (Test-Path $path) {
                    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                    $keyItem = Get-Item -Path $path -ErrorAction SilentlyContinue
                    if ($keyItem -and $keyItem.ValueCount -eq 0 -and $keyItem.SubKeyCount -eq 0) {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    }
                }
            } elseif (-not $entry.ValueExists) {
                # Ключ был, но значения не было — удаляем добавленное значение
                if (Test-Path $path) {
                    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                }
            } else {
                # Значение было — восстанавливаем исходное значение и тип
                if (-not (Test-Path $path)) {
                    New-Item -Path $path -Force | Out-Null
                }

                $regType = "String"
                switch ($entry.Type) {
                    "DWord"    { $regType = "DWord" }
                    "QWord"    { $regType = "QWord" }
                    "Binary"   { $regType = "Binary" }
                    "MultiString" { $regType = "MultiString" }
                    "ExpandString" { $regType = "ExpandString" }
                    default    { $regType = "String" }
                }

                Set-ItemProperty -Path $path -Name $name -Value $entry.Value -Type $regType -Force -ErrorAction Stop
            }
            $restoredCount++
        } catch {
            Write-Verbose "Error restoring $($entry.Path)\$($entry.Name): $_"
        }
    }

    Write-Host "[Safety] Успешно восстановлено параметров: $restoredCount из $($payload.Entries.Count)" -ForegroundColor Green
    return $true
}

function Get-BackupHistory {
    Initialize-SafetyModule
    $files = Get-ChildItem -Path $Script:BackupDir -Filter "Backup_*.json" | Sort-Object LastWriteTime -Descending
    $history = @()
    foreach ($file in $files) {
        try {
            $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $history += [PSCustomObject]@{
                FileName  = $file.Name
                Category  = $raw.Category
                Date      = $raw.Date
                Count     = $raw.Entries.Count
                FullPath  = $file.FullName
            }
        } catch {
            # Skip invalid files
        }
    }
    return $history
}

Export-ModuleMember -Function New-OptimizerRestorePoint, Save-RegistrySnapshot, Restore-RegistrySnapshot, Get-BackupHistory
