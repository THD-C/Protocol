param(
    $Version = "main"
)

New-Variable -Name "PROTO_REPO" -Value "https://github.com/THD-C/Protocol.git" -Option ReadOnly -Scope Script -Force
New-Variable -Name "PROTO_REPO_PATH" -Value "./Protocol" -Option ReadOnly -Scope Script -Force
New-Variable -Name "PROTO_PATH" -Value "./Protocol/proto" -Option ReadOnly -Scope Script -Force
New-Variable -Name "ROOT_PACKAGE_DIR" -Value "./thdcgrpc" -Option ReadOnly -Scope Script -Force
New-Variable -Name "SETUP_CONFIG_FILE" -Value "./cfg.py" -Option ReadOnly -Scope Script -Force

function Invoke-Main {
    Set-PythonEnv
    Remove-ProtobufRepo
    Get-ProtobufRepo
    $ProtoDirs = Invoke-ProtobufCompiler
    Remove-ProtobufRepo
    New-InitFilesInSubDirs -ProtoDirs $ProtoDirs
    New-MainInitFiles -ProtoDirs $ProtoDirs
}
function Set-PythonEnv {
    pip install -r ./build/requirements.txt
}
function Get-ProtobufRepo {
    $ScriptRoot = (Get-Location).Path
    git clone $PROTO_REPO
    Set-Location -Path $PROTO_REPO_PATH
    git checkout "$Version"
    Set-Location -Path $ScriptRoot
}
function Invoke-ProtobufCompiler {
    $ProtoFiles = (Get-ChildItem -Path $PROTO_REPO_PATH -Filter *.proto -Recurse)
    $ProtoDirs = @()
    foreach ($file in $ProtoFiles) {
        $ProtoFilePath = (Resolve-Path -Path $file.FullName -Relative -RelativeBasePath $PROTO_PATH).Replace("./", "")
        $ProtoDirs += $(Split-Path -Path $ProtoFilePath -Parent)
        python -m grpc_tools.protoc --proto_path=./Protocol/proto/ --python_out=. --grpc_python_out=. --pyi_out=. "$ProtoFilePath"
    }

    $ProtoDirs = $($ProtoDirs | Sort-Object -Unique)
    if (Test-Path -Path $ROOT_PACKAGE_DIR) {
        Remove-Item -Path $ROOT_PACKAGE_DIR -Recurse -Force
    }
    $null = New-Item -Path $ROOT_PACKAGE_DIR -ItemType Directory

    foreach ($dir in $ProtoDirs) {
        Move-Item -Path "./$dir" -Destination "./$ROOT_PACKAGE_DIR/$dir" -Force
    }
    return $ProtoDirs
}
function Remove-ProtobufRepo {
    if (Test-Path -Path $PROTO_REPO_PATH) {
        Remove-Item -Path $PROTO_REPO_PATH -Recurse -Force
    }
}
function New-InitFilesInSubDirs {
    param (
        $ProtoDirs
    )
    $RootDirName = $ROOT_PACKAGE_DIR.Split("/")[-1]
    foreach ($dir in $ProtoDirs) {
        $InitFilePath = "$RootDirName/$dir/__init__.py"
        if ((Test-Path -Path $InitFilePath)) {
            Remove-Item -Path $InitFilePath -Force
        }
        Get-ChildItem -Path "$RootDirName/$dir" -File | ForEach-Object {
            "from $RootDirName.$dir.$($_.Name.Split(".")[0]) import *" | Out-File -FilePath $InitFilePath -Append
        }
    }
}
function New-MainInitFiles {
    param (
        $ProtoDirs
    )
    $InitFilePath = "$ROOT_PACKAGE_DIR/__init__.py"
    $RootDirName = $ROOT_PACKAGE_DIR.Split("/")[-1]
    if ((Test-Path -Path $InitFilePath)) {
        Remove-Item -Path $InitFilePath -Force
    }
    foreach ($dir in $ProtoDirs) {
        "import $RootDirName.$dir" | Out-File -FilePath $InitFilePath -Append
    }
}

Invoke-Main